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
# -------------------- PostgreSQL -----------------------
# -------------------------------------------------------

# NOTE: iRedMail will force all clients to send encrypted password
#       after configuration completed and SQL data imported.
# Reference: functions/cleanup.sh, function cleanup_pgsql_force_password().

pgsql_initialize()
{
    ECHO_INFO "Configure PostgreSQL database server." 

    # Init db
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ${PGSQL_RC_SCRIPT} initdb &>/dev/null
    elif [ X"${DISTRO}" == X'SUSE' ]; then
        su - ${PGSQL_SYS_USER} -c "initdb -D ${PGSQL_DATA_DIR} -U ${PGSQL_SYS_USER} -A trust" >/dev/null
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        # FreeBSD: Start pgsql when system start up.
        # Warning: We must have 'postgresql_enable=YES' before start/stop pgsql daemon.
        freebsd_enable_service_in_rc_conf 'postgresql_enable' 'YES'

        ${PGSQL_RC_SCRIPT} initdb &>/dev/null
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        mkdir -p ${PGSQL_DATA_DIR} 2>/dev/null
        chown ${PGSQL_SYS_USER}:${PGSQL_SYS_GROUP} ${PGSQL_DATA_DIR}
        su - ${PGSQL_SYS_USER} -c "initdb -D ${PGSQL_DATA_DIR} -U ${PGSQL_SYS_USER} -A trust" >/dev/null
    fi

    backup_file ${PGSQL_CONF_PG_HBA} ${PGSQL_CONF_POSTGRESQL}

    ECHO_DEBUG "Listen on address: ${LOCAL_ADDRESS}"
    if [ X"${LOCAL_ADDRESS}" == X'127.0.0.1' ]; then
        perl -pi -e 's#.*(listen_addresses.=.)(.).*#${1}${2}localhost${2}#' ${PGSQL_CONF_POSTGRESQL}
    else
        perl -pi -e 's#.*(listen_addresses.=.)(.).*#${1}${2}$ENV{LOCAL_ADDRESS}${2}#' ${PGSQL_CONF_POSTGRESQL}

        # Allow remote access
        echo "host   all all ${LOCAL_ADDRESS}/32 md5" >> ${PGSQL_CONF_PG_HBA}
    fi

    ECHO_DEBUG "Set client_min_messages to ERROR."
    perl -pi -e 's#.*(client_min_messages =).*#${1} error#' ${PGSQL_CONF_POSTGRESQL}

    ECHO_DEBUG "Copy iRedMail SSL cert/key with strict permission."
    backup_file ${PGSQL_DATA_DIR}/server.{crt,key}
    rm -f ${PGSQL_DATA_DIR}/server.{crt,key} >/dev/null
    cp -f ${SSL_CERT_FILE} ${PGSQL_SSL_CERT} >/dev/null
    cp -f ${SSL_KEY_FILE} ${PGSQL_SSL_KEY} >/dev/null
    chown ${PGSQL_SYS_USER}:${PGSQL_SYS_GROUP} ${PGSQL_SSL_CERT} ${PGSQL_SSL_KEY}
    chmod 0600 ${PGSQL_SSL_CERT} ${PGSQL_SSL_KEY}
    ln -s ${PGSQL_SSL_CERT} ${PGSQL_DATA_DIR}/server.crt >/dev/null
    ln -s ${PGSQL_SSL_KEY} ${PGSQL_DATA_DIR}/server.key >/dev/null

    ECHO_DEBUG "Copy iRedMail SSL cert/key with strict permission."
    # SSL is enabled by default on Ubuntu.
    [ X"${DISTRO}" == X'FREEBSD' ] && \
        perl -pi -e 's/^#(ssl.=.)off(.*)/${1}on${2}/' ${PGSQL_CONF_POSTGRESQL}

    ECHO_DEBUG "Start PostgreSQL server"
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        ${PGSQL_RC_SCRIPT} start  #&>/dev/null
    else
        ${PGSQL_RC_SCRIPT} restart &>/dev/null
    fi

    ECHO_DEBUG "Sleep 5 seconds for PostgreSQL daemon initialize ..."
    sleep 5

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
    * Admin user: ${PGSQL_ROOT_USER}, Password: ${PGSQL_ROOT_PASSWD}
    * Bind account (read-only):
        - Name: ${VMAIL_DB_BIND_USER}, Password: ${VMAIL_DB_BIND_PASSWD}
    * Vmail admin account (read-write):
        - Name: ${VMAIL_DB_ADMIN_USER}, Password: ${VMAIL_DB_ADMIN_PASSWD}
    * Database stored in: ${PGSQL_DATA_DIR}
    * RC script: ${PGSQL_RC_SCRIPT}
    * Log file: /var/log/postgresql/
    * See also:
        - ${PGSQL_INIT_SQL_SAMPLE}
        - ${PGSQL_DOT_PGPASS}

EOF

    echo 'export status_pgsql_initialize="DONE"' >> ${STATUS_FILE}
}

