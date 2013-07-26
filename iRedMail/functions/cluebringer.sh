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

# ---------------------------------------------
# Policyd-2.x (code name: cluebringer).
# ---------------------------------------------
cluebringer_user()
{
    ECHO_DEBUG "Add user and group for policyd: ${CLUEBRINGER_USER}:${CLUEBRINGER_GROUP}."

    # User/group will be created during installing binary package on:
    #   - Ubuntu
    #   - openSUSE
    if [ X"${DISTRO}" == X'RHEL' -o X"${DISTRO}" == X'SUSE' ]; then
        groupadd ${CLUEBRINGER_GROUP}
        useradd -m -d ${CLUEBRINGER_USER_HOME} -s ${SHELL_NOLOGIN} -g ${CLUEBRINGER_GROUP} ${CLUEBRINGER_USER}
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        pw useradd -n ${CLUEBRINGER_USER} -s ${SHELL_NOLOGIN} -d ${CLUEBRINGER_USER_HOME} -m
    fi

    echo 'export status_cluebringer_user="DONE"' >> ${STATUS_FILE}
}

cluebringer_config()
{
    ECHO_DEBUG "Initialize SQL database for policyd."

    backup_file ${CLUEBRINGER_CONF}

    # FreeBSD: Generate sample config file
    [ X"${DISTRO}" == X'FREEBSD' ] && cp ${CLUEBRINGER_CONF}.sample ${CLUEBRINGER_CONF}

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
    perl -pi -e 's/^(log_mail=).*/${1}mail\@syslog:native/' ${CLUEBRINGER_CONF}

    # File to log to instead of stdout
    perl -pi -e 's/^#(log_file=).*/${1}$ENV{CLUEBRINGER_LOG_FILE}/' ${CLUEBRINGER_CONF}

    # IP to listen on, * for all
    perl -pi -e 's/^(host=).*/${1}$ENV{CLUEBRINGER_BIND_HOST}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(host=).*/${1}$ENV{CLUEBRINGER_BIND_HOST}/' ${CLUEBRINGER_CONF}
    # Port to run on
    perl -pi -e 's/^#(port=).*/${1}$ENV{CLUEBRINGER_BIND_PORT}/' ${CLUEBRINGER_CONF}

    # How many seconds before we retry a DB connection
    perl -pi -e 's/^#(bypass_timeout=).*/${1}10/' ${CLUEBRINGER_CONF}
    perl -pi -e 's#^(bypass_timeout=).*#${1}10#' ${CLUEBRINGER_CONF}

    #
    # Configure '[database]' section.
    #
    perl -pi -e 's#^(bypass_mode=).*#${1}pass#' ${CLUEBRINGER_CONF}

    # DSN
    if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
        perl -pi -e 's/^(#*)(DSN=DBI:mysql:).*/${2}host=$ENV{SQL_SERVER};database=$ENV{CLUEBRINGER_DB_NAME};user=$ENV{CLUEBRINGER_DB_USER};password=$ENV{CLUEBRINGER_DB_PASSWD}/' ${CLUEBRINGER_CONF}
        perl -pi -e 's/^(DB_Type=).*/${1}mysql/' ${CLUEBRINGER_CONF}

    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        # Comment out all default DSN settings
        perl -pi -e 's/^(DB_Type=).*/${1}pgsql/' ${CLUEBRINGER_CONF}
        perl -pi -e 's/^(DSN=.*)/#${1}/g' ${CLUEBRINGER_CONF}

        perl -pi -e 's#^(.database.)$#${1}\nDSN=DBI:Pg:host=$ENV{SQL_SERVER};database=$ENV{CLUEBRINGER_DB_NAME};user=$ENV{CLUEBRINGER_DB_USER};password=$ENV{CLUEBRINGER_DB_PASSWD}#' ${CLUEBRINGER_CONF}
    fi

    # Database
    # Uncomment variables first.
    perl -pi -e 's/^#(DB_Host=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(DB_Port=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(DB_Name=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(Username=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(Password=.*)/${1}/' ${CLUEBRINGER_CONF}
    # Set proper values
    perl -pi -e 's/^(DB_Host=).*/${1}$ENV{SQL_SERVER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Port=).*/${1}$ENV{SQL_SERVER_PORT}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Name=).*/${1}$ENV{CLUEBRINGER_DB_NAME}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(Username=).*/${1}$ENV{CLUEBRINGER_DB_USER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(Password=).*/${1}$ENV{CLUEBRINGER_DB_PASSWD}/' ${CLUEBRINGER_CONF}

    # Get SQL structure template file.
    tmp_sql="/tmp/cluebringer_init_sql.${RANDOM}${RANDOM}"
    if [ X"${DISTRO}" == X"RHEL" -o X"${DISTRO}" == X"SUSE" ]; then
        DB_SAMPLE_FILE_NAME='policyd.mysql.sql'

        if [ X"${DISTRO}" == X'SUSE' ]; then
            cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME};
