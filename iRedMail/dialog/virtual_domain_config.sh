#!/usr/bin/env bash

# Author:   Zhang Huangbin <zhb _at_ iredmail.org>

#---------------------------------------------------------------------
# This file is part of iRedMail, which is an open source mail server
# solution for Red Hat(R) Enterprise Linux, CentOS, Debian and Ubuntu.
#
# iRedMail is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# iRedMail is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iRedMail.  If not, see <http://www.gnu.org/licenses/>.
#---------------------------------------------------------------------

# First domain name.
while : ; do
    ${DIALOG} \
    --title "Your first mail domain name" \
    --inputbox "\
Please specify your first mail domain name.

EXAMPLE:

* example.com

WARNING:

It can *NOT* be the same as server hostname: ${HOSTNAME}, please either change your server hostname or use another mail domain name.
" 20 76 2>/tmp/first_domain

    FIRST_DOMAIN="$(cat /tmp/first_domain)"

    echo "${FIRST_DOMAIN}" | grep '\.' &>/dev/null
    [ X"$?" == X"0" -a X"${FIRST_DOMAIN}" != X"${HOSTNAME}" ] && break
done

echo "export FIRST_DOMAIN='${FIRST_DOMAIN}'" >> ${IREDMAIL_CONFIG_FILE}
rm -f /tmp/first_domain

#DOMAIN_ADMIN_NAME
export DOMAIN_ADMIN_NAME='postmaster'
export SITE_ADMIN_NAME="${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}"
echo "export DOMAIN_ADMIN_NAME='${DOMAIN_ADMIN_NAME}'" >>${IREDMAIL_CONFIG_FILE}
echo "export SITE_ADMIN_NAME='${SITE_ADMIN_NAME}'" >>${IREDMAIL_CONFIG_FILE}

# DOMAIN_ADMIN_PASSWD
while : ; do
    ${DIALOG} \
    --title "Password for the mail domain administrator" \
    --passwordbox "\
Please specify password for the mail domain administrator:

* ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}

You can login to webmail and iRedAdmin with this account.

WARNING:

* Do *NOT* use special characters in password right now. e.g. $, #, @.
* EMPTY password is *NOT* permitted.

" 20 76 2>/tmp/first_domain_admin_passwd

    DOMAIN_ADMIN_PASSWD="$(cat /tmp/first_domain_admin_passwd)"

    [ X"${DOMAIN_ADMIN_PASSWD}" != X"" ] && break
done

export DOMAIN_ADMIN_PASSWD_PLAIN="${DOMAIN_ADMIN_PASSWD}"
export SITE_ADMIN_PASSWD="${DOMAIN_ADMIN_PASSWD_PLAIN}"
echo "export DOMAIN_ADMIN_PASSWD_PLAIN='${DOMAIN_ADMIN_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export DOMAIN_ADMIN_PASSWD='${DOMAIN_ADMIN_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export SITE_ADMIN_PASSWD='${SITE_ADMIN_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}
rm -f /tmp/first_domain_admin_passwd

# First mail user and password
export FIRST_USER="${DOMAIN_ADMIN_NAME}"
export FIRST_USER_PASSWD="${DOMAIN_ADMIN_PASSWD}"
export FIRST_USER_PASSWD_PLAIN="${DOMAIN_ADMIN_PASSWD_PLAIN}"
echo "export FIRST_USER='${FIRST_USER}'" >>${IREDMAIL_CONFIG_FILE}
echo "export FIRST_USER_PASSWD='${FIRST_USER_PASSWD}'" >>${IREDMAIL_CONFIG_FILE}
echo "export FIRST_USER_PASSWD_PLAIN='${FIRST_USER_PASSWD_PLAIN}'" >>${IREDMAIL_CONFIG_FILE}

cat >> ${TIP_FILE} <<EOF
Admin of domain ${FIRST_DOMAIN}:

    * Account: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}
    * Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}

    You can login to iRedAdmin with this account, login name is full email address.

First mail user:
    * Username: ${FIRST_USER}@${FIRST_DOMAIN}
    * Password: ${FIRST_USER_PASSWD}
    * SMTP/IMAP auth type: login
    * Connection security: STARTTLS or SSL/TLS

    You can login to webmail with this account, login name is full email address.

EOF
