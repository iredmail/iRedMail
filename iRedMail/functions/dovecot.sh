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
    ECHO_INFO "Configure Dovecot (pop3/imap/managesieve server)."

    backup_file ${DOVECOT_CONF}

    ECHO_DEBUG "Configure dovecot: ${DOVECOT_CONF}."

    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        if [ ! -d ${DOVECOT_CONF_DIR} ]; then
            ECHO_ERROR "${DOVECOT_CONF_DIR} not exist."
            mkdir -p ${DOVECOT_CONF_DIR} &>/dev/null
        fi
    fi

    # RHEL/CentOS 6:    Dovecot-2.1.x
    # Debian 7:         Dovecot-2.1.x
    # Ubuntu 12.04:     Dovecot-2.0.x
    dovecot_version="$(dovecot --version | cut -c1,2,3)"
    if [ X"${dovecot_version}" == X'2.0' -o X"${dovecot_version}" == X'2.1' ]; then
        cp ${SAMPLE_DIR}/dovecot/dovecot2.conf ${DOVECOT_CONF}
    else
        cp ${SAMPLE_DIR}/dovecot/dovecot22.conf ${DOVECOT_CONF}
    fi
    chmod 0664 ${DOVECOT_CONF}

    # Base directory.
    perl -pi -e 's#PH_BASE_DIR#$ENV{DOVECOT_BASE_DIR}#' ${DOVECOT_CONF}
    # base_dir is required on OpenBSD
    [ X"${DISTRO}" == X'OPENBSD' ] && \
        perl -pi -e 's/^#(base_dir.*)/${1}/' ${DOVECOT_CONF}

    # Provided services.
    export DOVECOT_PROTOCOLS
    perl -pi -e 's#PH_PROTOCOLS#$ENV{DOVECOT_PROTOCOLS}#' ${DOVECOT_CONF}

    # Set correct uid/gid.
    perl -pi -e 's#PH_MAIL_UID#$ENV{VMAIL_USER_UID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_MAIL_GID#$ENV{VMAIL_USER_GID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_FIRST_VALID_UID#$ENV{VMAIL_USER_UID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_LAST_VALID_UID#$ENV{VMAIL_USER_UID}#' ${DOVECOT_CONF}

    # Log file.
    perl -pi -e 's#PH_LOG_PATH#$ENV{DOVECOT_LOG_FILE}#' ${DOVECOT_CONF}

    # Authentication related settings.
    # Append this domain name if client gives empty realm.
    perl -pi -e 's#PH_AUTH_DEFAULT_REALM#$ENV{FIRST_DOMAIN}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MECHANISMS#$ENV{DOVECOT_AUTH_MECHS}#' ${DOVECOT_CONF}

    # service auth {}
    perl -pi -e 's#PH_DOVECOT_AUTH_USER#$ENV{POSTFIX_DAEMON_USER}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_AUTH_GROUP#$ENV{POSTFIX_DAEMON_GROUP}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MASTER_USER#$ENV{VMAIL_USER_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MASTER_GROUP#$ENV{VMAIL_GROUP_NAME}#' ${DOVECOT_CONF}

    # Virtual mail accounts.
    # Reference: http://wiki2.dovecot.org/AuthDatabase/LDAP
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_LDAP_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#ldap#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_LDAP_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#ldap#' ${DOVECOT_CONF}
    elif [ X"${BACKEND}" == X"MYSQL" ]; then
        # MySQL.
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_MYSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#sql#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_MYSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#sql#' ${DOVECOT_CONF}
    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        # PostgreSQL.
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_PGSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#sql#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_PGSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#sql#' ${DOVECOT_CONF}
    fi

    # Master user.
    perl -pi -e 's#PH_DOVECOT_MASTER_USER_PASSWORD_FILE#$ENV{DOVECOT_MASTER_USER_PASSWORD_FILE}#' ${DOVECOT_CONF}
    touch ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chmod 0500 ${DOVECOT_MASTER_USER_PASSWORD_FILE}

    perl -pi -e 's#PH_AUTH_SOCKET_PATH#$ENV{DOVECOT_AUTH_SOCKET_PATH}#' ${DOVECOT_CONF}

    # Quota.
    perl -pi -e 's#PH_QUOTA_TYPE#$ENV{DOVECOT_QUOTA_TYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_SCRIPT#$ENV{DOVECOT_QUOTA_WARNING_SCRIPT}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_USER#$ENV{VMAIL_USER_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_GROUP#$ENV{VMAIL_GROUP_NAME}#' ${DOVECOT_CONF}

    # Quota dict.
    perl -pi -e 's#PH_SERVICE_DICT_USER#$ENV{VMAIL_USER_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SERVICE_DICT_GROUP#$ENV{VMAIL_GROUP_NAME}#' ${DOVECOT_CONF}
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

    perl -pi -e 's#PH_POSTFIX_CHROOT_DIR#$ENV{POSTFIX_CHROOT_DIR}#' ${DOVECOT_CONF}

    # Generate dovecot quota warning script.
    mkdir -p $(dirname ${DOVECOT_QUOTA_WARNING_SCRIPT}) &>/dev/null

    backup_file ${DOVECOT_QUOTA_WARNING_SCRIPT}
    rm -f ${DOVECOT_QUOTA_WARNING_SCRIPT} &>/dev/null
    cp -f ${SAMPLE_DIR}/dovecot/dovecot2-quota-warning.sh ${DOVECOT_QUOTA_WARNING_SCRIPT}
    if [ X"${DOVECOT_QUOTA_TYPE}" == X'maildir' ]; then
        perl -pi -e 's#(.*)(-o.*plugin.*)#${1}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    export DOVECOT_DELIVER HOSTNAME
    perl -pi -e 's#PH_DOVECOT_DELIVER#$ENV{DOVECOT_DELIVER}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}

    chown root ${DOVECOT_QUOTA_WARNING_SCRIPT}
    chmod 0755 ${DOVECOT_QUOTA_WARNING_SCRIPT}

    # Use '/usr/local/bin/bash' as shabang line, otherwise quota waning will be failed.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        perl -pi -e 's#(.*)/usr/bin/env bash.*#${1}/usr/local/bin/bash#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        backup_file ${DOVECOT_LDAP_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-ldap.conf ${DOVECOT_LDAP_CONF}
        perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_LDAP_CONF}

        perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BIND_VERSION#$ENV{LDAP_BIND_VERSION}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BINDPW#$ENV{LDAP_BINDPW}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_STORAGE_BASE_DIR#$ENV{STORAGE_BASE_DIR}#' ${DOVECOT_LDAP_CONF}

        # Set file permission.
        chmod 0500 ${DOVECOT_LDAP_CONF}

    elif [ X"${BACKEND}" == X"MYSQL" ]; then

        backup_file ${DOVECOT_MYSQL_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-sql.conf ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#(.*mailbox.)(enable.*Lc)(=1)#${1}`${2}`${3}#' ${DOVECOT_MYSQL_CONF}

        perl -pi -e 's#PH_SQL_DRIVER#mysql#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB#$ENV{VMAIL_DB}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#' ${DOVECOT_MYSQL_CONF}

        # Set file permission.
        chmod 0550 ${DOVECOT_MYSQL_CONF}
    elif [ X"${BACKEND}" == X"PGSQL" ]; then

        backup_file ${DOVECOT_PGSQL_CONF}
        if [ X"${DISTRO}" == X'RHEL' ]; then
            # PGSQL 8.x
            cp -f ${SAMPLE_DIR}/dovecot/dovecot-pgsql-8.x.conf ${DOVECOT_PGSQL_CONF}
        else
            cp -f ${SAMPLE_DIR}/dovecot/dovecot-sql.conf ${DOVECOT_PGSQL_CONF}
        fi
        perl -pi -e 's#(.*mailbox.)(enable.*Lc)(=1)#${1}"${2}"${3}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_SQL_DRIVER#pgsql#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB#$ENV{VMAIL_DB}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#' ${DOVECOT_PGSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#' ${DOVECOT_PGSQL_CONF}

        # Set file permission.
        chmod 0550 ${DOVECOT_PGSQL_CONF}
    fi

    # Realtime quota
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        export realtime_quota_db_name="${IREDADMIN_DB_NAME}"
        export realtime_quota_db_user="${IREDADMIN_DB_USER}"
        export realtime_quota_db_passwd="${IREDADMIN_DB_PASSWD}"
    elif [ X"${BACKEND}" == X"MYSQL" ]; then
        export realtime_quota_db_name="${VMAIL_DB}"
        export realtime_quota_db_user="${VMAIL_DB_ADMIN_USER}"
        export realtime_quota_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"
    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        export realtime_quota_db_name="${VMAIL_DB}"
        export realtime_quota_db_user="${VMAIL_DB_BIND_USER}"
        export realtime_quota_db_passwd="${VMAIL_DB_BIND_PASSWD}"
    fi

    # Copy sample config and set file owner/permission
    cp ${SAMPLE_DIR}/dovecot/dovecot-used-quota.conf ${DOVECOT_REALTIME_QUOTA_CONF}
    chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_REALTIME_QUOTA_CONF}
    chmod 0500 ${DOVECOT_REALTIME_QUOTA_CONF}

    # Replace place holders in sample config file
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_NAME#$ENV{realtime_quota_db_name}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_USER#$ENV{realtime_quota_db_user}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_PASSWORD#$ENV{realtime_quota_db_passwd}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_TABLE#$ENV{DOVECOT_REALTIME_QUOTA_TABLE}#' ${DOVECOT_REALTIME_QUOTA_CONF}

    # IMAP shared folder
    backup_file ${DOVECOT_SHARE_FOLDER_CONF}

    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        export share_folder_db_name="${IREDADMIN_DB_NAME}"
        export share_folder_db_user="${IREDADMIN_DB_USER}"
        export share_folder_db_passwd="${IREDADMIN_DB_PASSWD}"
    elif [ X"${BACKEND}" == X"MYSQL" -o X"${BACKEND}" == X'PGSQL' ]; then
        export share_folder_db_name="${VMAIL_DB}"
        export share_folder_db_user="${VMAIL_DB_ADMIN_USER}"
        export share_folder_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"
    fi

    # ACL and share folder settings in dovecot.conf
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_SQLTYPE#$ENV{DOVECOT_SHARE_FOLDER_SQLTYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_CONF#$ENV{DOVECOT_SHARE_FOLDER_CONF}#' ${DOVECOT_CONF}

    # Copy sample config and set file owner/permission
    cp ${SAMPLE_DIR}/dovecot/dovecot-share-folder.conf ${DOVECOT_SHARE_FOLDER_CONF}
    chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_SHARE_FOLDER_CONF}
    chmod 0500 ${DOVECOT_SHARE_FOLDER_CONF}

    # Replace place holders in sample config file
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_NAME#$ENV{share_folder_db_name}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_USER#$ENV{share_folder_db_user}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_PASSWORD#$ENV{share_folder_db_passwd}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}

    # Create MySQL database ${IREDADMIN_DB_USER} and addition tables:
    #   - used_quota: used to store realtime quota.
    #   - share_folder: used to store share folder settings.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # If iRedAdmin is not used, create database and import table here.
        ${MYSQL_CLIENT_ROOT} <<EOF
