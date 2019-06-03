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

    backup_file ${PHP_INI}

    # FreeBSD: Copy sample file.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        cp -f /usr/local/etc/php.ini-production ${PHP_INI}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable PHP modules
        for i in $(ls -d /etc/php-${OB_PHP_VERSION}.sample/*); do
            ln -sf ${i} /etc/php-${OB_PHP_VERSION}/$(basename $i)
        done
    fi

    ECHO_DEBUG "Hide PHP info from remote users requests: ${PHP_INI}."
    perl -pi -e 's#^(expose_php.*=).*#${1} Off;#' ${PHP_INI}

    ECHO_DEBUG "Increase 'memory_limit' to 256M: ${PHP_INI}."
    perl -pi -e 's#^(memory_limit.*=).*#${1} 256M;#' ${PHP_INI}

    ECHO_DEBUG "Increase 'upload_max_filesize', 'post_max_size' to 10/12M: ${PHP_INI}."
    perl -pi -e 's/^(upload_max_filesize.*=).*/${1} 10M;/' ${PHP_INI}
    perl -pi -e 's/^(post_max_size.*=).*/${1} 12M;/' ${PHP_INI}

    ECHO_DEBUG "Disable php extension: suhosin. ${PHP_INI}."
    perl -pi -e 's/^(suhosin.session.encrypt.*=).*/${1} Off;/' ${PHP_INI}
    perl -pi -e 's/^;(suhosin.session.encrypt.*=).*/${1} Off;/' ${PHP_INI}

    #perl -pi -e 's/^(allow_url_fopen.*=).*/${1} On/' ${PHP_INI}

    # Add setting `disable_functions`
    perl -pi -e 's#^;(disable_functions.*)#${1}#g' ${PHP_INI}
    perl -pi -e 's#^(disable_functions).*#${1} = $ENV{PHP_DISABLE_FUNCTIONS}#g' ${PHP_INI}

    # Create directory used to store session (session.save_path)
    perl -pi -e 's#^;(session.save_path).*#${1}#g' ${PHP_INI}
    perl -pi -e 's#^(session.save_path).*#session.save_path = "$ENV{PHP_SESSION_SAVE_PATH}"#g' ${PHP_INI}
    # Set correct owner and permission
    [ -d ${PHP_SESSION_SAVE_PATH} ] || mkdir -p ${PHP_SESSION_SAVE_PATH} >> ${INSTALL_LOG} 2>&1
    chown ${SYS_USER_ROOT}:${HTTPD_GROUP} ${PHP_SESSION_SAVE_PATH}
    chmod 0770 ${PHP_SESSION_SAVE_PATH}

    # Set date.timezone. Required by PHP-5.3.
    grep '^date.timezone' ${PHP_INI} >/dev/null
    if [ X"$?" == X"0" ]; then
        perl -pi -e 's#^(date.timezone).*#${1} = GMT#' ${PHP_INI}
    else
        perl -pi -e 's#^;(date.timezone).*#${1} = GMT#' ${PHP_INI}
    fi

    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        # Enable mcrypt
        ${PHPENMOD_BIN} mcrypt >> ${INSTALL_LOG} 2>&1

        # `intl` is required by Roundcube.
        ${PHPENMOD_BIN} intl >> ${INSTALL_LOG} 2>&1
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ECHO_DEBUG "Disable suhosin.session.encrypt -> Off."
        echo 'suhosin.session.encrypt = Off' >> ${PHP_INI}
    fi

    cat >> ${TIP_FILE} <<EOF
PHP:
    * PHP config file for Nginx: ${NGINX_PHP_INI}
    * Disabled functions: ${PHP_DISABLE_FUNCTIONS}

EOF

    echo 'export status_php_config="DONE"' >> ${STATUS_FILE}
}
