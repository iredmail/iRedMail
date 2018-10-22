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

# -------------------------------------------------------
# Dovecot & dovecot-sieve.
# -------------------------------------------------------

dovecot_config()
{
    ECHO_INFO "Configure Dovecot (POP3/IMAP/Managesieve/LMTP/LDA)."

    backup_file ${DOVECOT_CONF}

    # RHEL/CentOS 7:    Dovecot-2.2.32+
    # Debian 9:         Dovecot-2.2.27
    # Ubuntu 16.04 (xenial):    Dovecot-2.2.22
    # Ubuntu 18.04 (bionic):    Dovecot-2.2.33
    # Ubuntu 18.10 (cosmic):    Dovecot-2.3.33
    # FreeBSD:          Dovecot-2.3.0+
    # OpenBSD:          Dovecot-2.2.36
    ECHO_DEBUG "Copy sample Dovecot config file to ${DOVECOT_CONF}."
    if [ X"${DOVECOT_VERSION}" == X'2.2' ]; then
        cp ${SAMPLE_DIR}/dovecot/dovecot22.conf ${DOVECOT_CONF}
    else
        cp ${SAMPLE_DIR}/dovecot/dovecot23.conf ${DOVECOT_CONF}
    fi

    # FreeBSD ports tree offers Dovecot 2.3, we need to fix some backward
    # compatibilites.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        perl -pi -e 's/^ssl_protocols/#${1}/g' ${DOVECOT_CONF}
        perl -pi -e 's#^(mail_plugins.*) stats(.*)#${1} old_stats${2}#g' ${DOVECOT_CONF}
        perl -pi -e 's#imap_stats#imap_old_stats#g' ${DOVECOT_CONF}
        perl -pi -e 's#service stats#service old-stats#g' ${DOVECOT_CONF}
        perl -pi -e 's#fifo_listener stats-mail#fifo_listener old-stats-mail#g' ${DOVECOT_CONF}
        perl -pi -e 's#stats_refresh#old_stats_refresh#g' ${DOVECOT_CONF}
        perl -pi -e 's#stats_track_cmds#old_stats_track_cmds#g' ${DOVECOT_CONF}
        echo "ssl_dh = <${SSL_DH1024_PARAM_FILE}" >> ${DOVECOT_CONF}
    fi

    chmod 0664 ${DOVECOT_CONF}

    ECHO_DEBUG "Configure dovecot: ${DOVECOT_CONF}."

    perl -pi -e 's#PH_DOVECOT_CONF_INCLUDE_DIR#$ENV{DOVECOT_CONF_INCLUDE_DIR}#g' ${DOVECOT_CONF}

    # Listen address
    if [ X"${IREDMAIL_HAS_IPV6}" == X'NO' ]; then
        perl -pi -e 's#^(listen.*=).*#${1} \*#g' ${DOVECOT_CONF}
    fi

    # Service listen addresses and ports.
    perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#g' ${DOVECOT_CONF}

    #
    # Listen on localhost
    #
    # Managesieve
    perl -pi -e 's#PH_MANAGESIEVE_BIND_HOST#$ENV{MANAGESIEVE_BIND_HOST}#g' ${DOVECOT_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_BIND_PORT#$ENV{MANAGESIEVE_BIND_PORT}#g' ${DOVECOT_CONF}

    # LMTP
    perl -pi -e 's#PH_LMTP_BIND_ADDRESS#$ENV{LMTP_BIND_ADDRESS}#g' ${DOVECOT_CONF}
    perl -pi -e 's#PH_LMTP_BIND_PORT#$ENV{LMTP_BIND_PORT}#' ${DOVECOT_CONF}

    # Base directory.
    perl -pi -e 's#PH_BASE_DIR#$ENV{DOVECOT_BASE_DIR}#' ${DOVECOT_CONF}
    # base_dir is required on OpenBSD
    [ X"${DISTRO}" == X'OPENBSD' ] && \
        perl -pi -e 's/^#(base_dir.*)/${1}/' ${DOVECOT_CONF}

    # Public mailbox directory
    perl -pi -e 's#PH_PUBLIC_MAILBOX_DIR#$ENV{PUBLIC_MAILBOX_DIR}#' ${DOVECOT_CONF}

    # Mailbox index directory
    if [ -n "${MAILBOX_INDEX_DIR}" ]; then
        perl -pi -e 's#^(mail_location.*:INDEX=)%Lh/Maildir/#${1}$ENV{MAILBOX_INDEX_DIR}/%Ld/%Ln/#' ${DOVECOT_CONF}

        # Per-user seen flags. Maildir indexes are not shared. INDEXPVT requires v2.2+.
        perl -pi -e 's#(location.*:INDEX=)(.*/Shared/.*)#${1}$ENV{MAILBOX_INDEX_DIR}/%Ld/%Ln/Shared/%%Ld/%%Ln:INDEXPVT=$ENV{MAILBOX_INDEX_DIR}/%Ld/%Ln/Shared/%%Ld/%%Ln#g' ${DOVECOT_CONF}
    fi

    # Provided services.
    export DOVECOT_PROTOCOLS
    perl -pi -e 's#PH_PROTOCOLS#$ENV{DOVECOT_PROTOCOLS}#' ${DOVECOT_CONF}

    # Set correct uid/gid.
    perl -pi -e 's#PH_MAIL_UID#$ENV{SYS_USER_VMAIL_UID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_MAIL_GID#$ENV{SYS_GROUP_VMAIL_GID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_FIRST_VALID_UID#$ENV{SYS_USER_VMAIL_UID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_LAST_VALID_UID#$ENV{SYS_USER_VMAIL_UID}#' ${DOVECOT_CONF}

    # syslog and log file.
    perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_LOG_PATH#$ENV{DOVECOT_LOG_FILE}#' ${DOVECOT_CONF}

    # Authentication related settings.
    # Append this domain name if client gives empty realm.
    export FIRST_DOMAIN
    perl -pi -e 's#PH_AUTH_DEFAULT_REALM#$ENV{FIRST_DOMAIN}#' ${DOVECOT_CONF}

    # service auth {}
    perl -pi -e 's#PH_DOVECOT_AUTH_USER#$ENV{SYS_USER_POSTFIX}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_AUTH_GROUP#$ENV{SYS_GROUP_POSTFIX}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MASTER_USER#$ENV{SYS_USER_VMAIL}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MASTER_GROUP#$ENV{SYS_GROUP_VMAIL}#' ${DOVECOT_CONF}

    # service stats {}
    perl -pi -e 's#PH_DOVECOT_SERVICE_STATS_PORT#$ENV{DOVECOT_SERVICE_STATS_PORT}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_SERVICE_STATS_USER#$ENV{DOVECOT_SERVICE_STATS_USER}#' ${DOVECOT_CONF}

    # Virtual mail accounts.
    # Reference: http://wiki2.dovecot.org/AuthDatabase/LDAP
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_LDAP_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#ldap#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_LDAP_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#ldap#' ${DOVECOT_CONF}
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        # MySQL.
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_MYSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#sql#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_MYSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#sql#' ${DOVECOT_CONF}
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        # PostgreSQL.
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_PGSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#sql#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_PGSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#sql#' ${DOVECOT_CONF}
    fi

    # Master user.
    perl -pi -e 's#PH_DOVECOT_MASTER_USER_PASSWORD_FILE#$ENV{DOVECOT_MASTER_USER_PASSWORD_FILE}#' ${DOVECOT_CONF}
    touch ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chown ${SYS_USER_DOVECOT}:${SYS_GROUP_DOVECOT} ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chmod 0500 ${DOVECOT_MASTER_USER_PASSWORD_FILE}

    perl -pi -e 's#PH_DOVECOT_AUTH_MASTER_PATH#$ENV{DOVECOT_AUTH_MASTER_PATH}#' ${DOVECOT_CONF}

    # Quota.
    perl -pi -e 's#PH_QUOTA_TYPE#$ENV{DOVECOT_QUOTA_TYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_SCRIPT#$ENV{DOVECOT_QUOTA_WARNING_SCRIPT}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_USER#$ENV{SYS_USER_VMAIL}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_GROUP#$ENV{SYS_GROUP_VMAIL}#' ${DOVECOT_CONF}

    # Quota dict.
    perl -pi -e 's#PH_SERVICE_DICT_USER#$ENV{SYS_USER_VMAIL}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SERVICE_DICT_GROUP#$ENV{SYS_GROUP_VMAIL}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_SQLTYPE#$ENV{DOVECOT_REALTIME_QUOTA_SQLTYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_CONF#$ENV{DOVECOT_REALTIME_QUOTA_CONF}#' ${DOVECOT_CONF}

    # Sieve.
    perl -pi -e 's#PH_SIEVE_DIR#$ENV{SIEVE_DIR}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_SIEVE_LOG_FILE#$ENV{DOVECOT_SIEVE_LOG_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SIEVE_RULE_FILENAME#$ENV{SIEVE_RULE_FILENAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_GLOBAL_SIEVE_FILE#$ENV{DOVECOT_GLOBAL_SIEVE_FILE}#' ${DOVECOT_CONF}

    # LMTP
    perl -pi -e 's#PH_DOVECOT_LMTP_LOG_FILE#$ENV{DOVECOT_LMTP_LOG_FILE}#' ${DOVECOT_CONF}

    # SSL.
    perl -pi -e 's#PH_SSL_CERT#$ENV{SSL_CERT_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SSL_KEY#$ENV{SSL_KEY_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SSL_CIPHERS#$ENV{SSL_CIPHERS}#' ${DOVECOT_CONF}

    if [ X"${DISTRO_CODENAME}" == X'stretch' ]; then
        perl -pi -e 's#^(ssl_protocols).*#ssl_protocols = !SSLv3#' ${DOVECOT_CONF}
    fi

    perl -pi -e 's#PH_POSTFIX_CHROOT_DIR#$ENV{POSTFIX_CHROOT_DIR}#' ${DOVECOT_CONF}

    # Generate dovecot quota warning script.
    mkdir -p $(dirname ${DOVECOT_QUOTA_WARNING_SCRIPT}) >> ${INSTALL_LOG} 2>&1

    backup_file ${DOVECOT_QUOTA_WARNING_SCRIPT}
    rm -f ${DOVECOT_QUOTA_WARNING_SCRIPT} >> ${INSTALL_LOG} 2>&1
    cp -f ${SAMPLE_DIR}/dovecot/dovecot2-quota-warning.sh ${DOVECOT_QUOTA_WARNING_SCRIPT}
    if [ X"${DOVECOT_QUOTA_TYPE}" == X'maildir' ]; then
        perl -pi -e 's#(.*)(-o.*plugin.*)#${1}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    # on OpenBSD: get FQDN with command 'hostname', not 'hostname -f'.
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        perl -pi -e 's#hostname -f#hostname#g' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    export DOVECOT_DELIVER_BIN HOSTNAME
    perl -pi -e 's#PH_DOVECOT_DELIVER_BIN#$ENV{DOVECOT_DELIVER_BIN}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}

    chown root ${DOVECOT_QUOTA_WARNING_SCRIPT}
    chmod 0755 ${DOVECOT_QUOTA_WARNING_SCRIPT}

    # Use '/usr/local/bin/bash' as shabang line, otherwise quota warning will fail.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        perl -pi -e 's#(.*)/usr/bin/env bash.*#${1}/usr/local/bin/bash#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        backup_file ${DOVECOT_LDAP_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-ldap.conf ${DOVECOT_LDAP_CONF}
        perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_LDAP_CONF}

        perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BIND_VERSION#$ENV{LDAP_BIND_VERSION}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BINDPW#$ENV{LDAP_BINDPW}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#' ${DOVECOT_LDAP_CONF}

        # Set file permission.
        chmod 0500 ${DOVECOT_LDAP_CONF}

    elif [ X"${BACKEND}" == X'MYSQL' ]; then

        backup_file ${DOVECOT_MYSQL_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-sql.conf ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#(.*mailbox.)(enable.*Lc)(=1)#${1}`${2}`${3}#' ${DOVECOT_MYSQL_CONF}

        perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_SQL_DRIVER#mysql#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_NAME#$ENV{VMAIL_DB_NAME}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#' ${DOVECOT_MYSQL_CONF}

        # Set file permission.
        chmod 0550 ${DOVECOT_MYSQL_CONF}
    elif [ X"${BACKEND}" == X'PGSQL' ]; then

        backup_file ${DOVECOT_PGSQL_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-sql.conf ${DOVECOT_PGSQL_CONF}

        perl -pi -e 's#(.*mailbox.)(enable.*Lc)(=1)#${1}"${2}"${3}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_SQL_DRIVER#pgsql#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_NAME#$ENV{VMAIL_DB_NAME}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#' ${DOVECOT_PGSQL_CONF}

        # Set file permission.
        chmod 0550 ${DOVECOT_PGSQL_CONF}
    fi

    # Realtime quota
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        export realtime_quota_db_name="${IREDADMIN_DB_NAME}"
        export realtime_quota_db_user="${IREDADMIN_DB_USER}"
        export realtime_quota_db_passwd="${IREDADMIN_DB_PASSWD}"
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        export realtime_quota_db_name="${VMAIL_DB_NAME}"
        export realtime_quota_db_user="${VMAIL_DB_ADMIN_USER}"
        export realtime_quota_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        export realtime_quota_db_name="${VMAIL_DB_NAME}"
        export realtime_quota_db_user="${VMAIL_DB_BIND_USER}"
        export realtime_quota_db_passwd="${VMAIL_DB_BIND_PASSWD}"
    fi

    # Copy sample config and set file owner/permission
    cp ${SAMPLE_DIR}/dovecot/dovecot-used-quota.conf ${DOVECOT_REALTIME_QUOTA_CONF}
    chown ${SYS_USER_DOVECOT}:${SYS_GROUP_DOVECOT} ${DOVECOT_REALTIME_QUOTA_CONF}
    chmod 0500 ${DOVECOT_REALTIME_QUOTA_CONF}

    # Replace place holders in sample config file
    perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_NAME#$ENV{realtime_quota_db_name}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_USER#$ENV{realtime_quota_db_user}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_PASSWORD#$ENV{realtime_quota_db_passwd}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_TABLE#$ENV{DOVECOT_REALTIME_QUOTA_TABLE}#' ${DOVECOT_REALTIME_QUOTA_CONF}

    # IMAP shared folder
    backup_file ${DOVECOT_SHARE_FOLDER_CONF}

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        export share_folder_db_name="${IREDADMIN_DB_NAME}"
        export share_folder_db_user="${IREDADMIN_DB_USER}"
        export share_folder_db_passwd="${IREDADMIN_DB_PASSWD}"
    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        export share_folder_db_name="${VMAIL_DB_NAME}"
        export share_folder_db_user="${VMAIL_DB_ADMIN_USER}"
        export share_folder_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"
    fi

    # ACL and share folder settings in dovecot.conf
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_SQLTYPE#$ENV{DOVECOT_SHARE_FOLDER_SQLTYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_CONF#$ENV{DOVECOT_SHARE_FOLDER_CONF}#' ${DOVECOT_CONF}

    # Copy sample config and set file owner/permission
    cp ${SAMPLE_DIR}/dovecot/dovecot-share-folder.conf ${DOVECOT_SHARE_FOLDER_CONF}
    chown ${SYS_USER_DOVECOT}:${SYS_GROUP_DOVECOT} ${DOVECOT_SHARE_FOLDER_CONF}
    chmod 0500 ${DOVECOT_SHARE_FOLDER_CONF}

    # Replace place holders in sample config file
    perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_NAME#$ENV{share_folder_db_name}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_USER#$ENV{share_folder_db_user}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_PASSWORD#$ENV{share_folder_db_passwd}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}

    ECHO_DEBUG "Copy global sieve filter rule file: ${DOVECOT_GLOBAL_SIEVE_FILE}."
    cp -f ${SAMPLE_DIR}/dovecot/dovecot.sieve ${DOVECOT_GLOBAL_SIEVE_FILE}
    chown ${SYS_USER_VMAIL}:${SYS_GROUP_VMAIL} ${DOVECOT_GLOBAL_SIEVE_FILE}
    chmod 0500 ${DOVECOT_GLOBAL_SIEVE_FILE}

    ECHO_DEBUG "Enable dovecot SASL support in postfix: ${POSTFIX_FILE_MAIN_CF}."
    cat ${SAMPLE_DIR}/postfix/main.cf.dovecot >> ${POSTFIX_FILE_MAIN_CF}

    perl -pi -e 's#PH_DOVECOT_SASL_AUTH_SOCKET#$ENV{DOVECOT_SASL_AUTH_SOCKET}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_DOVECOT_SASL_AUTH_PATH#$ENV{_dovecot_sasl_auth_path}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_DOVECOT_DELIVER_BIN#$ENV{DOVECOT_DELIVER_BIN}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_TRANSPORT#$ENV{TRANSPORT}#g' ${POSTFIX_FILE_MAIN_CF}

    ECHO_DEBUG "Create directory for Dovecot plugin: Expire."
    dovecot_expire_dict_dir="$(dirname ${DOVECOT_EXPIRE_DICT_BDB})"
    mkdir -p ${dovecot_expire_dict_dir} && \
    chown -R ${SYS_USER_DOVECOT}:${SYS_GROUP_DOVECOT} ${dovecot_expire_dict_dir} && \
    chmod -R 0750 ${dovecot_expire_dict_dir}

    # Prevent read-only files forced by systemd.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        mkdir -p /etc/systemd/system/dovecot.service.d >> ${INSTALL_LOG} 2>&1
        cp -f ${SAMPLE_DIR}/dovecot/systemd/override.conf /etc/systemd/system/dovecot.service.d >> ${INSTALL_LOG} 2>&1
    fi

    cat >> ${TIP_FILE} <<EOF
Dovecot:
    * Configuration files:
        - ${DOVECOT_CONF}
        - ${DOVECOT_LDAP_CONF} (For OpenLDAP backend)
        - ${DOVECOT_MYSQL_CONF} (For MySQL backend)
        - ${DOVECOT_PGSQL_CONF} (For PostgreSQL backend)
        - ${DOVECOT_REALTIME_QUOTA_CONF} (For real-time quota usage)
        - ${DOVECOT_SHARE_FOLDER_CONF} (For IMAP sharing folder)
    * Syslog config file:
        - ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf (present if rsyslog >= 8.x)
    * RC script: ${DIR_RC_SCRIPTS}/${DOVECOT_RC_SCRIPT_NAME}
    * Log files:
        - ${DOVECOT_LOG_FILE}
        - ${DOVECOT_SIEVE_LOG_FILE}
        - ${DOVECOT_LMTP_LOG_FILE}
        - ${DOVECOT_SYSLOG_FILE_LDA} (present if rsyslog >= 8.x)
        - ${DOVECOT_SYSLOG_FILE_IMAP} (present if rsyslog >= 8.x)
        - ${DOVECOT_SYSLOG_FILE_POP3} (present if rsyslog >= 8.x)
        - ${DOVECOT_SYSLOG_FILE_SIEVE} (present if rsyslog >= 8.x)
    * See also:
        - ${DOVECOT_GLOBAL_SIEVE_FILE}
        - Logrotate config file: ${DOVECOT_LOGROTATE_FILE}

EOF

    echo 'export status_dovecot_config="DONE"' >> ${STATUS_FILE}
}

dovecot_log() {
    ECHO_DEBUG "Configure Dovecot logging."

    mkdir -p ${DOVECOT_LOG_DIR} >> ${INSTALL_LOG} 2>&1
    chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${DOVECOT_LOG_DIR}
    touch ${DOVECOT_LOG_FILE}
    chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${DOVECOT_LOG_FILE}
    chmod 0640 ${DOVECOT_LOG_FILE}

    ECHO_DEBUG "Generate modular syslog and log rotate config files for dovecot log files."
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        # Use rsyslog.
        # Copy rsyslog config file used to filter Dovecot log
        cp ${SAMPLE_DIR}/rsyslog.d/1-iredmail-dovecot.conf ${SYSLOG_CONF_DIR}

        perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf
        perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf
        perl -pi -e 's#PH_DOVECOT_SYSLOG_FILE_LDA#$ENV{DOVECOT_SYSLOG_FILE_LDA}#g' ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf
        perl -pi -e 's#PH_DOVECOT_SYSLOG_FILE_IMAP#$ENV{DOVECOT_SYSLOG_FILE_IMAP}#g' ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf
        perl -pi -e 's#PH_DOVECOT_SYSLOG_FILE_POP3#$ENV{DOVECOT_SYSLOG_FILE_POP3}#g' ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf
        perl -pi -e 's#PH_DOVECOT_SYSLOG_FILE_SIEVE#$ENV{DOVECOT_SYSLOG_FILE_SIEVE}#g' ${SYSLOG_CONF_DIR}/1-iredmail-dovecot.conf

        # Although no need to create log files manually, but fail2ban will skip
        # the log file which doesn't exist while fail2ban starts up, so we
        # create it manually to avoid this.
        for f in ${DOVECOT_LOG_FILE} \
            ${DOVECOT_SYSLOG_FILE_LDA} \
            ${DOVECOT_SYSLOG_FILE_IMAP} \
            ${DOVECOT_SYSLOG_FILE_POP3} \
            ${DOVECOT_SYSLOG_FILE_SIEVE}; do
            ECHO_DEBUG "Create dovecot log file: ${f}."
            touch ${f}
            chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${f}
            chmod 0640 ${f}
        done

        cp -f ${SAMPLE_DIR}/logrotate/dovecot ${DOVECOT_LOGROTATE_FILE}
        chmod 0644 ${DOVECOT_LOGROTATE_FILE}

        perl -pi -e 's#PH_DOVECOT_LOG_DIR#$ENV{DOVECOT_LOG_DIR}#g' ${DOVECOT_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYSLOG_POSTROTATE_CMD#$ENV{SYSLOG_POSTROTATE_CMD}#g' ${DOVECOT_LOGROTATE_FILE}

    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        #
        # modular syslog config file
        #
        cp -f ${SAMPLE_DIR}/freebsd/syslog.d/dovecot.conf ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/dovecot.conf
        perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/dovecot.conf

        #
        # modular log rotate config file
        #
        cp -f ${SAMPLE_DIR}/freebsd/newsyslog.conf.d/dovecot ${DOVECOT_LOGROTATE_FILE}

        perl -pi -e 's#PH_DOVECOT_MASTER_PID#$ENV{DOVECOT_MASTER_PID}#g' ${DOVECOT_LOGROTATE_FILE}
        perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_FILE}#g' ${DOVECOT_LOGROTATE_FILE}
        perl -pi -e 's#PH_DOVECOT_SIEVE_LOG_FILE#$ENV{DOVECOT_SIEVE_LOG_FILE}#g' ${DOVECOT_LOGROTATE_FILE}
        perl -pi -e 's#PH_DOVECOT_LMTP_LOG_FILE#$ENV{DOVECOT_LMTP_LOG_FILE}#g' ${DOVECOT_LOGROTATE_FILE}

        perl -pi -e 's#PH_SYS_USER_SYSLOG#$ENV{SYS_USER_SYSLOG}#g' ${DOVECOT_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_GROUP_SYSLOG#$ENV{SYS_GROUP_SYSLOG}#g' ${DOVECOT_LOGROTATE_FILE}

    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        #
        # modular syslog config file
        #
        if ! grep "${DOVECOT_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
            # '!!' means abort further evaluation after first match
            echo '!!dovecot' >> ${SYSLOG_CONF}
            echo "${IREDMAIL_SYSLOG_FACILITY}.*        ${DOVECOT_LOG_FILE}" >> ${SYSLOG_CONF}
        fi

        if ! grep "${DOVECOT_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_LOG_FILE}    ${SYS_USER_ROOT}:${SYS_GROUP_ROOT}   600  7     *    24    Z "${DOVECOT_DOVEADM_BIN} log reopen"
EOF
        fi

        if ! grep "${DOVECOT_SIEVE_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_SIEVE_LOG_FILE}    ${SYS_USER_ROOT}:${SYS_GROUP_ROOT}   600  7     *    24    Z "${DOVECOT_DOVEADM_BIN} log reopen"
EOF
        fi

        if ! grep "${DOVECOT_LMTP_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_LMTP_LOG_FILE}    ${SYS_USER_VMAIL}:${SYS_GROUP_VMAIL}   600  7     *    24    Z "${DOVECOT_DOVEADM_BIN} log reopen"
EOF
        fi
    fi

    echo 'export status_dovecot_log="DONE"' >> ${STATUS_FILE}
}

dovecot_initialize_db_for_ldap() {
    # Create MySQL database ${IREDADMIN_DB_USER} and addition tables:
    #   - used_quota: used to store realtime quota.
    #   - share_folder: used to store share folder settings.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # If iRedAdmin is not used, create database and import table here.
        ${MYSQL_CLIENT_ROOT} >> ${INSTALL_LOG} 2>&1 <<EOF
-- Create databases.
CREATE DATABASE IF NOT EXISTS ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Import SQL template.
USE ${IREDADMIN_DB_NAME};

-- used_quota
SOURCE ${SAMPLE_DIR}/dovecot/used_quota.mysql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${HOSTNAME}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";

-- share_folder
SOURCE ${SAMPLE_DIR}/dovecot/imap_share_folder.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${HOSTNAME}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";

FLUSH PRIVILEGES;
EOF
    fi

    echo 'export status_dovecot_initialize_db_for_ldap="DONE"' >> ${STATUS_FILE}
}

dovecot_setup()
{
    check_status_before_run dovecot_config
    check_status_before_run dovecot_log
    check_status_before_run dovecot_initialize_db_for_ldap

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # It seems there's a bug in Dovecot port, it will try to invoke '/usr/lib/sendmail'
        # to send vacation response which should be '/usr/sbin/mailwrapper'.
        [ ! -e /usr/lib/sendmail ] && ln -s /usr/sbin/mailwrapper /usr/lib/sendmail >> ${INSTALL_LOG} 2>&1

        # Start service when system start up.
        service_control enable 'dovecot_enable' 'YES'

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # By default, the _dovecot user, and so the Dovecot processes run in
        # the login(1) class of "daemon". On a busy server, it may be advisable
        # to put the _dovecot user and processes in their own login(1) class
        # with tuned resources, such as more open file descriptors etc.
        if [ -f /etc/login.conf ]; then
            if ! grep '^dovecot:' /etc/login.conf &>/dev/null; then
                cat >> /etc/login.conf <<EOF
dovecot:\\
        :openfiles-cur=1024:\\
        :openfiles-max=4096:\\
        :tc=daemon:
EOF
            fi

            # Rebuild the login.conf.db file if necessary
            [ -f /etc/login.conf.db ] && cap_mkdb /etc/login.conf
        fi
    fi

    echo 'export status_dovecot_setup="DONE"' >> ${STATUS_FILE}
}

