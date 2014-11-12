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

# -------------------------------------------------------
# ---------------- Apache & PHP -------------------------
# -------------------------------------------------------

apache_config()
{
    ECHO_INFO "Configure Apache web server and PHP."

    backup_file ${HTTPD_CONF} ${HTTPD_SSL_CONF}

    # --------------------------
    # Apache Setting.
    # --------------------------
    ECHO_DEBUG "Basic configurations."
    perl -pi -e 's#^(ServerTokens).*#${1} ProductOnly#' ${HTTPD_CONF}
    perl -pi -e 's#^(ServerSignature).*#${1} EMail#' ${HTTPD_CONF}
    perl -pi -e 's#^(LogLevel).*#${1} warn#' ${HTTPD_CONF}

    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        perl -pi -e 's#^(ServerTokens).*#${1} ProductOnly#' ${HTTPD_MOD_CONF_SECURITY}
    fi

    ############
    # SSL
    #
    # Disable SSLv3
    echo '# Disable SSLv3' >> ${HTTPD_CONF}
    echo 'SSLProtocol all -SSLv2 -SSLv3' >> ${HTTPD_CONF}

    ECHO_DEBUG "Set correct SSL Cert/Key file location."
    if [ X"${DISTRO}" == X"RHEL" \
        -o X"${DISTRO}" == X'FREEBSD' \
        -o X"${DISTRO}" == X'OPENBSD' \
        ]; then
        perl -pi -e 's#^(SSLCertificateFile)(.*)#${1} $ENV{SSL_CERT_FILE}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(SSLCertificateKeyFile)(.*)#${1} $ENV{SSL_KEY_FILE}#' ${HTTPD_SSL_CONF}

    elif [ X"${DISTRO}" == X"DEBIAN" \
        -o X"${DISTRO}" == X"UBUNTU" \
        ]; then
        perl -pi -e 's#^([ \t]+SSLCertificateFile)(.*)#${1} $ENV{SSL_CERT_FILE}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^([ \t]+SSLCertificateKeyFile)(.*)#${1} $ENV{SSL_KEY_FILE}#' ${HTTPD_SSL_CONF}
    fi

    # Load/enable Apache modules
    ECHO_DEBUG "Enable Apache modules."
    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        a2ensite default-ssl &>/dev/null

        a2enmod ssl deflate &>/dev/null

        # SOGo
        [ X"${USE_SOGO}" == X'YES' ] && a2enmod proxy proxy_http headers rewrite version &>/dev/null

        [ X"${BACKEND}" == X'OPENLDAP' ] && a2enmod authnz_ldap > /dev/null

    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] && \
            perl -pi -e 's/^#(LoadModule.*ldap_module.*)/${1}/' ${HTTPD_CONF}

        [ X"${BACKEND}" == X'MYSQL' ] && \
            perl -pi -e 's/^#(LoadModule.*mysql_auth_module.*)/${1}/' ${HTTPD_CONF}

        [ X"${BACKEND}" == X'PGSQL' ] && \
            perl -pi -e 's/^#(LoadModule.*auth_pgsql_module.*)/${1}/' ${HTTPD_CONF}
    fi

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        ECHO_DEBUG "Configure Apache."
        # With Apache2.2 it now wants to load an Accept Filter.
        echo 'accf_http_load="YES"' >> /boot/loader.conf &>/dev/null

        # Change 'Deny from all' to 'Allow from all'.
        sed -i '.iredmailtmp' '/Each directory to/,/Note that from/s#Deny\ from\ all#Allow\ from\ all#' ${HTTPD_CONF}
        rm -f ${HTTPD_CONF}.iredmailtmp &>/dev/null

        # Set ServerName.
        perl -pi -e 's/^#(ServerName).*/${1} $ENV{HOSTNAME}/' ${HTTPD_CONF}

        # Disable modules:
        #   - unique_id_module
        #   - optional_hook_export_module
        #   - optional_hook_import_module
        #   - optional_fn_import_module
        #   - optional_fn_export_module
        perl -pi -e 's/^(LoadModule.*unique_id_module.*)/#${1}/' ${HTTPD_CONF}
        perl -pi -e 's/^(LoadModule.*optional_hook_export_module.*)/#${1}/' ${HTTPD_CONF}
        perl -pi -e 's/^(LoadModule.*optional_hook_import_module.*)/#${1}/' ${HTTPD_CONF}
        perl -pi -e 's/^(LoadModule.*optional_fn_import_module.*)/#${1}/' ${HTTPD_CONF}
        perl -pi -e 's/^(LoadModule.*optional_fn_export_module.*)/#${1}/' ${HTTPD_CONF}

        # Add index.php in DirectoryIndex.
        perl -pi -e 's#(.*DirectoryIndex.*)(index.html)#${1} index.php ${2}#' ${HTTPD_CONF}

        # Add php file type.
        echo 'AddType application/x-httpd-php .php' >> ${HTTPD_CONF}
        echo 'AddType application/x-httpd-php-source .phps' >> ${HTTPD_CONF}

        # Enable httpd-ssl.conf.
        perl -pi -e 's/^#(Include.*etc.*apache.*extra.*httpd-ssl.conf.*)/${1}/' ${HTTPD_CONF}

        # Create empty directory for htcacheclean.
        mkdir -p /usr/local/www/proxy/ &>/dev/null

        # Start service when system start up.
        if [ X"${DEFAULT_WEB_SERVER}" == X'APACHE' ]; then
            service_control enable "${APACHE_RC_SCRIPT_NAME}_enable" 'YES'
            service_control enable 'htcacheclean_enable' 'NO'
        fi
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # iRedMail doesn't support the built-in httpd daemon (not Apache).
        :
    fi

    cat >> ${TIP_FILE} <<EOF
Apache:
    * Configuration files:
        - ${HTTPD_CONF_ROOT}
        - ${HTTPD_CONF}
        - ${HTTPD_CONF_DIR}/*
    * Directories:
        - ${HTTPD_SERVERROOT}
        - ${HTTPD_DOCUMENTROOT}
    * See also:
        - ${HTTPD_DOCUMENTROOT}/index.html

EOF

    echo 'export status_apache_config="DONE"' >> ${STATUS_FILE}
}
