#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb@iredmail.org>
# Purpose: Enable Postfix postscreen.

export KERNEL_NAME="$(uname -s | tr '[a-z]' '[A-Z]')"
export DATE="$(/bin/date +%Y.%m.%d.%H.%M.%S)"

# Postfix config files: main.cf, master.cf
export POSTFIX_DAEMON_USER='postfix'
export POSTFIX_DAEMON_GROUP='postfix'
export POSTFIX_ROOT_DIR='/etc/postfix'
export POSTFIX_DATA_DIRECTORY='/var/lib/postfix'   # postconf data_directory

if [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
    export POSTFIX_ROOT_DIR='/usr/local/etc/postfix'
    export POSTFIX_DATA_DIRECTORY='/var/db/postfix'
elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
    export POSTFIX_DAEMON_USER='_postfix'
    export POSTFIX_DAEMON_GROUP='_postfix'
    export POSTFIX_DATA_DIRECTORY='/var/postfix'
fi

export MAIN_CF="${POSTFIX_ROOT_DIR}/main.cf"
export MASTER_CF="${POSTFIX_ROOT_DIR}/master.cf"
export POSTSCREEN_DNSBL_REPLY="${POSTFIX_ROOT_DIR}/postscreen_dnsbl_reply"
export POSTSCREEN_ACCESS_CIDR="${POSTFIX_ROOT_DIR}/postscreen_access.cidr"

# Get Postfix version number.
export POSTFIX_VERSION="$(postconf mail_version 2>/dev/null | awk '{print $NF}')"

# postscreen requires Postfix 2.8 or later.
if echo ${POSTFIX_VERSION} | grep '^2\.[01234567]\.' &>/dev/null; then
    echo "<ERROR> postscreen requires Postfix 2.8 or later, you're running ${POSTFIX_VERSION}."
    exit 255
fi

backup_file()
{
    # Usage: backup_file file1 [file2 file3 ... fileN]
    if [ X"$#" != X"0" ]; then
        for f in $@; do
            if [ -f ${f} ]; then
                echo -e "* [BACKUP] ${f} -> ${f}.${DATE}."
                cp -f ${f} ${f}.${DATE}
            fi
        done
    fi
}

backup_file ${MAIN_CF} ${MASTER_CF} ${POSTSCREEN_ACCESS_CIDR} ${POSTSCREEN_DNSBL_REPLY}

echo "* Comment out 'smtp inet ... smtpd' service in ${MASTER_CF}."
perl -pi -e 's/^(smtp .*inet.*smtpd)$/#${1}/g' ${MASTER_CF}

echo "* Uncomment the new 'smtpd pass ... smtpd' service in ${MASTER_CF}."
perl -pi -e 's/^#(smtpd.*pass.*smtpd)$/${1}/g' ${MASTER_CF}

echo "* Uncomment the new "smtp inet ... postscreen" service in ${MASTER_CF}."
perl -pi -e 's/^#(smtp *.*inet.*postscreen)$/${1}/g' ${MASTER_CF}

echo "* Uncomment the new 'tlsproxy unix ... tlsproxy' service in ${MASTER_CF}."
perl -pi -e 's/^#(tlsproxy.*unix.*tlsproxy)$/${1}/g' ${MASTER_CF}

echo "* Uncomment the new 'dnsblog unix ... dnsblog' service in ${MASTER_CF}."
perl -pi -e 's/^#(dnsblog.*unix.*dnsblog)$/${1}/g' ${MASTER_CF}

echo "* Update ${MAIN_CF} to enable postscreen."
postconf -e postscreen_dnsbl_threshold=2
postconf -e postscreen_dnsbl_sites='zen.spamhaus.org*3 b.barracudacentral.org*2 bl.spameatingmonkey.net*2 bl.spamcop.net dnsbl.sorbs.net psbl.surriel.com bl.mailspike.net swl.spamhaus.org*-4 list.dnswl.org=127.[0..255].[0..255].0*-2 list.dnswl.org=127.[0..255].[0..255].1*-3 list.dnswl.org=127.[0..255].[0..255].[2..255]*-4'

postconf -e postscreen_dnsbl_reply_map="texthash:${POSTSCREEN_DNSBL_REPLY}"
cat > ${POSTSCREEN_DNSBL_REPLY} <<EOF
# Secret DNSBL name           Name in postscreen(8) replies
EOF

postconf -e postscreen_access_list="permit_mynetworks, cidr:${POSTSCREEN_ACCESS_CIDR}"
cat > ${POSTSCREEN_ACCESS_CIDR} <<EOF
# Rules are evaluated in the order as specified.
#1.2.3.4 permit
#2.3.4.5 reject

# Permit local clients
192.168.254.0/24 permit
EOF

postconf -e postscreen_greet_action='enforce'
postconf -e postscreen_dnsbl_action='enforce'
postconf -e postscreen_blacklist_action='enforce'

# Require Postfix-2.11.
if echo ${POSTFIX_VERSION} | grep '^2\.[123456789][123456789]' &>/dev/null; then
    postconf -e postscreen_dnsbl_whitelist_threshold='-2'
fi

# From Postfix author Wietse Venema, posted in Postfix mailing list on Jul 14, 2015:
# ----
# I would not enable the "after 220 greeting" protocol tests, because
# some senders that pass the tests will not retry (mail will never
# be delivered), and some will retry from a different client IP address
# (mail will be delayed).  Whitelisting Google does not solve the
# problem because it also affects other senders.
#
# The amount of mail stopped by these tests is so small that it is not
# worth the trouble at this time.
# ----
#postscreen_pipelining_enable=yes
#postscreen_pipelining_action=
#
#postscreen_non_smtp_command_enable=yes
#postscreen_non_smtp_command_action=
#
#postscreen_bare_newline_enable=yes
#postscreen_bare_newline_action=

echo "* Reloading postfix service to read the new configuration."
postfix reload

echo "* postscreen is now enabled."
