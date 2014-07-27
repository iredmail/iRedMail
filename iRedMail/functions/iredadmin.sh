#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Install & config necessary packages for iRedAdmin.

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

iredadmin_config()
{
    ECHO_INFO "Configure iRedAdmin (official web-based admin panel)."

    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        ECHO_DEBUG "Enable apache module: wsgi."
        a2enmod wsgi >/dev/null 2>&1
    fi

    cd ${PKG_MISC_DIR}

    # Extract source tarball.
    extract_pkg ${IREDADMIN_TARBALL} ${HTTPD_SERVERROOT}

    # Create symbol link, so that we don't need to modify apache
    # conf.d/iredadmin.conf file after upgrading this component.
    ln -s ${IREDADMIN_HTTPD_ROOT} ${IREDADMIN_HTTPD_ROOT_SYMBOL_LINK} 2>/dev/null

    ECHO_DEBUG "Set correct permission for iRedAdmin: ${IREDADMIN_HTTPD_ROOT}."
    chown -R ${IREDADMIN_USER_NAME}:${IREDADMIN_GROUP_NAME} ${IREDADMIN_HTTPD_ROOT}
    chmod -R 0555 ${IREDADMIN_HTTPD_ROOT}

    # Copy sample configure file.
    cd ${IREDADMIN_HTTPD_ROOT}/

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        cp settings.py.ldap.sample settings.py
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        cp settings.py.mysql.sample settings.py
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp settings.py.pgsql.sample settings.py
    fi

    chown -R ${IREDADMIN_USER_NAME}:${IREDADMIN_GROUP_NAME} settings.py
    chmod 0400 settings.py

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Change file owner
        # iRedAdmin is not running as user 'iredadmin' on OpenBSD
        chown -R ${HTTPD_USER}:${HTTPD_GROUP} settings.py
    fi

    if [ X"${WEB_SERVER_USE_APACHE}" == X'YES' ]; then
        backup_file ${IREDADMIN_HTTPD_CONF}
        ECHO_DEBUG "Create directory alias for iRedAdmin."

        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # Create directory alias.
            perl -pi -e 's#^(\s*</VirtualHost>)#Alias /iredadmin/static "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/static"\n${1}#' ${HTTPD_SSL_CONF}
            perl -pi -e 's#^(\s*</VirtualHost>)#ScriptAlias /iredadmin "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/iredadmin.py"\n${1}#' ${HTTPD_SSL_CONF}

            # There's no wsgi module for Apache available on OpenBSD, so
            # iRedAdmin runs as CGI program.
            cat > ${IREDADMIN_HTTPD_CONF} <<EOF
AddType text/html .py
AddHandler cgi-script .py

<Directory "${IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}">
    Options +ExecCGI
    Order allow,deny
    Allow from all
</Directory>
EOF
        else
            perl -pi -e 's#^(\s*</VirtualHost>)#Alias /iredadmin/static "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/static/"\n${1}#' ${HTTPD_SSL_CONF}
            perl -pi -e 's#^(\s*</VirtualHost>)#WSGIScriptAlias /iredadmin "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/iredadmin.py/"\n${1}#' ${HTTPD_SSL_CONF}

            # iRedAdmin runs as WSGI application with Apache + mod_wsgi
            cat > ${IREDADMIN_HTTPD_CONF} <<EOF
WSGISocketPrefix /var/run/wsgi
WSGIDaemonProcess iredadmin user=${IREDADMIN_USER_NAME} threads=15
WSGIProcessGroup ${IREDADMIN_GROUP_NAME}

AddType text/html .py

<Directory ${IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/>
    Order allow,deny
    Allow from all
</Directory>
EOF
        fi

        # Enable Apache module config file on Ubuntu 14.04.
        if [ X"${DISTRO}" == X'UBUNTU' ]; then
            a2enconf iredadmin &>/dev/null
        fi
    fi

    ECHO_DEBUG "Import iredadmin database template."
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        # Required by MySQL-5.6: TEXT/BLOB column cannot have a default value.
        perl -pi -e 's#(.*maildir.*)TEXT(.*)#${1}VARCHAR\(255\)${2}#g' ${IREDADMIN_HTTPD_ROOT}/docs/samples/iredadmin.sql;

        ${MYSQL_CLIENT_ROOT} <<EOF
# Create databases.
CREATE DATABASE ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

# Import SQL template.
USE ${IREDADMIN_DB_NAME};
SOURCE ${IREDADMIN_HTTPD_ROOT}/docs/samples/iredadmin.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF

        # Import addition tables.
        if [ X"${BACKEND}" == X"OPENLDAP" ]; then
            ${MYSQL_CLIENT_ROOT} <<EOF
USE ${IREDADMIN_DB_NAME};
SOURCE ${SAMPLE_DIR}/dovecot/used_quota.mysql;
SOURCE ${SAMPLE_DIR}/dovecot/imap_share_folder.sql;
FLUSH PRIVILEGES;
EOF
        fi

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp -f ${IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/docs/samples/iredadmin.pgsql ${PGSQL_DATA_DIR}/ >/dev/null
        chmod 0777 ${PGSQL_DATA_DIR}/iredadmin.pgsql >/dev/null
        su - ${PGSQL_SYS_USER} -c "psql -d template1" >/dev/null <<EOF
-- Create database
CREATE DATABASE ${IREDADMIN_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
-- Create user
CREATE USER ${IREDADMIN_DB_USER} WITH ENCRYPTED PASSWORD '${IREDADMIN_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
\c ${IREDADMIN_DB_NAME};
\i ${PGSQL_DATA_DIR}/iredadmin.pgsql;
-- Grant permissions
GRANT INSERT,UPDATE,DELETE,SELECT on sessions,log,updatelog to ${IREDADMIN_DB_USER};
GRANT UPDATE,USAGE,SELECT ON log_id_seq TO ${IREDADMIN_DB_USER};
EOF
        rm -f ${PGSQL_DATA_DIR}/iredadmin.pgsql
    fi

    ECHO_DEBUG "Configure iRedAdmin."

    # Modify iRedAdmin settings.
    # [general] section.
    ECHO_DEBUG "Configure general settings."
    perl -pi -e 's#^(webmaster =).*#${1} "$ENV{FIRST_USER}\@$ENV{FIRST_DOMAIN}"#' settings.py
    perl -pi -e 's#^(storage_base_directory =).*#${1} "$ENV{STORAGE_MAILBOX_DIR}"#' settings.py

    # [iredadmin] section.
    ECHO_DEBUG "Configure iredadmin database related settings."
    perl -pi -e 's#^(iredadmin_db_host =).*#${1} "$ENV{SQL_SERVER}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_port =).*#${1} "$ENV{SQL_SERVER_PORT}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_name =).*#${1} "$ENV{IREDADMIN_DB_NAME}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_user =).*#${1} "$ENV{IREDADMIN_DB_USER}"#' settings.py
    perl -pi -e 's#^(iredadmin_db_password =).*#${1} "$ENV{IREDADMIN_DB_PASSWD}"#' settings.py

    # Backend related settings.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ECHO_DEBUG "Configure OpenLDAP backend related settings."
        perl -pi -e 's#^(ldap_uri =).*#${1} "ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(ldap_basedn =).*#${1} "$ENV{LDAP_BASEDN}"#' settings.py
        perl -pi -e 's#^(ldap_domainadmin_dn =).*#${1} "$ENV{LDAP_ADMIN_BASEDN}"#' settings.py
        perl -pi -e 's#^(ldap_bind_dn =).*#${1} "$ENV{LDAP_ADMIN_DN}"#' settings.py
        perl -pi -e 's#^(ldap_bind_password =).*#${1} "$ENV{LDAP_ADMIN_PW}"#' settings.py

    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        ECHO_DEBUG "Configure SQL mail accounts related settings."
        perl -pi -e 's#^(vmail_db_host =).*#${1} "$ENV{SQL_SERVER}"#' settings.py
        perl -pi -e 's#^(vmail_db_port =).*#${1} "$ENV{SQL_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(vmail_db_name =).*#${1} "$ENV{VMAIL_DB}"#' settings.py
        perl -pi -e 's#^(vmail_db_user =).*#${1} "$ENV{VMAIL_DB_ADMIN_USER}"#' settings.py
        perl -pi -e 's#^(vmail_db_password =).*#${1} "$ENV{VMAIL_DB_ADMIN_PASSWD}"#' settings.py
    fi

    # Policyd or Cluebringer
    if [ X"${USE_CLUEBRINGER}" == X'YES' ]; then
        ECHO_DEBUG "Configure Cluebringer related settings."
        perl -pi -e 's#^(policyd_enabled =).*#${1} True#' settings.py
        perl -pi -e 's#^(policyd_db_host =).*#${1} "$ENV{SQL_SERVER}"#' settings.py
        perl -pi -e 's#^(policyd_db_port =).*#${1} "$ENV{SQL_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(policyd_db_name =).*#${1} "$ENV{CLUEBRINGER_DB_NAME}"#' settings.py
        perl -pi -e 's#^(policyd_db_user =).*#${1} "$ENV{CLUEBRINGER_DB_USER}"#' settings.py
        perl -pi -e 's#^(policyd_db_password =).*#${1} "$ENV{CLUEBRINGER_DB_PASSWD}"#' settings.py
    else
        perl -pi -e 's#^(policyd_enabled =).*#${1} False#' settings.py
    fi

    # Amavisd.
    ECHO_DEBUG "Configure Amavisd related settings."
    perl -pi -e 's#^(amavisd_db_host =).*#${1} "$ENV{SQL_SERVER}"#' settings.py
    perl -pi -e 's#^(amavisd_db_port =).*#${1} "$ENV{SQL_SERVER_PORT}"#' settings.py
    perl -pi -e 's#^(amavisd_db_name =).*#${1} "$ENV{AMAVISD_DB_NAME}"#' settings.py
    perl -pi -e 's#^(amavisd_db_user =).*#${1} "$ENV{AMAVISD_DB_USER}"#' settings.py
    perl -pi -e 's#^(amavisd_db_password =).*#${1} "$ENV{AMAVISD_DB_PASSWD}"#' settings.py

    perl -pi -e 's#^(amavisd_enable_logging =).*#${1} True#' settings.py
    perl -pi -e 's#^(amavisd_enable_quarantine =).*#${1} True#' settings.py
    perl -pi -e 's#^(amavisd_quarantine_port =).*#${1} "$ENV{AMAVISD_QUARANTINE_PORT}"#' settings.py

    cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Cleanup Amavisd database
1  2   *   *   *   ${PYTHON_BIN} ${IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/tools/cleanup_amavisd_db.py >/dev/null
EOF

    cat >> ${TIP_FILE} <<EOF
iRedAdmin - official web-based admin panel:
    * Version: ${IREDADMIN_VERSION}
    * Configuration files:
        - ${HTTPD_SERVERROOT}/iRedAdmin-${IREDADMIN_VERSION}/
        - ${HTTPD_SERVERROOT}/iRedAdmin-${IREDADMIN_VERSION}/settings.py*
    * URL:
        - https://${HOSTNAME}/iredadmin/
    * Login account:
        - Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}, password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * SQL database account:
        - Database name: ${IREDADMIN_DB_NAME}
        - Username: ${IREDADMIN_DB_USER}
        - Password: ${IREDADMIN_DB_PASSWD}
    * Settings:
        - ${IREDADMIN_HTTPD_ROOT}/settings.py
    * See also:
        - ${IREDADMIN_HTTPD_CONF}

EOF

    echo 'export status_iredadmin_config="DONE"' >> ${STATUS_FILE}
}
