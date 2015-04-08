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

web_server_extra()
{
    # Create robots.txt.
    backup_file ${HTTPD_DOCUMENTROOT}/robots.txt
    cat >> ${HTTPD_DOCUMENTROOT}/robots.txt <<EOF
User-agent: *
Disallow: /
EOF

    # Redirect home page to webmail by default
    backup_file ${HTTPD_DOCUMENTROOT}/index.html
    cat > ${HTTPD_DOCUMENTROOT}/index.html <<EOF
<html>
    <head>
        <meta HTTP-EQUIV="REFRESH" content="0; url=/mail/">
    </head>
</html>
EOF

    # Add alias for Apache daemon user
    add_postfix_alias ${HTTPD_USER} ${SYS_ROOT_USER}

    echo 'export status_web_server_extra="DONE"' >> ${STATUS_FILE}
}

web_server_config()
{
    # Create required directories
    [ -d ${HTTPD_SERVERROOT} ] || mkdir -p ${HTTPD_SERVERROOT} >> ${INSTALL_LOG} 2>&1
    [ -d ${HTTPD_DOCUMENTROOT} ] || mkdir -p ${HTTPD_DOCUMENTROOT} >> ${INSTALL_LOG} 2>&1

    if [ X"${USE_APACHE}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # The new built-in httpd daemon (Not Apache-1.3) is not supported.
            :
        else
            . ${FUNCTIONS_DIR}/apache.sh
            check_status_before_run apache_config
        fi
    fi

    if [ X"${USE_NGINX}" == X'YES' ]; then
        . ${FUNCTIONS_DIR}/nginx.sh
        check_status_before_run nginx_config
    fi

    . ${FUNCTIONS_DIR}/php.sh
    check_status_before_run php_config

    check_status_before_run web_server_extra

    echo 'export status_web_server_config="DONE"' >> ${STATUS_FILE}
}
