#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Install & config necessary packages for iRedAPD.

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


iredapd_install()
{
    ECHO_INFO "Configure iRedAPD (postfix policy daemon)."

    # Extract source tarball.
    cd ${PKG_MISC_DIR}
    [ -d ${IREDAPD_PARENT_DIR} ] || mkdir -p ${IREDAPD_PARENT_DIR}
    extract_pkg ${IREDAPD_TARBALL} ${IREDAPD_PARENT_DIR}

    ECHO_DEBUG "Configure iRedAPD."
    # Create symbol link.
    ln -s ${IREDAPD_ROOT_DIR} ${IREDAPD_ROOT_DIR_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

    # Copy init rc script.
    if [ X"${USE_SYSTEMD}" == X'YES' ]; then
        ECHO_DEBUG "Create symbol link: ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.service -> ${SYSTEMD_SERVICE_DIR}/iredapd.service."
        ln -s ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.service ${SYSTEMD_SERVICE_DIR}/iredapd.service >> ${INSTALL_LOG} 2>&1
        systemctl daemon-reload >> ${INSTALL_LOG} 2>&1
    else
        if [ X"${DISTRO}" == X'RHEL' ]; then
            cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.rhel ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.debian ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'FREEBSD' ]; then
            cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.freebsd ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
            service_control enable 'iredapd_enable' 'YES' >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.openbsd ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
        else
            cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.rhel ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
        fi

        chmod 0755 ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
    fi

    ECHO_DEBUG "Make iredapd start after system startup."
    service_control enable iredapd >> ${INSTALL_LOG} 2>&1
    export ENABLED_SERVICES="${ENABLED_SERVICES} iredapd"

    # Set file permission.
    chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${IREDAPD_ROOT_DIR}
    chmod -R 0500 ${IREDAPD_ROOT_DIR}

    # Copy sample config file.
    cd ${IREDAPD_ROOT_DIR_SYMBOL_LINK}
    cp settings.py.sample settings.py
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} settings.py
    chmod -R 0400 settings.py

    echo 'export status_iredapd_install="DONE"' >> ${STATUS_FILE}
}

