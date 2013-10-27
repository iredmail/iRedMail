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

    #########################################
    # Create ${HTTPD_CONF} or ${HTTPD_SSL_CONF} for special distributions.
    #
    if [ X"${DISTRO}" == X"SUSE" ]; then
        cat > ${HTTPD_CONF} <<EOF
<VirtualHost *:80>
    ServerAdmin ${FIRST_USER}@${FIRST_DOMAIN}
    DocumentRoot ${HTTPD_DOCUMENTROOT}
    ErrorLog ${HTTPD_LOG_ERRORLOG}
    CustomLog ${HTTPD_LOG_ACCESSLOG} combined
    HostnameLookups Off
    UseCanonicalName Off
    ServerSignature Off

    <Directory />
        Options FollowSymLinks
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    <Directory "/srv/www/htdocs">
        Options Indexes FollowSymLinks
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    ScriptAlias /cgi-bin "${HTTPD_CGIBIN_DIR}"
    <Directory "${HTTPD_CGIBIN_DIR}">
        AllowOverride None
        Options +ExecCGI -Includes
        Order allow,deny
        Allow from all
    </Directory>

    <IfModule mod_userdir.c>
        UserDir public_html
        Include ${HTTPD_CONF_ROOT}/mod_userdir.conf
    </IfModule>

</VirtualHost>
EOF

        cat > ${HTTPD_SSL_CONF} <<EOF
NameVirtualHost *:443
<VirtualHost *:443>
    ServerAdmin ${FIRST_USER}@${FIRST_DOMAIN}
    DocumentRoot ${HTTPD_DOCUMENTROOT}

    # Enable SSL.
    SSLEngine On
    SSLCertificateFile ${SSL_CERT_FILE}
    SSLCertificateKeyFile ${SSL_KEY_FILE}

    <Directory />
        Options FollowSymLinks
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    <Directory "/srv/www/htdocs">
        Options Indexes FollowSymLinks
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    ScriptAlias /cgi-bin "${HTTPD_CGIBIN_DIR}"
    <Directory "${HTTPD_CGIBIN_DIR}">
        AllowOverride None
        Options +ExecCGI -Includes
        Order allow,deny
        Allow from all
    </Directory>

    <IfModule mod_userdir.c>
        UserDir public_html
        Include ${HTTPD_CONF_ROOT}/mod_userdir.conf
    </IfModule>

</VirtualHost>
EOF
    else
        :
    fi

    # --------------------------
    # Apache Setting.
    # --------------------------
    ECHO_DEBUG "Basic configurations."
    if [ X"${DISTRO}" == X"SUSE" ]; then
        # openSUSE:
        #   - Define some settings in /etc/sysconfig/apache2
        perl -pi -e 's#^(APACHE_SERVERTOKENS=).*#${1}"ProductOnly"#' ${HTTPD_SYSCONFIG_CONF}
        perl -pi -e 's#^(APACHE_SERVERSIGNATURE=).*#${1}"email"#' ${HTTPD_SYSCONFIG_CONF}
        perl -pi -e 's#^(APACHE_LOGLEVEL=).*#${1}"warn"#' ${HTTPD_SYSCONFIG_CONF}

        #perl -pi -e 's#(.*Options).*#${1} FollowSymLinks#' ${HTTPD_CONF_ROOT}/httpd.conf
        #sed -i -e '/AllowOverride/,/AccessFileName/s#Deny from all#Allow from all#' ${HTTPD_CONF_ROOT}/httpd.conf
    else
        perl -pi -e 's#^(ServerTokens).*#${1} ProductOnly#' ${HTTPD_CONF}
        perl -pi -e 's#^(ServerSignature).*#${1} EMail#' ${HTTPD_CONF}
        perl -pi -e 's#^(LogLevel).*#${1} warn#' ${HTTPD_CONF}

        if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            perl -pi -e 's#^(ServerTokens).*#${1} ProductOnly#' ${HTTPD_MOD_CONF_SECURITY}
        fi
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

    #####################
    # LoadModule
    #
    ECHO_DEBUG "Enable modules."
    if [ X"${DISTRO}" == X"RHEL" ]; then
        # Enable wsgi.
        perl -pi -e 's/#(LoadModule.*wsgi_module.*modules.*mod_wsgi.so)/${1}/' ${HTTPD_CONF_DIR}/wsgi.conf

    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        a2ensite default-ssl >/dev/null

        a2enmod ssl >/dev/null
        a2enmod deflate >/dev/null 2>&1

        [ X"${BACKEND}" == X"OPENLDAP" ] && a2enmod authnz_ldap > /dev/null
        [ X"${BACKEND}" == X"MYSQL" ] && a2enmod auth_mysql > /dev/null
        [ X"${BACKEND}" == X"PGSQL" ] && a2enmod 000_auth_pgsql > /dev/null

    elif [ X"${DISTRO}" == X"SUSE" ]; then
        a2enmod authz_core &>/dev/null
        a2enmod deflate &>/dev/null

        # Enable SSL.
        a2enmod ssl &>/dev/null
        perl -pi -e 's/#(Listen 443)/${1}/' ${HTTPD_CONF_ROOT}/listen.conf

        [ X"${BACKEND}" == X"OPENLDAP" ] && \
            a2enmod authnz_ldap &>/dev/null && \
            a2enmod ldap &>/dev/null

        [ X"${BACKEND}" == X"MYSQL" ] && a2enmod auth_mysql &>/dev/null

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
        [ X"${DISTRO}" == X"SUSE" ] && perl -pi -e 's#^(DirectoryIndex)(.*)#${1} index.php ${2}#' ${HTTPD_CONF}

        # Add php file type.
        echo 'AddType application/x-httpd-php .php' >> ${HTTPD_CONF}
        echo 'AddType application/x-httpd-php-source .phps' >> ${HTTPD_CONF}

        # Enable httpd-ssl.conf.
        perl -pi -e 's/^#(Include.*etc.*apache.*extra.*httpd-ssl.conf.*)/${1}/' ${HTTPD_CONF}

        # Create empty directory for htcacheclean.
        mkdir -p /usr/local/www/proxy/ 2>/dev/null

        # Start apache when system start up.
        freebsd_enable_service_in_rc_conf 'apache22_enable' 'YES'
        freebsd_enable_service_in_rc_conf 'htcacheclean_enable' 'NO'
    fi

    ##############
    # HTTP Port
    #
    #if [ X"${HTTPD_PORT}" != X"80" ]; then
    #    ECHO_DEBUG "Change Apache listen port to: ${HTTPD_PORT}."
    #    perl -pi -e 's#^(Listen )(80)$#${1}$ENV{HTTPD_PORT}#' ${HTTPD_CONF}
    #else
    #    :
    #fi

    ##################
    # /robots.txt.
    #
    backup_file ${HTTPD_DOCUMENTROOT}/robots.txt
    cat >> ${HTTPD_DOCUMENTROOT}/robots.txt <<EOF
