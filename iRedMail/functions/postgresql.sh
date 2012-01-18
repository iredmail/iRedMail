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
    ECHO_INFO "Configure PostgreSQL database server." 

    # FreeBSD: Start pgsql when system start up.
    # Warning: We must have 'postgresql_enable=YES' before start/stop mysql daemon.
    [ X"${DISTRO}" == X"FREEBSD" ] && cat >> /etc/rc.conf <<EOF
# Start PostgreSQL server.
postgresql_enable="YES"
EOF

    backup_file ${PGSQL_CONF_PG_HBA} ${PGSQL_CONF_POSTGRESQL}

    #ECHO_DEBUG "Force all users to connect PGSQL server with password."
    #perl -pi -e 's#^(local.*)peer#${1}md5#' ${PGSQL_CONF_PG_HBA}

    #ECHO_DEBUG "Listen on only localhost"
    #perl -pi -e 's/^#(listen_addresses)(.*)/${1} = "localhost"/' ${PGSQL_CONF_POSTGRESQL}

    ECHO_DEBUG "Copy iRedMail SSL cert/key with strict permission."
    # SSL is enabled by default.
    backup_file ${PGSQL_DATA_DIR}/server.{crt,key}
    rm -f ${PGSQL_DATA_DIR}/server.{crt,key} >/dev/null
    cp -f ${SSL_CERT_FILE} ${PGSQL_SSL_CERT} >/dev/null
    cp -f ${SSL_KEY_FILE} ${PGSQL_SSL_KEY} >/dev/null
    chown ${PGSQL_SYS_USER}:${PGSQL_SYS_GROUP} ${PGSQL_SSL_CERT} ${PGSQL_SSL_KEY}
    chmod 0600 ${PGSQL_SSL_CERT} ${PGSQL_SSL_KEY}
    ln -s ${PGSQL_SSL_CERT} ${PGSQL_DATA_DIR}/server.crt >/dev/null
    ln -s ${PGSQL_SSL_KEY} ${PGSQL_DATA_DIR}/server.key >/dev/null

    ECHO_DEBUG "Start PostgreSQL server"
    ${PGSQL_INIT_SCRIPT} restart >/dev/null 2>&1

    ECHO_INFO -n "Sleep 5 seconds for PostgreSQL daemon initialize:"
    for i in 5 4 3 2 1; do
        echo -n " ${i}" && sleep 1
    done
    echo '.'

    ECHO_DEBUG "Setting password for PostgreSQL admin: (${PGSQL_ROOT_USER})."
    su - ${PGSQL_SYS_USER} -c "psql -d template1" >/dev/null <<EOF
ALTER USER ${PGSQL_ROOT_USER} WITH ENCRYPTED PASSWORD '${PGSQL_ROOT_PASSWD}';
EOF

    ECHO_DEBUG "Generate ${PGSQL_DOT_PGPASS}."
    cat > ${PGSQL_DOT_PGPASS} <<EOF
localhost:*:*:${PGSQL_ROOT_USER}:${PGSQL_ROOT_PASSWD}
EOF

    chown ${PGSQL_SYS_USER}:${PGSQL_SYS_GROUP} ${PGSQL_DOT_PGPASS}
    chmod 0600 ${PGSQL_DOT_PGPASS} >/dev/null

    cat >> ${TIP_FILE} <<EOF
PostgreSQL:
    * Bind account (read-only):
        - Name: ${VMAIL_DB_BIND_USER}, Password: ${VMAIL_DB_BIND_PASSSWD}
    * Vmail admin account (read-write):
        - Name: ${VMAIL_DB_ADMIN_USER}, Password: ${VMAIL_DB_ADMIN_PASSWD}
    * Database stored in: ${PGSQL_DATA_DIR}
    * RC script: ${PGSQL_INIT_SCRIPT}
    * Log file: /var/log/postgresql/
    * See also:
        - ${PGSQL_INIT_SQL}
        - ${PGSQL_DOT_PGPASS}

EOF

    echo 'export status_pgsql_initialize="DONE"' >> ${STATUS_FILE}
}

pgsql_import_vmail_users()
{
    export DOMAIN_ADMIN_PASSWD="$(openssl passwd -1 ${DOMAIN_ADMIN_PASSWD})"
    export FIRST_USER_PASSWD="$(openssl passwd -1 ${FIRST_USER_PASSWD})"

    # Generate SQL.
    # Modify default SQL template, set storagebasedirectory.
    perl -pi -e 's#(.*storagebasedirectory.*DEFAULT).*#${1} "$ENV{STORAGE_BASE_DIR}",#' ${PGSQL_VMAIL_STRUCTURE_SAMPLE}
    perl -pi -e 's#(.*storagenode.*DEFAULT).*#${1} "$ENV{STORAGE_NODE}",#' ${PGSQL_VMAIL_STRUCTURE_SAMPLE}

    ECHO_DEBUG "Generating SQL template for postfix virtual hosts: ${PGSQL_INIT_SQL_SAMPLE}."
    cat > ${PGSQL_INIT_SQL_SAMPLE} <<EOF
-- Create database to store mail accounts
CREATE DATABASE ${VMAIL_DB} WITH TEMPLATE template0 ENCODING 'UTF8';
\c vmail;
\i ${PGSQL_VMAIL_STRUCTURE_SAMPLE}

-- Crete roles:
-- + vmail: read-only
-- + vmailadmin: read, write
CREATE ROLE ${VMAIL_DB_BIND_USER} WITH ENCRYPTED PASSWORD '${VMAIL_DB_BIND_PASSSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Set correct privilege for ROLE: vmail
GRANT SELECT ON admin,alias,alias_domain,domain,domain_admins,mailbox,mailbox,recipient_bcc_domain,recipient_bcc_user,sender_bcc_domain,sender_bcc_user TO ${VMAIL_DB_BIND_USER};
GRANT SELECT,UPDATE,INSERT,DELETE ON share_folder,used_quota TO ${VMAIL_DB_BIND_USER};

-- Set correct privilege for ROLE: vmailadmin
GRANT SELECT,UPDATE,INSERT ON admin,alias,alias_domain,domain,domain_admins,mailbox,mailbox,recipient_bcc_domain,recipient_bcc_user,sender_bcc_domain,sender_bcc_user,share_folder,used_quota TO ${VMAIL_DB_ADMIN_USER};

-- Add first mail domain
-- Add first domain admin
-- Assign mail domain to admin
-- Add first mail user
EOF

    ECHO_DEBUG "Import postfix virtual hosts/users: ${PGSQL_INIT_SQL_SAMPLE}."
    su - ${PGSQL_SYS_USER} -c "psql -f ${PGSQL_INIT_SQL_SAMPLE}" >/dev/null

    cat >> ${TIP_FILE} <<EOF
Virtual Users:
    - ${PGSQL_INIT_SQL_SAMPLE}
    - ${PGSQL_VMAIL_STRUCTURE_SAMPLE}

EOF

    echo 'export status_pgsql_import_vmail_users="DONE"' >> ${STATUS_FILE}
}
