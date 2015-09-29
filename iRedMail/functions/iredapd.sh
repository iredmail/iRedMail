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
    [ -d ${IREDAPD_ROOT_DIR} ] || mkdir -p ${IREDAPD_ROOT_DIR}
    extract_pkg ${IREDAPD_TARBALL} ${IREDAPD_ROOT_DIR}

    ECHO_DEBUG "Configure iRedAPD."
    # Create symbol link.
    ln -s ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION} ${IREDAPD_ROOT_DIR}/iredapd >> ${INSTALL_LOG} 2>&1

    # Copy init rc script.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.rhel ${DIR_RC_SCRIPTS}/iredapd
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.debian ${DIR_RC_SCRIPTS}/iredapd
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.freebsd ${DIR_RC_SCRIPTS}/iredapd
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.openbsd ${DIR_RC_SCRIPTS}/iredapd
    else
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.rhel ${DIR_RC_SCRIPTS}/iredapd
    fi

    chmod 0755 ${DIR_RC_SCRIPTS}/iredapd

    if [ X"${DISTRO}" != X'OPENBSD' ]; then
        ECHO_DEBUG "Make iredapd start after system startup."
        service_control enable iredapd >> ${INSTALL_LOG} 2>&1
        export ENABLED_SERVICES="${ENABLED_SERVICES} iredapd"
    fi

    # Set file permission.
    chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION}
    chmod -R 0500 ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION}

    # Copy sample config file.
    cd ${IREDAPD_ROOT_DIR}/iredapd/
    cp settings.py.sample settings.py
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} settings.py
    chmod -R 0400 settings.py

    echo 'export status_iredapd_install="DONE"' >> ${STATUS_FILE}
}