pgsql_import_vmail_users()
{
    export DOMAIN_ADMIN_PASSWD="$(gen_md5_passwd ${DOMAIN_ADMIN_PASSWD})"
    export FIRST_USER_PASSWD="$(gen_md5_passwd ${FIRST_USER_PASSWD})"

    # Generate SQL.
    # Modify default SQL template, set storagebasedirectory, storagenode.
    perl -pi -e 's#(.*storagebasedirectory.*DEFAULT..)(.*)#${1}$ENV{STORAGE_BASE_DIR}${2}#' ${PGSQL_VMAIL_STRUCTURE_SAMPLE}
    perl -pi -e 's#(.*storagenode.*DEFAULT..)(.*)#${1}$ENV{STORAGE_NODE}${2}#' ${PGSQL_VMAIL_STRUCTURE_SAMPLE}

    ECHO_DEBUG "Generating SQL template for postfix virtual hosts: ${PGSQL_INIT_SQL_SAMPLE}."

    cat > ${PGSQL_INIT_SQL_SAMPLE} <<EOF
-- Create database to store mail accounts
CREATE DATABASE ${VMAIL_DB} WITH TEMPLATE template0 ENCODING 'UTF8';
\c ${VMAIL_DB};
EOF

    # PostgreSQL 8.x
    # - Create language plpgsql
    # - Create extension dblink via importing SQL file
    if [ X"${DISTRO}" == X'RHEL' ]; then
        cat >> ${PGSQL_INIT_SQL_SAMPLE} <<EOF
CREATE LANGUAGE plpgsql;
\i /usr/share/pgsql/contrib/dblink.sql;
EOF
    fi

    cat >> ${PGSQL_INIT_SQL_SAMPLE} <<EOF
\i ${PGSQL_DATA_DIR}/vmail.sql;
EOF

    # PostgreSQL 9.x can create extension directly
    if [ X"${DISTRO}" != X'RHEL' ]; then
        cat >> ${PGSQL_INIT_SQL_SAMPLE} <<EOF
-- Create extension dblink.
-- Used to change password through Roundcube webmail
CREATE EXTENSION dblink;
EOF
    fi

    cat >> ${PGSQL_INIT_SQL_SAMPLE} <<EOF
-- Crete roles:
-- + vmail: read-only
-- + vmailadmin: read, write
CREATE USER ${VMAIL_DB_BIND_USER} WITH ENCRYPTED PASSWORD '${VMAIL_DB_BIND_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE USER ${VMAIL_DB_ADMIN_USER} WITH ENCRYPTED PASSWORD '${VMAIL_DB_ADMIN_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Set correct privilege for ROLE: vmail
GRANT SELECT ON admin,alias,alias_domain,domain,domain_admins,mailbox,mailbox,recipient_bcc_domain,recipient_bcc_user,sender_bcc_domain,sender_bcc_user TO ${VMAIL_DB_BIND_USER};
GRANT SELECT,UPDATE,INSERT,DELETE ON used_quota TO ${VMAIL_DB_BIND_USER};

-- Set correct privilege for ROLE: vmailadmin
GRANT SELECT,UPDATE,INSERT,DELETE ON admin,alias,alias_domain,domain,domain_admins,mailbox,mailbox,recipient_bcc_domain,recipient_bcc_user,sender_bcc_domain,sender_bcc_user,share_folder,anyone_shares,used_quota TO ${VMAIL_DB_ADMIN_USER};
GRANT SELECT,UPDATE,INSERT,DELETE ON deleted_mailboxes,deleted_mailboxes_id_seq TO ${VMAIL_DB_ADMIN_USER};

-- Add first mail domain
INSERT INTO domain (domain,transport,created) VALUES ('${FIRST_DOMAIN}', '${TRANSPORT}', NOW());

-- Add first mail user
INSERT INTO mailbox (username,password,name,maildir,quota,domain,isadmin,isglobaladmin,created) VALUES ('${FIRST_USER}@${FIRST_DOMAIN}','${FIRST_USER_PASSWD}','${FIRST_USER}','$( hash_domain ${FIRST_DOMAIN})/$( hash_maildir ${FIRST_USER} )',100, '${FIRST_DOMAIN}', 1, 1, NOW());
INSERT INTO alias (address,goto,domain,created) VALUES ('${FIRST_USER}@${FIRST_DOMAIN}', '${FIRST_USER}@${FIRST_DOMAIN}', '${FIRST_DOMAIN}', NOW());

-- Mark first mail user as global admin
INSERT INTO domain_admins (username,domain,created) VALUES ('${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}','ALL', NOW());
EOF

    ECHO_DEBUG "Import postfix virtual hosts/users: ${PGSQL_INIT_SQL_SAMPLE}."
    cp -f ${PGSQL_VMAIL_STRUCTURE_SAMPLE} ${PGSQL_DATA_DIR}/vmail.sql >/dev/null
    cp -f ${PGSQL_INIT_SQL_SAMPLE} ${PGSQL_DATA_DIR}/init.sql >/dev/null
    chmod 0777 ${PGSQL_DATA_DIR}/{vmail,init}.sql >/dev/null
    su - ${PGSQL_SYS_USER} -c "psql -d template1 -f ${PGSQL_DATA_DIR}/init.sql" >/dev/null
    rm -f ${PGSQL_DATA_DIR}/{vmail,init}.sql >/dev/null

    cat >> ${TIP_FILE} <<EOF
Virtual Users:
    - ${PGSQL_VMAIL_STRUCTURE_SAMPLE}
    - ${PGSQL_INIT_SQL_SAMPLE}

EOF

    echo 'export status_pgsql_import_vmail_users="DONE"' >> ${STATUS_FILE}
}
