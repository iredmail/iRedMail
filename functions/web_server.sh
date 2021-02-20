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
    [[ ! -r ${HTTPD_DOCUMENTROOT}/robots.txt ]] && \
      printf '%s\n' 'User-agent: *' 'Disallow: /' >> "${HTTPD_DOCUMENTROOT}"/robots.txt

    # Redirect home page to webmail by default
    if [[ ! -r ${HTTPD_DOCUMENTROOT}/index.html ]]; then
        local HTTPD_DOCUMENTROOT_INDEX="${HTTPD_DOCUMENTROOT}"/index.html
        if [[ "${USE_ROUNDCUBE}" == "YES" ]]; then
            echo '<html><head><meta HTTP-EQUIV="REFRESH" content="0; url=/mail/"></head></html>' > "$HTTPD_DOCUMENTROOT_INDEX"
        elif [[ "${USE_SOGO}" == "YES" ]]; then
            echo '<html><head><meta HTTP-EQUIV="REFRESH" content="0; url=/SOGo/"></head></html>' > "$HTTPD_DOCUMENTROOT_INDEX"
        fi
    fi

    # Add alias for web server daemon user
    add_postfix_alias "${HTTPD_USER}" "${SYS_USER_ROOT}"

    echo 'export status_web_server_extra="DONE"' >> "${STATUS_FILE}"
}

web_server_config()
{
    # Create required directories
    [[ -d "${HTTPD_SERVERROOT}" ]] || mkdir -p "${HTTPD_SERVERROOT}" >> "${INSTALL_LOG}" 2>&1
    [[ -d "${HTTPD_DOCUMENTROOT}" ]] || mkdir -p "${HTTPD_DOCUMENTROOT}" >> "${INSTALL_LOG}" 2>&1

    if [[ "${WEB_SERVER}" == "NGINX" ]]; then
        # shellcheck source=nginx.sh
        . "${FUNCTIONS_DIR}"/nginx.sh
        check_status_before_run nginx_config
        check_status_before_run web_server_extra
    fi

    if [[ "${IREDMAIL_USE_PHP}" == "YES" ]]; then
        # shellcheck source=php.sh
        . "${FUNCTIONS_DIR}"/php.sh
        check_status_before_run php_config
    fi

    echo 'export status_web_server_config="DONE"' >> "${STATUS_FILE}"
}