# Create databases.
CREATE DATABASE IF NOT EXISTS ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

# Import SQL template.
USE ${IREDADMIN_DB_NAME};

# used_quota
SOURCE ${SAMPLE_DIR}/dovecot/used_quota.mysql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";

# share_folder
SOURCE ${SAMPLE_DIR}/dovecot/imap_share_folder.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";

FLUSH PRIVILEGES;
EOF
    fi

    ECHO_DEBUG "Copy global sieve filter rule file: ${DOVECOT_GLOBAL_SIEVE_FILE}."
    cp -f ${SAMPLE_DIR}/dovecot/dovecot.sieve ${DOVECOT_GLOBAL_SIEVE_FILE}
    chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${DOVECOT_GLOBAL_SIEVE_FILE}
    chmod 0500 ${DOVECOT_GLOBAL_SIEVE_FILE}

    for f in ${DOVECOT_LOG_FILE} ${DOVECOT_SIEVE_LOG_FILE} ${DOVECOT_LMTP_LOG_FILE}; do
        ECHO_DEBUG "Create dovecot log file: ${f}."
        touch ${f}
        chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${f}
        chmod 0600 ${f}
    done

    ECHO_DEBUG "Enable dovecot SASL support in postfix: ${POSTFIX_FILE_MAIN_CF}."
    postconf -e mailbox_command="${DOVECOT_DELIVER}"
    postconf -e virtual_transport="${TRANSPORT}"
    postconf -e dovecot_destination_recipient_limit='1'

    postconf -e smtpd_sasl_type='dovecot'
    postconf -e smtpd_sasl_path='private/dovecot-auth'

    ECHO_DEBUG "Create directory for Dovecot plugin: Expire."
    dovecot_expire_dict_dir="$(dirname ${DOVECOT_EXPIRE_DICT_BDB})"
    mkdir -p ${dovecot_expire_dict_dir} && \
    chown -R ${DOVECOT_USER}:${DOVECOT_GROUP} ${dovecot_expire_dict_dir} && \
    chmod -R 0750 ${dovecot_expire_dict_dir}

    cat >> ${POSTFIX_FILE_MASTER_CF} <<EOF
