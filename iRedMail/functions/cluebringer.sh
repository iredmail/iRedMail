#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)

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

# ---------------------------------------------
# Policyd-2.x (code name: cluebringer).
# ---------------------------------------------
cluebringer_user()
{
    ECHO_DEBUG "Add user and group for policyd: ${CLUEBRINGER_USER}:${CLUEBRINGER_GROUP}."

    if [ X"${DISTRO}" == X"UBUNTU" ]; then
        if [ X"${DISTRO_CODENAME}" == X"oneiric" ]; then
            # User/group will be created during installing binary package.
            :
        fi
    fi
    #if [ X"${DISTRO}" == X"FREEBSD" ]; then
    #    pw useradd -n ${CLUEBRINGER_USER} -s ${SHELL_NOLOGIN} -d ${CLUEBRINGER_USER_HOME} -m
    #elif [ X"${DISTRO}" == X"SUSE" ]; then
    #    # Not need to add user/group.
    #    :
    #else
    #    groupadd ${CLUEBRINGER_GROUP}
    #    useradd -m -d ${CLUEBRINGER_USER_HOME} -s ${SHELL_NOLOGIN} -g ${CLUEBRINGER_GROUP} ${CLUEBRINGER_USER}
    #fi

    echo 'export status_cluebringer_user="DONE"' >> ${STATUS_FILE}
}

cluebringer_config()
{
    ECHO_DEBUG "Initialize MySQL database of policyd."

    backup_file ${CLUEBRINGER_CONF}

    #
    # Configure '[server]' section.
    #
    # User to run this daemon as
    perl -pi -e 's/^#(user=).*/${1}$ENV{CLUEBRINGER_USER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(group=).*/${1}$ENV{CLUEBRINGER_GROUP}/' ${CLUEBRINGER_CONF}

    # Filename to store pid of parent process
    perl -pi -e 's/^(pid_file=).*/${1}$ENV{CLUEBRINGER_PID_FILE}/' ${CLUEBRINGER_CONF}

    # Log level
    # 0 - Errors only
    # 1 - Warnings and errors
    # 2 - Notices, warnings, errors
    # 3 - Info, notices, warnings, errors
    # 4 - Debugging 
    perl -pi -e 's/^#(log_level=).*/${1}2/' ${CLUEBRINGER_CONF}

    # File to log to instead of stdout
    perl -pi -e 's/^#(log_file=).*/${1}$ENV{CLUEBRINGER_LOG_FILE}/' ${CLUEBRINGER_CONF}

    # IP to listen on, * for all
    perl -pi -e 's/^(host=).*/${1}$ENV{CLUEBRINGER_BINDHOST}/' ${CLUEBRINGER_CONF}
    # Port to run on
    perl -pi -e 's/^#(port=).*/${1}$ENV{CLUEBRINGER_BINDPORT}/' ${CLUEBRINGER_CONF}

    #
    # Configure '[database]' section.
    #
    # DSN
    perl -pi -e 's/^#(DSN=DBI:mysql:).*/${1}host=$ENV{MYSQL_SERVER};database=$ENV{CLUEBRINGER_DB_NAME};user=$ENV{CLUEBRINGER_DB_USER};password=$ENV{CLUEBRINGER_DB_PASSWD}/' ${CLUEBRINGER_CONF}
    # Database
    perl -pi -e 's/^(DB_Type=).*/${1}mysql/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Host=).*/${1}$ENV{MYSQL_SERVER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Port=).*/${1}$ENV{MYSQL_PORT}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Name=).*/${1}$ENV{CLUEBRINGER_DB_NAME}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(Username=).*/${1}$ENV{CLUEBRINGER_DB_USER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(Password=).*/${1}$ENV{CLUEBRINGER_DB_PASSWD}/' ${CLUEBRINGER_CONF}

    # Get SQL structure template file.
    tmp_sql="/tmp/policyd_config_tmp.${RANDOM}${RANDOM}"
    if [ X"${DISTRO}" == X"RHEL" -o X"${DISTRO}" == X"SUSE" ]; then
        cat > ${tmp_sql} <<EOF
# Import SQL structure template.
SOURCE $(eval ${LIST_FILES_IN_PKG} ${PKG_CLUEBRINGER} | grep '/DATABASE.mysql$');

# Grant privileges.
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@localhost IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF

    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME};
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@localhost IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
USE ${CLUEBRINGER_DB_NAME};
EOF

        if [ X"${BACKEND}" == X"OpenLDAP" -o X"${BACKEND}" == X"MySQL" ]; then
            gunzip -c /usr/share/doc/postfix-cluebringer/database/policyd-db.mysql.gz >> ${tmp_sql}
        elif [ X"${BACKEND}" == X"PostgreSQL" ]; then
            gunzip -c /usr/share/doc/postfix-cluebringer/database/policyd-db.pgsql.gz >> ${tmp_sql}
        fi

    elif [ X"${DISTRO}" == X"FREEBSD" ]; then
        # Template file will create database: policyd.
        cat > ${tmp_sql} <<EOF
