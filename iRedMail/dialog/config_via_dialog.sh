#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)

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
. ${CONF_DIR}/postfix

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

export VMAIL_USER_HOME_DIR="$(cat /tmp/vmail_user_home_dir)"
rm -f /tmp/vmail_user_home_dir

export STORAGE_BASE_DIR="${VMAIL_USER_HOME_DIR}"
export SIEVE_DIR="${VMAIL_USER_HOME_DIR}/sieve"
echo "export VMAIL_USER_HOME_DIR='${VMAIL_USER_HOME_DIR}'" >> ${CONFIG_FILE}
echo "export STORAGE_BASE_DIR='${VMAIL_USER_HOME_DIR}'" >> ${CONFIG_FILE}
echo "export SIEVE_DIR='${SIEVE_DIR}'" >>${CONFIG_FILE}

export BACKUP_DIR="${VMAIL_USER_HOME_DIR}/backup"
export BACKUP_SCRIPT_OPENLDAP="${BACKUP_DIR}/backup_openldap.sh"
export BACKUP_SCRIPT_MYSQL="${BACKUP_DIR}/backup_mysql.sh"
export BACKUP_SCRIPT_PGSQL="${BACKUP_DIR}/backup_pgsql.sh"
echo "export BACKUP_DIR='${BACKUP_DIR}'" >>${CONFIG_FILE}
echo "export BACKUP_SCRIPT_OPENLDAP='${BACKUP_SCRIPT_OPENLDAP}'" >>${CONFIG_FILE}
echo "export BACKUP_SCRIPT_MYSQL='${BACKUP_SCRIPT_MYSQL}'" >>${CONFIG_FILE}
echo "export BACKUP_SCRIPT_PGSQL='${BACKUP_SCRIPT_PGSQL}'" >>${CONFIG_FILE}

# --------------------------------------------------
# --------------------- Backend --------------------
# --------------------------------------------------
# PGSQL is available on Ubuntu 11.04, 11.10.
if [ X"${ENABLE_BACKEND_PGSQL}" == X"YES" ]; then
    ${DIALOG} \
    --title "Choose your preferred backend used to store mail accounts" \
    --radiolist "\
We provide two backends and the homologous webmail programs:
+------------+---------------+---------------------------+
| Backend    | Web Mail      | Web-based management tool |
+------------+---------------+---------------------------+
| OpenLDAP   |               | iRedAdmin, phpLDAPadmin   |
+------------+               +---------------------------+
| MySQL      | Roundcube     | iRedAdmin, phpMyAdmin     |
+------------+               +---------------------------+
| PostgreSQL |               | iRedAdmin, phpPgAdmin     |
+------------+---------------+---------------------------+
TIP: Use SPACE key to select item.
" 20 76 3 \
    'OpenLDAP' 'An open source implementation of LDAP protocol' 'on' \
    'MySQL' "The world's most popular open source database" 'off' \
    'PostgreSQL' 'Powerful, open source database system' 'off' \
    2>/tmp/backend

else
    ${DIALOG} \
    --title "Choose your preferred backend used to store mail accounts" \
    --radiolist "\
We provide two backends and the homologous webmail programs:
+------------+---------------+---------------------------+
| Backend    | Web Mail      | Web-based management tool |
+------------+---------------+---------------------------+
| OpenLDAP   |               | iRedAdmin, phpLDAPadmin   |
+------------+ Roundcube     +---------------------------+
| MySQL      |               | iRedAdmin, phpMyAdmin     |
+------------+---------------+---------------------------+

TIP: Use SPACE key to select item.
" 20 76 3 \
    'OpenLDAP' 'An open source implementation of LDAP protocol' 'on' \
    'MySQL' "The world's most popular open source database" 'off' \
    2>/tmp/backend
fi

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

# Read-only SQL user/role, used to query mail accounts in Postfix, Dovecot.
export VMAIL_DB_BIND_PASSWD="$(${RANDOM_STRING})"
echo "export VMAIL_DB_BIND_PASSWD='${VMAIL_DB_BIND_PASSWD}'" >> ${CONFIG_FILE}

# For database management: vmail.
export VMAIL_DB_ADMIN_PASSWD="$(${RANDOM_STRING})"
echo "export VMAIL_DB_ADMIN_PASSWD='${VMAIL_DB_ADMIN_PASSWD}'" >> ${CONFIG_FILE}

# LDAP bind dn & password.
export LDAP_BINDPW="$(${RANDOM_STRING})"
export LDAP_ADMIN_PW="$(${RANDOM_STRING})"
echo "export LDAP_BINDPW='${LDAP_BINDPW}'" >> ${CONFIG_FILE}
echo "export LDAP_ADMIN_PW='${LDAP_ADMIN_PW}'" >> ${CONFIG_FILE}

if [ X"${BACKEND}" == X"OPENLDAP" ]; then
    . ${DIALOG_DIR}/ldap_config.sh

    # MySQL server is used to store policyd/roundcube data.
    . ${DIALOG_DIR}/mysql_config.sh
elif [ X"${BACKEND}" == X"MYSQL" ]; then
    . ${DIALOG_DIR}/mysql_config.sh
elif [ X"${BACKEND}" == X"PGSQL" ]; then
    . ${DIALOG_DIR}/pgsql_config.sh
fi

if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X'MYSQL' ]; then
    export SQL_SERVER="${MYSQL_SERVER}"
    export SQL_SERVER_PORT="${MYSQL_SERVER_PORT}"
elif [ X"${BACKEND}" == X'PGSQL' ]; then
    export SQL_SERVER="${PGSQL_SERVER}"
    export SQL_SERVER_PORT="${PGSQL_SERVER_PORT}"
fi

echo "export SQL_SERVER='${SQL_SERVER}'" >> ${CONFIG_FILE}
echo "export SQL_SERVER_PORT='${SQL_SERVER_PORT}'" >> ${CONFIG_FILE}

# Virtual domain configuration.
. ${DIALOG_DIR}/virtual_domain_config.sh

# Optional components.
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
read_setting ${AUTO_INSTALL_WITHOUT_CONFIRM}
case ${ANSWER} in
    Y|y) : ;;
    N|n|*)
        ECHO_INFO "Cancelled, Exit."
        exit 255
        ;;
esac
