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


# PHP Setting.
php_config()
{
    ECHO_INFO "Configure PHP."

    backup_file ${APACHE_PHP_INI} ${NGINX_PHP_INI}

    # FreeBSD: Copy sample file.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        cp -f /usr/local/etc/php.ini-production ${APACHE_PHP_INI}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        #if [ X"${WEB_SERVER_USE_APACHE}" == X'YES' ]; then
        #    ln -s /var/www/conf/modules.sample/php-${PHP_VERSION}.conf /var/www/conf/modules/php.conf
        #fi

        # Enable Apache modules
        for i in $(ls -d /etc/php-${PHP_VERSION}.sample/*); do
            ln -sf ${i} /etc/php-${PHP_VERSION}/$(basename $i)
        done
    fi

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
        php5enmod mcrypt >> ${INSTALL_LOG} 2>&1

        # `intl` is required by Roundcube.
        php5enmod intl >> ${INSTALL_LOG} 2>&1
    fi

    # Copy to ${NGINX_PHP_INI}
    if [ X"${APACHE_PHP_INI}" != X"${NGINX_PHP_INI}" ]; then
        cp -f ${APACHE_PHP_INI} ${NGINX_PHP_INI}
    fi

    cat >> ${TIP_FILE} <<EOF
PHP:
    * PHP config file for Apache: ${APACHE_PHP_INI}
    * PHP config file for Nginx: ${NGINX_PHP_INI}
    * Disabled functions: ${PHP_DISABLED_FUNCTIONS}

EOF

    echo 'export status_php_config="DONE"' >> ${STATUS_FILE}
}
