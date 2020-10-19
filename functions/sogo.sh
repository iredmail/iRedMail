#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

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

sogo_initialize_db()
{
    ECHO_DEBUG "Initialize SOGo database."

    # Create log directory
    mkdir -p $(dirname ${SOGO_LOG_FILE}) >> ${INSTALL_LOG} 2>&1

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        tmp_sql="${ROOTDIR}/sogo_init.sql"

        cat > ${tmp_sql} <<EOF
CREATE DATABASE ${SOGO_DB_NAME} CHARSET='UTF8';
EOF

        cat >> ${tmp_sql} <<EOF
GRANT ALL ON ${SOGO_DB_NAME}.* TO ${SOGO_DB_USER}@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${SOGO_DB_PASSWD}";
-- GRANT ALL ON ${SOGO_DB_NAME}.* TO ${SOGO_DB_USER}@"${HOSTNAME}" IDENTIFIED BY "${SOGO_DB_PASSWD}";
EOF

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            cat >> ${tmp_sql} <<EOF
GRANT SELECT ON ${VMAIL_DB_NAME}.mailbox TO ${SOGO_DB_USER}@"${MYSQL_GRANT_HOST}";
-- GRANT SELECT ON ${VMAIL_DB_NAME}.mailbox TO ${SOGO_DB_USER}@"${HOSTNAME}";
CREATE VIEW ${SOGO_DB_NAME}.${SOGO_DB_VIEW_AUTH} (c_uid, c_name, c_password, c_cn, mail, domain) AS SELECT username, username, password, name, username, domain FROM ${VMAIL_DB_NAME}.mailbox WHERE enablesogo=1 AND active=1;
EOF
        fi

        ${MYSQL_CLIENT_ROOT} -e "SOURCE ${tmp_sql}"

        # Generate .my.cnf file
        cat > /root/.my.cnf-${SOGO_DB_USER} <<EOF
[client]
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
user=${SOGO_DB_USER}
password="${SOGO_DB_PASSWD}"
EOF

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        tmp_sql="${PGSQL_DATA_DIR}/create_db.sql"

        # Create db, user/role, set ownership
        cat > ${tmp_sql} <<EOF
CREATE DATABASE ${SOGO_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE USER ${SOGO_DB_USER} WITH ENCRYPTED PASSWORD '${SOGO_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE ${SOGO_DB_NAME} OWNER TO ${SOGO_DB_USER};
\c ${SOGO_DB_NAME};
CREATE EXTENSION dblink;
EOF

        # Create view for user authentication
        cat >> ${tmp_sql} <<EOF
CREATE VIEW ${SOGO_DB_VIEW_AUTH} AS
     SELECT * FROM dblink('host=${SQL_SERVER_ADDRESS}
                           port=${SQL_SERVER_PORT}
                           dbname=${VMAIL_DB_NAME}
                           user=${VMAIL_DB_BIND_USER}
                           password=${VMAIL_DB_BIND_PASSWD}',
                          'SELECT username AS c_uid,
                                  username AS c_name,
                                  password AS c_password,
                                  name     AS c_cn,
                                  username AS mail,
                                  domain   AS domain
                             FROM mailbox
                            WHERE enablesogo=1 AND active=1')
         AS ${SOGO_DB_VIEW_AUTH} (c_uid         VARCHAR(255),
                                  c_name        VARCHAR(255),
                                  c_password    VARCHAR(255),
                                  c_cn          VARCHAR(255),
                                  mail          VARCHAR(255),
                                  domain        VARCHAR(255));

ALTER TABLE ${SOGO_DB_VIEW_AUTH} OWNER TO ${SOGO_DB_USER};
EOF

        su - ${SYS_USER_PGSQL} -c "psql -d template1 -f ${tmp_sql} >/dev/null" >> ${INSTALL_LOG} 2>&1
    fi

    rm -f ${tmp_sql} &>/dev/null

    echo 'export status_sogo_initialize_db="DONE"' >> ${STATUS_FILE}
}

sogo_config() {
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # Start services when system start up.
        service_control enable 'memcached_enable' 'YES'
        service_control enable 'memcached_flags' "-l ${MEMCACHED_BIND_ADDRESS}"
        service_control enable 'sogod_enable' 'YES'
    fi

    # Configure SOGo config file
    backup_file ${SOGO_CONF}

    # Create /etc/timezone required by sogo
    if [ ! -f /etc/timezone ]; then
        echo 'America/New_York' > /etc/timezone
    fi

    # Create directory to store config files
    [ ! -d ${SOGO_CONF_DIR} ] && mkdir -p ${SOGO_CONF_DIR}

    cp -f ${SAMPLE_DIR}/sogo/sogo.conf ${SOGO_CONF}
    chown ${SYS_USER_SOGO}:${SYS_GROUP_SOGO} ${SOGO_CONF}
    chmod 0400 ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${SOGO_CONF}

    # PID, log file
    perl -pi -e 's#PH_SOGO_PID_FILE#$ENV{SOGO_PID_FILE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_LOG_FILE#$ENV{SOGO_LOG_FILE}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_MESSAGE_SIZE_LIMIT_KB#$ENV{MESSAGE_SIZE_LIMIT_KB}#g' ${SOGO_CONF}

    # Proxy timeout
    perl -pi -e 's#PH_SOGO_PROXY_TIMEOUT#$ENV{SOGO_PROXY_TIMEOUT}#g' ${SOGO_CONF}
    # WatchDog timeout
    export watchdog_request_timeout="$((SOGO_PROXY_TIMEOUT / 60 + 2 ))"
    perl -pi -e 's#PH_SOGO_WATCHDOG_REQUEST_TIMEOUT#$ENV{watchdog_request_timeout}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_IMAP_SERVER#$ENV{IMAP_SERVER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_SERVER#$ENV{MANAGESIEVE_SERVER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_PORT#$ENV{MANAGESIEVE_PORT}#g' ${SOGO_CONF}

    # SMTP server
    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' ${SOGO_CONF}

    # Memcached server
    perl -pi -e 's#PH_MEMCACHED_BIND_ADDRESS#$ENV{MEMCACHED_BIND_ADDRESS}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_DB_TYPE#$ENV{SOGO_DB_TYPE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_USER#$ENV{SOGO_DB_USER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_PASSWD#$ENV{SOGO_DB_PASSWD}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_NAME#$ENV{SOGO_DB_NAME}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_DB_VIEW_AUTH#$ENV{SOGO_DB_VIEW_AUTH}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_VIEW_ALIASES#$ENV{SOGO_DB_VIEW_ALIASES}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_DB_TABLE_USER_PROFILE#$ENV{SOGO_DB_TABLE_USER_PROFILE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_FOLDER_INFO#$ENV{SOGO_DB_TABLE_FOLDER_INFO}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_SESSIONS_FOLDER#$ENV{SOGO_DB_TABLE_SESSIONS_FOLDER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_ALARMS#$ENV{SOGO_DB_TABLE_ALARMS}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_STORE#$ENV{SOGO_DB_TABLE_STORE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_ACL#$ENV{SOGO_DB_TABLE_ACL}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_CACHE_FOLDER#$ENV{SOGO_DB_TABLE_CACHE_FOLDER}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#g' ${SOGO_CONF}
    if [ X"${SQL_SERVER_ADDRESS_IS_IPV6}" == X'YES' ]; then
        # [ipv6]
        perl -pi -e 's#PH_SQL_SERVER_ADDRESS#[$ENV{SQL_SERVER_ADDRESS}]#g' ${SOGO_CONF}
    else
        perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#g' ${SOGO_CONF}
    fi

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # Enable LDAP as SOGoUserSources
        perl -pi -e 's#/\* LDAP backend##' ${SOGO_CONF}
        perl -pi -e 's#LDAP backend \*/##' ${SOGO_CONF}

        perl -pi -e 's#PH_LDAP_URI#ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}#' ${SOGO_CONF}
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#' ${SOGO_CONF}
        perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#' ${SOGO_CONF}
        perl -pi -e 's#PH_LDAP_BINDPW#$ENV{LDAP_BINDPW}#' ${SOGO_CONF}

        if [ X"${DEFAULT_PASSWORD_SCHEME}" == X'SSHA' ]; then
            perl -pi -e 's#= ssha512#= ssha#' ${SOGO_CONF}
        fi
    else
        # Enable LDAP as SOGoUserSources
        perl -pi -e 's#/\* SQL backend##' ${SOGO_CONF}
        perl -pi -e 's#SQL backend \*/##' ${SOGO_CONF}

        # Enable password change in MySQL backend
        if [ X"${BACKEND}" == X'PGSQL' ]; then
            perl -pi -e 's#(.*SOGoPasswordChangeEnabled = )YES;#${1}NO;#g' ${SOGO_CONF}
        fi
    fi

    # SOGo reads some additional config file for certain parameters.
    # Increase WOWorkerCount.
    if [ X"${DISTRO}" == X'RHEL' \
        -o X"${DISTRO}" == X'DEBIAN' \
        -o X"${DISTRO}" == X'UBUNTU' ]; then
        if [ -f ${ETC_SYSCONFIG_DIR}/sogo ]; then
            perl -pi -e 's/^# (PREFORK=).*/${1}10/g' ${ETC_SYSCONFIG_DIR}/sogo
        fi
    fi

    # Add Dovecot Master User, for vacation message expiration
    cat >> ${DOVECOT_MASTER_USER_PASSWORD_FILE} <<EOF
${SOGO_SIEVE_MASTER_USER}@${DOVECOT_MASTER_USER_DOMAIN}:$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} "${SOGO_SIEVE_MASTER_PASSWD}")
EOF

    cat >> ${SOGO_SIEVE_CREDENTIAL_FILE} <<EOF
${SOGO_SIEVE_MASTER_USER}@${DOVECOT_MASTER_USER_DOMAIN}:${SOGO_SIEVE_MASTER_PASSWD}
EOF

    chown ${SYS_USER_SOGO}:${SYS_GROUP_SOGO} ${SOGO_SIEVE_CREDENTIAL_FILE}
    chmod 0400 ${SOGO_SIEVE_CREDENTIAL_FILE}

    # Start SOGo service to avoid cron job error.
    service_control restart ${SOGO_RC_SCRIPT_NAME}
    sleep 3

    add_postfix_alias ${SYS_USER_SOGO} ${SYS_USER_ROOT}

    # Enable sieve support if Roundcube is not installed
    # WARNING: Do not enable sieve support in both Roundcube and SOGo, because
    #          the sieve rules generated by them are not compatible.
    if [ X"${USE_ROUNDCUBE}" != X'YES' ]; then
        perl -pi -e 's#(//)(SOGoSieveServer.*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoSieveScriptsEnabled.*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoSieveFolderEncoding*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoVacationEnabled.*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoForwardEnabled.*)#${2}#' ${SOGO_CONF}

        # Disable Roundcube in Nginx, redirect '/mail' to SOGo.
        if [ X"${WEB_SERVER}" == X'NGINX' ]; then
            perl -pi -e 's/^#(location.*mail.*SOGo.*)/${1}/g' ${NGINX_CONF_TMPL_DIR}/sogo.tmpl
        fi
    fi

    cat >> ${TIP_FILE} <<EOF
SOGo Groupware:
    * Web access: httpS://${HOSTNAME}/SOGo/
    * Main config file: ${SOGO_CONF}
    * Nginx template file: ${NGINX_CONF_TMPL_DIR}/sogo.tmpl
    * Database:
        - Database name: ${SOGO_DB_NAME}
        - Database user: ${SOGO_DB_USER}
        - Database password: ${SOGO_DB_PASSWD}
    * SOGo sieve account (Warning: it's a Dovecot Master User):
        - file: ${SOGO_SIEVE_CREDENTIAL_FILE}
        - username: ${SOGO_SIEVE_MASTER_USER}@${DOVECOT_MASTER_USER_DOMAIN}
        - password: ${SOGO_SIEVE_MASTER_PASSWD}
    * See also:
        - cron job of system user: ${SYS_USER_SOGO}

EOF

    echo 'export status_sogo_config="DONE"' >> ${STATUS_FILE}
}

sogo_cron_setup()
{
    # Add cron jobs
    cp -f ${SAMPLE_DIR}/sogo/sogo.cron ${CRON_FILE_SOGO} &>/dev/null
    chmod 0600 ${CRON_FILE_SOGO}
    perl -pi -e 's#PH_SOGO_CMD_TOOL#$ENV{SOGO_CMD_TOOL}#g' ${CRON_FILE_SOGO}
    perl -pi -e 's#PH_SOGO_CMD_EALARMS_NOTIFY#$ENV{SOGO_CMD_EALARMS_NOTIFY}#g' ${CRON_FILE_SOGO}
    perl -pi -e 's#PH_SOGO_SIEVE_CREDENTIAL_FILE#$ENV{SOGO_SIEVE_CREDENTIAL_FILE}#g' ${CRON_FILE_SOGO}

    # backup script
    cp -f ${TOOLS_DIR}/backup_sogo.sh ${BACKUP_SCRIPT_SOGO}
    chmod 0400 ${BACKUP_SCRIPT_SOGO}
    perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#g' ${BACKUP_SCRIPT_SOGO}

    # Add cron job for root user
    cat >> ${CRON_FILE_ROOT} <<EOF
# ${PROG_NAME}: Backup SOGo data databases on 04:01AM
1   4   *   *   *   ${SHELL_BASH} ${BACKUP_SCRIPT_SOGO}

EOF

    # Disable cron jobs if we don't need to initialize database on this server.
    if [ X"${INITIALIZE_SQL_DATA}" != X'YES' ]; then
        perl -pi -e 's/(.*sogo-tool.*)/#${1}/g' ${CRON_FILE_SOGO}
    fi

    echo 'export status_sogo_cron_setup="DONE"' >> ${STATUS_FILE}
}

memcached_setup()
{
    # Listen on localhost by default
    if [ X"${DISTRO}" == X'RHEL' ]; then
        if [ -f ${ETC_SYSCONFIG_DIR}/memcached ]; then
            perl -pi -e 's#^(OPTIONS=).*#${1}"-l $ENV{MEMCACHED_BIND_ADDRESS}"#g' ${ETC_SYSCONFIG_DIR}/memcached
        fi
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        if grep -- '^-l' ${MEMCACHED_CONF} &>/dev/null; then
            perl -pi -e 's#^(-l).*#${1} $ENV{MEMCACHED_BIND_ADDRESS}#g' ${MEMCACHED_CONF}
        else
            echo "-l ${MEMCACHED_BIND_ADDRESS}" >> ${MEMCACHED_CONF}
        fi
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        echo "memcached_flags='-u ${MEMCACHED_DAEMIN_USER} -l ${MEMCACHED_BIND_ADDRESS}'" >> ${RC_CONF_LOCAL}
    fi

    echo 'export status_memcached_setup="DONE"' >> ${STATUS_FILE}
}

sogo_setup()
{
    ECHO_INFO "Configure SOGo Groupware (Webmail, Calendar, Address Book, ActiveSync)."

    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run sogo_initialize_db
    fi

    check_status_before_run sogo_config
    check_status_before_run memcached_setup
    check_status_before_run sogo_cron_setup

    write_iredmail_kv "sql_user_${SOGO_DB_USER}" "${SOGO_DB_PASSWD}"
    write_iredmail_kv sogo_sieve_master_password "${SOGO_SIEVE_MASTER_PASSWD}"
    echo 'export status_sogo_setup="DONE"' >> ${STATUS_FILE}
}
