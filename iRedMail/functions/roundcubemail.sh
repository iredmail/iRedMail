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
        ln -s ${RCM_HTTPD_ROOT} ${RCM_HTTPD_ROOT_SYMBOL_LINK} &>/dev/null

        ECHO_DEBUG "Set correct permission for Roundcubemail: ${RCM_HTTPD_ROOT}."
        chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${RCM_HTTPD_ROOT}
        chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${RCM_HTTPD_ROOT}/{temp,logs}
        chmod 0000 ${RCM_HTTPD_ROOT}/{CHANGELOG,INSTALL,LICENSE,README*,UPGRADING,installer,SQL}
    fi

    # Copy sample config files.
    cd ${RCM_HTTPD_ROOT}/config/
    cp ${SAMPLE_DIR}/roundcubemail/config.inc.php .
    cp -f ${SAMPLE_DIR}/dovecot/dovecot.sieve.roundcube ${RCM_SIEVE_SAMPLE_FILE}
    chown ${HTTPD_USER}:${HTTPD_GROUP} config.inc.php ${RCM_SIEVE_SAMPLE_FILE}
    chmod 0640 config.inc.php ${RCM_SIEVE_SAMPLE_FILE}
}

rcm_config_httpd()
{
    ECHO_DEBUG "Create directory alias for Roundcubemail."
    cat > ${HTTPD_CONF_DIR}/roundcubemail.conf <<EOF
${CONF_MSG}
# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.
Alias /mail "${RCM_HTTPD_ROOT_SYMBOL_LINK}/"
<Directory "${RCM_HTTPD_ROOT_SYMBOL_LINK}/">
    Options -Indexes
</Directory>
EOF

    # Enable this config file on Ubuntu 13.10 and later releases.
    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        if [ X"${DISTRO_CODENAME}" != X'wheezy' \
            -a X"${DISTRO_CODENAME}" != X'precise' ]; then
            # Enable conf file: conf-available/roundcubemail.conf
            a2enconf roundcubemail &>/dev/null
        fi
    fi

    # Make Roundcube can be accessed via HTTPS.
    if [ X"${WEB_SERVER_USE_APACHE}" == X'YES' ]; then
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /mail "$ENV{RCM_HTTPD_ROOT_SYMBOL_LINK}/"\n${1}#' ${HTTPD_SSL_CONF}
    fi

    # Redirect home page to webmail by default
    backup_file ${HTTPD_DOCUMENTROOT}/index.html
    cat > ${HTTPD_DOCUMENTROOT}/index.html <<EOF
<html>
    <head>
        <meta HTTP-EQUIV="REFRESH" content="0; url=/mail/">
    </head>
</html>
EOF
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
        cp -f ${RCM_HTTPD_ROOT}/SQL/postgres.initial.sql ${PGSQL_SYS_USER_HOME}/rcm.sql >/dev/null
        chmod 0777 ${PGSQL_SYS_USER_HOME}/rcm.sql >/dev/null

        su - ${PGSQL_SYS_USER} -c "psql -d template1 >/dev/null" >/dev/null <<EOF
-- Create database and role
CREATE DATABASE ${RCM_DB} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE ROLE ${RCM_DB_USER} WITH LOGIN ENCRYPTED PASSWORD '${RCM_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Import Roundcubemail SQL template
\c ${RCM_DB};
\i ${PGSQL_SYS_USER_HOME}/rcm.sql;

-- Grant privileges
GRANT SELECT,INSERT,UPDATE,DELETE ON cache,cache_index,cache_messages,cache_shared,cache_thread,contactgroupmembers,contactgroups,contacts,dictionary,identities,searches,session,system,users TO ${RCM_DB_USER};
GRANT SELECT,UPDATE,USAGE ON contacts_seq,contactgroups_seq,identities_seq,searches_seq,users_seq TO ${RCM_DB_USER};

-- Grant privilege to update password through roundcube webmail
\c ${VMAIL_DB};
GRANT UPDATE,SELECT ON mailbox TO ${RCM_DB_USER};
EOF
        rm -f ${PGSQL_SYS_USER_HOME}/rcm.sql >/dev/null
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
}

