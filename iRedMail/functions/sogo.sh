#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

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


sogo_config()
{
    ECHO_INFO "Configure SOGo Groupware (Webmail, Calendar, Address Book, ActiveSync)."

    tmp_sql="${ROOTDIR}/sogo_init.sql"

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        cat >> ${tmp_sql} <<EOF
CREATE DATABASE ${SOGO_DB_NAME} CHARSET='UTF8';
GRANT ALL ON ${SOGO_DB_NAME}.* TO ${SOGO_DB_USER}@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${SOGO_DB_PASSWD}";
EOF

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            cat >> ${tmp_sql} <<EOF
GRANT SELECT ON ${VMAIL_DB}.mailbox TO ${SOGO_DB_USER}@"${MYSQL_GRANT_HOST}";
CREATE VIEW ${SOGO_DB_NAME}.${SOGO_DB_AUTH_VIEW} (c_uid, c_name, c_password, c_cn, mail, home) AS SELECT username, username, password, name, username, maildir FROM ${VMAIL_DB}.mailbox;
EOF
        fi

        ${MYSQL_CLIENT_ROOT} -e "SOURCE ${tmp_sql}"

    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        cat > ${tmp_sql} <<EOF
CREATE DATABASE ${SOGO_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';
CREATE USER ${SOGO_DB_USER} WITH ENCRYPTED PASSWORD '${SOGO_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
\c ${SOGO_DB_NAME};
EOF
        # Grant permission
        echo "host   sogo   sogo ${LOCAL_ADDRESS}   md5" >> ${PGSQL_CONF_PG_HBA}

        su - ${PGSQL_SYS_USER} -c "psql -d template1 -f ${tmp_sql} >/dev/null" >/dev/null 
    fi

    # Configure SOGo config file
    backup_file ${SOGO_CONF}
    cp -f ${SAMPLE_DIR}/sogo/sogo.conf ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_IMAP_SERVER#$ENV{IMAP_SERVER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_BIND_HOST#$ENV{MANAGESIEVE_BIND_HOST}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_MANAGESIEVE_PORT#$ENV{MANAGESIEVE_PORT}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_MEMCACHED_BIND_HOST#$ENV{MEMCACHED_BIND_HOST}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SOGO_DB_USER#$ENV{SOGO_DB_USER}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_PASSWD#$ENV{SOGO_DB_PASSWD}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_NAME#$ENV{SOGO_DB_NAME}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SOGO_DB_AUTH_VIEW#$ENV{SOGO_DB_AUTH_VIEW}#g' ${SOGO_CONF}

    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#g' ${SOGO_CONF}
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#g' ${SOGO_CONF}

    # Enable ActiveSync in Apache
    if [ -f ${SOGO_HTTPD_CONF} ]; then
        perl -pi -e 's/^#(.*Microsoft-Server-ActiveSync.*)/${1}/g' ${SOGO_HTTPD_CONF}
        perl -pi -e 's/^#(.*retry.*connectiontimeout.*timeout.*)/${1}/g' ${SOGO_HTTPD_CONF}

        perl -pi -e 's/^(.*x-webobjects-server-port.).*/#${1} "443"/g' ${SOGO_HTTPD_CONF}
        perl -pi -e 's/^(.*x-webobjects-server-name.*)/#${1}/g' ${SOGO_HTTPD_CONF}
        perl -pi -e 's/^(.*x-webobjects-server-url.*)/#${1}/g' ${SOGO_HTTPD_CONF}
    fi

    echo 'export status_sogo_config="DONE"' >> ${STATUS_FILE}
}
