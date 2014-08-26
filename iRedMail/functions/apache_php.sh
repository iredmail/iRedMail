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

apache_php_config()
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
    else
        :
    fi

    # Load/enable Apache modules
    ECHO_DEBUG "Enable Apache modules."
    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        a2ensite default-ssl &>/dev/null

        a2enmod ssl &>/dev/null
        a2enmod deflate &>/dev/null

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
            service_control enable 'apache22_enable' 'YES'
            service_control enable 'htcacheclean_enable' 'NO'
        fi
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable httpd.
        # Note: iRedAdmin doesn't work under chroot since Python doesn't work.
        if [ X"${DEFAULT_WEB_SERVER}" == X'APACHE' ]; then
            echo 'httpd_flags="-DSSL -u"  # -u is required by iRedAdmin' >> ${RC_CONF_LOCAL}
        fi

        # Create /var/www/dev/*random.
        cd /var/www/dev/ && /dev/MAKEDEV random

        # Enable mod_auth_ldap/mysql/pgsql
        [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'LDAPD' ] && /usr/local/sbin/mod_auth_ldap-enable &>/dev/null
        [ X"${BACKEND}" == X'MYSQL' ] && /usr/local/sbin/mod_auth_mysql-enable &>/dev/null
        [ X"${BACKEND}" == X'PGSQL' ] && /usr/local/sbin/mod_auth_pgsql-enable &>/dev/null
    fi

    # --------------------------
    # PHP Setting.
    # --------------------------
    backup_file ${APACHE_PHP_INI}

    # FreeBSD: Copy sample file.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        cp -f /usr/local/etc/php.ini-production ${APACHE_PHP_INI}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ln -s /var/www/conf/modules.sample/php-${PHP_VERSION}.conf /var/www/conf/modules/php.conf

        # Enable Apache modules
        for i in $(ls -d /etc/php-${PHP_VERSION}.sample/*); do
            ln -sf ${i} /etc/php-${PHP_VERSION}/$(basename $i)
        done
    fi

    #ECHO_DEBUG "Setting error_reporting to 'E_ERROR': ${APACHE_PHP_INI}."
    #perl -pi -e 's#^(error_reporting.*=)#${1} E_ERROR;#' ${APACHE_PHP_INI}

    ECHO_DEBUG "Disable several functions: ${APACHE_PHP_INI}."
    perl -pi -e 's/^(disable_functions.*=)(.*)/${1}$ENV{PHP_DISABLED_FUNCTIONS}; # ${2}/' ${APACHE_PHP_INI}

    ECHO_DEBUG "Hide PHP Version in Apache from remote users requests: ${APACHE_PHP_INI}."
    perl -pi -e 's#^(expose_php.*=).*#${1} Off;#' ${APACHE_PHP_INI}

    ECHO_DEBUG "Increase 'memory_limit' to 256M: ${APACHE_PHP_INI}."
    perl -pi -e 's#^(memory_limit = ).*#${1} 256M;#' ${APACHE_PHP_INI}

    ECHO_DEBUG "Increase 'upload_max_filesize', 'post_max_size' to 10/12M: ${APACHE_PHP_INI}."
    perl -pi -e 's/^(upload_max_filesize.*=).*/${1} 10M;/' ${APACHE_PHP_INI}
    perl -pi -e 's/^(post_max_size.*=).*/${1} 12M;/' ${APACHE_PHP_INI}

    ECHO_DEBUG "Disable php extension: suhosin. ${APACHE_PHP_INI}."
    perl -pi -e 's/^(suhosin.session.encrypt.*=)/${1} Off;/' ${APACHE_PHP_INI}
    perl -pi -e 's/^;(suhosin.session.encrypt.*=)/${1} Off;/' ${APACHE_PHP_INI}

    # Set date.timezone. Required by PHP-5.3.
    grep '^date.timezone' ${APACHE_PHP_INI} >/dev/null
    if [ X"$?" == X"0" ]; then
        perl -pi -e 's#^(date.timezone).*#${1} = GMT#' ${APACHE_PHP_INI}
    else
        perl -pi -e 's#^;(date.timezone).*#${1} = GMT#' ${APACHE_PHP_INI}
    fi

    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        # Disable suhosin.session.encrypt on Debian 6. Required by Roundcube webmail.
        [ -f ${APACHE_PHP_INI_CONF_DIR}/suhosin.ini ] && \
            perl -pi -e 's#.*(suhosin.session.encrypt).*#${1} = off#' ${APACHE_PHP_INI_CONF_DIR}/suhosin.ini

        # Enable mcrypt
        php5enmod mcrypt &>/dev/null
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

PHP:
    * Configuration file: ${APACHE_PHP_INI}
    * Disabled functions: ${PHP_DISABLED_FUNCTIONS}

EOF
}