USE ${CLUEBRINGER_DB_NAME};
EOF
        fi

        DB_SAMPLE_FILE="$(eval ${LIST_FILES_IN_PKG} ${PKG_CLUEBRINGER} | grep "/${DB_SAMPLE_FILE_NAME}$")"
        perl -pi -e 's#TYPE=#ENGINE=#g' ${DB_SAMPLE_FILE}

        if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
            cat >> ${tmp_sql} <<EOF
-- Import SQL structure template.
SOURCE ${DB_SAMPLE_FILE};

-- Grant privileges.
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@"${SQL_HOSTNAME}" IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF
        elif [ X"${BACKEND}" == X"PGSQL" ]; then
            export shipped_pgsql_temp="$(eval ${LIST_FILES_IN_PKG} ${PKG_CLUEBRINGER} | grep '/policyd.pgsql.sql$')"
            perl -pi -e 's=^(#.*)=/*${1}*/=' ${shipped_pgsql_temp}
            cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE USER ${CLUEBRINGER_DB_USER} WITH ENCRYPTED PASSWORD '${CLUEBRINGER_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
\c ${CLUEBRINGER_DB_NAME};

-- Import SQL structure template.
\i ${shipped_pgsql_temp};
EOF

            unset shipped_pgsql_temp
        fi

    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
            cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME};
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@"${SQL_HOSTNAME}" IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
USE ${CLUEBRINGER_DB_NAME};
EOF

            # Append cluebringer default sql template.
            gunzip -c /usr/share/doc/postfix-cluebringer/database/policyd-db.mysql.gz >> ${tmp_sql}
            perl -pi -e 's#TYPE=#ENGINE=#g' ${tmp_sql}

        elif [ X"${BACKEND}" == X"PGSQL" ]; then
            cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE USER ${CLUEBRINGER_DB_USER} WITH ENCRYPTED PASSWORD '${CLUEBRINGER_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
\c ${CLUEBRINGER_DB_NAME};
EOF

            # Append cluebringer default sql template.
            gunzip -c /usr/share/doc/postfix-cluebringer/database/policyd-db.pgsql.gz >> ${tmp_sql}
        fi

    elif [ X"${DISTRO}" == X"FREEBSD" ]; then
        # Template file will create database: policyd.
        cd /usr/local/share/policyd2/database/
        chmod +x ./convert-tsql

        if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
            policyd_sql_type='mysql'
            cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME};
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@"${SQL_HOSTNAME}" IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
USE ${CLUEBRINGER_DB_NAME};
EOF
        elif [ X"${BACKEND}" == X"PGSQL" ]; then
            policyd_sql_type='pgsql'
            cat > ${tmp_sql} <<EOF
