#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -------------------------------------------------
# phpPgAdmin.
# -------------------------------------------------
phppgadmin_install()
{
    ECHO_INFO "Configure phpPgAdmin (web-based PostgreSQL management tool)." 

    if [ X"${PHPPGADMIN_USE_SOURCE}" == X"YES" ]; then
        cd ${MISC_DIR}

        extract_pkg ${PHPPGADMIN_TARBALL} ${HTTPD_SERVERROOT}

        ECHO_DEBUG "Set file permission for phpPgAdmin: ${PHPPGADMIN_HTTPD_ROOT}."
        chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${PHPPGADMIN_HTTPD_ROOT}
        chmod -R 0755 ${PHPPGADMIN_HTTPD_ROOT}

        # Create symbol link, so that we don't need to modify apache
        # conf.d/phppgadmin.conf file after upgrade this component.
        ln -s ${PHPPGADMIN_HTTPD_ROOT} ${PHPPGADMIN_HTTPD_ROOT_SYMBOL_LINK} >/dev/null
    fi

    backup_file ${PHPPGADMIN_CONFIG_FILE}

    ECHO_DEBUG "Create directory alias for phpPgAdmin in Apache: ${PHPPGADMIN_HTTPD_CONF}."
    cat > ${PHPPGADMIN_HTTPD_CONF} <<EOF
${CONF_MSG}
# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.
<Directory "${PHPPGADMIN_HTTPD_ROOT_SYMBOL_LINK}/">
    Options -Indexes
</Directory>
EOF

    # Make phpPgAdmin can be accessed via HTTPS only.
    perl -pi -e 's#( *</VirtualHost>)#Alias /phppgadmin "$ENV{PHPPGADMIN_HTTPD_ROOT_SYMBOL_LINK}/"\n${1}#' ${HTTPD_SSL_CONF}

    ECHO_DEBUG "Config phpPgAdmin: ${PHPPGADMIN_CONFIG_FILE}."
    cd ${PHPPGADMIN_HTTPD_ROOT} && cp config.inc.php-dist ${PHPPGADMIN_CONFIG_FILE} &>/dev/null

    perl -pi -e 's#(.*servers.*host.*=).*#${1} "$ENV{SQL_SERVER}";#' ${PHPPGADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*servers.*port.*=).*#${1} $ENV{SQL_SERVER_PORT};#' ${PHPPGADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*servers.*sslmode.*=).*#${1} "require";#' ${PHPPGADMIN_CONFIG_FILE}

    perl -pi -e 's#(.*servers.*pg_dump_path.*=).*#${1} "$ENV{PGSQL_BIN_PG_DUMP}";#' ${PHPPGADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*servers.*pg_dumpall_path.*=).*#${1} "$ENV{PGSQL_BIN_PG_DUMPALL}";#' ${PHPPGADMIN_CONFIG_FILE}

    perl -pi -e 's#(.*owned_only.*=).*#${1} true;#' ${PHPPGADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*show_reports.*=).*#${1} false;#' ${PHPPGADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*owned_reports_only.*=).*#${1} true;#' ${PHPPGADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*min_password_length.*=).*#${1} 8;#' ${PHPPGADMIN_CONFIG_FILE}

    perl -pi -e 's#(.*Servers.*connect_type.*=).*#${1}"socket";#' ${PHPPGADMIN_CONFIG_FILE}

    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        # Create a symbol link
        if [ -f /etc/phppgadmin/config.inc.php ]; then
            backup_file /etc/phppgadmin/config.inc.php
            rm -f /etc/phppgadmin/config.inc.php &>/dev/null
            ln -s ${PHPPGADMIN_CONFIG_FILE} /etc/phppgadmin/config.inc.php
        fi
    fi

    cat >> ${TIP_FILE} <<EOF
phpPgAdmin:
    * Configuration files:
        - ${PHPPGADMIN_HTTPD_ROOT}
        - ${PHPPGADMIN_CONFIG_FILE}
    * Login account:
        - Username: ${PGSQL_ROOT_USER}, password: ${PGSQL_ROOT_PASSWD}
        - Username: ${VMAIL_DB_ADMIN_USER}, password: ${VMAIL_DB_ADMIN_PASSWD}
        - Username (read-only): ${VMAIL_DB_BIND_USER}, password: ${VMAIL_DB_BIND_PASSWD}
    * URL:
        - httpS://${HOSTNAME}/phppgadmin
    * See also:
        - ${PHPPGADMIN_HTTPD_CONF}

EOF

    echo 'export status_phppgadmin_install="DONE"' >> ${STATUS_FILE}
}