# Import SQL structure template.
SOURCE $(eval ${LIST_FILES_IN_PKG} "${PKG_CLUEBRINGER}*" | grep '/DATABASE.mysql$');

# Grant privileges.
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@localhost IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF

    else
        :
    fi

    mysql -h${MYSQL_SERVER} -P${MYSQL_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
$(cat ${tmp_sql})

-- Delete default sample domains.
-- DELETE FROM policy_group_members WHERE Member IN ('@example.com', '@example.org', '10.0.0.0/8');

-- Enable greylisting on all inbound emails by default.
INSERT INTO greylisting (PolicyID, Name, UseGreylisting, GreylistPeriod, Track, GreylistAuthValidity, GreylistUnAuthValidity, UseAutoWhitelist, AutoWhitelistPeriod, AutoWhitelistCount, AutoWhitelistPercentage, UseAutoBlacklist, AutoBlacklistPeriod, AutoBlacklistCount, AutoBlacklistPercentage, Comment, Disabled) VALUES (1, 'Greylisting Inbound Emails', 1, 240, 'SenderIP:/24', 604800, 86400, 1, 604800, 100, 90, 1, 604800, 100, 20, '', 0);
EOF

    rm -rf ${tmp_sql} 2>/dev/null
    unset tmp_sql

    # Configure policyd.
    ECHO_DEBUG "Configure policyd: ${CLUEBRINGER_CONF}."

    # FreeBSD: Copy sample config file.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        cp /usr/local/etc/postfix-policyd-sf.conf.sample ${CLUEBRINGER_CONF}
    fi

    # Set correct permission.
    chown ${CLUEBRINGER_USER}:${CLUEBRINGER_GROUP} ${CLUEBRINGER_CONF}
    chmod 0700 ${CLUEBRINGER_CONF}

    if [ X"${CLUEBRINGER_SEPERATE_LOG}" == X"YES" ]; then
        echo -e "local1.*\t\t\t\t\t\t-${CLUEBRINGER_LOGFILE}" >> ${SYSLOG_CONF}
        cat > ${CLUEBRINGER_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${AMAVISD_LOGFILE} {
    compress
    weekly
    rotate 10
    create 0600 amavis amavis
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        ${SYSLOG_POSTROTATE_CMD}
    endscript
}
EOF
    else
        :
    fi

    # Add postfix alias.
    if [ ! -z ${MAIL_ALIAS_ROOT} ]; then
        echo "cluebringer: ${MAIL_ALIAS_ROOT}" >> ${POSTFIX_FILE_ALIASES}
        postalias hash:${POSTFIX_FILE_ALIASES} 2>/dev/null
    else
        :
    fi

    # Tips.
    cat >> ${TIP_FILE} <<EOF
Policyd (cluebringer):
    * Configuration files:
        - ${CLUEBRINGER_CONF}
        - ${CLUEBRINGER_WEBUI_CONF}
    * RC script:
        - ${CLUEBRINGER_INIT_SCRIPT}
    * Database:
        - Database name: ${CLUEBRINGER_DB_NAME}
        - Database user: ${CLUEBRINGER_DB_USER}
        - Database password: ${CLUEBRINGER_DB_PASSWD}

EOF

    if [ X"${CLUEBRINGER_SEPERATE_LOG}" == X"YES" ]; then
        cat >> ${TIP_FILE} <<EOF
    * Log file:
        - ${SYSLOG_CONF}
        - ${CLUEBRINGER_LOGFILE}

EOF
    else
        echo -e '\n' >> ${TIP_FILE}
    fi

    echo 'export status_cluebringer_config="DONE"' >> ${STATUS_FILE}
}

cluebringer_webui_config()
{
    ECHO_DEBUG "Configure webui of Policyd (cluebringer)."

    backup_file ${CLUEBRINGER_CONF}

    # Make Cluebringer accessible via HTTPS.
    perl -pi -e 's#(</VirtualHost>)#Alias /cluebringer "$ENV{CLUEBRINGER_HTTPD_ROOT}/"\n${1}#' ${HTTPD_SSL_CONF}

    # Configure webui.
    perl -pi -e 's#(.DB_DSN=).*#${1}"mysql:host=$ENV{MYSQL_SERVER};dbname=${CLUEBRINGER_DB_NAME}";#' ${CLUEBRINGER_WEBUI_CONF}
    perl -pi -e 's#(.DB_USER=).*#${1}"$ENV{CLUEBRINGER_DB_USER}";#' ${CLUEBRINGER_WEBUI_CONF}
    perl -pi -e 's#(.DB_PASS=).*#${1}"$ENV{CLUEBRINGER_DB_PASSWD}";#' ${CLUEBRINGER_WEBUI_CONF}

    cat > ${CLUEBRINGER_HTTPD_CONF} <<EOF
${CONF_MSG}
#
# SECURITY WARNING:
#
# Since libapache2-mod-auth-mysql doesn't support advance SQL query, both
# global admins and normal domain admins are able to login to this webui.

# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.

<Directory ${CLUEBRINGER_HTTPD_ROOT}/>
    DirectoryIndex index.php
    Options ExecCGI
    Order allow,deny
    allow from 127.0.0.1
    #allow from all

    AuthName "Authorization Required"
EOF

    ECHO_DEBUG "Setup user auth for cluebringer webui: ${CLUEBRINGER_HTTPD_CONF}."
    if [ X"${BACKEND}" == X"OpenLDAP" ]; then
        # Use LDAP auth.
        cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthBasicProvider ldap
    AuthzLDAPAuthoritative   Off

    AuthLDAPUrl   ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}/${LDAP_ADMIN_BASEDN}?${LDAP_ATTR_USER_RDN}?sub?(&(objectclass=${LDAP_OBJECTCLASS_MAILADMIN})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ATTR_DOMAIN_GLOBALADMIN}=${LDAP_VALUE_DOMAIN_GLOBALADMIN}))

    AuthLDAPBindDN "${LDAP_BINDDN}"
    AuthLDAPBindPassword "${LDAP_BINDPW}"