CREATE DATABASE ${CLUEBRINGER_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE USER ${CLUEBRINGER_DB_USER} WITH ENCRYPTED PASSWORD '${CLUEBRINGER_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
\c ${CLUEBRINGER_DB_NAME};
EOF
        fi

        for i in core.tsql \
            access_control.tsql \
            quotas.tsql \
            amavis.tsql \
            checkhelo.tsql \
            checkspf.tsql \
            greylisting.tsql \
            accounting.tsql; do
            [ -f $i ] && bash convert-tsql ${policyd_sql_type} $i >> ${tmp_sql}
        done >> ${tmp_sql}

        unset policyd_sql_type
    fi

    if [ X"${BACKEND}" == X'PGSQL' ]; then
        cat >> ${tmp_sql} <<EOF
GRANT SELECT,INSERT,UPDATE,DELETE ON access_control,amavis_rules,checkhelo,checkhelo_blacklist,checkhelo_tracking,checkhelo_whitelist,checkspf,greylisting,greylisting_autoblacklist,greylisting_autowhitelist,greylisting_tracking,greylisting_whitelist,policies,policy_group_members,policy_groups,policy_members,quotas,quotas_limits,quotas_tracking,session_tracking TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON access_control_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON amavis_rules_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON checkhelo_blacklist_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON checkhelo_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON checkhelo_whitelist_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON checkspf_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON greylisting_autoblacklist_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON greylisting_autowhitelist_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON greylisting_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON greylisting_whitelist_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON policies_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON policy_group_members_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON policy_groups_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON policy_members_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON quotas_id_seq TO ${CLUEBRINGER_DB_USER};
GRANT SELECT,UPDATE,USAGE ON quotas_limits_id_seq TO ${CLUEBRINGER_DB_USER};
EOF
    fi

    # Enable greylisting on Default Inbound.
    cat >> ${tmp_sql} <<EOF
INSERT INTO greylisting (PolicyID, Name, UseGreylisting, GreylistPeriod, Track, GreylistAuthValidity, GreylistUnAuthValidity, UseAutoWhitelist, AutoWhitelistPeriod, AutoWhitelistCount, AutoWhitelistPercentage, UseAutoBlacklist, AutoBlacklistPeriod, AutoBlacklistCount, AutoBlacklistPercentage, Comment, Disabled) VALUES (3, 'Greylisting Inbound Emails', 1, 240, 'SenderIP:/24', 604800, 86400, 1, 604800, 100, 90, 1, 604800, 100, 20, '', 0);
EOF

    # Enable HELO/EHLO check on Default Inbound.
    cat >> ${tmp_sql} <<EOF
INSERT INTO checkhelo (id, policyid, name, useblacklist, blacklistperiod, usehrp, hrpperiod, hrplimit, rejectinvalid, rejectip, rejectunresolvable, comment, disabled) VALUES (1, 3, 'Enable HELO/EHLO check', 1, 2419200, 1, 2419200, 5, 1, 1, 0, 'Enable HELO/EHLO check on inbound by default', 0);
EOF

    # Add first mail domain to policy group: internal_domains
    cat >> ${tmp_sql} <<EOF
INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled) VALUES (2, '@${FIRST_DOMAIN}', 0);
EOF

    # Initial cluebringer db.
    # Enable greylisting on all inbound emails by default.
    if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
        mysql -h${SQL_SERVER} -P${SQL_SERVER_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
$(cat ${tmp_sql})
EOF

    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        # Comment out all lines starts with '#'
        perl -pi -e 's=^(#.*)=/*${1}*/=' ${tmp_sql}

        # Initial cluebringer db.
        su - ${PGSQL_SYS_USER} -c "psql -d template1 -f ${tmp_sql} >/dev/null" >/dev/null 
    fi

    rm -f ${tmp_sql} 2>/dev/null
    unset tmp_sql

    # Set correct permission.
    chown ${CLUEBRINGER_USER}:${CLUEBRINGER_GROUP} ${CLUEBRINGER_CONF}
    chmod 0700 ${CLUEBRINGER_CONF}

    # FreeBSD: Enable policyd2
    freebsd_enable_service_in_rc_conf 'policyd2_enable' 'YES'

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
    fi

    # Add postfix alias.
    add_postfix_alias ${CLUEBRINGER_USER} ${SYS_ROOT_USER}

    # Tips.
    cat >> ${TIP_FILE} <<EOF
Policyd (cluebringer):
    * Web UI:
        - URL: httpS://${HOSTNAME}/cluebringer/
        - Username: ${FIRST_USER}@${FIRST_DOMAIN}
        - Password: ${FIRST_USER_PASSWD_PLAIN}
    * Configuration files:
        - ${CLUEBRINGER_CONF}
        - ${CLUEBRINGER_WEBUI_CONF}
    * RC script:
        - ${CLUEBRINGER_RC_SCRIPT}
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

    backup_file ${CLUEBRINGER_WEBUI_CONF}

    [ X"${DISTRO}" == X'FREEBSD' ] && \
        cp /usr/local/share/policyd2/contrib/httpd/cluebringer-httpd.conf ${CLUEBRINGER_WEBUI_CONF}

    # Make Cluebringer accessible via HTTPS.
    perl -pi -e 's#(</VirtualHost>)#Alias /cluebringer "$ENV{CLUEBRINGER_HTTPD_ROOT}/"\n${1}#' ${HTTPD_SSL_CONF}

    # Configure webui.
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        perl -pi -e 's#(.DB_DSN=).*#${1}"mysql:host=$ENV{SQL_SERVER};dbname=$ENV{CLUEBRINGER_DB_NAME}";#' ${CLUEBRINGER_WEBUI_CONF}
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#(.DB_DSN=).*#${1}"pgsql:host=$ENV{SQL_SERVER};dbname=$ENV{CLUEBRINGER_DB_NAME}";#' ${CLUEBRINGER_WEBUI_CONF}
    fi

    perl -pi -e 's#(.DB_USER=).*#${1}"$ENV{CLUEBRINGER_DB_USER}";#' ${CLUEBRINGER_WEBUI_CONF}
    perl -pi -e 's/.*(.DB_PASS=).*/${1}"$ENV{CLUEBRINGER_DB_PASSWD}";/' ${CLUEBRINGER_WEBUI_CONF}
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
    #allow from ${CLUEBRINGER_BIND_HOST}
    allow from all

    AuthType basic
    AuthName "Authorization Required"
EOF

    ECHO_DEBUG "Setup user auth for cluebringer webui: ${CLUEBRINGER_HTTPD_CONF}."
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        # Use LDAP auth.
        cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthBasicProvider ldap
    AuthzLDAPAuthoritative   Off

    AuthLDAPUrl   ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}/${LDAP_BASEDN}?${LDAP_ATTR_USER_RDN}?sub?(&(objectclass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ATTR_DOMAIN_GLOBALADMIN}=${LDAP_VALUE_DOMAIN_GLOBALADMIN}))

    AuthLDAPBindDN "${LDAP_BINDDN}"
    AuthLDAPBindPassword "${LDAP_BINDPW}"
