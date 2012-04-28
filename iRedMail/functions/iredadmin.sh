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
    chown -R ${IREDADMIN_HTTPD_USER}:${IREDADMIN_HTTPD_GROUP} ${IREDADMIN_HTTPD_ROOT}
    chmod -R 0555 ${IREDADMIN_HTTPD_ROOT}

    perl -pi -e 's#TYPE=#ENGINE=#g' ${IREDADMIN_HTTPD_ROOT}/docs/samples/iredadmin.sql
    perl -pi -e 's#TIMESTAMP\(14\)#TIMESTAMP#g' ${IREDADMIN_HTTPD_ROOT}/docs/samples/iredadmin.sql

    # Copy sample configure file.
    cd ${IREDADMIN_HTTPD_ROOT}/

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        cp settings.ini.ldap.sample settings.ini
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        cp settings.ini.mysql.sample settings.ini
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp settings.ini.pgsql.sample settings.ini
    fi

    chown -R ${IREDADMIN_HTTPD_USER}:${IREDADMIN_HTTPD_GROUP} settings.ini
    chmod 0400 settings.ini

    ECHO_DEBUG "Create directory alias for iRedAdmin."
    backup_file ${HTTPD_CONF_DIR}/iredadmin.conf
    perl -pi -e 's#(</VirtualHost>)#WSGIScriptAlias /iredadmin "$ENV{HTTPD_SERVERROOT}/iredadmin/iredadmin.py/"\n${1}#' ${HTTPD_SSL_CONF}
    perl -pi -e 's#(</VirtualHost>)#Alias /iredadmin/static "$ENV{HTTPD_SERVERROOT}/iredadmin/static/"\n${1}#' ${HTTPD_SSL_CONF}

    cat > ${HTTPD_CONF_DIR}/iredadmin.conf <<EOF
WSGISocketPrefix /var/run/wsgi
WSGIDaemonProcess iredadmin user=${IREDADMIN_HTTPD_USER} threads=15
WSGIProcessGroup ${IREDADMIN_HTTPD_GROUP}

AddType text/html .py

<Directory ${IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}/>
    Order allow,deny
    Allow from all
</Directory>
EOF

    ECHO_DEBUG "Import iredadmin database template."
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        mysql -h${SQL_SERVER} -P${SQL_SERVER_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
# Create databases.
CREATE DATABASE ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

# Import SQL template.
USE ${IREDADMIN_DB_NAME};
SOURCE ${IREDADMIN_HTTPD_ROOT}/docs/samples/iredadmin.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@localhost IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";
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
    sed -i.tmp \
        -e "/\[general\]/,/\[/ s#\(^webmaster =\).*#\1 ${MAIL_ALIAS_ROOT}#" \
        -e "/\[general\]/,/\[/ s#\(^storage_base_directory =\).*#\1 ${STORAGE_BASE_DIR}/${STORAGE_NODE}#" \
        settings.ini

    # [iredadmin] section.
    ECHO_DEBUG "Configure iredadmin database related settings."
    sed -i.tmp \
        -e "/\[iredadmin\]/,/\[/ s#\(^host =\).*#\1 ${SQL_SERVER}#" \
        -e "/\[iredadmin\]/,/\[/ s#\(^port =\).*#\1 ${SQL_SERVER_PORT}#" \
        -e "/\[iredadmin\]/,/\[/ s#\(^db =\).*#\1 ${IREDADMIN_DB_NAME}#" \
        -e "/\[iredadmin\]/,/\[/ s#\(^user =\).*#\1 ${IREDADMIN_DB_USER}#" \
        -e "/\[iredadmin\]/,/\[/ s#\(^passwd =\).*#\1 ${IREDADMIN_DB_PASSWD}#" \
        settings.ini

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
        sed -i.tmp \
            -e "/\[vmaildb\]/,/\[/ s#\(^host =\).*#\1 ${SQL_SERVER}#" \
            -e "/\[vmaildb\]/,/\[/ s#\(^port =\).*#\1 ${SQL_SERVER_PORT}#" \
            -e "/\[vmaildb\]/,/\[/ s#\(^db =\).*#\1 ${VMAIL_DB}#" \
            -e "/\[vmaildb\]/,/\[/ s#\(^user =\).*#\1 ${VMAIL_DB_ADMIN_USER}#" \
            -e "/\[vmaildb\]/,/\[/ s#\(^passwd =\).*#\1 ${VMAIL_DB_ADMIN_PASSWD}#" \
            settings.ini
    fi

    # Section [policyd].
    ECHO_DEBUG "Configure Policyd related settings."
    sed -i.tmp \
        -e "/\[policyd\]/,/\[/ s#\(^enabled =\).*#\1 True#" \
        -e "/\[policyd\]/,/\[/ s#\(^host =\).*#\1 ${SQL_SERVER}#" \
        -e "/\[policyd\]/,/\[/ s#\(^port =\).*#\1 ${SQL_SERVER_PORT}#" \
        -e "/\[policyd\]/,/\[/ s#\(^db =\).*#\1 ${POLICYD_DB_NAME}#" \
        -e "/\[policyd\]/,/\[/ s#\(^user =\).*#\1 ${POLICYD_DB_USER}#" \
        -e "/\[policyd\]/,/\[/ s#\(^passwd =\).*#\1 ${POLICYD_DB_PASSWD}#" \
        settings.ini


    # Policyd-2 (cluebringer) is not yet supported in iRedAdmin.
    if [ X"${USE_CLUEBRINGER}" == X'YES' ]; then
        sed -i.tmp -e "/\[policyd\]/,/\[/ s#\(^enabled =\).*#\1 False#" settings.ini
    fi

    # Section [amavisd].
    ECHO_DEBUG "Configure Amavisd related settings."
    sed -i.tmp \
        -e "/\[amavisd\]/,/\[/ s#\(^quarantine =\).*#\1 True#" \
        -e "/\[amavisd\]/,/\[/ s#\(^server =\).*#\1 ${AMAVISD_SERVER}#" \
        -e "/\[amavisd\]/,/\[/ s#\(^quarantine_port =\).*#\1 ${AMAVISD_QUARANTINE_PORT}#" \
        -e "/\[amavisd\]/,/\[/ s#\(^logging_into_sql =\).*#\1 True#" \
        -e "/\[amavisd\]/,/\[/ s#\(^host =\).*#\1 ${SQL_SERVER}#" \
        -e "/\[amavisd\]/,/\[/ s#\(^port =\).*#\1 ${SQL_SERVER_PORT}#" \
        -e "/\[amavisd\]/,/\[/ s#\(^db =\).*#\1 ${AMAVISD_DB_NAME}#" \
        -e "/\[amavisd\]/,/\[/ s#\(^user =\).*#\1 ${AMAVISD_DB_USER}#" \
        -e "/\[amavisd\]/,/\[/ s#\(^passwd =\).*#\1 ${AMAVISD_DB_PASSWD}#" \
        settings.ini

    [ -f settings.ini.tmp ] && rm -f settings.ini.tmp &>/dev/null

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
        server = ${AMAVISD_SERVER}
        quarantine_port = ${AMAVISD_QUARANTINE_PORT}
        logging_into_sql = True
        host = ${SQL_SERVER}
        port = ${SQL_SERVER_PORT}
        db = ${AMAVISD_DB_NAME}
        user = ${AMAVISD_DB_USER}
        passwd = ${AMAVISD_DB_PASSWD}

    * See also:
        - ${HTTPD_CONF_DIR}/iredadmin.conf

EOF

    echo 'export status_iredadmin_config="DONE"' >> ${STATUS_FILE}
}
