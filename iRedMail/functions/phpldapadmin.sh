#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -------------------------------------------------------
# ------------------- phpLDAPadmin ----------------------
# -------------------------------------------------------
phpldapadmin_config()
{
    ECHO_INFO "Configure phpLDAPadmin (web-based LDAP management tool)."

    cd ${PLA_CONF_DIR}
    if [ X"${DISTRO}" != X'RHEL' ]; then
        ECHO_DEBUG "Copy example config file."
        cd ${PLA_CONF_DIR}/ && \
        cp -f config.php.example config.php
    fi
    chown ${HTTPD_USER}:${HTTPD_GROUP} config.php
    chmod 0700 config.php

    # Config phpLDAPadmin.
    perl -pi -e 's#(// )(.*hide_template_warning.*=).*#${2} true;#' config.php
    perl -pi -e 's#(// )(.*custom_templates_only.*=).*#${2} true;#' config.php

    perl -pi -e 's#(.*servers.*setValue.*login.*attr.*uid.*).*#// ${1}#' config.php
    perl -pi -e 's#(// )(.*servers.*setValue.*login.*attr..).*#${2}"dn"\);#' config.php

    ECHO_DEBUG "Set file permission."
    chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${PLA_HTTPD_ROOT}
    chmod -R 0755 ${PLA_HTTPD_ROOT}

    # Make phpldapadmin can be accessed via HTTPS only.
    if [ X"${WEB_SERVER_USE_APACHE}" == X'YES' ]; then
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

    echo 'export status_phpldapadmin_config="DONE"' >> ${STATUS_FILE}
}