# Use dovecot deliver program as LDA.
dovecot unix    -       n       n       -       -      pipe
    flags=DRhu user=${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} argv=${DOVECOT_DELIVER} -f \${sender} -d \${user}@\${domain} -m \${extension}

EOF

    ECHO_DEBUG "Setting logrotate for dovecot log file."
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        cat > ${DOVECOT_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${DOVECOT_LOG_FILE}
${DOVECOT_SIEVE_LOG_FILE}
${DOVECOT_LMTP_LOG_FILE} {
    compress
    weekly
    rotate 10
    create 0600 ${VMAIL_USER_NAME} ${VMAIL_GROUP_NAME}
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        doveadm log reopen
    endscript
}
EOF
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        if ! grep "${DOVECOT_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_LOG_FILE}    ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}   600  7     *    24    Z    ${DOVECOT_MASTER_PID}
EOF
        fi

        if ! grep "${DOVECOT_SIEVE_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_SIEVE_LOG_FILE}    ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}   600  7     *    24    Z    ${DOVECOT_MASTER_PID}
EOF
        fi

        if ! grep "${DOVECOT_LMTP_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_LMTP_LOG_FILE}    ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}   600  7     *    24    Z    ${DOVECOT_MASTER_PID}
EOF
        fi
    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep "${DOVECOT_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_LOG_FILE}    ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}   600  7     *    24    Z "${DOVECOT_DOVEADM_BIN} log reopen"
EOF
        fi

        if ! grep "${DOVECOT_SIEVE_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_SIEVE_LOG_FILE}    ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}   600  7     *    24    Z "${DOVECOT_DOVEADM_BIN} log reopen"
EOF
        fi

        if ! grep "${DOVECOT_LMTP_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            # Define command used to reopen log service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${DOVECOT_LMTP_LOG_FILE}    ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}   600  7     *    24    Z "${DOVECOT_DOVEADM_BIN} log reopen"
EOF
        fi
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
    * RC script: ${DIR_RC_SCRIPTS}/${DOVECOT_RC_SCRIPT_NAME}
    * Log files:
        - ${DOVECOT_LOG_FILE}
        - ${DOVECOT_SIEVE_LOG_FILE}
        - ${DOVECOT_LMTP_LOG_FILE}
    * See also:
        - ${DOVECOT_GLOBAL_SIEVE_FILE}
        - Logrotate config file: ${DOVECOT_LOGROTATE_FILE}

EOF

    echo 'export status_dovecot_config="DONE"' >> ${STATUS_FILE}
}

enable_dovecot()
{
    check_status_before_run dovecot_config

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # It seems there's a bug in Dovecot port, it will try to invoke '/usr/lib/sendmail'
        # to send vacation response which should be '/usr/sbin/mailwrapper'.
        [ ! -e /usr/lib/sendmail ] && ln -s /usr/sbin/mailwrapper /usr/lib/sendmail &>/dev/null

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
        :openfiles-cur=512:\\
        :openfiles-max=2048:\\
        :tc=daemon:
EOF
            fi

            # Rebuild the login.conf.db file if necessary
            [ -f /etc/login.conf.db ] && cap_mkdb /etc/login.conf
        fi
    fi

    echo 'export status_enable_dovecot="DONE"' >> ${STATUS_FILE}
}

