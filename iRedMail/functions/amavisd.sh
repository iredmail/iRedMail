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

# --------------------------------------------
# Amavisd-new.
# --------------------------------------------

amavisd_initialize_db()
{
    ECHO_DEBUG "Import Amavisd database and privileges."

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create database
CREATE DATABASE ${AMAVISD_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Grant privileges
GRANT SELECT,INSERT,UPDATE,DELETE ON ${AMAVISD_DB_NAME}.* TO '${AMAVISD_DB_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${AMAVISD_DB_PASSWD}';
-- GRANT SELECT,INSERT,UPDATE,DELETE ON ${AMAVISD_DB_NAME}.* TO '${AMAVISD_DB_USER}'@'${HOSTNAME}' IDENTIFIED BY '${AMAVISD_DB_PASSWD}';

-- Import Amavisd SQL template
USE ${AMAVISD_DB_NAME};
SOURCE ${AMAVISD_DB_MYSQL_TMPL};
SOURCE ${SAMPLE_DIR}/amavisd/default_spam_policy.sql;

FLUSH PRIVILEGES;
EOF

        # Generate .my.cnf file
        cat > /root/.my.cnf-${AMAVISD_DB_USER} <<EOF
[client]
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
user=${AMAVISD_DB_USER}
password="${AMAVISD_DB_PASSWD}"
EOF

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp -f ${AMAVISD_DB_PGSQL_TMPL} ${PGSQL_USER_HOMEDIR}/amavisd.sql >> ${INSTALL_LOG} 2>&1
        cp -f ${SAMPLE_DIR}/amavisd/default_spam_policy.sql ${PGSQL_USER_HOMEDIR}/default_spam_policy.sql >> ${INSTALL_LOG} 2>&1
        chmod 0777 ${PGSQL_USER_HOMEDIR}/amavisd.sql >/dev/null

        su - ${SYS_USER_PGSQL} -c "psql -d template1" >> ${INSTALL_LOG}  <<EOF
-- Create database
CREATE DATABASE ${AMAVISD_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

-- Create user
CREATE USER ${AMAVISD_DB_USER} WITH ENCRYPTED PASSWORD '${AMAVISD_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

ALTER DATABASE ${AMAVISD_DB_NAME} OWNER TO ${AMAVISD_DB_USER};
EOF

        # Import Amavisd SQL template
        su - ${SYS_USER_PGSQL} -c "psql -U ${AMAVISD_DB_USER} -d ${AMAVISD_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
\i ${PGSQL_USER_HOMEDIR}/amavisd.sql;
\i ${PGSQL_USER_HOMEDIR}/default_spam_policy.sql;
EOF
        rm -f ${PGSQL_USER_HOMEDIR}/{amavisd,bypass}.sql >> ${INSTALL_LOG}

        su - ${SYS_USER_PGSQL} -c "psql -U ${AMAVISD_DB_USER} -d ${AMAVISD_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
ALTER DATABASE ${AMAVISD_DB_NAME} SET bytea_output TO 'escape';
EOF
    fi

    echo 'export status_amavisd_initialize_db="DONE"' >> ${STATUS_FILE}
}

amavisd_config()
{
    ECHO_INFO "Configure Amavisd-new (interface between MTA and content checkers)."

    backup_file ${AMAVISD_CONF}

    #
    # DKIM
    #
    export AMAVISD_FIRST_DOMAIN_DKIM_KEY="${AMAVISD_DKIM_DIR}/${FIRST_DOMAIN}.pem"

    ECHO_DEBUG "Generate DKIM pem files: ${AMAVISD_FIRST_DOMAIN_DKIM_KEY}."
    mkdir -p ${AMAVISD_DKIM_DIR} &>/dev/null && \
    chown -R ${SYS_USER_AMAVISD}:${SYS_GROUP_AMAVISD} ${AMAVISD_DKIM_DIR}
    chmod -R 0700 ${AMAVISD_DKIM_DIR}

    # Create DKIM key if not exists.
    if [ ! -f ${AMAVISD_FIRST_DOMAIN_DKIM_KEY} ]; then
        # Not all DNS vendor supports key length >= 2048, so we stick to 1024.
        ${AMAVISD_BIN} genrsa ${AMAVISD_FIRST_DOMAIN_DKIM_KEY} 1024 &>/dev/null
    fi

    chown -R ${SYS_USER_AMAVISD}:${SYS_GROUP_AMAVISD} ${AMAVISD_FIRST_DOMAIN_DKIM_KEY}
    chmod 0400 ${AMAVISD_FIRST_DOMAIN_DKIM_KEY}

    #
    # Disclaimer
    #
    # Create directory to store disclaimer files if not exist.
    [ -d ${DISCLAIMER_DIR} ] || mkdir -p ${DISCLAIMER_DIR} >> ${INSTALL_LOG} 2>&1
    # Create a empty disclaimer.
    echo -e '\n----' > ${DISCLAIMER_DIR}/default.txt

    #
    # SQL integration
    #
    # Integrate SQL. Used to store incoming & outgoing related mail information.
    if [ X"${BACKEND}" == X'PGSQL' ]; then
        export AMAVISD_PERL_SQL_DBI='Pg'
    else
        export AMAVISD_PERL_SQL_DBI='mysql'
    fi

    #
    # Main config file
    #
    cp -f ${SAMPLE_DIR}/amavisd/amavisd.conf ${AMAVISD_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_SYS_USER_AMAVISD#$ENV{SYS_USER_AMAVISD}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_SYS_GROUP_AMAVISD#$ENV{SYS_GROUP_AMAVISD}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_AMAVISD_SPOOL_DIR#$ENV{AMAVISD_SPOOL_DIR}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_TEMP_DIR#$ENV{AMAVISD_TEMP_DIR}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_DB_DIR#$ENV{AMAVISD_DB_DIR}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_QUARANTINE_DIR#$ENV{AMAVISD_QUARANTINE_DIR}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_AMAVISD_LOCK_FILE#$ENV{AMAVISD_LOCK_FILE}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_PID_FILE#$ENV{AMAVISD_PID_FILE}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_SOCKET_FILE#$ENV{AMAVISD_SOCKET_FILE}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_AMAVISD_SMTP_PORT#$ENV{AMAVISD_SMTP_PORT}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_ORIGINATING_PORT#$ENV{AMAVISD_ORIGINATING_PORT}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_QUARANTINE_PORT#$ENV{AMAVISD_QUARANTINE_PORT}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_POSTFIX_MAIL_REINJECT_PORT#$ENV{POSTFIX_MAIL_REINJECT_PORT}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_AMAVISD_MLMMJ_PORT#$ENV{AMAVISD_MLMMJ_PORT}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_POSTFIX_MLMMJ_REINJECT_PORT#$ENV{POSTFIX_MLMMJ_REINJECT_PORT}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_CLAMD_LOCAL_SOCKET#$ENV{CLAMD_LOCAL_SOCKET}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_FIRST_DOMAIN#$ENV{FIRST_DOMAIN}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_FIRST_DOMAIN_DKIM_KEY#$ENV{AMAVISD_FIRST_DOMAIN_DKIM_KEY}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_CMD_ALTERMIME#$ENV{CMD_ALTERMIME}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_AMAVISD_PERL_SQL_DBI#$ENV{AMAVISD_PERL_SQL_DBI}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_DB_NAME#$ENV{AMAVISD_DB_NAME}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_DB_USER#$ENV{AMAVISD_DB_USER}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_DB_PASSWD#$ENV{AMAVISD_DB_PASSWD}#g' ${AMAVISD_CONF}

    perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#g' ${AMAVISD_CONF}
    perl -pi -e 's#PH_AMAVISD_MAX_SERVERS#$ENV{AMAVISD_MAX_SERVERS}#g' ${AMAVISD_CONF}

    if [ X"${DISTRO}" == X'RHEL' ]; then
        usermod -G ${SYS_GROUP_AMAVISD} ${SYS_USER_CLAMAV} >> ${INSTALL_LOG} 2>&1
    fi

    if [ X"${DISTRO}" == X'RHEL' \
        -o X"${DISTRO}" == X'FREEBSD' \
        -o X"${DISTRO}" == X'OPENBSD' ]; then
        chgrp ${SYS_GROUP_AMAVISD} ${AMAVISD_CONF}
        chmod 0640 ${AMAVISD_CONF}
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        # Make sure clamav is configured to init supplementary
        # groups when it drops priviledges, and that you add the
        # clamav user to the amavis group.
        adduser --quiet ${SYS_USER_CLAMAV} ${SYS_GROUP_AMAVISD} >> ${INSTALL_LOG} 2>&1
    fi

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # Start service when system start up.
        service_control enable 'amavisd_enable' 'YES'
        service_control enable 'amavisd_pidfile' "${AMAVISD_PID_FILE}"
        service_control enable 'amavis_milter_enable' 'NO'
        service_control enable 'amavis_p0fanalyzer_enable' 'NO'
    fi

    #
    # Postfix integration
    #
    cat ${SAMPLE_DIR}/postfix/main.cf.amavisd >> ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' ${POSTFIX_FILE_MAIN_CF}

    # Add postfix alias for user: amavis.
    add_postfix_alias 'virusalert' ${SYS_ROOT_USER}
    add_postfix_alias ${SYS_USER_AMAVISD} ${SYS_ROOT_USER}

    #
    # Cron jobs
    #
    if [ -n "${AMAVISD_VIRUSMAILS_DIR}" ]; then
        ECHO_DEBUG "Setting cron job for vmail user to delete virus mail per month."
        cat >> ${CRON_FILE_AMAVISD} <<EOF
${CONF_MSG}
# Delete virus mails which created 15 days ago.
1   5   *   *   *   touch ${AMAVISD_VIRUSMAILS_DIR}; find ${AMAVISD_VIRUSMAILS_DIR}/ -mtime +15 | xargs rm -rf {}

EOF
    fi

    #
    # Populate SQL data
    #
    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run amavisd_initialize_db
    fi

    #
    # Tip file
    #
    cat >> ${TIP_FILE} <<EOF
Amavisd-new:
    * Configuration files:
        - ${AMAVISD_CONF}
        - ${POSTFIX_FILE_MASTER_CF}
        - ${POSTFIX_FILE_MAIN_CF}
    * RC script:
        - ${DIR_RC_SCRIPTS}/${AMAVISD_RC_SCRIPT_NAME}
    * SQL Database:
        - Database name: ${AMAVISD_DB_NAME}
        - Database user: ${AMAVISD_DB_USER}
        - Database password: ${AMAVISD_DB_PASSWD}

DNS record for DKIM support:

EOF

    if [ X"${DISTRO}" == X'RHEL' ]; then
        cat >> ${TIP_FILE} <<EOF
$(${AMAVISD_BIN} -c ${AMAVISD_CONF} showkeys 2>> ${INSTALL_LOG})
EOF
    else
        cat >> ${TIP_FILE} <<EOF
$(${AMAVISD_BIN} showkeys 2>> ${INSTALL_LOG})
EOF
    fi

    echo 'export status_amavisd_config="DONE"' >> ${STATUS_FILE}
}
