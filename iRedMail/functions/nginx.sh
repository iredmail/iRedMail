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

    backup_file ${NGINX_CONF} ${NGINX_CONF_DEFAULT} ${PHP_FPM_POOL_WWW_CONF}

    # Copy sample config files
    [ ! -d ${NGINX_CONF_DIR} ] && mkdir -p ${NGINX_CONF_DIR}
    cp ${SAMPLE_DIR}/nginx/nginx.conf ${NGINX_CONF}
    cp ${SAMPLE_DIR}/nginx/default.conf ${NGINX_CONF_DEFAULT}

    # nginx.conf
    perl -pi -e 's#PH_HTTPD_USER#$ENV{HTTPD_USER}#g' ${NGINX_CONF}

    perl -pi -e 's#PH_NGINX_LOG_ERRORLOG#$ENV{NGINX_LOG_ERRORLOG}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_NGINX_LOG_ACCESSLOG#$ENV{NGINX_LOG_ACCESSLOG}#g' ${NGINX_CONF} ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_NGINX_PID#$ENV{NGINX_PID}#g' ${NGINX_CONF}

    perl -pi -e 's#PH_NGINX_MIME_TYPES#$ENV{NGINX_MIME_TYPES}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_NGINX_CONF_DIR#$ENV{NGINX_CONF_DIR}#g' ${NGINX_CONF}

    # top directory used to store temporary user uploaded file and other stuffs.
    #[ -d /var/lib/nginx ] && \
    #    chown -R ${HTTPD_USER}:${HTTPD_GROUP} /var/lib/nginx

    # default server
    perl -pi -e 's#PH_HTTPD_PORT#$ENV{HTTPD_PORT}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_HTTPD_SERVERROOT#$ENV{HTTPD_SERVERROOT}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_HTTPD_DOCUMENTROOT#$ENV{HTTPD_DOCUMENTROOT}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_PHP_FASTCGI_SOCKET_FULL#$ENV{PHP_FASTCGI_SOCKET_FULL}#g' ${NGINX_CONF_DEFAULT}

    # ssl
    perl -pi -e 's#PH_HTTPS_PORT#$ENV{HTTPS_PORT}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_SSL_KEY_FILE#$ENV{SSL_KEY_FILE}#g' ${NGINX_CONF_DEFAULT}

    # Roundcube
    perl -pi -e 's#PH_RCM_HTTPD_ROOT_SYMBOL_LINK#$ENV{RCM_HTTPD_ROOT_SYMBOL_LINK}#g' ${NGINX_CONF_DEFAULT}
    # iRedAdmin
    perl -pi -e 's#PH_IREDADMIN_HTTPD_ROOT_SYMBOL_LINK#$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_UWSGI_SOCKET_IREDADMIN_FULL#$ENV{UWSGI_SOCKET_IREDADMIN_FULL}#g' ${NGINX_CONF_DEFAULT}
    # SOGo
    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${NGINX_CONF_DEFAULT}
    perl -pi -e 's#PH_SOGO_GNUSTEP_DIR#$ENV{SOGO_GNUSTEP_DIR}#g' ${NGINX_CONF_DEFAULT}

    # php-fpm
    perl -pi -e 's#^(listen *=).*#${1} $ENV{PHP_FASTCGI_SOCKET}#g' ${PHP_FPM_POOL_WWW_CONF}
    perl -pi -e 's#^;(listen.owner *=).*#${1} $ENV{HTTPD_USER}#g' ${PHP_FPM_POOL_WWW_CONF}
    perl -pi -e 's#^;(listen.group *=).*#${1} $ENV{HTTPD_GROUP}#g' ${PHP_FPM_POOL_WWW_CONF}
    perl -pi -e 's#^;(listen.mode *=).*#${1} 0660#g' ${PHP_FPM_POOL_WWW_CONF}
    perl -pi -e 's#^(user.*=).*#${1} $ENV{HTTPD_USER}#g' ${PHP_FPM_POOL_WWW_CONF}
    perl -pi -e 's#^(group.*=).*#${1} $ENV{HTTPD_GROUP}#g' ${PHP_FPM_POOL_WWW_CONF}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        perl -pi -e 's#^(\[www\])$#${1}\nuser = $ENV{HTTPD_USER}\ngroup = $ENV{HTTPD_GROUP}\n#' ${PHP_FPM_POOL_WWW_CONF}
    fi

    # Copy uwsgi config file for iRedAdmin
    if [ X"${DISTRO}" == X'RHEL' ]; then
        cp ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        cp ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's/^(pidfile.*)/#${1}/' ${IREDADMIN_UWSGI_CONF}
        ln -s ${IREDADMIN_UWSGI_CONF} /etc/uwsgi/apps-enabled/iredadmin.ini
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        mkdir -p /var/log/nginx >> ${INSTALL_LOG} 2>&1

        mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        cp -f ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}

        perl -pi -e 's/^(plugins.*)/#${1}/' ${IREDADMIN_UWSGI_CONF}

        service_control enable 'nginx_enable' 'YES'
        service_control enable 'php_fpm_enable' 'YES'
        service_control enable 'uwsgi_enable' 'YES'
        service_control enable 'uwsgi_profiles' 'iredadmin'
        service_control enable 'uwsgi_iredadmin_flags' "--ini ${IREDADMIN_UWSGI_CONF}"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable unchrooted Nginx
        echo 'nginx_flags="-u"' >> ${RC_CONF_LOCAL}

        # Disable chroot in php-fpm
        perl -pi -e 's#^(chroot *=.*)#;${1}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#^(chdir *=.*)#;${1}#g' ${PHP_FPM_POOL_WWW_CONF}

        mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        cp ${SAMPLE_DIR}/nginx/uwsgi_iredadmin.ini ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#^(uid).*#${1} = $ENV{HTTPD_USER}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's#^(gid).*#${1} = $ENV{HTTPD_GROUP}#g' ${IREDADMIN_UWSGI_CONF}
        perl -pi -e 's/^(plugins.*)/#${1}/g' ${IREDADMIN_UWSGI_CONF}

        # Start uWSGI
        cp ${SAMPLE_DIR}/openbsd/rc.d/uwsgi ${DIR_RC_SCRIPTS}
        chmod +x ${DIR_RC_SCRIPTS}/uwsgi
        echo "uwsgi_flags='--ini ${IREDADMIN_UWSGI_CONF} --daemonize ${IREDADMIN_UWSGI_LOGFILE}'" >> ${RC_CONF_LOCAL}
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
        - ${NGINX_CONF_DEFAULT}
    * Directories:
        - ${NGINX_CONF_ROOT}
        - ${HTTPD_DOCUMENTROOT}
    * See also:
        - ${HTTPD_DOCUMENTROOT}/index.html

php-fpm:
    * Configuration files:
        - ${PHP_FPM_POOL_WWW_CONF}
    * Socket: ${PHP_FASTCGI_SOCKET}

uWSGI:
    * Configuration files:
        - ${UWSGI_CONF_DIR}
    * Socket for iRedAdmin: ${UWSGI_SOCKET_IREDADMIN}
EOF

    echo 'export status_nginx_config="DONE"' >> ${STATUS_FILE}
}
