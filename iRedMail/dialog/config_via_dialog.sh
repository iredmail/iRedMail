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
. ${CONF_DIR}/roundcube
. ${CONF_DIR}/iredadmin

trap "exit 255" 2

# Initialize config file.
echo '' > ${IREDMAIL_CONFIG_FILE}

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
Please specify a directory (in lowercase) used to store user mailboxes.
Default is: ${VMAIL_USER_HOME_DIR}

EXAMPLE:

    * ${VMAIL_USER_HOME_DIR}

NOTES:

    * Depends on the mail traffic, it may take large disk space.
    * Path will be converted to lowercases.
" 20 76 "${VMAIL_USER_HOME_DIR}" 2>/tmp/vmail_user_home_dir

export VMAIL_USER_HOME_DIR="$(cat /tmp/vmail_user_home_dir)"
rm -f /tmp/vmail_user_home_dir &>/dev/null

export STORAGE_BASE_DIR="${VMAIL_USER_HOME_DIR}"
export STORAGE_MAILBOX_DIR="${STORAGE_BASE_DIR}/${STORAGE_NODE}"
export SIEVE_DIR="${VMAIL_USER_HOME_DIR}/sieve"
echo "export VMAIL_USER_HOME_DIR='${VMAIL_USER_HOME_DIR}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export STORAGE_BASE_DIR='${VMAIL_USER_HOME_DIR}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export STORAGE_MAILBOX_DIR='${STORAGE_MAILBOX_DIR}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export SIEVE_DIR='${SIEVE_DIR}'" >>${IREDMAIL_CONFIG_FILE}

export BACKUP_DIR="${VMAIL_USER_HOME_DIR}/backup"
export BACKUP_SCRIPT_OPENLDAP="${BACKUP_DIR}/backup_openldap.sh"
export BACKUP_SCRIPT_MYSQL="${BACKUP_DIR}/backup_mysql.sh"
export BACKUP_SCRIPT_PGSQL="${BACKUP_DIR}/backup_pgsql.sh"
echo "export BACKUP_DIR='${BACKUP_DIR}'" >>${IREDMAIL_CONFIG_FILE}
echo "export BACKUP_SCRIPT_OPENLDAP='${BACKUP_SCRIPT_OPENLDAP}'" >>${IREDMAIL_CONFIG_FILE}
echo "export BACKUP_SCRIPT_MYSQL='${BACKUP_SCRIPT_MYSQL}'" >>${IREDMAIL_CONFIG_FILE}
echo "export BACKUP_SCRIPT_PGSQL='${BACKUP_SCRIPT_PGSQL}'" >>${IREDMAIL_CONFIG_FILE}

# --------------------------------------------------
# -------------------- Web server ------------------
# --------------------------------------------------
while : ; do
    ${DIALOG} \
    --title "Choose default web server" \
    --radiolist "Both Apache and Nginx will be installed on your server, please choose the default web server you want to run. You're free to switch between them after installation completed.

TIP: Use SPACE key to select item." \
20 76 2 \
"Apache" "The most popular web server" "off" \
"Nginx" "The fastest web server" "on" \
2>/tmp/web_servers

    web_servers="$(cat /tmp/web_servers | tr '[a-z]' '[A-Z]')"
    rm -f /tmp/web_servers
    [ X"${web_servers}" != X"" ] && break
done

echo ${web_servers} | grep -i 'apache' >/dev/null 2>&1
[ X"$?" == X"0" ] && export WEB_SERVER_USE_APACHE='YES' && echo "export WEB_SERVER_USE_APACHE='YES'" >>${IREDMAIL_CONFIG_FILE}

echo ${web_servers} | grep -i 'nginx' >/dev/null 2>&1
[ X"$?" == X"0" ] && export WEB_SERVER_USE_NGINX='YES' && echo "export WEB_SERVER_USE_NGINX='YES'" >>${IREDMAIL_CONFIG_FILE}

# --------------------------------------------------
# --------------------- Backends --------------------
# --------------------------------------------------
export DIALOG_AVAILABLE_BACKENDS=''
if [ X"${ENABLE_BACKEND_LDAPD}" == X'YES' ]; then
    export DIALOG_AVAILABLE_BACKENDS="${DIALOG_AVAILABLE_BACKENDS} ldapd The_OpenBSD_built-in_LDAP_server off"
fi
if [ X"${ENABLE_BACKEND_OPENLDAP}" == X'YES' ]; then
    export DIALOG_AVAILABLE_BACKENDS="${DIALOG_AVAILABLE_BACKENDS} OpenLDAP An_open_source_implementation_of_LDAP_protocol off"
fi