rcm_config()
{
    ECHO_DEBUG "Configure database for Roundcubemail: ${RCM_HTTPD_ROOT}/config/*."

    cd ${RCM_HTTPD_ROOT}/config/

    #export RCM_DB_USER RCM_DB_PASSWD RCMD_DB SQL_SERVER FIRST_DOMAIN
    #export RCM_DES_KEY

    perl -pi -e 's#PH_PHP_CONN_TYPE#$ENV{PHP_CONN_TYPE}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DB_USER#$ENV{RCM_DB_USER}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DB_PASSWD#$ENV{RCM_DB_PASSWD}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DB#$ENV{RCM_DB}#g' config.inc.php
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#g' config.inc.php

    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' config.inc.php
    perl -pi -e 's#PH_RCM_DES_KEY#$ENV{RCM_DES_KEY}#g' config.inc.php
    perl -pi -e 's#PH_FIRST_DOMAIN#$ENV{FIRST_DOMAIN}#g' config.inc.php

    # Enable mime.types on Linux
    if [ X"${KERNEL_NAME}" == X"LINUX" ]; then
        perl -pi -e 's#//(.*mime_types.*)#${1}#' config.inc.php
    fi

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        export LDAP_SERVER_HOST LDAP_SERVER_PORT LDAP_BIND_VERSION LDAP_BASEDN LDAP_ATTR_DOMAIN_RDN LDAP_ATTR_USER_RDN
        cd ${RCM_HTTPD_ROOT}/config/
        ECHO_DEBUG "Setting global LDAP address book in Roundcube."

        cat >> config.inc.php <<EOF
// Global LDAP address book.
\$config['ldap_public']["global_ldap_abook"] = array(
    'name'          => 'Global LDAP Address Book',
    'hosts'         => array('${LDAP_SERVER_HOST}'),
    'port'          => ${LDAP_SERVER_PORT},
    'use_tls'       => false,
    'ldap_version'  => '${LDAP_BIND_VERSION}',
    'network_timeout' => 10,
    'user_specific' => true,

    // Search mail users under same domain.
    'base_dn'       => '${LDAP_ATTR_DOMAIN_RDN}=%d,${LDAP_BASEDN}',
    'bind_dn'       => '${LDAP_ATTR_USER_RDN}=%u@%d,${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_USERS},${LDAP_ATTR_DOMAIN_RDN}=%d,${LDAP_BASEDN}',

    'hidden'        => false,
    'searchonly'    => false,
    'writable'      => false,

    'search_fields' => array('mail', 'cn', 'sn', 'givenName', 'street', 'telephoneNumber', 'mobile', 'stree', 'postalCode'),

    // mapping of contact fields to directory attributes
    'fieldmap' => array(
        'name'        => 'cn',
        'surname'     => 'sn',
        'firstname'   => 'givenName',
        'title'       => 'title',
        'email'       => 'mail:*',
        'phone:work'  => 'telephoneNumber',
        'phone:mobile' => 'mobile',
        'street'      => 'street',
        'zipcode'     => 'postalCode',
        'locality'    => 'l',
        'department'  => 'departmentNumber',
        'notes'       => 'description',
        'name'        => 'cn',
        'surname'     => 'sn',
        'firstname'   => 'givenName',
        'title'       => 'title',
        'email'       => 'mail:*',
        'phone:work'  => 'telephoneNumber',
        'phone:mobile' => 'mobile',
        'phone:workfax' => 'facsimileTelephoneNumber',
        'street'      => 'street',
        'zipcode'     => 'postalCode',
        'locality'    => 'l',
        'department'  => 'departmentNumber',
        'notes'       => 'description',
        'photo'       => 'jpegPhoto',
    ),
    'sort'          => 'cn',
    'scope'         => 'sub',
    'filter'        => '(&(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DELIVER})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DISPLAYED_IN_ADDRBOOK})(|(objectClass=${LDAP_OBJECTCLASS_MAILGROUP})(objectClass=${LDAP_OBJECTCLASS_MAILALIAS})(objectClass=${LDAP_OBJECTCLASS_MAILUSER})))',
    'fuzzy_search'  => true,
    'vlv'           => false,   // Enable Virtual List View to more efficiently fetch paginated data (if server supports it)
    'sizelimit'     => '0',     // Enables you to limit the count of entries fetched. Setting this to 0 means no limit.
    'timelimit'     => '0',     // Sets the number of seconds how long is spend on the search. Setting this to 0 means no limit.
    'referrals'     => false,  // Sets the LDAP_OPT_REFERRALS option. Mostly used in multi-domain Active Directory setups

    'group_filters' => array(
        'departments' => array(
            'name'    => 'Mailing Lists',
            'scope'   => 'sub',
            'base_dn' => '${LDAP_ATTR_DOMAIN_RDN}=%d,${LDAP_BASEDN}',
            'filter'  => '(&(objectclass=mailList)(accountStatus=active)(enabledService=${LDAP_SERVICE_DISPLAYED_IN_ADDRBOOK}))',
            'name_attr' => 'cn',
            'email'     => 'mail',
        ),
    ),
);
\$config['autocomplete_addressbooks'] = array('sql', 'global_ldap_abook');
EOF
    fi

    # Attachment size.
    if [ -f ${RCM_HTTPD_ROOT}/.htaccess ]; then
        perl -pi -e 's#(.*upload_max_filesize.*)5M#${1}10M#' ${RCM_HTTPD_ROOT}/.htaccess
        perl -pi -e 's#(.*post_max_size.*)6M#${1}12M#' ${RCM_HTTPD_ROOT}/.htaccess
    fi

    cat >> ${TIP_FILE} <<EOF
Roundcube webmail:
    * Configuration files:
        - ${HTTPD_SERVERROOT}/roundcubemail-${RCM_VERSION}/
        - ${HTTPD_SERVERROOT}/roundcubemail-${RCM_VERSION}/config/
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

EOF
}