EOF

        [ X"${LDAP_USE_TLS}" == X"YES" ] && \
            perl -pi -e 's#(AuthLDAPUrl.*)(ldap://)(.*)#${1}ldaps://${3}#' ${CLUEBRINGER_HTTPD_CONF}

    elif [ X"${BACKEND}" == X"MySQL" ]; then
        # Use mod_auth_mysql.
        if [ X"${DISTRO}" == X"RHEL" -o X"${DISTRO}" == X"SUSE" -o X"${DISTRO}" == X"FREEBSD" ]; then
            cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthMYSQLEnable On
    AuthMySQLHost ${MYSQL_SERVER}
    AuthMySQLPort ${MYSQL_PORT}
    AuthMySQLUser ${MYSQL_BIND_USER}
    AuthMySQLPassword ${MYSQL_BIND_PW}
    AuthMySQLDB ${VMAIL_DB}
    AuthMySQLUserTable admin
    AuthMySQLNameField username
    AuthMySQLPasswordField password
EOF

            # FreeBSD special.
            if [ X"${DISTRO}" == X"FREEBSD" ]; then
                # Enable mod_auth_mysql module in httpd.conf.
                perl -pi -e 's/^#(LoadModule.*mod_auth_mysql.*)/${1}/' ${HTTPD_CONF}
            fi

            # OpenSuSE & FreeBSD special.
            if [ X"${DISTRO}" == X"SUSE" -o X"${DISTRO}" == X"FREEBSD" ]; then
                echo "AuthBasicAuthoritative Off" >> ${CLUEBRINGER_HTTPD_CONF}
            fi

        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthMYSQL on
    AuthBasicAuthoritative Off
    AuthUserFile /dev/null

    # Database related.
    AuthMySQL_Password_Table admin
    Auth_MySQL_Username_Field username
    Auth_MySQL_Password_Field password

    # Password related.
    AuthMySQL_Empty_Passwords off
    AuthMySQL_Encryption_Types Crypt_MD5
    Auth_MySQL_Authoritative On
EOF

            # Set file permission.
            chmod 0600 ${CLUEBRINGER_HTTPD_CONF}

            cat >> ${HTTPD_CONF} <<EOF
# MySQL auth (libapache2-mod-auth-apache2).
# Global config of MySQL server, username, password.
Auth_MySQL_Info ${MYSQL_SERVER} ${MYSQL_BIND_USER} ${MYSQL_BIND_PW}
Auth_MySQL_General_DB ${VMAIL_DB}
EOF
        else
            :
        fi  # DISTRO
    fi  # BACKEND

        # Close <Directory> container.
        cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF

    Require valid-user
</Directory>
EOF

    echo 'export status_cluebringer_webui_config="DONE"' >> ${STATUS_FILE}
}
