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

# Note: config file will be sourced in 'conf/core', function `check_env()`.

. ${CONF_DIR}/global
. ${CONF_DIR}/core
. ${CONF_DIR}/openldap
. ${CONF_DIR}/postfix
. ${CONF_DIR}/roundcube
. ${CONF_DIR}/iredadmin

trap "exit 255" 2

# Initialize config file.
echo '' > ${IREDMAIL_CONFIG_FILE}
chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${IREDMAIL_CONFIG_FILE}
chmod 0400 ${IREDMAIL_CONFIG_FILE}

DIALOG="dialog --colors --no-collapse --insecure --ok-label Next \
        --no-cancel --backtitle ${PROG_NAME}:_Open_Source_Mail_Server_Solution"

# Welcome message.
${DIALOG} \
    --title "Welcome and thanks for your use" \
    --yesno "\
Welcome to the iRedMail setup wizard, we will ask you some simple questions required to setup a mail server. If you encounter any trouble or issues, please report to our support forum: https://forum.iredmail.org/

NOTE: You can abort this installation wizard by pressing key Ctrl-C.
" 20 76

# Exit when user choose 'exit'.
[ X"$?" != X"0" ] && ECHO_INFO "Exit." && exit 0

# Storage base directory
while :; do
    ${DIALOG} \
        --title "Default mail storage path" \
        --inputbox "\
Please specify a directory (in lowercase) used to store user mailboxes.
Default is: ${STORAGE_BASE_DIR}

NOTES:

* Depends on the mail traffic, it may take large disk space.
* Maildir path will be converted to lowercases, so please create this
  directory in lowcases.
* It cannot be /var/mail or /root.
* Mailboxes will be stored under its sub-directory: ${STORAGE_BASE_DIR}/${STORAGE_NODE}/
* Daily backup of SQL/LDAP databases will be stored under another sub-directory: /var/vmail/backup.
" 20 76 "${STORAGE_BASE_DIR}" 2>${RUNTIME_DIR}/.storage_base_dir

    export STORAGE_BASE_DIR="$(cat ${RUNTIME_DIR}/.storage_base_dir | tr '[A-Z]' '[a-z]')"

    # Make sure storage directory is not one of:
    #   - /var/mail: it's used to store mails for system accounts
    #   - /root: only root user can access it, mail services won't work.
    if echo ${STORAGE_BASE_DIR} | grep -iE '^(/var/mail\>|/root\>)' &>/dev/null; then
        :
    else
        break
    fi
done

rm -f ${RUNTIME_DIR}/.storage_base_dir &>/dev/null

export STORAGE_BASE_DIR="${STORAGE_BASE_DIR}"
echo "export STORAGE_BASE_DIR='${STORAGE_BASE_DIR}'" >> ${IREDMAIL_CONFIG_FILE}

# --------------------------------------------------
# ------------ Default web server ------------------
# --------------------------------------------------
export DISABLE_WEB_SERVER='NO'
export WEB_SERVER=''

if [ X"${DISTRO}" == X'OPENBSD' ]; then
    while : ; do
        ${DIALOG} \
        --title "Preferred web server" \
        --radiolist "Choose a web server you want to run.

TIP: Use SPACE key to select item." \
20 76 3 \
"Nginx" "The fastest web server" "on" \
"No web server" "I don't need any web applications on this server" "off" \
2>${RUNTIME_DIR}/.web_server

        web_server_case_sensitive="$(cat ${RUNTIME_DIR}/.web_server)"
        web_server="$(echo ${web_server_case_sensitive} | tr '[a-z]' '[A-Z]')"
        [ X"${web_server}" != X"" ] && break
    done

    rm -f ${RUNTIME_DIR}/.web_server
else
    while : ; do
        ${DIALOG} \
        --title "Preferred web server" \
        --radiolist "Choose a web server you want to run.

