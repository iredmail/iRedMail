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
# ------------- Install and config backend. -------------
# -------------------------------------------------------
backend_install()
{
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        export SQL_SERVER_ADDRESS="${MYSQL_SERVER_ADDRESS}"
        export SQL_SERVER_PORT="${MYSQL_SERVER_PORT}"
        export SQL_ROOT_USER="${MYSQL_ROOT_USER}"
        export SQL_ROOT_PASSWD="${MYSQL_ROOT_PASSWD}"
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        export SQL_SERVER_ADDRESS="${PGSQL_SERVER_ADDRESS}"
        export SQL_SERVER_PORT="${PGSQL_SERVER_PORT}"
        export SQL_ROOT_USER="${PGSQL_ROOT_USER}"
        export SQL_ROOT_PASSWD="${PGSQL_ROOT_PASSWD}"
    fi

    # Check whether remote MySQL server is an IPv6 address.
    SQL_SERVER_ADDRESS_IS_IPV6='NO'
    if echo ${SQL_SERVER_ADDRESS} | grep ':' &>/dev/null; then
        SQL_SERVER_ADDRESS_IS_IPV6='YES'
    fi

    # Hashed admin password. It requies Python.
    export DOMAIN_ADMIN_PASSWD_HASH="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${DOMAIN_ADMIN_PASSWD_PLAIN})"

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # Install, config and initialize LDAP server
        check_status_before_run ldap_server_config
        check_status_before_run ldap_server_cron_backup

        # Setup MySQL database server.
        if [ X"${BACKEND_ORIG}" == X'MARIADB' ]; then
            ECHO_INFO "Configure MariaDB database server."
        else
            ECHO_INFO "Configure MySQL database server."
        fi
        check_status_before_run mysql_initialize_db
        check_status_before_run mysql_generate_defaults_file_root
        check_status_before_run mysql_remove_insecure_data
        check_status_before_run mysql_cron_backup

    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        check_status_before_run mysql_setup

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        check_status_before_run pgsql_setup
    fi
}
