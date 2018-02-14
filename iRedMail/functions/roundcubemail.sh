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

        # Create symbol link, so that we don't need to modify web server config
        # file to set new version number after upgrading this software.
        ln -s ${RCM_HTTPD_ROOT} ${RCM_HTTPD_ROOT_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

        ECHO_DEBUG "Set correct permission for Roundcubemail: ${RCM_HTTPD_ROOT}."
        chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${RCM_HTTPD_ROOT}
        chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${RCM_HTTPD_ROOT}/{temp,logs}
        chmod 0000 ${RCM_HTTPD_ROOT}/{CHANGELOG,INSTALL,LICENSE,README*,UPGRADING,installer,SQL}
    fi

    # Copy sample config files.
    cp -f ${SAMPLE_DIR}/roundcubemail/config.inc.php ${RCM_CONF}
    chown ${HTTPD_USER}:${HTTPD_GROUP} ${RCM_CONF}
    chmod 0600 ${RCM_CONF}

    echo 'export status_rcm_install="DONE"' >> ${STATUS_FILE}
}

rcm_initialize_db()
{
    ECHO_DEBUG "Import SQL database and privileges for Roundcubemail."

    # Initial roundcube db.
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create database and grant privileges
CREATE DATABASE ${RCM_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL ON ${RCM_DB_NAME}.* TO "${RCM_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY '${RCM_DB_PASSWD}';
-- GRANT ALL ON ${RCM_DB_NAME}.* TO "${RCM_DB_USER}"@"${HOSTNAME}" IDENTIFIED BY '${RCM_DB_PASSWD}';

-- Import Roundcubemail SQL template
USE ${RCM_DB_NAME};
SOURCE ${RCM_HTTPD_ROOT}/SQL/mysql.initial.sql;

FLUSH PRIVILEGES;
EOF

        # Generate .my.cnf file
        cat > /root/.my.cnf-${RCM_DB_USER} <<EOF
[client]
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
user=${RCM_DB_USER}
password="${RCM_DB_PASSWD}"
EOF

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp -f ${RCM_HTTPD_ROOT}/SQL/postgres.initial.sql ${PGSQL_USER_HOMEDIR}/rcm.sql >> ${INSTALL_LOG} 2>&1
        chmod 0777 ${PGSQL_USER_HOMEDIR}/rcm.sql

        su - ${SYS_USER_PGSQL} -c "psql -d template1 >/dev/null" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Create database and role
CREATE DATABASE ${RCM_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE ROLE ${RCM_DB_USER} WITH LOGIN ENCRYPTED PASSWORD '${RCM_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Grant privilege
ALTER DATABASE ${RCM_DB_NAME} OWNER TO ${RCM_DB_USER};
EOF

        # Import sql templte as roundcube user.
        su - ${SYS_USER_PGSQL} -c "psql -U ${RCM_DB_USER} -d ${RCM_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Import Roundcubemail SQL template
\i ${PGSQL_USER_HOMEDIR}/rcm.sql;

-- Grant privileges
-- GRANT SELECT,INSERT,UPDATE,DELETE ON cache,cache_index,cache_messages,cache_shared,cache_thread,contactgroupmembers,contactgroups,contacts,dictionary,identities,searches,session,system,users TO ${RCM_DB_USER};
-- GRANT SELECT,UPDATE,USAGE ON contacts_seq,contactgroups_seq,identities_seq,searches_seq,users_seq TO ${RCM_DB_USER};
EOF

        # Grant privilege to update password (vmail.mailbox) through roundcube webmail
        su - ${SYS_USER_PGSQL} -c "psql -d ${VMAIL_DB_NAME} >/dev/null" >> ${INSTALL_LOG} 2>&1 <<EOF
\c ${VMAIL_DB_NAME};
GRANT UPDATE,SELECT ON mailbox TO ${RCM_DB_USER};
EOF
        rm -f ${PGSQL_USER_HOMEDIR}/rcm.sql >> ${INSTALL_LOG} 2>&1
    fi

    # Grant privileges
    if [ X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Grant privileges for Roundcubemail, so that user can change
-- their own password and setting mail forwarding.
GRANT UPDATE,SELECT ON ${VMAIL_DB_NAME}.mailbox TO "${RCM_DB_USER}"@"${MYSQL_GRANT_HOST}";
-- GRANT UPDATE,SELECT ON ${VMAIL_DB_NAME}.mailbox TO "${RCM_DB_USER}"@"${HOSTNAME}";

FLUSH PRIVILEGES;
EOF
    fi

    echo 'export status_rcm_initialize_db="DONE"' >> ${STATUS_FILE}
}

rcm_config()
{
    ECHO_DEBUG "Configure database for Roundcubemail: ${RCM_CONF_DIR}/*."

    cd ${RCM_CONF_DIR}

    perl -pi -e 's#PH_IMAP_SERVER#$ENV{IMAP_SERVER}#g' ${RCM_CONF}

    perl -pi -e 's#PH_PHP_CONN_TYPE#$ENV{PHP_CONN_TYPE}#g' ${RCM_CONF}
    perl -pi -e 's#PH_RCM_DB_USER#$ENV{RCM_DB_USER}#g' ${RCM_CONF}
    perl -pi -e 's#PH_RCM_DB_PASSWD#$ENV{RCM_DB_PASSWD}#g' ${RCM_CONF}
    perl -pi -e 's#PH_RCM_DB_NAME#$ENV{RCM_DB_NAME}#g' ${RCM_CONF}
    perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#g' ${RCM_CONF}
    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#g' ${RCM_CONF}

    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' ${RCM_CONF}
    perl -pi -e 's#PH_RCM_DES_KEY#$ENV{RCM_DES_KEY}#g' ${RCM_CONF}
    perl -pi -e 's#PH_FIRST_DOMAIN#$ENV{FIRST_DOMAIN}#g' ${RCM_CONF}

    # Enable mime.types on Linux
    if [ X"${KERNEL_NAME}" == X"LINUX" ]; then
        perl -pi -e 's#//(.*mime_types.*)#${1}#' ${RCM_CONF}
    fi

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        export LDAP_SERVER_HOST LDAP_SERVER_PORT LDAP_BIND_VERSION LDAP_BASEDN LDAP_ATTR_DOMAIN_RDN LDAP_ATTR_USER_RDN
        cd ${RCM_CONF_DIR}
        ECHO_DEBUG "Setting global LDAP address book in Roundcube."

        cat ${SAMPLE_DIR}/roundcubemail/global_ldap_address_book.inc.php >> ${RCM_CONF}
        perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#g' ${RCM_CONF}
        perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#g' ${RCM_CONF}
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' ${RCM_CONF}
    fi

    # Attachment size.
    if [ -f ${RCM_HTTPD_ROOT}/.htaccess ]; then
        perl -pi -e 's#(.*upload_max_filesize.*)5M#${1}10M#' ${RCM_HTTPD_ROOT}/.htaccess
        perl -pi -e 's#(.*post_max_size.*)6M#${1}12M#' ${RCM_HTTPD_ROOT}/.htaccess
    fi

    cat >> ${TIP_FILE} <<EOF
Roundcube webmail: ${RCM_HTTPD_ROOT}
    * Config file: ${RCM_CONF_DIR}
    * Web access:
        - URL: http://${HOSTNAME}/mail/ (will be redirected to https:// site)
        - URL: https://${HOSTNAME}/mail/ (secure connection)
        - Username: ${DOMAIN_ADMIN_EMAIL}
        - Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * SQL database account:
        - Database name: ${RCM_DB_NAME}
        - Username: ${RCM_DB_USER}
        - Password: ${RCM_DB_PASSWD}
    * Cron job:
        - Command: "crontab -l -u ${SYS_ROOT_USER}"

EOF

    echo 'export status_rcm_config="DONE"' >> ${STATUS_FILE}
}

rcm_cron_setup()
{
    ECHO_DEBUG "Setup daily cron job to keep SQL database clean."
    cat >> ${CRON_FILE_ROOT} <<EOF
# ${PROG_NAME}: Cleanup Roundcube SQL database
2   2   *   *   *   ${PHP_BIN} ${RCM_HTTPD_ROOT_SYMBOL_LINK}/bin/cleandb.sh >/dev/null

# ${PROG_NAME}: Cleanup Roundcube temporary files under 'temp/' directory
2   2   *   *   *   ${PHP_BIN} ${RCM_HTTPD_ROOT_SYMBOL_LINK}/bin/gc.sh >/dev/null
EOF

    echo 'export status_rcm_cron_setup="DONE"' >> ${STATUS_FILE}
}

rcm_plugin_managesieve()
{
    ECHO_DEBUG "Config plugin: managesieve."
    cd ${RCM_CONF_DIR}

    export MANAGESIEVE_SERVER MANAGESIEVE_PORT
    cd ${RCM_HTTPD_ROOT}/plugins/managesieve/ && \
    cp config.inc.php.dist config.inc.php && \
    perl -pi -e 's#(.*managesieve_host.*=).*#${1} "$ENV{MANAGESIEVE_SERVER}";#' config.inc.php
    perl -pi -e 's#(.*managesieve_port.*=).*#${1} $ENV{MANAGESIEVE_PORT};#' config.inc.php
    perl -pi -e 's#(.*managesieve_usetls.*=).*#${1} true;#' config.inc.php
    perl -pi -e 's#(.*managesieve_default.*=).*#${1} "";#' config.inc.php
    perl -pi -e 's#(.*managesieve_vacation.*=).*#${1} 1;#' config.inc.php

    # Disable ssl peer verify
    perl -pi -e 's#(.*managesieve_conn_options.*=.*)(null.*)#${1}array("ssl" => array("verify_peer" => false, "verify_peer_name" => false));#' config.inc.php

    echo 'export status_rcm_plugin_managesieve="DONE"' >> ${STATUS_FILE}
}

rcm_plugin_password()
{
    ECHO_DEBUG "Config plugin: password."
    cd ${RCM_CONF_DIR}

    cd ${RCM_HTTPD_ROOT}/plugins/password/
    cp config.inc.php.dist config.inc.php
    chown ${HTTPD_USER}:${HTTPD_GROUP} config.inc.php
    chmod 0400 config.inc.php

    # Determine whether current password is required to change password
    perl -pi -e 's#(.*password_confirm_current.*=).*#${1} true;#' config.inc.php

    # Require the new password to be a certain length
    perl -pi -e 's#(.*password_minimum_length.*=).*#${1} 8;#' config.inc.php

    # Require the new password to contain a letter and punctuation character
    perl -pi -e 's#(.*password_require_nonalpha.*=).*#${1} true;#' config.inc.php
    perl -pi -e 's#(.*password_log.*=).*#${1} true;#' config.inc.php

    # Roundcube uses scheme name in lower cases
    export default_password_scheme="$(echo ${DEFAULT_PASSWORD_SCHEME} | tr '[A-Z]' '[a-z]')"

    # Dovecot uses scheme name in upper cases
    export dovecotpw_method="${DEFAULT_PASSWORD_SCHEME}"

    if [ X"${dovecotpw_method}" == X'BCRYPT' ]; then
        # Password scheme name used in Dovecot (doveadm pw).
        export default_password_scheme='blf-crypt'
        export dovecotpw_method='BLF-CRYPT'
    fi

    # Roundcube supports ssha, but not ssha512.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        export default_password_scheme='ssha'
    fi

    perl -pi -e 's#(.*password_dovecotpw.*=.*for dovecot-1.*)#//${1}#' config.inc.php
    perl -pi -e 's#// (.*password_dovecotpw.*=).*for dovecot-2.*#${1} "$ENV{DOVECOT_DOVEADM_BIN} pw";#' config.inc.php

    perl -pi -e 's#(.*password_dovecotpw_method.*=).*#${1} "$ENV{dovecotpw_method}";#' config.inc.php
    perl -pi -e 's#(.*password_dovecotpw_with_method.*=).*#${1} true;#' config.inc.php

    if [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#(.*password_driver.*=).*#${1} "sql";#' config.inc.php
        perl -pi -e 's#(.*password_db_dsn.*= )(.*)#${1}"$ENV{PHP_CONN_TYPE}://$ENV{RCM_DB_USER}:$ENV{RCM_DB_PASSWD}\@$ENV{SQL_SERVER_ADDRESS}/$ENV{VMAIL_DB_NAME}";#' config.inc.php

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

rcm_plugin_enigma()
{
    ECHO_DEBUG "Config plugin: enigma."

    cd ${RCM_HTTPD_ROOT}/plugins/enigma/
    cp -f config.inc.php.dist config.inc.php
    perl -pi -e 's#(.*enigma_pgp_homedir.*=).*#${1} "$ENV{RCM_PLUGIN_ENIGMA_PGP_HOMEDIR}";#' config.inc.php

    # Directory used to store pgp keys generated by enigma plugin.
    mkdir -p ${RCM_PLUGIN_ENIGMA_PGP_HOMEDIR} >> ${INSTALL_LOG} 2>&1
    chown ${HTTPD_USER}:${HTTPD_GROUP} ${RCM_PLUGIN_ENIGMA_PGP_HOMEDIR}
    chmod 0700 ${RCM_PLUGIN_ENIGMA_PGP_HOMEDIR}

    echo 'export status_rcm_plugin_enigma="DONE"' >> ${STATUS_FILE}
}

rcm_setup() {
    check_status_before_run rcm_install

    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run rcm_initialize_db
    fi

    check_status_before_run rcm_config
    check_status_before_run rcm_cron_setup
    check_status_before_run rcm_plugin_managesieve
    check_status_before_run rcm_plugin_password
    check_status_before_run rcm_plugin_enigma

    echo 'export status_rcm_setup="DONE"' >> ${STATUS_FILE}
}
