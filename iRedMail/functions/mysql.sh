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
mysql_initialize_db()
{
    ECHO_DEBUG "Initialize MySQL server."

    backup_file ${MYSQL_MY_CNF}

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
        ECHO_DEBUG "Copy sample MySQL config file: ${MYSQL_MY_CNF_SAMPLE} -> ${MYSQL_MY_CNF}."
        mkdir -p $(dirname ${MYSQL_MY_CNF}) &>/dev/null >> ${INSTALL_LOG} 2>&1
        cp ${MYSQL_MY_CNF_SAMPLE} ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    fi

    ECHO_DEBUG "Disable 'skip-networking' in my.cnf."
    perl -pi -e 's/^(skip-networking.*)/#${1}/' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1

    # Enable innodb_file_per_table by default.
    grep '^innodb_file_per_table' ${MYSQL_MY_CNF} &>/dev/null
    if [ X"$?" != X'0' ]; then
        ECHO_DEBUG "Enable 'innodb_file_per_table' in my.cnf."
        perl -pi -e 's#^(\[mysqld\])#${1}\ninnodb_file_per_table#' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    fi

    # Bind to 127.0.0.1 on OpenBSD
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        grep '^bind-address' ${MYSQL_MY_CNF} &>/dev/null
        if [ X"$?" != X'0' ]; then
            ECHO_DEBUG "Enable 'bind-address = 127.0.0.1' in my.cnf."
            perl -pi -e 's#^(\[mysqld\])#${1}\nbind-address = 127.0.0.1#' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
        fi
    fi

    service_control restart ${MYSQL_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Sleep 10 seconds for MySQL daemon initialization ..."
    sleep 10

    if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
        if [ X"${DISTRO}" == X'FREEBSD' ]; then
            # Get initial random root password from /root/.mysql-secret
            export _mysql_root_pw="$(tail -1 /root/.mysql_secret)"
            mysqladmin -u${MYSQL_ROOT_USER} -p${_mysql_root_pw} password ${MYSQL_ROOT_PASSWD} >> ${INSTALL_LOG} 2>&1
        else
            # Try to access without password, set a password if it's empty.
            mysql -u${MYSQL_ROOT_USER} -e "show databases" >> ${INSTALL_LOG} 2>&1

            if [ X"$?" == X'0' ]; then
                #ECHO_DEBUG "Disable plugin 'unix_socket' to force all users to login with a password."
                #mysql -u${MYSQL_ROOT_USER} mysql -e "UPDATE user SET plugin='' WHERE User='root'" >> ${INSTALL_LOG} 2>&1

                ECHO_DEBUG "Setting password for MySQL admin (${MYSQL_ROOT_USER})."
                #mysqladmin -u${MYSQL_ROOT_USER} password ${MYSQL_ROOT_PASSWD} >> ${INSTALL_LOG} 2>&1

                mysql -u ${MYSQL_ROOT_USER} -e "DESC mysql.user" | grep '\<Password\>' &>/dev/null
                if [ X"$?" == X'0' ]; then
                    # MySQL 5.6 and earlier
                    mysqladmin -u${MYSQL_ROOT_USER} password ${MYSQL_ROOT_PASSWD} >> ${INSTALL_LOG} 2>&1
                else
                    # MySQL 5.7 and later.
                    mysql -u${MYSQL_ROOT_USER} -e "UPDATE mysql.user SET authentication_string = PASSWORD('${MYSQL_ROOT_PASSWD}') WHERE User='root' AND Host='localhost'; FLUSH PRIVILEGES;" >> ${INSTALL_LOG} 2>&1
                fi
            else
                ECHO_DEBUG "MySQL root password is not empty, not reset."
            fi
        fi
    fi

    cat >> ${TIP_FILE} <<EOF
MySQL:
    * Root user: ${MYSQL_ROOT_USER}, Password: "${MYSQL_ROOT_PASSWD}" (without quotes)
    * Bind account (read-only):
        - Username: ${VMAIL_DB_BIND_USER}, Password: ${VMAIL_DB_BIND_PASSWD}
    * Vmail admin account (read-write):
        - Username: ${VMAIL_DB_ADMIN_USER}, Password: ${VMAIL_DB_ADMIN_PASSWD}
    * Config file: ${MYSQL_MY_CNF}
    * RC script: ${MYSQLD_RC_SCRIPT}

EOF

    echo 'export status_mysql_initialize_db="DONE"' >> ${STATUS_FILE}
}

mysql_grant_permission_on_remote_server()
{
    # If we're using a remote mysql server: grant access privilege first.
    if [ X"${USE_EXISTING_MYSQL}" == X'YES' -a X"${MYSQL_SERVER_ADDRESS}" != X'127.0.0.1' ]; then
        ECHO_DEBUG "Grant access privilege to ${MYSQL_ROOT_USER}@${MYSQL_GRANT_HOST} ..."

        cp -f ${SAMPLE_DIR}/mysql/sql/remote_grant_permission.sql ${RUNTIME_DIR}/
        perl -pi -e 's#PH_MYSQL_ROOT_USER#$ENV{MYSQL_ROOT_USER}#g' ${RUNTIME_DIR}/remote_grant_permission.sql
        perl -pi -e 's#PH_MYSQL_GRANT_HOST#$ENV{MYSQL_GRANT_HOST}#g' ${RUNTIME_DIR}/remote_grant_permission.sql
        perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#g' ${RUNTIME_DIR}/remote_grant_permission.sql

        ${MYSQL_CLIENT_ROOT} -e "SOURCE ${RUNTIME_DIR}/remote_grant_permission.sql;"
    fi

    echo 'export status_mysql_grant_permission_on_remote_server="DONE"' >> ${STATUS_FILE}
}

mysql_generate_defaults_file_root()
{
    ECHO_DEBUG "Generate defauts file for MySQL client option --defaults-file: ${MYSQL_DEFAULTS_FILE_ROOT}."
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

    chmod 0400 ${MYSQL_DEFAULTS_FILE_ROOT}

    echo 'export status_mysql_generate_defaults_file_root="DONE"' >> ${STATUS_FILE}
}

mysql_remove_insecure_data()
{
    ECHO_DEBUG "Delete anonymous database user."
    ${MYSQL_CLIENT_ROOT} -e "SOURCE ${SAMPLE_DIR}/mysql/sql/delete_anonymous_user.sql;"

    # Delete root access with empty passwords
    ${MYSQL_CLIENT_ROOT} -e "DESC mysql.user" | grep '\<Password\>' &>/dev/null
    if [ X"$?" == X'0' ]; then
        ECHO_DEBUG "Delete root access with empty passwords."
        ${MYSQL_CLIENT_ROOT} -e "DELETE FROM mysql.user WHERE User='root' AND Password=''"
    fi

    ${MYSQL_CLIENT_ROOT} -e "DESC mysql.user" | grep '\<Password\>' &>/dev/null
    if [ X"$?" == X'0' ]; then
        ECHO_DEBUG "Delete root access with empty passwords."
        ${MYSQL_CLIENT_ROOT} -e "DELETE FROM mysql.user WHERE User='root' AND Password=''"
    fi

    ${MYSQL_CLIENT_ROOT} -e "SHOW DATABASES" | grep '\<test\>' &>/dev/null
    if [ X"$?" == X'0' ]; then
        ECHO_DEBUG "Remove 'test' database."
        ${MYSQL_CLIENT_ROOT} -e "DROP DATABASE test"
    fi

    echo 'export status_mysql_remove_insecure_data="DONE"' >> ${STATUS_FILE}
}

# It's used only when backend is MySQL.
mysql_import_vmail_users()
{
    export FIRST_USER_PASSWD_HASHED="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${FIRST_USER_PASSWD})"

    ECHO_DEBUG "Generate sample SQL templates."
    cp -f ${SAMPLE_DIR}/mysql/sql/init_vmail_db.sql ${RUNTIME_DIR}/
    cp -f ${SAMPLE_DIR}/iredmail/iredmail.mysql ${RUNTIME_DIR}/iredmail.sql
    cp -f ${SAMPLE_DIR}/mysql/sql/add_first_domain_and_user.sql ${RUNTIME_DIR}/

    perl -pi -e 's#PH_VMAIL_DB_NAME#$ENV{VMAIL_DB_NAME}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_VMAIL_DB_ADMIN_USER#$ENV{VMAIL_DB_ADMIN_USER}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_VMAIL_DB_ADMIN_PASSWD#$ENV{VMAIL_DB_ADMIN_PASSWD}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_MYSQL_GRANT_HOST#$ENV{MYSQL_GRANT_HOST}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#g' ${RUNTIME_DIR}/*.sql

    export FIRST_DOMAIN
    perl -pi -e 's#PH_FIRST_DOMAIN#$ENV{FIRST_DOMAIN}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_TRANSPORT#$ENV{TRANSPORT}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_FIRST_USER_PASSWD#$ENV{FIRST_USER_PASSWD_HASHED}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_FIRST_USER_MAILDIR_HASH_PART#$ENV{FIRST_USER_MAILDIR_HASH_PART}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_FIRST_USER#$ENV{FIRST_USER}#g' ${RUNTIME_DIR}/*.sql
    perl -pi -e 's#PH_DOMAIN_ADMIN_NAME#$ENV{DOMAIN_ADMIN_NAME}#g' ${RUNTIME_DIR}/*.sql

    # Modify default SQL template
    perl -pi -e 's#^-- (USE.*)#${1}#g' ${RUNTIME_DIR}/iredmail.sql
    perl -pi -e 's#(.*storagebasedirectory.*DEFAULT).*#${1} "$ENV{STORAGE_BASE_DIR}",#' ${RUNTIME_DIR}/iredmail.sql
    perl -pi -e 's#(.*storagenode.*DEFAULT).*#${1} "$ENV{STORAGE_NODE}",#' ${RUNTIME_DIR}/iredmail.sql
    # Rename SQL table `vmail.used_quota`
    perl -pi -e 's#used_quota`#$ENV{DOVECOT_REALTIME_QUOTA_TABLE}`#g' ${RUNTIME_DIR}/iredmail.sql

    ECHO_DEBUG "Create database: ${VMAIL_DB_NAME}."
    ${MYSQL_CLIENT_ROOT} -e "SOURCE ${RUNTIME_DIR}/init_vmail_db.sql;"

    ECHO_DEBUG "Initialize database: ${VMAIL_DB_NAME}."
    ${MYSQL_CLIENT_ROOT} -e "SOURCE ${RUNTIME_DIR}/iredmail.sql;"

    ECHO_DEBUG "Add first domain and postmaster@ user."
    ${MYSQL_CLIENT_ROOT} -e "SOURCE ${RUNTIME_DIR}/add_first_domain_and_user.sql;"

    cat >> ${TIP_FILE} <<EOF
Virtual Users:
    - ${MYSQL_VMAIL_STRUCTURE_SAMPLE}
    - ${RUNTIME_DIR}/*.sql

EOF

    echo 'export status_mysql_import_vmail_users="DONE"' >> ${STATUS_FILE}
}

mysql_create_sql_table_used_quota()
{
    # Create `vmail.used_quota<_suffix>` for cluster nodes.

    if [ X"${WITH_HAPROXY}" == X'YES' -a X"${INITIALIZE_SQL_DATA}" == X'NO' ]; then
        cp -f ${SAMPLE_DIR}/dovecot/used_quota.mysql ${RUNTIME_DIR}/used_quota.sql

        # Rename SQL table `vmail.used_quota` to `vmail.used_quota_<hostname>`
        perl -pi -e 's#used_quota`#$ENV{DOVECOT_REALTIME_QUOTA_TABLE}`#g' ${RUNTIME_DIR}/used_quota.sql

        ${MYSQL_CLIENT_ROOT} -e "USE ${VMAIL_DB_NAME}; SOURCE ${RUNTIME_DIR}/used_quota.sql;"
    fi

    echo 'export status_mysql_create_sql_table_used_quota="DONE"' >> ${STATUS_FILE}
}

mysql_cron_backup()
{
    mysql_backup_script="${BACKUP_DIR}/${BACKUP_SCRIPT_MYSQL_NAME}"

    ECHO_INFO "Setup daily cron job to backup SQL databases with ${mysql_backup_script}"

    [ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} >> ${INSTALL_LOG} 2>&1

    backup_file ${mysql_backup_script}
    cp ${TOOLS_DIR}/${BACKUP_SCRIPT_MYSQL_NAME} ${mysql_backup_script}
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${mysql_backup_script}
    chmod 0500 ${mysql_backup_script}

    export MYSQL_ROOT_PASSWD SQL_BACKUP_DATABASES
    perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${mysql_backup_script}
    perl -pi -e 's#^(export MYSQL_USER=).*#${1}"$ENV{MYSQL_ROOT_USER}"#' ${mysql_backup_script}
    perl -pi -e 's#^(export MYSQL_PASSWD=).*#${1}"$ENV{MYSQL_ROOT_PASSWD}"#' ${mysql_backup_script}
    perl -pi -e 's#^(export DATABASES=)(.*)#${1}"$ENV{SQL_BACKUP_DATABASES}"#' ${mysql_backup_script}

    # Add cron job
    cat >> ${CRON_FILE_ROOT} <<EOF
# ${PROG_NAME}: Backup MySQL databases on 03:30 AM
30   3   *   *   *   ${SHELL_BASH} ${mysql_backup_script}

EOF

    if [ X"${INITIALIZE_SQL_DATA}" != X'YES' ]; then
        perl -pi -e 's/(.*bash.*backup_mysql.sh.*)/#${1}/g' ${CRON_FILE_ROOT}
    fi

    cat >> ${TIP_FILE} <<EOF
Backup MySQL database:
    * Script: ${mysql_backup_script}
    * See also:
        # crontab -l -u ${SYS_ROOT_USER}
EOF

    echo 'export status_mysql_cron_backup="DONE"' >> ${STATUS_FILE}
}

mysql_setup()
{
    if [ X"${BACKEND_ORIG}" == X'MARIADB' ]; then
        ECHO_INFO "Configure MariaDB database server."
    else
        ECHO_INFO "Configure MySQL database server."
    fi

    if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
        check_status_before_run mysql_initialize_db
    fi

    check_status_before_run mysql_generate_defaults_file_root

    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run mysql_grant_permission_on_remote_server
        check_status_before_run mysql_remove_insecure_data
        check_status_before_run mysql_import_vmail_users
    fi

    check_status_before_run mysql_create_sql_table_used_quota
    check_status_before_run mysql_cron_backup

    echo 'export status_mysql_setup="DONE"' >> ${STATUS_FILE}
}
