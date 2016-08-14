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

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # Install, config and initialize LDAP server
        check_status_before_run ldap_server_config
        check_status_before_run ldap_server_cron_backup

        # Initialize MySQL database server.
        check_status_before_run mysql_generate_defauts_file_root
        check_status_before_run mysql_initialize_db
        check_status_before_run mysql_cron_backup

    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        check_status_before_run mysql_generate_defauts_file_root

        if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
            check_status_before_run mysql_initialize_db
        fi

        if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
            check_status_before_run mysql_import_vmail_users
        fi

        check_status_before_run mysql_create_sql_table_used_quota
        check_status_before_run mysql_cron_backup
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        check_status_before_run pgsql_initialize
        check_status_before_run pgsql_import_vmail_users
        check_status_before_run pgsql_cron_backup
    fi
}
