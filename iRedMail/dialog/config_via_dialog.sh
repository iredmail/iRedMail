#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb(at)iredmail.org)

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

# Note: config file will be sourced in 'conf/core', check_env().

. ${CONF_DIR}/global
. ${CONF_DIR}/core
. ${CONF_DIR}/openldap
. ${CONF_DIR}/roundcube

trap "exit 255" 2

# Initialize config file.
echo '' > ${CONFIG_FILE}

if [ X"${DISTRO}" == X"FREEBSD" ]; then
    DIALOG='dialog'
    PASSWORDBOX='--inputbox'
else
    DIALOG="dialog --colors --no-collapse --insecure \
            --ok-label Next --no-cancel \
            --backtitle ${PROG_NAME}:_Open_Source_Mail_Server_Solution"
    PASSWORDBOX='--passwordbox'
fi

# Welcome message.
${DIALOG} \
    --title "Welcome and thanks for your use" \
    --yesno "\
Thanks for your use of ${PROG_NAME}.
Bug report, feedback, suggestion are always welcome.

* Community: http://www.iredmail.org/forum/
* Admin FAQ: http://www.iredmail.org/faq.html

NOTE:

    Ctrl-C will abort this wizard.
" 20 76

# Exit when user choose 'exit'.
[ X"$?" != X"0" ] && ECHO_INFO "Exit." && exit 0

# VMAIL_USER_HOME_DIR
VMAIL_USER_HOME_DIR="/var/vmail"
${DIALOG} \
    --title "Default mail storage path" \
    --inputbox "\
Please specify a directory for mail storage.
Default is: ${VMAIL_USER_HOME_DIR}

EXAMPLE:

    * ${VMAIL_USER_HOME_DIR}

NOTE:

    * It may take large disk space.
" 20 76 "${VMAIL_USER_HOME_DIR}" 2>/tmp/vmail_user_home_dir

VMAIL_USER_HOME_DIR="$(cat /tmp/vmail_user_home_dir)"
export VMAIL_USER_HOME_DIR="${VMAIL_USER_HOME_DIR}" && echo "export VMAIL_USER_HOME_DIR='${VMAIL_USER_HOME_DIR}'" >> ${CONFIG_FILE}
export STORAGE_BASE_DIR="${VMAIL_USER_HOME_DIR}" && echo "export STORAGE_BASE_DIR='${VMAIL_USER_HOME_DIR}'" >> ${CONFIG_FILE}
export SIEVE_DIR="${VMAIL_USER_HOME_DIR}/sieve" && echo "export SIEVE_DIR='${SIEVE_DIR}'" >>${CONFIG_FILE}
rm -f /tmp/vmail_user_home_dir

# --------------------------------------------------
# --------------------- Backend --------------------
# --------------------------------------------------
${DIALOG} \
    --title "Choose your preferred backend" \
    --radiolist "\
We provide two backends and the homologous webmail programs:

    +------------+---------------+---------------------------+
    | Backend    | Web Mail      | Web-based management tool |
    +------------+---------------+---------------------------+
    | OpenLDAP   |               | iRedAdmin, phpLDAPadmin   |
    +------------+               +---------------------------+
    | MySQL      | Roundcube     | iRedAdmin, phpMyAdmin     |
    +------------+               +---------------------------+
    | PostgreSQL |               | phpPGadmin                |
    +------------+---------------+---------------------------+

TIP:
    * Use SPACE key to select item.

" 20 76 3 \
    'OpenLDAP' 'An open source implementation of LDAP protocol' 'on' \
    'MySQL' "The world's most popular open source database" 'off' \
    'PostgreSQL' 'powerful, open source object-relational database system' 'off' \
    2>/tmp/backend

BACKEND_ORIG="$(cat /tmp/backend)"
if [ X"${BACKEND_ORIG}" == X'OpenLDAP' ]; then
    export BACKEND='OPENLDAP'
elif [ X"${BACKEND_ORIG}" == X'MySQL' ]; then
    export BACKEND='MYSQL'
elif [ X"${BACKEND_ORIG}" == X'PostgreSQL' ]; then
    export BACKEND='PGSQL'
fi
echo "export BACKEND='${BACKEND}'" >> ${CONFIG_FILE}
rm -f /tmp/backend

# For virtual user query in Postfix, Dovecot.
export MYSQL_BIND_USER="${VMAIL_USER_NAME}"
export MYSQL_BIND_PW="$(${RANDOM_STRING})"
echo "export MYSQL_BIND_USER='${MYSQL_BIND_USER}'" >> ${CONFIG_FILE}
echo "export MYSQL_BIND_PW='${MYSQL_BIND_PW}'" >> ${CONFIG_FILE}

# For database management: vmail.
export MYSQL_ADMIN_USER="${VMAIL_ADMIN_USER_NAME}"
export MYSQL_ADMIN_PW="$(${RANDOM_STRING})"
echo "export MYSQL_ADMIN_USER='${MYSQL_ADMIN_USER}'" >> ${CONFIG_FILE}
echo "export MYSQL_ADMIN_PW='${MYSQL_ADMIN_PW}'" >> ${CONFIG_FILE}

# LDAP bind dn & password.
export LDAP_BINDPW="$(${RANDOM_STRING})"
export LDAP_ADMIN_PW="$(${RANDOM_STRING})"
echo "export LDAP_BINDPW='${LDAP_BINDPW}'" >> ${CONFIG_FILE}
echo "export LDAP_ADMIN_PW='${LDAP_ADMIN_PW}'" >> ${CONFIG_FILE}

echo "export RCM_DB_USER='${RCM_DB_USER}'" >> ${CONFIG_FILE}
echo "export RCM_DB_PASSWD='${RCM_DB_PASSWD}'" >> ${CONFIG_FILE}

if [ X"${BACKEND}" == X"OPENLDAP" ]; then
    . ${DIALOG_DIR}/ldap_config.sh
else
    :
fi

# MySQL server is required as backend or used to store policyd/roundcube data.
. ${DIALOG_DIR}/mysql_config.sh

#
# Virtual domain configuration.
#
. ${DIALOG_DIR}/virtual_domain_config.sh

#
# For optional components.
#
. ${DIALOG_DIR}/optional_components.sh

# Append EOF tag in config file.
echo "#EOF" >> ${CONFIG_FILE}

#
# Ending message.
#
cat <<EOF
Configuration completed.

*************************************************************************
***************************** WARNING ***********************************
*************************************************************************
*                                                                       *
* Please do remember to *MOVE* configuration file after installation    *
* completed successfully.                                               *
*                                                                       *
*   * ${CONFIG_FILE}
*                                                                       *
*************************************************************************
EOF

ECHO_QUESTION -n "Continue? [y|N]"
read ANSWER

case ${ANSWER} in
    Y|y) : ;;
    N|n|*)
        ECHO_INFO "Cancelled, Exit."
        exit 255
        ;;
esac
