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

    # Add alias for Apache daemon user
    add_postfix_alias ${HTTPD_USER} ${SYS_ROOT_USER}
}

web_server_config()
{
    if [ X"${USE_APACHE}" == X'YES' ]; then
        . ${FUNCTIONS_DIR}/apache_php.sh
        check_status_before_run apache_php_config
    fi

    if [ X"${USE_NGINX}" == X'YES' ]; then
        . ${FUNCTIONS_DIR}/nginx.sh
        check_status_before_run nginx_config
    fi

    check_status_before_run web_server_extra
}