iredapd_import_sql()
{
    ECHO_DEBUG "Import iRedAPD database template."

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create databases and user.
CREATE DATABASE IF NOT EXISTS ${IREDAPD_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Import SQL template.
USE ${IREDAPD_DB_NAME};
SOURCE ${IREDAPD_ROOT_DIR}/iredapd/SQL/iredapd.mysql;
GRANT ALL ON ${IREDAPD_DB_NAME}.* TO "${IREDAPD_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${IREDAPD_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/SQL/iredapd.pgsql ${PGSQL_DATA_DIR}/iredapd.pgsql >> ${INSTALL_LOG} 2>&1
        chmod 0555 ${PGSQL_DATA_DIR}/iredapd.pgsql
        su - ${PGSQL_SYS_USER} -c "psql -d template1" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Create database
CREATE DATABASE ${IREDAPD_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

-- Create user
CREATE USER ${IREDAPD_DB_USER} WITH ENCRYPTED PASSWORD '${IREDAPD_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE ${IREDAPD_DB_NAME} OWNER TO ${IREDAPD_DB_USER};

-- Import SQL template
\c ${IREDAPD_DB_NAME};
\i ${PGSQL_DATA_DIR}/iredapd.pgsql;

-- Grant permissions
GRANT ALL ON throttle,throttle_tracking TO ${IREDAPD_DB_USER};
GRANT ALL ON throttle_id_seq,throttle_tracking_id_seq TO ${IREDAPD_DB_USER};
EOF

        rm -f ${PGSQL_DATA_DIR}/iredapd.pgsql
    fi

    echo 'export status_iredapd_import_sql="DONE"' >> ${STATUS_FILE}
}

iredapd_config()
{
    # General settings.
    perl -pi -e 's#^(listen_address).*#${1} = "$ENV{IREDAPD_BIND_HOST}"#' settings.py
    perl -pi -e 's#^(listen_port).*#${1} = "$ENV{IREDAPD_LISTEN_PORT}"#' settings.py
    perl -pi -e 's#^(run_as_user).*#${1} = "$ENV{IREDAPD_DAEMON_USER}"#' settings.py
    perl -pi -e 's#^(log_level).*#${1} = "info"#' settings.py

    # Backend.
    [ X"${BACKEND}" == X'OPENLDAP' ] && perl -pi -e 's#^(backend).*#${1} = "ldap"#' settings.py
    [ X"${BACKEND}" == X'MYSQL' ] && perl -pi -e 's#^(backend).*#${1} = "mysql"#' settings.py
    [ X"${BACKEND}" == X'PGSQL' ] && perl -pi -e 's#^(backend).*#${1} = "pgsql"#' settings.py

    # Backend related parameters.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#^(ldap_uri).*#${1} = "ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(ldap_binddn).*#${1} = "$ENV{LDAP_BINDDN}"#' settings.py
        perl -pi -e 's#^(ldap_bindpw).*#${1} = "$ENV{LDAP_BINDPW}"#' settings.py
        perl -pi -e 's#^(ldap_basedn).*#${1} = "$ENV{LDAP_BASEDN}"#' settings.py

        perl -pi -e 's#^(plugins).*#${1} = ["reject_null_sender", "throttle", "amavisd_wblist", "ldap_maillist_access_policy"]#' settings.py

    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(sql_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' settings.py
        perl -pi -e 's#^(sql_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(sql_db).*#${1} = "$ENV{VMAIL_DB}"#' settings.py
        perl -pi -e 's#^(sql_user).*#${1} = "$ENV{VMAIL_DB_BIND_USER}"#' settings.py
        perl -pi -e 's#^(sql_password).*#${1} = "$ENV{VMAIL_DB_BIND_PASSWD}"#' settings.py

        perl -pi -e 's#^(plugins).*#${1} = ["reject_null_sender", "throttle", "amavisd_wblist", "sql_alias_access_policy"]#' settings.py
    fi

    # Amavisd database
    perl -pi -e 's#^(amavisd_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' settings.py
    perl -pi -e 's#^(amavisd_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' settings.py
    perl -pi -e 's#^(amavisd_db_name).*#${1} = "$ENV{AMAVISD_DB_NAME}"#' settings.py
    perl -pi -e 's#^(amavisd_db_user).*#${1} = "$ENV{AMAVISD_DB_USER}"#' settings.py
    perl -pi -e 's#^(amavisd_db_password).*#${1} = "$ENV{AMAVISD_DB_PASSWD}"#' settings.py

    # iRedAdmin database
    perl -pi -e 's#^(iredadmin_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_name).*#${1} = "$ENV{IREDADMIN_DB_NAME}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_user).*#${1} = "$ENV{IREDADMIN_DB_USER}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_password).*#${1} = "$ENV{IREDADMIN_DB_PASSWD}"#' settings.py

    # iRedAPD database
    perl -pi -e 's#^(iredapd_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' settings.py
    perl -pi -e 's#^(iredapd_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' settings.py
    perl -pi -e 's#^(iredapd_db_name).*#${1} = "$ENV{IREDAPD_DB_NAME}"#' settings.py
    perl -pi -e 's#^(iredapd_db_user).*#${1} = "$ENV{IREDAPD_DB_USER}"#' settings.py
    perl -pi -e 's#^(iredapd_db_password).*#${1} = "$ENV{IREDAPD_DB_PASSWD}"#' settings.py

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # Start service when system start up.
        service_control enable 'iredapd_enable' 'YES'
    fi

    # Log rotate
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        ECHO_DEBUG "Setting logrotate for iRedAPD log file."
        cat > ${IREDAPD_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${IREDAPD_LOG_FILE} {
    compress
    weekly
    rotate 10
    create 0600 ${SYS_ROOT_USER} ${SYS_ROOT_GROUP}
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        ${DIR_RC_SCRIPTS}/iredapd restart
    endscript
}
EOF
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        if ! grep 'iredapd.log' /etc/newsyslog.conf &>/dev/null; then
            # Define path of PID file to restart iRedAPD service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${IREDAPD_LOG_FILE}    ${SYS_ROOT_USER}:${SYS_ROOT_GROUP}   640  7     *    24    Z ${IREDAPD_PID_FILE}
EOF
        fi

    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep 'iredapd.log' /etc/newsyslog.conf &>/dev/null; then
            # Define command used to restart iRedAPD service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${IREDAPD_LOG_FILE}    ${SYS_ROOT_USER}:${SYS_ROOT_GROUP}   640  7     *    24    Z "${DIR_RC_SCRIPTS}/iredapd restart >/dev/null"
EOF
        fi
    fi

    echo 'export status_iredapd_config="DONE"' >> ${STATUS_FILE}
}

iredapd_setup()
{
    iredapd_install
    iredapd_import_sql
    iredapd_config

    cat >> ${TIP_FILE} <<EOF
iRedAPD - Postfix Policy Daemon:
    * Version: ${IREDAPD_VERSION}
    * Listen address: ${IREDAPD_BIND_HOST}, port: ${IREDAPD_LISTEN_PORT}
    * SQL database account:
        - Database name: ${IREDAPD_DB_NAME}
        - Username: ${IREDAPD_DB_USER}
        - Password: ${IREDAPD_DB_PASSWD}
    * Related files:
        - ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION}/
        - ${IREDAPD_ROOT_DIR}/iredapd/
        - ${IREDAPD_ROOT_DIR}/iredapd/etc/settings.py

EOF

    echo 'export status_iredapd_setup="DONE"' >> ${STATUS_FILE}
}