rcm_plugin_managesieve()
{
    ECHO_DEBUG "Config plugin: managesieve."
    cd ${RCM_HTTPD_ROOT}/config/

    export MANAGESIEVE_BIND_HOST MANAGESIEVE_PORT RCM_SIEVE_SAMPLE_FILE
    cd ${RCM_HTTPD_ROOT}/plugins/managesieve/ && \
    cp config.inc.php.dist config.inc.php && \
    perl -pi -e 's#(.*managesieve_port.*=).*#${1} $ENV{MANAGESIEVE_PORT};#' config.inc.php
    perl -pi -e 's#(.*managesieve_host.*=).*#${1} "$ENV{MANAGESIEVE_BIND_HOST}";#' config.inc.php
    perl -pi -e 's#(.*managesieve_usetls.*=).*#${1} false;#' config.inc.php
    perl -pi -e 's#(.*managesieve_default.*=).*#${1} "$ENV{RCM_SIEVE_SAMPLE_FILE}";#' config.inc.php
    perl -pi -e 's#(.*managesieve_vacation.*=).*#${1} 1;#' config.inc.php
}

rcm_plugin_password()
{
    ECHO_DEBUG "Enable and config plugin: password."
    cd ${RCM_HTTPD_ROOT}/config/

    cd ${RCM_HTTPD_ROOT}/plugins/password/ && \
        cp config.inc.php.dist config.inc.php

    if [ X"${BACKEND}" == X'PGSQL' ]; then
        # Patch to escape single quote while updating password
        cd ${RCM_HTTPD_ROOT}
        patch -p0 <${PATCH_DIR}/roundcubemail/password_driver_pgsql.patch &>/dev/null

        # Re-generate config.inc.php because it's hard to use perl to update
        # 'password_query' setting.
        cd ${RCM_HTTPD_ROOT}/plugins/password/
        sed '/password_query/,$d' config.inc.php.dist > config.inc.php.tmp
        # Update 'password_query' setting.
        cat >> config.inc.php.tmp <<EOF
\$rcmail_config['password_query'] = "SELECT * from dblink_exec(E'host=\'${SQL_SERVER}\' user=\'${RCM_DB_USER}\' password=\'${RCM_DB_PASSWD}\' dbname=\'${VMAIL_DB}\'', E'UPDATE mailbox SET password=%c,passwordlastchange=NOW() WHERE username=%u')";
EOF

        sed '1,/password_query/d' config.inc.php.dist >> config.inc.php.tmp
        rm -f config.inc.php &>/dev/null && \
            mv config.inc.php.tmp config.inc.php
    fi

    # Determine whether current password is required to change password
    perl -pi -e 's#(.*password_confirm_current.*=).*#${1} true;#' config.inc.php

    # Require the new password to be a certain length
    perl -pi -e 's#(.*password_minimum_length.*=).*#${1} 8;#' config.inc.php

    # Require the new password to contain a letter and punctuation character
    perl -pi -e 's#(.*password_require_nonalpha.*=).*#${1} true;#' config.inc.php
    perl -pi -e 's#(.*password_log.*=).*#${1} true;#' config.inc.php

    if [ X"${BACKEND}" == X"MYSQL" -o X"${BACKEND}" == X"PGSQL" ]; then
        perl -pi -e 's#(.*password_driver.*=).*#${1} "sql";#' config.inc.php
        perl -pi -e 's#(.*password_db_dsn.*= )(.*)#${1}"$ENV{PHP_CONN_TYPE}://$ENV{RCM_DB_USER}:$ENV{RCM_DB_PASSWD}\@$ENV{SQL_SERVER}/$ENV{VMAIL_DB}";#' config.inc.php
        perl -pi -e 's#(.*password_hash_algorithm.*=).*#${1} "md5crypt";#' config.inc.php
        perl -pi -e 's#(.*password_hash_base64.*=).*#${1} false;#' config.inc.php

        if [ X"${BACKEND}" == X"MYSQL" ]; then
            perl -pi -e 's#(.*password_query.*=).*#${1} "UPDATE $ENV{VMAIL_DB}.mailbox SET password=%c,passwordlastchange=NOW() WHERE username=%u LIMIT 1";#' config.inc.php
        fi

    elif [ X"${BACKEND}" == X"OPENLDAP" ]; then
        # LDAP backend. Driver: ldap_simple.
        perl -pi -e 's#(.*password_driver.*=).*#${1} "ldap_simple";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_host.*=).*#${1} "$ENV{LDAP_SERVER_HOST}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_port.*=).*#${1} "$ENV{LDAP_SERVER_PORT}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_starttls.*=).*#${1} false;#' config.inc.php
        perl -pi -e 's#(.*password_ldap_version.*=).*#${1} "3";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_basedn...=).*#${1} "$ENV{LDAP_BASEDN}";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_method.*=).*#${1} "user";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_adminDN.*=).*#${1} "null";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_adminPW.*=).*#${1} "null";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_userDN_mask...=).*#${1} "$ENV{LDAP_ATTR_USER_RDN}=%login,$ENV{LDAP_ATTR_GROUP_RDN}=$ENV{LDAP_ATTR_GROUP_USERS},$ENV{LDAP_ATTR_DOMAIN_RDN}=%domain,$ENV{LDAP_BASEDN}";#' config.inc.php

        # Use 'md5crypt' instead of 'ssha', because SSHA requires PHP module
        # 'mhash' which may be unavailable on some supported distros.
        perl -pi -e 's#(.*password_ldap_encodage.*=).*#${1} "md5crypt";#' config.inc.php

        perl -pi -e 's#(.*password_ldap_pwattr.*=).*#${1} "userPassword";#' config.inc.php
        perl -pi -e 's#(.*password_ldap_force_replace.*=).*#${1} false;#' config.inc.php
        perl -pi -e 's#(.*password_ldap_lchattr.*=).*#${1} "shadowLastChange";#' config.inc.php
    else
        :
    fi
}
