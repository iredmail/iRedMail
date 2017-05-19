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

It can *NOT* be the same as server hostname: ${HOSTNAME}.

We need Postfix to accept emails sent to system accounts (e.g. root), if your mail domain is same as server hostname, Postfix won't accept any email sent to this mail domain.
" 20 76 2>${RUNTIME_DIR}/.first_domain

    FIRST_DOMAIN="$(cat ${RUNTIME_DIR}/.first_domain | tr '[A-Z]' '[a-z]')"

    echo "${FIRST_DOMAIN}" | grep '\.' &>/dev/null
    [ X"$?" == X"0" -a X"${FIRST_DOMAIN}" != X"${HOSTNAME}" ] && break
done

export FIRST_DOMAIN="${FIRST_DOMAIN}"
echo "export FIRST_DOMAIN='${FIRST_DOMAIN}'" >> ${IREDMAIL_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.first_domain

# Domain admin password
while : ; do
    ${DIALOG} \
    --title "Password for the mail domain administrator" \
    --passwordbox "\
Please specify password for the mail domain administrator:

* ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}

You can login to webmail and iRedAdmin with this account.

WARNING:

* Do *NOT* use special characters (like \$, #, @, white space) in password.
* EMPTY password is *NOT* permitted.
* Sample password: $(${RANDOM_STRING})
" 20 76 2>${RUNTIME_DIR}/.first_domain_admin_passwd

    DOMAIN_ADMIN_PASSWD_PLAIN="$(cat ${RUNTIME_DIR}/.first_domain_admin_passwd)"

    [ X"${DOMAIN_ADMIN_PASSWD_PLAIN}" != X"" ] && break
done

export DOMAIN_ADMIN_PASSWD_PLAIN="${DOMAIN_ADMIN_PASSWD_PLAIN}"
echo "export DOMAIN_ADMIN_PASSWD_PLAIN='${DOMAIN_ADMIN_PASSWD_PLAIN}'" >> ${IREDMAIL_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.first_domain_admin_passwd

cat >> ${TIP_FILE} <<EOF
Admin of domain ${FIRST_DOMAIN}:

    * Account: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}
    * Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}

    You can login to iRedAdmin with this account, login name is full email address.

First mail user:
    * Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}
    * Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * SMTP/IMAP auth type: login
    * Connection security: STARTTLS or SSL/TLS

    You can login to webmail with this account, login name is full email address.

EOF
