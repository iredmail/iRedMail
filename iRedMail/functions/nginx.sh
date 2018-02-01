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
# ------------------- Nginx -----------------------------
# -------------------------------------------------------

nginx_config()
{
    ECHO_INFO "Configure Nginx web server."

    backup_file ${NGINX_CONF} ${NGINX_CONF_SITE_DEFAULT} ${PHP_FPM_POOL_WWW_CONF}

    # Make sure we have an empty directory
    [ -d ${HTTPD_CONF_DIR_AVAILABLE_CONF} ] && mv ${HTTPD_CONF_DIR_AVAILABLE_CONF} ${HTTPD_CONF_DIR_AVAILABLE_CONF}.bak
    [ ! -d ${HTTPD_CONF_DIR_AVAILABLE_CONF} ] && mkdir -p ${HTTPD_CONF_DIR_AVAILABLE_CONF}

    [ -d ${HTTPD_CONF_DIR_ENABLED_CONF} ] && mv ${HTTPD_CONF_DIR_ENABLED_CONF} ${HTTPD_CONF_DIR_ENABLED_CONF}.bak
    [ ! -d ${HTTPD_CONF_DIR_ENABLED_CONF} ] && mkdir -p ${HTTPD_CONF_DIR_ENABLED_CONF}

    # Directory used to store virtual web hosts config files
    [ -d ${HTTPD_CONF_DIR_AVAILABLE_SITES} ] && mv ${HTTPD_CONF_DIR_AVAILABLE_SITES} ${HTTPD_CONF_DIR_AVAILABLE_SITES}.bak
    [ ! -d ${HTTPD_CONF_DIR_AVAILABLE_SITES} ] && mkdir -p ${HTTPD_CONF_DIR_AVAILABLE_SITES}

    [ -d ${HTTPD_CONF_DIR_ENABLED_SITES} ] && mv ${HTTPD_CONF_DIR_ENABLED_SITES} ${HTTPD_CONF_DIR_ENABLED_SITES}.bak
    [ ! -d ${HTTPD_CONF_DIR_ENABLED_SITES} ] && mkdir -p ${HTTPD_CONF_DIR_ENABLED_SITES}

    #
    # Modular config files
    #
    # Copy sample files
    cp ${SAMPLE_DIR}/nginx/nginx.conf ${NGINX_CONF}
    cp -f ${SAMPLE_DIR}/nginx/conf-available/*.conf ${HTTPD_CONF_DIR_AVAILABLE_CONF}

    #
    # Enable modular config files
    #
    _modular_conf='client_max_body_size.conf \
        default_type.conf \
        gzip.conf \
        log.conf \
        mime_types.conf \
        sendfile.conf \
        server_tokens.conf \
        types_hash_max_size.conf'

    [ X"${IREDMAIL_USE_PHP}" == X'YES' ] && _modular_conf="${_modular_conf} php-fpm.conf"
    [ X"${USE_NETDATA}" == X'YES' ] && _modular_conf="${_modular_conf} netdata.conf"

    for cf in ${_modular_conf}; do
        ln -s ${HTTPD_CONF_DIR_AVAILABLE_CONF}/${cf} ${HTTPD_CONF_DIR_ENABLED_CONF}/${cf} >> ${INSTALL_LOG} 2>&1
    done

    #
    # Default sites
    #
    cp -f ${SAMPLE_DIR}/nginx/sites-available/00-default.conf ${NGINX_CONF_SITE_DEFAULT}
    cp -f ${SAMPLE_DIR}/nginx/sites-available/00-default-ssl.conf ${NGINX_CONF_SITE_DEFAULT_SSL}
    ln -s ${NGINX_CONF_SITE_DEFAULT} ${HTTPD_CONF_DIR_ENABLED_SITES} >> ${INSTALL_LOG} 2>&1
    ln -s ${NGINX_CONF_SITE_DEFAULT_SSL} ${HTTPD_CONF_DIR_ENABLED_SITES} >> ${INSTALL_LOG} 2>&1

    # Template configuration snippets.
    [ ! -d ${NGINX_CONF_TMPL_DIR} ] && mkdir -p ${NGINX_CONF_TMPL_DIR}
    cp ${SAMPLE_DIR}/nginx/templates/*.tmpl ${NGINX_CONF_TMPL_DIR}
    perl -pi -e 's#PH_NGINX_CONF_TMPL_DIR#$ENV{NGINX_CONF_TMPL_DIR}#g' \
        ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf \
        ${NGINX_CONF_TMPL_DIR}/*tmpl

    # nginx.conf
    perl -pi -e 's#PH_HTTPD_USER#$ENV{HTTPD_USER}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_NGINX_PID#$ENV{NGINX_PID}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_HTTPD_CONF_DIR_ENABLED_SITES#$ENV{HTTPD_CONF_DIR_ENABLED_SITES}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_HTTPD_CONF_DIR_ENABLED_CONF#$ENV{HTTPD_CONF_DIR_ENABLED_CONF}#g' ${NGINX_CONF}

    #
    # conf-available/*.conf
    #
    perl -pi -e 's#PH_HTTPD_LOG_ERRORLOG#$ENV{HTTPD_LOG_ERRORLOG}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/log.conf
    perl -pi -e 's#PH_HTTPD_LOG_ACCESSLOG#$ENV{HTTPD_LOG_ACCESSLOG}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/log.conf
    perl -pi -e 's#PH_NGINX_MIME_TYPES#$ENV{NGINX_MIME_TYPES}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/mime_types.conf
    perl -pi -e 's#PH_PHP_FPM_SOCKET#$ENV{PHP_FPM_SOCKET}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/php-fpm.conf
    # netdata
    perl -pi -e 's#PH_NETDATA_PORT#$ENV{NETDATA_PORT}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/*.conf

    #
    # web sites
    #
    perl -pi -e 's#PH_HTTPD_PORT#$ENV{HTTPD_PORT}#g' ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf
    perl -pi -e 's#PH_HTTPD_DOCUMENTROOT#$ENV{HTTPD_DOCUMENTROOT}#g' ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf

    # ssl
    perl -pi -e 's#PH_HTTPS_PORT#$ENV{HTTPS_PORT}#g' ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf
    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SSL_KEY_FILE#$ENV{SSL_KEY_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SSL_CIPHERS#$ENV{SSL_CIPHERS}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SSL_DH1024_PARAM_FILE#$ENV{SSL_DH1024_PARAM_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # Roundcube
    perl -pi -e 's#PH_RCM_HTTPD_ROOT_SYMBOL_LINK#$ENV{RCM_HTTPD_ROOT_SYMBOL_LINK}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # iRedAdmin
    perl -pi -e 's#PH_IREDADMIN_HTTPD_ROOT_SYMBOL_LINK#$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_IREDADMIN_UWSGI_SOCKET_FULL#$ENV{IREDADMIN_UWSGI_SOCKET_FULL}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # SOGo
    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_GNUSTEP_DIR#$ENV{SOGO_GNUSTEP_DIR}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_PROXY_TIMEOUT#$ENV{SOGO_PROXY_TIMEOUT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # netdata
    perl -pi -e 's#PH_NETDATA_HTTPD_AUTH_FILE#$ENV{NETDATA_HTTPD_AUTH_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # Adminer
    perl -pi -e 's#PH_HTTPD_SERVERROOT#$ENV{HTTPD_SERVERROOT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # php-fpm
    if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
        perl -pi -e 's#^(listen *=).*#${1} $ENV{PHP_FPM_SOCKET}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^;(listen.owner *=).*#${1} $ENV{HTTPD_USER}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^;(listen.group *=).*#${1} $ENV{HTTPD_GROUP}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^;(listen.mode *=).*#${1} 0660#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^(user.*=).*#${1} $ENV{HTTPD_USER}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^(group.*=).*#${1} $ENV{HTTPD_GROUP}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^(php_value.*session.save_path.).*#${1} = "$ENV{PHP_SESSION_SAVE_PATH}"#g' ${PHP_FPM_POOL_WWW_CONF}

        # Add '/status'
        perl -pi -e 's#^;(pm.status_path =).*#${1} /status#g' ${PHP_FPM_POOL_WWW_CONF}

        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            perl -pi -e 's#^(\[www\])$#${1}\nuser = $ENV{HTTPD_USER}\ngroup = $ENV{HTTPD_GROUP}\n#' ${PHP_FPM_POOL_WWW_CONF}

            # Disable chroot in php-fpm
            perl -pi -e 's#^(chroot *=.*)#;${1}#g' ${PHP_FPM_POOL_WWW_CONF}
            perl -pi -e 's#^(chdir *=.*)#;${1}#g' ${PHP_FPM_POOL_WWW_CONF}
        fi
    fi

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        mkdir -p /var/log/nginx >> ${INSTALL_LOG} 2>&1
        service_control enable 'nginx_enable' 'YES'
        service_control enable 'php_fpm_enable' 'YES'
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable unchrooted Nginx
        echo 'nginx_flags="-u"' >> ${RC_CONF_LOCAL}
    fi

    cat >> ${TIP_FILE} <<EOF
Nginx:
    * Configuration files:
        - ${NGINX_CONF}
        - ${NGINX_CONF_SITE_DEFAULT}
        - ${NGINX_CONF_SITE_DEFAULT_SSL}
    * Directories:
        - ${HTTPD_CONF_ROOT}
        - ${HTTPD_DOCUMENTROOT}
    * See also:
        - ${HTTPD_DOCUMENTROOT}/index.html

php-fpm:
    * Configuration files: ${PHP_FPM_POOL_WWW_CONF}
    * Socket: ${PHP_FPM_SOCKET}

EOF

    echo 'export status_nginx_config="DONE"' >> ${STATUS_FILE}
}
