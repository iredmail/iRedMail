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

sogo_config()
{
    ECHO_INFO "Configure SOGo Groupware (Webmail, Calendar, Address Book, ActiveSync)."

    # Create log directory
    mkdir -p $(dirname ${SOGO_LOG_FILE}) >> ${INSTALL_LOG} 2>&1

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        tmp_sql="${ROOTDIR}/sogo_init.sql"
        cat >> ${tmp_sql} <<EOF
CREATE DATABASE ${SOGO_DB_NAME} CHARSET='UTF8';
GRANT ALL ON ${SOGO_DB_NAME}.* TO ${SOGO_DB_USER}@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${SOGO_DB_PASSWD}";
EOF

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            cat >> ${tmp_sql} <<EOF
GRANT SELECT ON ${VMAIL_DB}.mailbox TO ${SOGO_DB_USER}@"${MYSQL_GRANT_HOST}";
CREATE VIEW ${SOGO_DB_NAME}.${SOGO_DB_AUTH_VIEW} (c_uid, c_name, c_password, c_cn, mail) AS SELECT username, username, password, name, username FROM ${VMAIL_DB}.mailbox WHERE active=1;
EOF
        fi

        ${MYSQL_CLIENT_ROOT} -e "SOURCE ${tmp_sql}"

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        tmp_sql="${PGSQL_DATA_DIR}/create_db.sql"

        # Create db, user/role, set ownership
        cat > ${tmp_sql} <<EOF
CREATE DATABASE ${SOGO_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE USER ${SOGO_DB_USER} WITH ENCRYPTED PASSWORD '${SOGO_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE ${SOGO_DB_NAME} OWNER TO ${SOGO_DB_USER};
\c ${SOGO_DB_NAME};
EOF

        if [ X"${DISTRO}" == X'RHEL' -a  X"${DISTRO_VERSION}" == X'6' ]; then
            cat >> ${tmp_sql} <<EOF
CREATE LANGUAGE plpgsql;
\i /usr/share/pgsql/contrib/dblink.sql;
EOF
        else
            cat >> ${tmp_sql} <<EOF
CREATE EXTENSION dblink;
EOF
        fi

        # Create view for user authentication
        cat >> ${tmp_sql} <<EOF
CREATE VIEW ${SOGO_DB_AUTH_VIEW} AS SELECT * FROM dblink('host=${SQL_SERVER_ADDRESS} port=${SQL_SERVER_PORT} user=${VMAIL_DB_ADMIN_USER} password=${VMAIL_DB_ADMIN_PASSWD} dbname=${VMAIL_DB}', 'SELECT username AS c_uid, username AS c_name, password AS c_password, name AS c_cn, username AS mail FROM mailbox WHERE active=1') AS ${SOGO_DB_AUTH_VIEW} (c_uid VARCHAR(255), c_name VARCHAR(255), c_password VARCHAR(255), c_cn VARCHAR(255), mail VARCHAR(255));
ALTER TABLE ${SOGO_DB_AUTH_VIEW} OWNER TO ${SOGO_DB_USER};
EOF

        su - ${PGSQL_SYS_USER} -c "psql -d template1 -f ${tmp_sql} >/dev/null" >> ${INSTALL_LOG} 2>&1
    fi

    rm -f ${tmp_sql} &>/dev/null

    # Configure SOGo config file
    backup_file ${SOGO_CONF}

    # Create /etc/timezone required by sogo
    if [ ! -f /etc/timezone ]; then
        echo 'America/New_York' > /etc/timezone
    fi

    # Create directory to store config files
    [ ! -d ${SOGO_CONF_DIR} ] && mkdir -p ${SOGO_CONF_DIR}

    cp -f ${SAMPLE_DIR}/sogo/sogo.conf ${SOGO_CONF}
    chown ${SOGO_DAEMON_USER}:${SOGO_DAEMON_GROUP} ${SOGO_CONF}
    chmod 0400 ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${SOGO_CONF}

    # PID, log file
    perl -pi -e 's#PH_SOGO_PID_FILE#$ENV{SOGO_PID_FILE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_LOG_FILE#$ENV{SOGO_LOG_FILE}#g' ${SOGO_CONF}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Default 'WOPort = 127.0.0.1:20000;' doesn't work on OpenBSD
        perl -pi -e 's#(.*WOPort = ).*#${1}\*:$ENV{SOGO_BIND_PORT};#' ${SOGO_CONF}

        # Default pid file is /var/run/sogo/sogo.pid, but SOGo rc script on
        # OpenBSD doesn't create this directory automatically, so we use this
        # alternative directory instead.
        perl -pi -e 's#//(WOPidFile =).*#${1} /var/log/sogo/sogo.pid;#' ${SOGO_CONF}
    fi

    perl -pi -e 's#PH_IMAP_SERVER#$ENV{IMAP_SERVER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_BIND_HOST#$ENV{MANAGESIEVE_BIND_HOST}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_PORT#$ENV{MANAGESIEVE_PORT}#g' ${SOGO_CONF}

    # SMTP server
    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' ${SOGO_CONF}

    # Memcached server
    perl -pi -e 's#PH_MEMCACHED_BIND_HOST#$ENV{MEMCACHED_BIND_HOST}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_DB_TYPE#$ENV{SOGO_DB_TYPE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_USER#$ENV{SOGO_DB_USER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_PASSWD#$ENV{SOGO_DB_PASSWD}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_NAME#$ENV{SOGO_DB_NAME}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_AUTH_VIEW#$ENV{SOGO_DB_AUTH_VIEW}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_DB_TABLE_USER_PROFILE#$ENV{SOGO_DB_TABLE_USER_PROFILE}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_FOLDER_INFO#$ENV{SOGO_DB_TABLE_FOLDER_INFO}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_SESSIONS_FOLDER#$ENV{SOGO_DB_TABLE_SESSIONS_FOLDER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_TABLE_ALARMS#$ENV{SOGO_DB_TABLE_ALARMS}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#g' ${SOGO_CONF}

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # Enable LDAP as SOGoUserSources
        perl -pi -e 's#/\* LDAP backend##' ${SOGO_CONF}
        perl -pi -e 's#LDAP backend \*/##' ${SOGO_CONF}

        perl -pi -e 's#PH_LDAP_URI#ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}#' ${SOGO_CONF}
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#' ${SOGO_CONF}
        perl -pi -e 's#PH_LDAP_ADMIN_DN#$ENV{LDAP_ADMIN_DN}#' ${SOGO_CONF}
        perl -pi -e 's#PH_LDAP_ADMIN_PW#$ENV{LDAP_ADMIN_PW}#' ${SOGO_CONF}
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

    # Enable ActiveSync in Apache
    if [ -f ${SOGO_HTTPD_CONF} ]; then
        perl -pi -e 's/^#(.*Microsoft-Server-ActiveSync.*)/${1}/g' ${SOGO_HTTPD_CONF}
        perl -pi -e 's/^#(.*retry.*connectiontimeout.*timeout.*)/${1}/g' ${SOGO_HTTPD_CONF}

        perl -pi -e 's#yourhostname#$ENV{HOSTNAME}#g' ${SOGO_HTTPD_CONF}

        #perl -pi -e 's/^(.*x-webobjects-server-port.).*/#${1} "443"/g' ${SOGO_HTTPD_CONF}
        #perl -pi -e 's/^(.*x-webobjects-server-name.*)/#${1}/g' ${SOGO_HTTPD_CONF}
        #perl -pi -e 's/^(.*x-webobjects-server-url.*)/#${1}/g' ${SOGO_HTTPD_CONF}
    fi

    # Add Dovecot Master User, for vacation message expiration
    cat >> ${DOVECOT_MASTER_USER_PASSWORD_FILE} <<EOF
${SOGO_SIEVE_MASTER_USER}@${DOVECOT_MASTER_USER_DOMAIN}:$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} "${SOGO_SIEVE_MASTER_PASSWD}")
EOF

    cat >> ${SOGO_SIEVE_CREDENTIAL_FILE} <<EOF
