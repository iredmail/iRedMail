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
    ECHO_INFO "Configure Nginx web server and uWSGI."

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

    # Copy sample config files
    cp ${SAMPLE_DIR}/nginx/nginx.conf ${NGINX_CONF}
    cp -f ${SAMPLE_DIR}/nginx/conf-available/*.conf ${HTTPD_CONF_DIR_AVAILABLE_CONF}
    cp -f ${SAMPLE_DIR}/nginx/sites-available/00-default.conf ${NGINX_CONF_SITE_DEFAULT}
    cp -f ${SAMPLE_DIR}/nginx/sites-available/00-default-ssl.conf ${NGINX_CONF_SITE_DEFAULT_SSL}

    # Enable basic config files
    for cf in client_max_body_size.conf \
        default_type.conf \
        gzip.conf \
        log.conf \
        mime_types.conf \
        php-fpm.conf \
        sendfile.conf \
        server_tokens.conf \
        types_hash_max_size.conf; do
        ln -s ${HTTPD_CONF_DIR_AVAILABLE_CONF}/${cf} ${HTTPD_CONF_DIR_ENABLED_CONF}/${cf} >> ${INSTALL_LOG} 2>&1
    done

    # Enable default sites
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

    # conf-available.d/*.conf
    perl -pi -e 's#PH_HTTPD_LOG_ERRORLOG#$ENV{HTTPD_LOG_ERRORLOG}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/log.conf
    perl -pi -e 's#PH_HTTPD_LOG_ACCESSLOG#$ENV{HTTPD_LOG_ACCESSLOG}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/log.conf
    perl -pi -e 's#PH_NGINX_MIME_TYPES#$ENV{NGINX_MIME_TYPES}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/mime_types.conf
    perl -pi -e 's#PH_PHP_FPM_SOCKET#$ENV{PHP_FPM_SOCKET}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/php-fpm.conf

    # default web sites
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
    perl -pi -e 's#PH_UWSGI_SOCKET_IREDADMIN_FULL#$ENV{UWSGI_SOCKET_IREDADMIN_FULL}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # SOGo
    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_GNUSTEP_DIR#$ENV{SOGO_GNUSTEP_DIR}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_PROXY_TIMEOUT#$ENV{SOGO_PROXY_TIMEOUT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

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

        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            perl -pi -e 's#^(\[www\])$#${1}\nuser = $ENV{HTTPD_USER}\ngroup = $ENV{HTTPD_GROUP}\n#' ${PHP_FPM_POOL_WWW_CONF}
        fi
    fi

    # Awstats
    perl -pi -e 's#PH_AWSTATS_STATIC_PAGES_DIR#$ENV{AWSTATS_STATIC_PAGES_DIR}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_AWSTATS_HTTPD_AUTH_FILE#$ENV{AWSTATS_HTTPD_AUTH_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_AWSTATS_ICON_DIR#$ENV{AWSTATS_ICON_DIR}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # Copy uwsgi config file for iRedAdmin
    [ -d ${UWSGI_CONF_DIR} ] || mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    backup_file ${UWSGI_CONF} ${IREDADMIN_UWSGI_CONF}

    if [ X"${DISTRO}" == X'RHEL' ]; then
        cp -f ${SAMPLE_DIR}/nginx/uwsgi.ini ${UWSGI_CONF}

        perl -pi -e 's#^(daemonize .*=).*#${1} $ENV{UWSGI_LOG_FILE}#' ${UWSGI_CONF}
        if [ X"${DISTRO_VERSION}" != X'6' ]; then
            perl -pi -e 's/^(daemonize.*)/#${1}/' ${UWSGI_CONF}
        fi

        perl -pi -e 's#^(pidfile.*=).*#${1} $ENV{UWSGI_PID}#' ${UWSGI_CONF}
        perl -pi -e 's#^(emperor *=).*#${1} $ENV{UWSGI_CONF_DIR}#' ${UWSGI_CONF}
        perl -pi -e 's#^(emperor-tyrant.*=).*#${1} false#' ${UWSGI_CONF}
        perl -pi -e 's#^(stats.*=).*#${1} $ENV{UWSGI_SOCKET}#' ${UWSGI_CONF}

        cp -f ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}

        ECHO_DEBUG "Setting logrotate for uwsgi log file: ${UWSGI_LOG_FILE}."
        mkdir -p ${UWSGI_LOG_DIR} >> ${INSTALL_LOG} 2>&1
        cp -f ${SAMPLE_DIR}/logrotate/uwsgi ${UWSGI_LOGROTATE_FILE}

        perl -pi -e 's#PH_UWSGI_LOG_FILE#$ENV{UWSGI_LOG_FILE}#g' ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_ROOT_USER#$ENV{SYS_ROOT_USER}#g' ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_ROOT_GROUP#$ENV{SYS_ROOT_GROUP}#g' ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYSLOG_POSTROTATE_CMD#$ENV{SYSLOG_POSTROTATE_CMD}#g' ${UWSGI_LOGROTATE_FILE}

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        cp ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's/^(pidfile.*)/#${1}/' ${IREDADMIN_UWSGI_CONF}
        ln -s ${IREDADMIN_UWSGI_CONF} /etc/uwsgi/apps-enabled/iredadmin.ini
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        mkdir -p /var/log/nginx >> ${INSTALL_LOG} 2>&1

        mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        cp -f ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}

        perl -pi -e 's/^(plugins.*)/#${1}/' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#PH_UWSGI_LOG_FILE#$ENV{UWSGI_LOG_FILE}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#PH_UWSGI_PID_IREDADMIN#$ENV{UWSGI_PID_IREDADMIN}#g' ${IREDADMIN_UWSGI_CONF}

        # Rotate log file with newsyslog
        cp -f ${SAMPLE_DIR}/freebsd/newsyslog.conf.d/uwsgi ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_UWSGI_PID_IREDADMIN#$ENV{UWSGI_PID_IREDADMIN}#g' ${UWSGI_LOGROTATE_FILE}

        service_control enable 'nginx_enable' 'YES'
        service_control enable 'php_fpm_enable' 'YES'
        service_control enable 'uwsgi_enable' 'YES'
        service_control enable 'uwsgi_profiles' 'iredadmin'
        service_control enable 'uwsgi_iredadmin_flags' "--ini ${IREDADMIN_UWSGI_CONF}"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable unchrooted Nginx
        echo 'nginx_flags="-u"' >> ${RC_CONF_LOCAL}

        # Disable chroot in php-fpm
        if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
            perl -pi -e 's#^(chroot *=.*)#;${1}#g' ${PHP_FPM_POOL_WWW_CONF}
            perl -pi -e 's#^(chdir *=.*)#;${1}#g' ${PHP_FPM_POOL_WWW_CONF}
        fi

        mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        cp ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#^(uid).*#${1} = $ENV{HTTPD_USER}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#^(gid).*#${1} = $ENV{HTTPD_GROUP}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's/^(plugins.*)/#${1}/g' ${IREDADMIN_UWSGI_CONF}

        # Start uWSGI
        cp ${SAMPLE_DIR}/openbsd/rc.d/uwsgi ${DIR_RC_SCRIPTS}/${UWSGI_RC_SCRIPT_NAME}
        chmod +x ${DIR_RC_SCRIPTS}/${UWSGI_RC_SCRIPT_NAME}
        service_control enable ${UWSGI_RC_SCRIPT_NAME}
        echo "uwsgi_flags='--ini ${IREDADMIN_UWSGI_CONF} --daemonize ${UWSGI_LOG_FILE}'" >> ${RC_CONF_LOCAL}
    fi

    if [ -f ${IREDADMIN_UWSGI_CONF} ]; then
        perl -pi -e 's#PH_HTTPD_USER#$ENV{HTTPD_USER}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#PH_HTTPD_GROUP#$ENV{HTTPD_GROUP}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#PH_UWSGI_SOCKET_IREDADMIN#$ENV{UWSGI_SOCKET_IREDADMIN}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#PH_UWSGI_PID_IREDADMIN#$ENV{UWSGI_PID_IREDADMIN}#g' ${IREDADMIN_UWSGI_CONF}
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

uWSGI:
    * Configuration files: ${UWSGI_CONF_DIR}
    * Logrotate config file: ${UWSGI_LOGROTATE_FILE}
    * Socket for iRedAdmin: ${UWSGI_SOCKET_IREDADMIN}

EOF

    echo 'export status_nginx_config="DONE"' >> ${STATUS_FILE}
}
