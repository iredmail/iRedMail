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

    echo "export IREDADMIN_DB_PASSWD='${IREDADMIN_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" -o X"${DISTRO}" == X"SUSE" ]; then
        ECHO_DEBUG "Enable apache module: wsgi."
        a2enmod wsgi >/dev/null 2>&1
    elif [ X"${DISTRO}" == X"RHEL" ]; then
        # Make sure wsgi module is loaded.
        [ -f ${HTTPD_WSGI_CONF} ] && \
            perl -pi -e 's/#(LoadModule.*wsgi_module.*modules.*mod_wsgi.so)/${1}/' ${HTTPD_WSGI_CONF}
    fi

    cd ${MISC_DIR}

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
        cp settings.ini.ldap.sample settings.ini
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        cp settings.ini.mysql.sample settings.ini
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp settings.ini.pgsql.sample settings.ini
    fi

    chown -R ${IREDADMIN_USER_NAME}:${IREDADMIN_GROUP_NAME} settings.ini
    chmod 0400 settings.ini

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Change file owner
        # iRedAdmin is not running as user 'iredadmin' on OpenBSD
        chown -R ${HTTPD_USER}:${HTTPD_GROUP} settings.ini
    fi

    backup_file ${IREDADMIN_HTTPD_CONF}
    ECHO_DEBUG "Create directory alias for iRedAdmin."

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Create directory alias.
        perl -pi -e 's#^(</VirtualHost>)#Alias /iredadmin/static "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/static"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(</VirtualHost>)#ScriptAlias /iredadmin "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/iredadmin.py"\n${1}#' ${HTTPD_SSL_CONF}

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
        perl -pi -e 's#^(</VirtualHost>)#Alias /iredadmin/static "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/static/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(</VirtualHost>)#WSGIScriptAlias /iredadmin "$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/iredadmin.py/"\n${1}#' ${HTTPD_SSL_CONF}

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

    ECHO_DEBUG "Import iredadmin database template."
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        mysql -h${SQL_SERVER} -P${SQL_SERVER_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
# Create databases.
CREATE DATABASE ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

# Import SQL template.
USE ${IREDADMIN_DB_NAME};
SOURCE ${IREDADMIN_HTTPD_ROOT}/docs/samples/iredadmin.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${SQL_HOSTNAME}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF

        # Import addition tables.
        if [ X"${BACKEND}" == X"OPENLDAP" ]; then
            mysql -h${SQL_SERVER} -P${SQL_SERVER_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
USE ${IREDADMIN_DB_NAME};
SOURCE ${SAMPLE_DIR}/dovecot/used_quota.sql;
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
    perl -pi -e 's#^(storage_base_directory =).*#${1} $ENV{STORAGE_MAILBOX_DIR}#' settings.ini

    # [iredadmin] section.
    ECHO_DEBUG "Configure iredadmin database related settings."
    perl -pi -e 's#(.*)host_of_iredadmin_sql_server#${1} $ENV{SQL_SERVER}#' settings.ini
    perl -pi -e 's#(.*)port_of_iredadmin_sql_server#${1} $ENV{SQL_SERVER_PORT}#' settings.ini
    perl -pi -e 's#^(db =) iredadmin#${1} $ENV{IREDADMIN_DB_NAME}#' settings.ini
    perl -pi -e 's#^(user =) iredadmin#${1} $ENV{IREDADMIN_DB_USER}#' settings.ini
    perl -pi -e 's#(.*)password_of_iredadmin_db#${1} $ENV{IREDADMIN_DB_PASSWD}#' settings.ini

    # Backend related settings.
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        # Change backend.
        perl -pi -e 's#^(backend.*=).*#${1} ldap#' settings.ini

        # Section [ldap].
        ECHO_DEBUG "Configure OpenLDAP backend related settings."
        perl -pi -e 's#^(uri =).*#${1} ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}#' settings.ini
        perl -pi -e 's#^(basedn =).*#${1} $ENV{LDAP_BASEDN}#' settings.ini
        perl -pi -e 's#^(domainadmin_dn =).*#${1} $ENV{LDAP_ADMIN_BASEDN}#' settings.ini
        perl -pi -e 's#^(bind_dn =).*#${1} $ENV{LDAP_ADMIN_DN}#' settings.ini
        perl -pi -e 's#^(bind_pw =).*#${1} $ENV{LDAP_ADMIN_PW}#' settings.ini

    elif [ X"${BACKEND}" == X"MYSQL" -o X"${BACKEND}" == X'PGSQL' ]; then
        ECHO_DEBUG "Configure MySQL related settings."
        perl -pi -e 's#(.*)host_of_vmaildb_sql_server#${1} $ENV{SQL_SERVER}#' settings.ini
        perl -pi -e 's#(.*)port_of_vmaildb_sql_server#${1} $ENV{SQL_SERVER_PORT}#' settings.ini
        perl -pi -e 's#^(db =) vmail#${1} $ENV{VMAIL_DB}#' settings.ini
        perl -pi -e 's#^(user =) vmailadmin#${1} $ENV{VMAIL_DB_ADMIN_USER}#' settings.ini
        perl -pi -e 's#(.*)password_of_vmail_db#${1} $ENV{VMAIL_DB_ADMIN_PASSWD}#' settings.ini
    fi

    # Section [policyd].
    ECHO_DEBUG "Configure Policyd related settings."
    if [ X"${USE_POLICYD}" == X'YES' ]; then
        perl -pi -e 's#^(enabled =).*#${1} True#' settings.ini
        perl -pi -e 's#(.*)host_of_policyd_sql_server#${1} $ENV{SQL_SERVER}#' settings.ini
        perl -pi -e 's#(.*)port_of_policyd_sql_server#${1} $ENV{SQL_SERVER_PORT}#' settings.ini
        perl -pi -e 's#^(db =) policyd#${1} $ENV{POLICYD_DB_NAME}#' settings.ini
        perl -pi -e 's#^(user =) policyd#${1} $ENV{POLICYD_DB_USER}#' settings.ini
        perl -pi -e 's#(.*)password_of_policyd_db#${1} $ENV{POLICYD_DB_PASSWD}#' settings.ini
    else
        # Policyd-2 (cluebringer) is not yet supported in iRedAdmin.
        perl -pi -e 's#^(enabled =) True#${1} False#' settings.ini
    fi

    # Section [amavisd].
    ECHO_DEBUG "Configure Amavisd related settings."
    perl -pi -e 's#(.*)host_of_amavisd_sql_server#${1} $ENV{SQL_SERVER}#' settings.ini
    perl -pi -e 's#(.*)port_of_amavisd_sql_server#${1} $ENV{SQL_SERVER_PORT}#' settings.ini
    perl -pi -e 's#^(db =) amavisd#${1} $ENV{AMAVISD_DB_NAME}#' settings.ini
    perl -pi -e 's#^(user =) amavisd#${1} $ENV{AMAVISD_DB_USER}#' settings.ini
    perl -pi -e 's#(.*)password_of_amavisd_db#${1} $ENV{AMAVISD_DB_PASSWD}#' settings.ini

    perl -pi -e 's#^(logging_into_sql =).*#${1} True#' settings.ini
    perl -pi -e 's#^(quarantine =).*#${1} True#' settings.ini
    perl -pi -e 's#^(quarantine_port =).*#${1} $ENV{AMAVISD_QUARANTINE_PORT}#' settings.ini

    cat >> ${TIP_FILE} <<EOF
iRedAdmin - official web-based admin panel:
    * Version: ${IREDADMIN_VERSION}
    * Configuration files:
        - ${HTTPD_SERVERROOT}/iRedAdmin-${IREDADMIN_VERSION}/
        - ${HTTPD_SERVERROOT}/iRedAdmin-${IREDADMIN_VERSION}/settings.ini*
    * URL:
        - https://${HOSTNAME}/iredadmin/
    * Login account:
        - Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}, password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * Settings:
        - ${IREDADMIN_HTTPD_ROOT}/settings.ini
        - Addition settings for Policyd & Amavisd integration support in iRedAdmin-Pro:

        [policyd]
        enabled = True
        host = ${SQL_SERVER}
        port = ${SQL_SERVER_PORT}
        db = ${POLICYD_DB_NAME}
        user = ${POLICYD_DB_USER}
        passwd = ${POLICYD_DB_PASSWD}

        [amavisd]
        quarantine = True
        quarantine_port = ${AMAVISD_QUARANTINE_PORT}

        logging_into_sql = True
        host = ${SQL_SERVER}
        port = ${SQL_SERVER_PORT}
        db = ${AMAVISD_DB_NAME}
        user = ${AMAVISD_DB_USER}
        passwd = ${AMAVISD_DB_PASSWD}

    * See also:
        - ${IREDADMIN_HTTPD_CONF}

EOF

    echo 'export status_iredadmin_config="DONE"' >> ${STATUS_FILE}
}