TIP: Use SPACE key to select item." \
20 76 3 \
"Nginx" "The fastest web server" "on" \
"No web server" "I don't need any web applications on this server" "off" \
2>${RUNTIME_DIR}/.web_server

        web_server_case_sensitive="$(cat ${RUNTIME_DIR}/.web_server)"
        web_server="$(echo ${web_server_case_sensitive} | tr '[a-z]' '[A-Z]')"
        [ X"${web_server}" != X"" ] && break
    done

    rm -f ${RUNTIME_DIR}/.web_server
fi

if [ X"${web_server}" == X'NGINX' ]; then
    export WEB_SERVER='NGINX'
else
    export DISABLE_WEB_SERVER='YES'
    echo "export DISABLE_WEB_SERVER='YES'" >>${IREDMAIL_CONFIG_FILE}
fi

echo "export WEB_SERVER='${WEB_SERVER}'" >>${IREDMAIL_CONFIG_FILE}

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
" 20 76 4 ${DIALOG_AVAILABLE_BACKENDS} 2>${RUNTIME_DIR}/.backend

    BACKEND_ORIG_CASE_SENSITIVE="$(cat ${RUNTIME_DIR}/.backend)"
    BACKEND_ORIG="$(echo ${BACKEND_ORIG_CASE_SENSITIVE} | tr '[a-z]' '[A-Z]')"
    [ X"${BACKEND_ORIG}" != X"" ] && break
done

rm -f ${RUNTIME_DIR}/.backend &>/dev/null
if [ X"${BACKEND_ORIG}" == X'LDAPD' ]; then
    export BACKEND='OPENLDAP'
elif [ X"${BACKEND_ORIG}" == X'OPENLDAP' ]; then
    export BACKEND='OPENLDAP'
elif [ X"${BACKEND_ORIG}" == X'MYSQL' -o X"${BACKEND_ORIG}" == X'MARIADB' ]; then
    export BACKEND='MYSQL'
elif [ X"${BACKEND_ORIG}" == X'POSTGRESQL' ]; then
    export BACKEND='PGSQL'
    export BACKEND_ORIG='PGSQL'
fi

echo "export BACKEND_ORIG='${BACKEND_ORIG}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export BACKEND='${BACKEND}'" >> ${IREDMAIL_CONFIG_FILE}

# Read-only SQL user/role, used to query mail accounts in Postfix, Dovecot.
export VMAIL_DB_BIND_PASSWD="$(${RANDOM_STRING})"
echo "export VMAIL_DB_BIND_PASSWD='${VMAIL_DB_BIND_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

# For database management: vmail.
export VMAIL_DB_ADMIN_PASSWD="$(${RANDOM_STRING})"
echo "export VMAIL_DB_ADMIN_PASSWD='${VMAIL_DB_ADMIN_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

# For mlmmj mailing list manager
export MLMMJADMIN_API_AUTH_TOKEN="$(${RANDOM_STRING})"
echo "export MLMMJADMIN_API_AUTH_TOKEN='${MLMMJADMIN_API_AUTH_TOKEN}'" >> ${IREDMAIL_CONFIG_FILE}

# For database management: vmail.
export NETDATA_DB_PASSWD="$(${RANDOM_STRING})"
echo "export NETDATA_DB_PASSWD='${NETDATA_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

if [ X"${BACKEND}" == X'OPENLDAP' ]; then
    . ${DIALOG_DIR}/ldap_config.sh
    . ${DIALOG_DIR}/mysql_config.sh
elif [ X"${BACKEND}" == X'MYSQL' ]; then
    . ${DIALOG_DIR}/mysql_config.sh
elif [ X"${BACKEND}" == X'PGSQL' ]; then
    . ${DIALOG_DIR}/pgsql_config.sh
fi

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
********************** Review your settings *****************************
*************************************************************************

* Storage base directory:               ${STORAGE_BASE_DIR}
* Mailboxes:                            ${STORAGE_MAILBOX_DIR}
* Daily backup of SQL/LDAP databases:   ${BACKUP_DIR}
* Store mail accounts in:               ${BACKEND_ORIG_CASE_SENSITIVE}
* Web server:                           ${web_server_case_sensitive}
* First mail domain name:               ${FIRST_DOMAIN}
* Mail domain admin:                    ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}
* Additional components:                ${OPTIONAL_COMPONENTS}

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
