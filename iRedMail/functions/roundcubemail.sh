#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -----------------------
# Roundcube.
# -----------------------
rcm_install()
{
    ECHO_INFO "Configure Roundcube webmail."

    if [ X"${RCM_USE_SOURCE}" == X'YES' ]; then
        cd ${PKG_MISC_DIR}

        # Extract source tarball.
        extract_pkg ${RCM_TARBALL} ${HTTPD_SERVERROOT}

        # Create symbol link, so that we don't need to modify apache
        # conf.d/roundcubemail.conf file after upgrade this component.
        ln -s ${RCM_HTTPD_ROOT} ${RCM_HTTPD_ROOT_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

        ECHO_DEBUG "Set correct permission for Roundcubemail: ${RCM_HTTPD_ROOT}."
        chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${RCM_HTTPD_ROOT}
        chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${RCM_HTTPD_ROOT}/{temp,logs}
        chmod 0000 ${RCM_HTTPD_ROOT}/{CHANGELOG,INSTALL,LICENSE,README*,UPGRADING,installer,SQL}
    fi

    # Copy sample config files.
    cd ${RCM_CONF_DIR}
    cp -f ${SAMPLE_DIR}/roundcubemail/config.inc.php .
    cp -f ${SAMPLE_DIR}/dovecot/dovecot.sieve.roundcube ${RCM_SIEVE_SAMPLE_FILE}
    chown ${HTTPD_USER}:${HTTPD_GROUP} config.inc.php ${RCM_SIEVE_SAMPLE_FILE}
    chmod 0600 config.inc.php ${RCM_SIEVE_SAMPLE_FILE}

    echo 'export status_rcm_install="DONE"' >> ${STATUS_FILE}
}

rcm_config_httpd()
{
    ECHO_DEBUG "Create directory alias for Roundcubemail."
    cat > ${HTTPD_CONF_DIR}/roundcubemail.conf <<EOF
${CONF_MSG}
# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.
Alias /mail "${RCM_HTTPD_ROOT_SYMBOL_LINK}/"
<Directory "${RCM_HTTPD_ROOT_SYMBOL_LINK}/">
    ${HTACCESS_ALLOW_ALL}
    Options -Indexes
</Directory>
EOF

    # Enable this config file on Ubuntu 13.10 and later releases.
    if [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # Enable conf file: conf-available/roundcubemail.conf
            a2enconf roundcubemail >> ${INSTALL_LOG} 2>&1
        fi
    fi

    # Make Roundcube can be accessed via HTTPS.
    if [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /mail "$ENV{RCM_HTTPD_ROOT_SYMBOL_LINK}/"\n${1}#' ${HTTPD_SSL_CONF}
    fi

    echo 'export status_rcm_config_httpd="DONE"' >> ${STATUS_FILE}
}

rcm_import_sql()
{
    ECHO_DEBUG "Import SQL database and privileges for Roundcubemail."

    # Initial roundcube db.
    if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create database and grant privileges
CREATE DATABASE ${RCM_DB} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT CREATE,SELECT,INSERT,UPDATE,DELETE,ALTER ON ${RCM_DB}.* TO "${RCM_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY '${RCM_DB_PASSWD}';

-- Import Roundcubemail SQL template
USE ${RCM_DB};
SOURCE ${RCM_HTTPD_ROOT}/SQL/mysql.initial.sql;

FLUSH PRIVILEGES;
EOF
    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        cp -f ${RCM_HTTPD_ROOT}/SQL/postgres.initial.sql ${PGSQL_SYS_USER_HOME}/rcm.sql >> ${INSTALL_LOG} 2>&1
        chmod 0777 ${PGSQL_SYS_USER_HOME}/rcm.sql 

        su - ${PGSQL_SYS_USER} -c "psql -d template1 >/dev/null" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Create database and role
CREATE DATABASE ${RCM_DB} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE ROLE ${RCM_DB_USER} WITH LOGIN ENCRYPTED PASSWORD '${RCM_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Grant privilege
ALTER DATABASE ${RCM_DB} OWNER TO ${RCM_DB_USER};
EOF

        # Import sql templte as roundcube user.
        su - ${PGSQL_SYS_USER} -c "psql -U ${RCM_DB_USER} -d ${RCM_DB}" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Import Roundcubemail SQL template
\i ${PGSQL_SYS_USER_HOME}/rcm.sql;

-- Grant privileges
-- GRANT SELECT,INSERT,UPDATE,DELETE ON cache,cache_index,cache_messages,cache_shared,cache_thread,contactgroupmembers,contactgroups,contacts,dictionary,identities,searches,session,system,users TO ${RCM_DB_USER};
-- GRANT SELECT,UPDATE,USAGE ON contacts_seq,contactgroups_seq,identities_seq,searches_seq,users_seq TO ${RCM_DB_USER};
EOF

        # Grant privilege to update password (vmail.mailbox) through roundcube webmail
        su - ${PGSQL_SYS_USER} -c "psql -d ${VMAIL_DB} >/dev/null" >> ${INSTALL_LOG} 2>&1 <<EOF
\c ${VMAIL_DB};
GRANT UPDATE,SELECT ON mailbox TO ${RCM_DB_USER};
EOF
        rm -f ${PGSQL_SYS_USER_HOME}/rcm.sql >> ${INSTALL_LOG} 2>&1
    fi


    # Grant privileges
    if [ X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Grant privileges for Roundcubemail, so that user can change
-- their own password and setting mail forwarding.
GRANT UPDATE,SELECT ON ${VMAIL_DB}.mailbox TO "${RCM_DB_USER}"@"${MYSQL_GRANT_HOST}";
-- GRANT INSERT,UPDATE,SELECT ON ${VMAIL_DB}.alias TO "${RCM_DB_USER}"@"${MYSQL_GRANT_HOST}";

FLUSH PRIVILEGES;
EOF
    fi

    echo 'export status_rcm_import_sql="DONE"' >> ${STATUS_FILE}
}

rcm_config()
{
    ECHO_DEBUG "Configure database for Roundcubemail: ${RCM_CONF_DIR}/*."

    cd ${RCM_CONF_DIR}

    #export RCM_DB_USER RCM_DB_PASSWD RCMD_DB SQL_SERVER_ADDRESS FIRST_DOMAIN
    #export RCM_DES_KEY

    perl -pi -e 's#PH_PHP_CONN_TYPE#$ENV{PHP_CONN_TYPE}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DB_USER#$ENV{RCM_DB_USER}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DB_PASSWD#$ENV{RCM_DB_PASSWD}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DB#$ENV{RCM_DB}#g' config.inc.php
    perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#g' config.inc.php

    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DES_KEY#$ENV{RCM_DES_KEY}#g' config.inc.php
    perl -pi -e 's#PH_FIRST_DOMAIN#$ENV{FIRST_DOMAIN}#g' config.inc.php

    # Enable mime.types on Linux
    if [ X"${KERNEL_NAME}" == X"LINUX" ]; then
        perl -pi -e 's#//(.*mime_types.*)#${1}#' config.inc.php
    fi

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        export LDAP_SERVER_HOST LDAP_SERVER_PORT LDAP_BIND_VERSION LDAP_BASEDN LDAP_ATTR_DOMAIN_RDN LDAP_ATTR_USER_RDN
        cd ${RCM_CONF_DIR}
        ECHO_DEBUG "Setting global LDAP address book in Roundcube."

        cat ${SAMPLE_DIR}/roundcubemail/global_ldap_address_book.inc.php >> config.inc.php
        perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#g' config.inc.php
        perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#g' config.inc.php
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' config.inc.php
    fi

    # Attachment size.
    if [ -f ${RCM_HTTPD_ROOT}/.htaccess ]; then
        perl -pi -e 's#(.*upload_max_filesize.*)5M#${1}10M#' ${RCM_HTTPD_ROOT}/.htaccess
        perl -pi -e 's#(.*post_max_size.*)6M#${1}12M#' ${RCM_HTTPD_ROOT}/.htaccess
    fi

    ECHO_DEBUG "Setup daily cron job to keep SQL database clean."
    cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Cleanup Roundcube SQL database
2   2   *   *   *   ${PHP_BIN} ${RCM_HTTPD_ROOT_SYMBOL_LINK}/bin/cleandb.sh >/dev/null

EOF

    cat >> ${TIP_FILE} <<EOF
Roundcube webmail: ${RCM_HTTPD_ROOT}
    * Configuration files:
        - ${RCM_CONF_DIR}
    * URL:
        - http://${HOSTNAME}/mail/
        - https://${HOSTNAME}/mail/ (Over SSL/TLS)
    * Login account:
        - Username: ${FIRST_USER}@${FIRST_DOMAIN}, password: ${FIRST_USER_PASSWD_PLAIN}
    * SQL database account:
        - Database name: ${RCM_DB}
        - Username: ${RCM_DB_USER}
        - Password: ${RCM_DB_PASSWD}
    * See also:
        - ${HTTPD_CONF_DIR}/roundcubemail.conf
        - Cron job: crontab -l -u ${SYS_ROOT_USER}

EOF

    echo 'export status_rcm_config="DONE"' >> ${STATUS_FILE}
}

rcm_plugin_managesieve()
{
    ECHO_DEBUG "Config plugin: managesieve."
    cd ${RCM_CONF_DIR}

    export MANAGESIEVE_BIND_HOST MANAGESIEVE_PORT RCM_SIEVE_SAMPLE_FILE
    cd ${RCM_HTTPD_ROOT}/plugins/managesieve/ && \
    cp config.inc.php.dist config.inc.php && \
    perl -pi -e 's#(.*managesieve_port.*=).*#${1} $ENV{MANAGESIEVE_PORT};#' config.inc.php
    perl -pi -e 's#(.*managesieve_host.*=).*#${1} "$ENV{MANAGESIEVE_BIND_HOST}";#' config.inc.php
    perl -pi -e 's#(.*managesieve_usetls.*=).*#${1} false;#' config.inc.php
    perl -pi -e 's#(.*managesieve_default.*=).*#${1} "$ENV{RCM_SIEVE_SAMPLE_FILE}";#' config.inc.php
    perl -pi -e 's#(.*managesieve_vacation.*=).*#${1} 1;#' config.inc.php

    echo 'export status_rcm_plugin_managesieve="DONE"' >> ${STATUS_FILE}
}

rcm_plugin_password()
{
    ECHO_DEBUG "Enable and config plugin: password."
    cd ${RCM_CONF_DIR}

    cd ${RCM_HTTPD_ROOT}/plugins/password/
    cp config.inc.php.dist config.inc.php

    # Determine whether current password is required to change password
    perl -pi -e 's#(.*password_confirm_current.*=).*#${1} true;#' config.inc.php

    # Require the new password to be a certain length
    perl -pi -e 's#(.*password_minimum_length.*=).*#${1} 8;#' config.inc.php

    # Require the new password to contain a letter and punctuation character
    perl -pi -e 's#(.*password_require_nonalpha.*=).*#${1} true;#' config.inc.php
    perl -pi -e 's#(.*password_log.*=).*#${1} true;#' config.inc.php

    # lower case
    export default_password_scheme="$(echo ${DEFAULT_PASSWORD_SCHEME} | tr [A-Z] [a-z])"
    # upper case
    export dovecotpw_method="${DEFAULT_PASSWORD_SCHEME}"
    if [ X"${dovecotpw_method}" == X'BCRYPT' ]; then
        # Password scheme name used in Dovecot (doveadm pw).
        export default_password_scheme='blf-crypt'
        export dovecotpw_method='BLF-CRYPT'
    fi

    perl -pi -e 's#// (.*password_dovecotpw.*=).*#${1} "$ENV{DOVECOT_DOVEADM_BIN} pw";#' config.inc.php
    perl -pi -e 's#(.*password_dovecotpw_method.*=).*#${1} "$ENV{dovecotpw_method}";#' config.inc.php
    perl -pi -e 's#(.*password_dovecotpw_with_method.*=).*#${1} true;#' config.inc.php

    if [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#(.*password_driver.*=).*#${1} "sql";#' config.inc.php
        perl -pi -e 's#(.*password_db_dsn.*= )(.*)#${1}"$ENV{PHP_CONN_TYPE}://$ENV{RCM_DB_USER}:$ENV{RCM_DB_PASSWD}\@$ENV{SQL_SERVER_ADDRESS}/$ENV{VMAIL_DB}";#' config.inc.php

        perl -pi -e 's#(.*password_query.*=).*#${1} "UPDATE mailbox SET password=%D,passwordlastchange=NOW() WHERE username=%u";#' config.inc.php

    elif [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#(.*password_confirm_current.*=).*#${1} true;#' config.inc.php

        perl -pi -e 's#(.*password_driver.*=).*#${1} "ldap_simple";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_host.*=).*#${1} "$ENV{LDAP_SERVER_HOST}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_port.*=).*#${1} "$ENV{LDAP_SERVER_PORT}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_starttls.*=).*#${1} false;#' config.inc.php
        perl -pi -e 's#(.*password_ldap_version.*=).*#${1} "3";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_basedn...=).*#${1} "$ENV{LDAP_BASEDN}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_userDN_mask...=).*#${1} "$ENV{LDAP_ATTR_USER_RDN}=%login,$ENV{LDAP_ATTR_GROUP_RDN}=$ENV{LDAP_ATTR_GROUP_USERS},$ENV{LDAP_ATTR_DOMAIN_RDN}=%domain,$ENV{LDAP_BASEDN}";#' config.inc.php

        perl -pi -e 's#(.*password_ldap_method.*=).*#${1} "user";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_adminDN.*=).*#${1} "null";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_adminPW.*=).*#${1} "null";#' config.inc.php

        perl -pi -e 's#(.*password_ldap_encodage.*=).*#${1} "$ENV{default_password_scheme}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_pwattr.*=).*#${1} "userPassword";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_lchattr.*=).*#${1} "shadowLastChange";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_force_replace.*=).*#${1} true;#' config.inc.php
    fi

    echo 'export status_rcm_plugin_password="DONE"' >> ${STATUS_FILE}
}