User-agent: *
Disallow: /
EOF

    # Add alias for Apache daemon user
    add_postfix_alias ${HTTPD_USER} ${SYS_ROOT_USER}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable httpd.
        # Note: iRedAdmin doesn't work with chroot.
        echo 'httpd_flags="-DSSL -u"  # -u is required by iRedAdmin' >> ${RC_CONF_LOCAL}

        # Create /var/www/dev/*random.
        cd /var/www/dev/ && /dev/MAKEDEV random
    fi

    # --------------------------
    # PHP Setting.
    # --------------------------
    backup_file ${PHP_INI}

    # FreeBSD: Copy sample file.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        cp -f /usr/local/etc/php.ini-production ${PHP_INI}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ln -s /var/www/conf/modules.sample/php-${PHP_VERSION}.conf /var/www/conf/modules/php.conf

        # Enable Apache modules
        for module in fileinfo bz2 imap ldap mcrypt mysql mysqli pgsql pspell gd; do
            ln -s /etc/php-${PHP_VERSION}.sample/${module}.ini /etc/php-${PHP_VERSION}/${module}.ini
        done
    fi

    #ECHO_DEBUG "Setting error_reporting to 'E_ERROR': ${PHP_INI}."
    #perl -pi -e 's#^(error_reporting.*=)#${1} E_ERROR;#' ${PHP_INI}

    ECHO_DEBUG "Disable several functions: ${PHP_INI}."
    perl -pi -e 's#^(disable_functions.*=)(.*)#${1}$ENV{PHP_DISABLED_FUNCTIONS}; ${2}#' ${PHP_INI}

    ECHO_DEBUG "Hide PHP Version in Apache from remote users requests: ${PHP_INI}."
    perl -pi -e 's#^(expose_php.*=).*#${1} Off;#' ${PHP_INI}

    ECHO_DEBUG "Increase 'memory_limit' to 256M: ${PHP_INI}."
    perl -pi -e 's#^(memory_limit = ).*#${1} 256M;#' ${PHP_INI}

    ECHO_DEBUG "Increase 'upload_max_filesize', 'post_max_size' to 10/12M: ${PHP_INI}."
    perl -pi -e 's/^(upload_max_filesize.*=).*/${1} 10M;/' ${PHP_INI}
    perl -pi -e 's/^(post_max_size.*=).*/${1} 12M;/' ${PHP_INI}

    ECHO_DEBUG "Disable php extension: suhosin. ${PHP_INI}."
    perl -pi -e 's/^(suhosin.session.encrypt.*=)/${1} Off;/' ${PHP_INI}
    perl -pi -e 's/^;(suhosin.session.encrypt.*=)/${1} Off;/' ${PHP_INI}

    # Set date.timezone. Required by PHP-5.3.
    grep '^date.timezone' ${PHP_INI} >/dev/null
    if [ X"$?" == X"0" ]; then
        perl -pi -e 's#^(date.timezone).*#${1} = GMT#' ${PHP_INI}
    else
        perl -pi -e 's#^;(date.timezone).*#${1} = GMT#' ${PHP_INI}
    fi

    # Disable suhosin.session.encrypt on Debian 6. Required by Roundcube webmail.
    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        [ -f ${PHP_INI_CONF_DIR}/suhosin.ini ] && \
            perl -pi -e 's#.*(suhosin.session.encrypt).*#${1} = off#' ${PHP_INI_CONF_DIR}/suhosin.ini
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
    * Configuration file: ${PHP_INI}
    * Disabled functions: ${PHP_DISABLED_FUNCTIONS}

EOF

    echo 'export status_apache_php_config="DONE"' >> ${STATUS_FILE}
}