${SOGO_SIEVE_MASTER_USER}@${DOVECOT_MASTER_USER_DOMAIN}:${SOGO_SIEVE_MASTER_PASSWD}
EOF

    chown ${SOGO_DAEMON_USER}:${SOGO_DAEMON_GROUP} ${SOGO_SIEVE_CREDENTIAL_FILE}
    chmod 0400 ${SOGO_SIEVE_CREDENTIAL_FILE}

    # Start SOGo service to avoid cron job error.
    service_control restart ${SOGO_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1
    sleep 3

    # Add cron job for email reminders
    cp -f ${SAMPLE_DIR}/sogo/sogo.cron ${SOGO_CRON_FILE} &>/dev/null
    perl -pi -e 's#PH_SOGO_CMD_TOOL#$ENV{SOGO_CMD_TOOL}#g' ${SOGO_CRON_FILE}
    perl -pi -e 's#PH_SOGO_CMD_EALARMS_NOTIFY#$ENV{SOGO_CMD_EALARMS_NOTIFY}#g' ${SOGO_CRON_FILE}
    perl -pi -e 's#PH_SOGO_SIEVE_CREDENTIAL_FILE#$ENV{SOGO_SIEVE_CREDENTIAL_FILE}#g' ${SOGO_CRON_FILE}

    add_postfix_alias ${SOGO_DAEMON_USER} ${SYS_ROOT_USER}

    # if Roundcube is not installed
    if [ X"${USE_RCM}" != X"YES" ]; then
        # Enable managesieve support
        perl -pi -e 's#(//)(SOGoSieveServer.*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoSieveScriptsEnabled.*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoSieveFolderEncoding*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoVacationEnabled.*)#${2}#' ${SOGO_CONF}
        perl -pi -e 's#(//)(SOGoForwardEnabled.*)#${2}#' ${SOGO_CONF}

        # URL redirect: /mail -> /SOGo
        mkdir -p ${RCM_HTTPD_ROOT_SYMBOL_LINK}
        cat > ${RCM_HTTPD_ROOT_SYMBOL_LINK}/index.php <<EOF
<html>
    <head>
        <meta HTTP-EQUIV="REFRESH" content="0; url=/SOGo">
    </head>
</html>
EOF
    fi

    if [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # SOGo package doesn't install Apache config file to correct place,
            # we have to fix it here.
            if [ -f /etc/apache2/conf.d/SOGo.conf \
                -a -d /etc/apache2/conf-available \
                -a -d /etc/apache2/conf-enabled ]; then
                cd /etc/apache2/conf-available/ && ln -s ../conf.d/SOGo.conf . >> ${INSTALL_LOG} 2>&1
            fi

            a2enconf SOGo >> ${INSTALL_LOG} 2>&1
        fi
    fi

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # Start service when system start up.
        service_control enable 'memcached_enable' 'YES'
        service_control enable 'sogod_enable' 'YES'
    fi

    cat >> ${TIP_FILE} <<EOF
SOGo Groupware:
    * Web access: httpS://${HOSTNAME}/SOGo/
    * Main config file: ${SOGO_CONF}
    * Apache config file: ${SOGO_HTTPD_CONF}
    * Nginx config file: ${NGINX_CONF_DEFAULT}
    * Database:
        - Database name: ${SOGO_DB_NAME}
        - Database user: ${SOGO_DB_USER}
        - Database password: ${SOGO_DB_PASSWD}
    * SOGo sieve account (Warning: it's a Dovecot Master User):
        - file: ${SOGO_SIEVE_CREDENTIAL_FILE}
        - username: ${SOGO_SIEVE_MASTER_USER}@${DOVECOT_MASTER_USER_DOMAIN}
        - password: ${SOGO_SIEVE_MASTER_PASSWD}
    * See also:
        - cron job of system user: ${SOGO_DAEMON_USER}

EOF

    echo 'export status_sogo_config="DONE"' >> ${STATUS_FILE}
}
