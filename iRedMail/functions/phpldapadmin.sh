#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -------------------------------------------------------
# ------------------- phpLDAPadmin ----------------------
# -------------------------------------------------------
pla_install()
{
    ECHO_INFO "Configure phpLDAPadmin (web-based LDAP management tool)."

    if [ X"${PHPLDAPADMIN_USE_SOURCE}" == X"YES" ]; then
        cd ${MISC_DIR}

        extract_pkg ${PLA_TARBALL} ${HTTPD_SERVERROOT}

        # Create symbol link, so that we don't need to modify apache
        # conf.d/phpldapadmin.conf file after upgrade this component.
        ln -s ${PLA_HTTPD_ROOT} ${PLA_HTTPD_ROOT_SYMBOL_LINK} 2>/dev/null

        # Patch phpldapadmin-1.2.3 to work under PHP 5.5.x
        cd ${PLA_HTTPD_ROOT} && \
            patch -p1 < ${PATCH_DIR}/phpldapadmin/php55.patch >/dev/null
    fi

    ECHO_DEBUG "Copy example config file."
    cd ${PLA_CONF_DIR}/ && \
    cp -f config.php.example config.php && \
    chown ${HTTPD_USER}:${HTTPD_GROUP} config.php && \
    chmod 0700 config.php

    # Config phpLDAPadmin.
    perl -pi -e 's#(// )(.*hide_template_warning.*=).*#${2} true;#' config.php
    perl -pi -e 's#(// )(.*custom_templates_only.*=).*#${2} true;#' config.php

    ECHO_DEBUG "Set file permission."
    chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${PLA_HTTPD_ROOT}
    chmod -R 0755 ${PLA_HTTPD_ROOT}

    # Make phpldapadmin can be accessed via HTTPS only.
    if [ X"${USE_APACHE}" == X'YES' ]; then
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /phpldapadmin "$ENV{PLA_HTTPD_ROOT_SYMBOL_LINK}/"\nAlias /ldap "$ENV{PLA_HTTPD_ROOT_SYMBOL_LINK}/"\n${1}#' ${HTTPD_SSL_CONF}
    fi

    cat >> ${TIP_FILE} <<EOF
phpLDAPadmin:
    * Configuration files:
        - ${PLA_CONF_DIR}/config.php
    * URL:
        - ${PLA_HTTPD_ROOT}
        - https://${HOSTNAME}/phpldapadmin/
        - https://${HOSTNAME}/ldap/
    * Login account:
        - LDAP root account:
            + Username: ${LDAP_ROOTDN}
            + Password: ${LDAP_ROOTPW}
        - Mail admin:
            + Username: ${LDAP_ADMIN_DN}
            + Password: ${LDAP_ADMIN_PW}
    * See also:
        - ${HTTPD_CONF_DIR}/phpldapadmin.conf

EOF

    echo 'export status_pla_install="DONE"' >> ${STATUS_FILE}
}
