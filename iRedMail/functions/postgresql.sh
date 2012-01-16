#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb(at)iredmail.org)

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
# -------------------- PostgreSQL -----------------------
# -------------------------------------------------------
pgsql_initialize()
{
    ECHO_DEBUG "Configure PostgreSQL database server." 

    ECHO_DEBUG "Starting PostgreSQL"

    # FreeBSD: Start pgsql when system start up.
    # Warning: We must have 'postgresql_enable=YES' before start/stop mysql daemon.
    [ X"${DISTRO}" == X"FREEBSD" ] && cat >> /etc/rc.conf <<EOF
# Start PostgreSQL server.
postgresql_enable="YES"
EOF

    ${PGSQL_INIT_SCRIPT} restart >/dev/null 2>&1

    ECHO_DEBUG -n "Sleep 5 seconds for PostgreSQL daemon initialize:"
    for i in 5 4 3 2 1; do
        ECHO_DEBUG -n " ${i}" && sleep 1
    done
    ECHO_DEBUG '.'

    ECHO_DEBUG "Setting password for PostgreSQL admin (${PGSQL_ADMIN_USER})."
    # TODO

    ECHO_DEBUG "Initialize MySQL database."
    # TODO

    # Generate PGSQL_INIT_SQL
    # TODO

    cat >> ${TIP_FILE} <<EOF
PostgreSQL:
    * Bind account (read-only):
        - Name: ${PGSQL_BIND_USER}, Password: ${PGSQL_BIND_PW}
    * Vmail admin account (read-write):
        - Name: ${PGSQL_ADMIN_USER}, Password: ${PGSQL_ADMIN_PW}
    * Database stored in: /var/lib/mysql
    * RC script: ${PGSQL_INIT_SCRIPT}
    * Log file: /var/log/mysqld.log
    * See also:
        - ${PGSQL_INIT_SQL}

EOF

    echo 'export status_pgsql_initialize="DONE"' >> ${STATUS_FILE}
}

pgsql_import_vmail_users()
{
    ECHO_DEBUG "Generating SQL template for postfix virtual hosts: ${PGSQL_VMAIL_SQL}."
    export DOMAIN_ADMIN_PASSWD="$(openssl passwd -1 ${DOMAIN_ADMIN_PASSWD})"
    export FIRST_USER_PASSWD="$(openssl passwd -1 ${FIRST_USER_PASSWD})"

    # Generate SQL.
    # Modify default SQL template, set storagebasedirectory.
    #perl -pi -e 's#(.*storagebasedirectory.*DEFAULT).*#${1} "$ENV{STORAGE_BASE_DIR}",#' ${SAMPLE_SQL}
    #perl -pi -e 's#(.*storagenode.*DEFAULT).*#${1} "$ENV{STORAGE_NODE}",#' ${SAMPLE_SQL}

    # Mailbox format is 'Maildir/' by default.
    # TODO:
    # - Create database to store mail accounts
    # - Set correct privilege for both ROLEs: vmail, vmailadmin
    # - Initialize database
    # - Add first mail domain
    # - Add first domain admin
    # - Assign mail domain to admin
    # - Add first mail user
    cat >> ${PGSQL_VMAIL_SQL} <<EOF
EOF

    ECHO_DEBUG "Import postfix virtual hosts/users: ${PGSQL_VMAIL_SQL}."
    # TODO

    cat >> ${TIP_FILE} <<EOF
Virtual Users:
    - ${PGSQL_VMAIL_SQL}
    - ${PGSQL_VMAIL_STRUCTURE_SAMPLE}

EOF

    echo 'export status_mysql_import_vmail_users="DONE"' >> ${STATUS_FILE}
}