if [ X"${ENABLE_BACKEND_MYSQL}" == X'YES' ]; then
    export DIALOG_AVAILABLE_BACKENDS="${DIALOG_AVAILABLE_BACKENDS} MySQL Most_popular_open_source_database off"
fi

if [ X"${ENABLE_BACKEND_MARIADB}" == X'YES' ]; then
    export DIALOG_AVAILABLE_BACKENDS="${DIALOG_AVAILABLE_BACKENDS} MariaDB An_enhanced,_drop-in_replacement_for_MySQL off"
fi

if [ X"${ENABLE_BACKEND_PGSQL}" == X'YES' ]; then
    export DIALOG_AVAILABLE_BACKENDS="${DIALOG_AVAILABLE_BACKENDS} PostgreSQL Powerful,_open_source_database_system off"
fi

while : ; do
    ${DIALOG} \
    --title "Choose preferred backend used to store mail accounts" \
    --radiolist "It's strongly recommended to choose the one you're farmliar with for easy maintenance. They all use the same webmail (Roundcube) and admin panel (iRedAdmin), and no big feature differences between them.

TIP: Use SPACE key to select item.
" 20 76 4 ${DIALOG_AVAILABLE_BACKENDS} 2>/tmp/backend

    BACKEND_ORIG="$(cat /tmp/backend | tr '[a-z]' '[A-Z]')"
    [ X"${BACKEND_ORIG}" != X"" ] && break
done

if [ X"${BACKEND_ORIG}" == X'LDAPD' ]; then
    export BACKEND='OPENLDAP'
elif [ X"${BACKEND_ORIG}" == X'OPENLDAP' ]; then
    export BACKEND='OPENLDAP'
elif [ X"${BACKEND_ORIG}" == X'MYSQL' ]; then
    export BACKEND='MYSQL'
elif [ X"${BACKEND_ORIG}" == X'MARIADB' ]; then
    export BACKEND='MYSQL'
    export BACKEND_ORIG='MARIADB'
elif [ X"${BACKEND_ORIG}" == X'POSTGRESQL' ]; then
    export BACKEND='PGSQL'
    export BACKEND_ORIG='PGSQL'
fi
echo "export BACKEND_ORIG='${BACKEND_ORIG}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export BACKEND='${BACKEND}'" >> ${IREDMAIL_CONFIG_FILE}
rm -f /tmp/backend &>/dev/null

# Read-only SQL user/role, used to query mail accounts in Postfix, Dovecot.
export VMAIL_DB_BIND_PASSWD="$(${RANDOM_STRING})"
echo "export VMAIL_DB_BIND_PASSWD='${VMAIL_DB_BIND_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

# For database management: vmail.
export VMAIL_DB_ADMIN_PASSWD="$(${RANDOM_STRING})"
echo "export VMAIL_DB_ADMIN_PASSWD='${VMAIL_DB_ADMIN_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

# LDAP bind dn & password.
export LDAP_BINDPW="$(${RANDOM_STRING})"
export LDAP_ADMIN_PW="$(${RANDOM_STRING})"
echo "export LDAP_BINDPW='${LDAP_BINDPW}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export LDAP_ADMIN_PW='${LDAP_ADMIN_PW}'" >> ${IREDMAIL_CONFIG_FILE}

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
    export SQL_ROOT_USER="${MYSQL_ROOT_USER}"
    export SQL_ROOT_PASSWD="${MYSQL_ROOT_PASSWD}"
elif [ X"${BACKEND}" == X'PGSQL' ]; then
    export SQL_SERVER="${PGSQL_SERVER}"
    export SQL_SERVER_PORT="${PGSQL_SERVER_PORT}"
    export SQL_ROOT_USER="${PGSQL_ROOT_USER}"
    export SQL_ROOT_PASSWD="${PGSQL_ROOT_PASSWD}"
fi

echo "export SQL_SERVER='${SQL_SERVER}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export SQL_SERVER_PORT='${SQL_SERVER_PORT}'" >> ${IREDMAIL_CONFIG_FILE}

# Virtual domain configuration.
. ${DIALOG_DIR}/virtual_domain_config.sh

# Optional components.
. ${DIALOG_DIR}/optional_components.sh

# Append EOF tag in config file.
echo "#EOF" >> ${IREDMAIL_CONFIG_FILE}

#
# Ending message.
#
cat <<EOF
Configuration completed.

*************************************************************************
***************************** WARNING ***********************************
*************************************************************************
*                                                                       *
* Below file contains sensitive infomation (username/password), please  *
* do remember to *MOVE* it to a safe place after installation.          *
*                                                                       *
*   * ${IREDMAIL_CONFIG_FILE}
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