iredapd_initialize_db()
{
    ECHO_DEBUG "Import iRedAPD database template."

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create databases and user.
CREATE DATABASE IF NOT EXISTS ${IREDAPD_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Import SQL template.
USE ${IREDAPD_DB_NAME};
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/iredapd.mysql;
GRANT ALL ON ${IREDAPD_DB_NAME}.* TO '${IREDAPD_DB_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${IREDAPD_DB_PASSWD}';
-- GRANT ALL ON ${IREDAPD_DB_NAME}.* TO '${IREDAPD_DB_USER}'@'${HOSTNAME}' IDENTIFIED BY '${IREDAPD_DB_PASSWD}';
FLUSH PRIVILEGES;

-- Enable greylisting by default.
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/enable_global_greylisting.sql;

-- Import greylisting whitelist domains.
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/greylisting_whitelist_domains.sql;

-- Blacklist some rDNS names
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/wblist_rdns.sql;
EOF

        # Generate .my.cnf file
        cat > /root/.my.cnf-${IREDAPD_DB_USER} <<EOF
[client]
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
user=${IREDAPD_DB_USER}
password="${IREDAPD_DB_PASSWD}"
EOF

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        mkdir ${PGSQL_DATA_DIR}/tmp 2>/dev/null
        cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/*sql ${PGSQL_DATA_DIR}/tmp/ >> ${INSTALL_LOG} 2>&1
        chmod 0555 ${PGSQL_DATA_DIR}/tmp/*sql

        su - ${PGSQL_SYS_USER} -c "psql -d template1" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Create user
CREATE USER ${IREDAPD_DB_USER} WITH ENCRYPTED PASSWORD '${IREDAPD_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Create database
CREATE DATABASE ${IREDAPD_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

ALTER DATABASE ${IREDAPD_DB_NAME} OWNER TO ${IREDAPD_DB_USER};
EOF

        su - ${PGSQL_SYS_USER} -c "psql -U ${IREDAPD_DB_USER} -d ${IREDAPD_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Import SQL template
\i ${PGSQL_DATA_DIR}/tmp/iredapd.pgsql;

-- Enable greylisting by default.
\i ${PGSQL_DATA_DIR}/tmp/enable_global_greylisting.sql;

-- Import greylisting whitelist domains.
\i ${PGSQL_DATA_DIR}/tmp/greylisting_whitelist_domains.sql;

-- Blacklist some rDNS names
\i ${PGSQL_DATA_DIR}/tmp/wblist_rdns.sql;

EOF

        rm -rf ${PGSQL_DATA_DIR}/tmp >> ${INSTALL_LOG} 2>&1
    fi

    echo 'export status_iredapd_initialize_db="DONE"' >> ${STATUS_FILE}
}

iredapd_config()
{
    perl -pi -e 's#^(listen_address).*#${1} = "$ENV{IREDAPD_BIND_HOST}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(listen_port).*#${1} = "$ENV{IREDAPD_LISTEN_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(run_as_user).*#${1} = "$ENV{IREDAPD_DAEMON_USER}"#' ${IREDAPD_CONF}

    [ -d ${IREDAPD_LOG_DIR} ] || mkdir -p ${IREDAPD_LOG_DIR} >> ${INSTALL_LOG} 2>&1
    chown -R ${IREDAPD_DB_USER}:${IREDAPD_DAEMON_GROUP} ${IREDAPD_LOG_DIR} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#^(log_file).*#${1} = "$ENV{IREDAPD_LOG_FILE}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(log_level).*#${1} = "info"#' ${IREDAPD_CONF}

    # Backend.
    [ X"${BACKEND}" == X'OPENLDAP' ] && perl -pi -e 's#^(backend).*#${1} = "ldap"#' ${IREDAPD_CONF}
    [ X"${BACKEND}" == X'MYSQL' ] && perl -pi -e 's#^(backend).*#${1} = "mysql"#' ${IREDAPD_CONF}
    [ X"${BACKEND}" == X'PGSQL' ] && perl -pi -e 's#^(backend).*#${1} = "pgsql"#' ${IREDAPD_CONF}

    # Backend related parameters.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#^(ldap_uri).*#${1} = "ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(ldap_binddn).*#${1} = "$ENV{LDAP_BINDDN}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(ldap_bindpw).*#${1} = "$ENV{LDAP_BINDPW}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(ldap_basedn).*#${1} = "$ENV{LDAP_BASEDN}"#' ${IREDAPD_CONF}

        perl -pi -e 's#^(plugins).*#${1} = ["reject_null_sender", "wblist_rdns", "reject_sender_login_mismatch", "greylisting", "throttle", "amavisd_wblist", "ldap_maillist_access_policy"]#' ${IREDAPD_CONF}

    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(vmail_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_name).*#${1} = "$ENV{VMAIL_DB_NAME}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_user).*#${1} = "$ENV{VMAIL_DB_BIND_USER}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_password).*#${1} = "$ENV{VMAIL_DB_BIND_PASSWD}"#' ${IREDAPD_CONF}

        perl -pi -e 's#^(plugins).*#${1} = ["reject_null_sender", "wblist_rdns", "reject_sender_login_mismatch", "greylisting", "throttle", "amavisd_wblist", "sql_alias_access_policy"]#' ${IREDAPD_CONF}
    fi

    # Amavisd database
    perl -pi -e 's#^(amavisd_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_name).*#${1} = "$ENV{AMAVISD_DB_NAME}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_user).*#${1} = "$ENV{AMAVISD_DB_USER}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_password).*#${1} = "$ENV{AMAVISD_DB_PASSWD}"#' ${IREDAPD_CONF}

    # iRedAdmin database
    perl -pi -e 's#^(iredadmin_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_name).*#${1} = "$ENV{IREDADMIN_DB_NAME}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_user).*#${1} = "$ENV{IREDADMIN_DB_USER}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_password).*#${1} = "$ENV{IREDADMIN_DB_PASSWD}"#' ${IREDAPD_CONF}

    # iRedAPD database
    perl -pi -e 's#^(iredapd_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_name).*#${1} = "$ENV{IREDAPD_DB_NAME}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_user).*#${1} = "$ENV{IREDAPD_DB_USER}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_password).*#${1} = "$ENV{IREDAPD_DB_PASSWD}"#' ${IREDAPD_CONF}

    if [ X"${LOCAL_ADDRESS}" != X'127.0.0.1' ]; then
        echo "MYNETWORKS = ['${LOCAL_ADDRESS}']" >> ${IREDAPD_CONF}
    fi

    echo 'export status_iredapd_config="DONE"' >> ${STATUS_FILE}
}

iredapd_cron_setup()
{
    # Setup cron job to clean up expired throttle tracking records.
    # Note: use ${IREDAPD_ROOT_DIR_SYMBOL_LINK} instead of ${IREDAPD_ROOT_DIR}
    # here, so that we don't need to change cron job after upgrading iRedAPD.
    cat >> ${CRON_FILE_ROOT} <<EOF
# iRedAPD: Clean up expired tracking records hourly.
1   *   *   *   *   ${PYTHON_BIN} ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/tools/cleanup_db.py >/dev/null

# iRedAPD: Convert SPF DNS record of specified domain names to IP
#          addresses/networks hourly.
2   *   *   *   *   ${PYTHON_BIN} ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/tools/spf_to_greylist_whitelists.py >/dev/null

EOF

    # Disable cron jobs if we don't need to initialize database on this server.
    if [ X"${INITIALIZE_SQL_DATA}" != X'YES' ]; then
        perl -pi -e 's/(.*iredapd.*tools.*cleanup_db.py.*)/#${1}/g' ${CRON_FILE_ROOT}
        perl -pi -e 's/(.*iredapd.*tools.*spf_to_greylist_whitelists.py.*)/#${1}/g' ${CRON_FILE_ROOT}
    fi

    echo 'export status_iredapd_cron_setup="DONE"' >> ${STATUS_FILE}
}

iredapd_setup()
{
    check_status_before_run iredapd_install

    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run iredapd_initialize_db
    fi

    check_status_before_run iredapd_cron_setup
    check_status_before_run iredapd_config

    cat >> ${TIP_FILE} <<EOF
iRedAPD - Postfix Policy Server:
    * Version: ${IREDAPD_VERSION}
    * Listen address: ${IREDAPD_BIND_HOST}, port: ${IREDAPD_LISTEN_PORT}
    * SQL database account:
        - Database name: ${IREDAPD_DB_NAME}
        - Username: ${IREDAPD_DB_USER}
        - Password: ${IREDAPD_DB_PASSWD}
    * Configuration file:
        - ${IREDAPD_CONF}
    * Related files:
        - ${IREDAPD_ROOT_DIR}
        - ${IREDAPD_ROOT_DIR_SYMBOL_LINK} (symbol link to ${IREDAPD_ROOT_DIR}

EOF

    echo 'export status_iredapd_setup="DONE"' >> ${STATUS_FILE}
}
