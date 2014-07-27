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

# Please refer another file: functions/backend.sh

# -------------------------------------------------------
# -------------------- MySQL ----------------------------
# -------------------------------------------------------
mysql_generate_defauts_file_root()
{
    ECHO_DEBUG "Generate temporary defauts file for MySQL client option --defaults-file: ${MYSQL_DEFAULTS_FILE_ROOT}."
    cat >> ${MYSQL_DEFAULTS_FILE_ROOT} <<EOF
[client]
host=${MYSQL_SERVER}
port=${MYSQL_SERVER_PORT}
user=${MYSQL_ROOT_USER}
password=${MYSQL_ROOT_PASSWD}
EOF
}

mysql_initialize()
{
    ECHO_DEBUG "Starting MySQL."

    # Initial MySQL database first
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        /usr/local/bin/mysql_install_db &>/dev/null
    fi

    # FreeBSD: Start mysql when system start up.
    # Warning: We must have 'mysql_enable=YES' before start/stop mysql daemon.
    freebsd_enable_service_in_rc_conf 'mysql_enable' 'YES'

    ECHO_DEBUG "Copy sample/my.cnf to ${MYSQL_MY_CNF}."
    if [ ! -f ${MYSQL_MY_CNF} ]; then
        cp ${SAMPLE_DIR}/my.cnf ${MYSQL_MY_CNF} &>/dev/null
    fi

    # Disable 'skip-networking' in my.cnf.
    perl -pi -e 's#^(skip-networking.*)#${1}#' ${MYSQL_MY_CNF} &>/dev/null

    # Enable innodb_file_per_table by default.
    grep '^innodb_file_per_table' ${MYSQL_MY_CNF} &>/dev/null
    if [ X"$?" != X'0' ]; then
        perl -pi -e 's#^(\[mysqld\])#${1}\ninnodb_file_per_table#' ${MYSQL_MY_CNF}
    fi

    service_control mariadb restart &>/dev/null

    ECHO_DEBUG "Sleep 5 seconds for MySQL daemon initialize ..."
    sleep 5

    if [ X"${LOCAL_ADDRESS}" == X'127.0.0.1' ]; then
        # Try to access without password, set a password if it's empty.
        mysql -u${MYSQL_ROOT_USER} -e "show databases" &>/dev/null
        if [ X"$?" == X'0' ]; then
            ECHO_DEBUG "Setting password for MySQL admin (${MYSQL_ROOT_USER})."
            mysqladmin --user=root password "${MYSQL_ROOT_PASSWD}"
        fi
    else
        ECHO_DEBUG "Grant access privilege to ${MYSQL_ROOT_USER}@${LOCAL_ADDRESS} ..."
        mysql -u${MYSQL_ROOT_USER} <<EOF
USE mysql;
-- Allow access from MYSQL_GRANT_HOST with password
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWD}';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_ROOT_PASSWD}';
-- Allow GRANT privilege
UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='${MYSQL_GRANT_HOST}';
UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='127.0.0.1';
-- Set root password
UPDATE user SET Password = PASSWORD('${MYSQL_ROOT_PASSWD}') WHERE User = 'root';
EOF
    fi

    echo '' > ${MYSQL_INIT_SQL}

    cat >> ${MYSQL_INIT_SQL} <<EOF
-- Delete anonymouse user.
USE mysql;

DELETE FROM user WHERE User='';
DELETE FROM db WHERE User='';
EOF

    ECHO_DEBUG "Initialize MySQL database."
    ${MYSQL_CLIENT_ROOT} <<EOF
SOURCE ${MYSQL_INIT_SQL};
FLUSH PRIVILEGES;
EOF

    cat >> ${TIP_FILE} <<EOF
MySQL:
    * Root user: ${MYSQL_ROOT_USER}, Password: ${MYSQL_ROOT_PASSWD}
    * Bind account (read-only):
        - Username: ${VMAIL_DB_BIND_USER}, Password: ${VMAIL_DB_BIND_PASSWD}
    * Vmail admin account (read-write):
        - Username: ${VMAIL_DB_ADMIN_USER}, Password: ${VMAIL_DB_ADMIN_PASSWD}
    * RC script: ${MYSQLD_RC_SCRIPT}
    * See also:
        - ${MYSQL_INIT_SQL}

EOF

    echo 'export status_mysql_initialize="DONE"' >> ${STATUS_FILE}
}

# It's used only when backend is MySQL.
mysql_import_vmail_users()
{
    ECHO_DEBUG "Generating SQL template for postfix virtual hosts: ${MYSQL_VMAIL_SQL}."
    export DOMAIN_ADMIN_PASSWD="$(gen_md5_passwd ${DOMAIN_ADMIN_PASSWD})"
    export FIRST_USER_PASSWD="$(gen_md5_passwd ${FIRST_USER_PASSWD})"

    # Generate SQL.
    # Modify default SQL template, set storagebasedirectory.
    perl -pi -e 's#(.*storagebasedirectory.*DEFAULT).*#${1} "$ENV{STORAGE_BASE_DIR}",#' ${MYSQL_VMAIL_STRUCTURE_SAMPLE}
    perl -pi -e 's#(.*storagenode.*DEFAULT).*#${1} "$ENV{STORAGE_NODE}",#' ${MYSQL_VMAIL_STRUCTURE_SAMPLE}

    # Mailbox format is 'Maildir/' by default.
    cat >> ${MYSQL_VMAIL_SQL} <<EOF
/* Create database for virtual hosts. */
CREATE DATABASE IF NOT EXISTS ${VMAIL_DB} CHARACTER SET utf8;

/* Permissions. */
GRANT SELECT ON ${VMAIL_DB}.* TO "${VMAIL_DB_BIND_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${VMAIL_DB_BIND_PASSWD}";
GRANT SELECT,INSERT,DELETE,UPDATE ON ${VMAIL_DB}.* TO "${VMAIL_DB_ADMIN_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${VMAIL_DB_ADMIN_PASSWD}";

/* Initialize the database. */
USE ${VMAIL_DB};
SOURCE ${MYSQL_VMAIL_STRUCTURE_SAMPLE};

/* Add your first domain. */
INSERT INTO domain (domain,transport,created) VALUES ("${FIRST_DOMAIN}", "${TRANSPORT}", NOW());

/* Add your first normal user. */
INSERT INTO mailbox (username,password,name,maildir,quota,domain,isadmin,isglobaladmin,created) VALUES ("${FIRST_USER}@${FIRST_DOMAIN}","${FIRST_USER_PASSWD}","${FIRST_USER}","${FIRST_USER_MAILDIR_HASH_PART}",100, "${FIRST_DOMAIN}", 1, 1, NOW());
INSERT INTO alias (address,goto,domain,created) VALUES ("${FIRST_USER}@${FIRST_DOMAIN}", "${FIRST_USER}@${FIRST_DOMAIN}", "${FIRST_DOMAIN}", NOW());

/* Mark first mail user as global admin */
INSERT INTO domain_admins (username,domain,created) VALUES ("${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}","ALL", NOW());

EOF

    ECHO_DEBUG "Import postfix virtual hosts/users: ${MYSQL_VMAIL_SQL}."
    ${MYSQL_CLIENT_ROOT} <<EOF
SOURCE ${MYSQL_VMAIL_SQL};
FLUSH PRIVILEGES;
EOF

    cat >> ${TIP_FILE} <<EOF
Virtual Users:
    - ${MYSQL_VMAIL_STRUCTURE_SAMPLE}
    - ${MYSQL_VMAIL_SQL}

EOF

    echo 'export status_mysql_import_vmail_users="DONE"' >> ${STATUS_FILE}
}
