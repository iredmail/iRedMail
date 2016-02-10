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
    if [ X"${BACKEND_ORIG}" == X'MARIADB' ]; then
        ECHO_INFO "Configure MariaDB database server."
    else
        ECHO_INFO "Configure MySQL database server."
    fi

    ECHO_DEBUG "Generate temporary defauts file for MySQL client option --defaults-file: ${MYSQL_DEFAULTS_FILE_ROOT}."
    cat >> ${MYSQL_DEFAULTS_FILE_ROOT} <<EOF
[client]
user=${MYSQL_ROOT_USER}
password="${MYSQL_ROOT_PASSWD}"
EOF

    if [ X"${LOCAL_ADDRESS}" != X'127.0.0.1' -o X"${MYSQL_SERVER_ADDRESS}" != X'127.0.0.1' ]; then
        cat >> ${MYSQL_DEFAULTS_FILE_ROOT} <<EOF
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
EOF
    fi
}

mysql_initialize()
{
    ECHO_DEBUG "Initialize MySQL server."

    backup_file ${MYSQL_MY_CNF}

    ECHO_DEBUG "Make sure MySQL server binds to local address: ${SQL_SERVER_ADDRESS}."
    if [ -f ${MYSQL_MY_CNF} ]; then
        # comment out 'bind-address' then reset
        perl -pi -e 's/^(bind-address.*)/#$1/g' ${MYSQL_MY_CNF}
        perl -pi -e 's#^(\[mysqld\])#${1}\nbind-address = $ENV{LOCAL_ADDRESS}#' ${MYSQL_MY_CNF}
    fi

    ECHO_DEBUG "Stop MySQL service before updating my.cnf."
    service_control stop ${MYSQL_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1
    sleep 3

    # Initial MySQL database first
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ECHO_DEBUG "Run mysql_install_db."
        /usr/local/bin/mysql_install_db >> ${INSTALL_LOG} 2>&1
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        # Start service when system start up.
        # 'mysql_enable=YES' is required to start service immediately.
        service_control enable 'mysql_enable' 'YES'
        service_control enable 'mysql_optfile' "${MYSQL_MY_CNF}"
    fi

    if [ ! -f ${MYSQL_MY_CNF} ]; then
        ECHO_DEBUG "Copy sample MySQL config file: ${SAMPLE_DIR}/mysql/my.cnf -> ${MYSQL_MY_CNF}."
        mkdir -p $(dirname ${MYSQL_MY_CNF}) &>/dev/null >> ${INSTALL_LOG} 2>&1
        cp ${SAMPLE_DIR}/mysql/my.cnf ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    fi

    ECHO_DEBUG "Disable 'skip-networking' in my.cnf."
    perl -pi -e 's#^(skip-networking.*)#${1}#' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1

    # Enable innodb_file_per_table by default.
    grep '^innodb_file_per_table' ${MYSQL_MY_CNF} &>/dev/null
    if [ X"$?" != X'0' ]; then
        ECHO_DEBUG "Enable 'innodb_file_per_table' in my.cnf."
        perl -pi -e 's#^(\[mysqld\])#${1}\ninnodb_file_per_table#' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    fi

    service_control restart ${MYSQL_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Sleep 10 seconds for MySQL daemon initialization ..."
    sleep 10

    if [ X"${LOCAL_ADDRESS}" == X'127.0.0.1' ]; then
        # Try to access without password, set a password if it's empty.
        mysql -u${MYSQL_ROOT_USER} -e "show databases" >> ${INSTALL_LOG} 2>&1
        if [ X"$?" == X'0' ]; then
            ECHO_DEBUG "Disable plugin 'unix_socket' to force all users to login with a password."
            mysql -u${MYSQL_ROOT_USER} mysql -e "UPDATE user SET plugin='' WHERE User='root'" >> ${INSTALL_LOG} 2>&1

            ECHO_DEBUG "Setting password for MySQL admin (${MYSQL_ROOT_USER})."
            mysql -u${MYSQL_ROOT_USER} mysql -e "UPDATE user SET Password=password('${MYSQL_ROOT_PASSWD}') WHERE User='root'; FLUSH PRIVILEGES;" >> ${INSTALL_LOG} 2>&1
        fi
    else
        ECHO_DEBUG "Grant access privilege to ${MYSQL_ROOT_USER}@${LOCAL_ADDRESS} ..."
        mysql -u${MYSQL_ROOT_USER} <<EOF
USE mysql;
-- Allow access from MYSQL_GRANT_HOST with password
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'${MYSQL_GRANT_HOST}';
-- GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'127.0.0.1';
-- GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'localhost';
-- GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'%';

-- Allow GRANT privilege
UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='${MYSQL_GRANT_HOST}';
-- UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='127.0.0.1';
-- UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='localhost';
-- UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='%';

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
    * Root user: ${MYSQL_ROOT_USER}, Password: "${MYSQL_ROOT_PASSWD}" (without quotes)
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
    export DOMAIN_ADMIN_PASSWD="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${DOMAIN_ADMIN_PASSWD})"
    export FIRST_USER_PASSWD="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${FIRST_USER_PASSWD})"

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
INSERT INTO domain (domain,transport,settings,created) VALUES ("${FIRST_DOMAIN}", "${TRANSPORT}", "default_user_quota:1024;", NOW());

/* Add your first normal user. */
INSERT INTO mailbox (username,password,name,maildir,quota,domain,isadmin,isglobaladmin,created) VALUES ("${FIRST_USER}@${FIRST_DOMAIN}","${FIRST_USER_PASSWD}","${FIRST_USER}","${FIRST_USER_MAILDIR_HASH_PART}",1024, "${FIRST_DOMAIN}", 1, 1, NOW());
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

mysql_cron_backup()
{
    ECHO_INFO "Setup daily cron job to backup SQL databases with ${BACKUP_SCRIPT_MYSQL}"

    [ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} >> ${INSTALL_LOG} 2>&1

    backup_file ${BACKUP_SCRIPT_MYSQL}
    cp ${TOOLS_DIR}/backup_mysql.sh ${BACKUP_SCRIPT_MYSQL}
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${BACKUP_SCRIPT_MYSQL}
    chmod 0700 ${BACKUP_SCRIPT_MYSQL}

    export MYSQL_ROOT_PASSWD MYSQL_BACKUP_DATABASES
    perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${BACKUP_SCRIPT_MYSQL}
    perl -pi -e 's#^(export MYSQL_USER=).*#${1}"$ENV{MYSQL_ROOT_USER}"#' ${BACKUP_SCRIPT_MYSQL}
    perl -pi -e 's#^(export MYSQL_PASSWD=).*#${1}"$ENV{MYSQL_ROOT_PASSWD}"#' ${BACKUP_SCRIPT_MYSQL}
    perl -pi -e 's#^(export DATABASES=)(.*)#${1}"$ENV{MYSQL_BACKUP_DATABASES}"#' ${BACKUP_SCRIPT_MYSQL}

    # Add cron job
    cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Backup MySQL databases on 03:30 AM
30   3   *   *   *   ${SHELL_BASH} ${BACKUP_SCRIPT_MYSQL}

EOF

    cat >> ${TIP_FILE} <<EOF
Backup MySQL database:
    * Script: ${BACKUP_SCRIPT_MYSQL}
    * See also:
        # crontab -l -u ${SYS_ROOT_USER}
EOF

    echo 'export status_mysql_cron_backup="DONE"' >> ${STATUS_FILE}
}