EOF

        [ X"${LDAP_USE_TLS}" == X"YES" ] && \
            perl -pi -e 's#(AuthLDAPUrl.*)(ldap://)(.*)#${1}ldaps://${3}#' ${CLUEBRINGER_HTTPD_CONF}

    elif [ X"${BACKEND}" == X"MYSQL" ]; then
        # Use mod_auth_mysql.
        if [ X"${DISTRO}" == X"RHEL" -o X"${DISTRO}" == X"SUSE" -o X"${DISTRO}" == X"FREEBSD" ]; then
            cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthMYSQLEnable On
    AuthMySQLHost ${SQL_SERVER}
    AuthMySQLPort ${SQL_SERVER_PORT}
    AuthMySQLUser ${VMAIL_DB_BIND_USER}
    AuthMySQLPassword ${VMAIL_DB_BIND_PASSWD}
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

            # openSUSE & FreeBSD special.
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
    AuthMySQL_Password_Table mailbox
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
Auth_MySQL_Info ${SQL_SERVER} ${VMAIL_DB_BIND_USER} ${VMAIL_DB_BIND_PASSWD}
Auth_MySQL_General_DB ${VMAIL_DB}
EOF
        fi  # DISTRO

    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        # Use mod_auth_pgsql.
        cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    Auth_PG_authoritative on
    Auth_PG_host ${SQL_SERVER}
    Auth_PG_port ${SQL_SERVER_PORT}
    Auth_PG_database ${VMAIL_DB}
    Auth_PG_user ${VMAIL_DB_BIND_USER}
    Auth_PG_pwd ${VMAIL_DB_BIND_PASSWD}
    Auth_PG_pwd_table mailbox
    Auth_PG_pwd_whereclause 'AND isadmin=1 AND isglobaladmin=1'
    Auth_PG_uid_field username
    Auth_PG_pwd_field password
    Auth_PG_lowercase_uid on
    Auth_PG_encrypted on
    Auth_PG_hash_type CRYPT
EOF

        # Set file permission.
        chmod 0600 ${CLUEBRINGER_HTTPD_CONF}

    fi
    # END BACKEND

        # Close <Directory> container.
        cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF

    Require valid-user
</Directory>
EOF

    if [ X"${DISTRO}" == X'SUSE' -a X"${BACKEND}" == X'PGSQL' ]; then
        # Don't enable Cluebringer webui since we don't have Apache module mod_auth_pgsql
        backup_file ${CLUEBRINGER_HTTPD_CONF}
        rm ${CLUEBRINGER_HTTPD_CONF} &>/dev/null
        backup_file ${CLUEBRINGER_HTTPD_CONF}
    fi
    echo 'export status_cluebringer_webui_config="DONE"' >> ${STATUS_FILE}
}
