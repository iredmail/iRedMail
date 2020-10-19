#!/usr/bin/env bash

# Author: Zhang Huangbin (zhb _at_ iredmail.org)

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
_enable_jail() {
    _jail_conf="${FAIL2BAN_JAIL_CONF_DIR}/${1}"

    if [ -e ${_jail_conf} ]; then
        perl -pi -e 's#(enabled.*=.*)false#${1}true#' ${_jail_conf}
    fi
}

fail2ban_post_installation() {
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # pip doesn't generate `/etc/fail2an/*` correctly.
        cp -rf /usr/local/lib/python${PYTHON_VERSION}/site-packages/etc/fail2ban /etc/
    fi
}

fail2ban_initialize_db() {
    ECHO_DEBUG "Import Fail2ban database and grant privileges."

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create database
CREATE DATABASE ${FAIL2BAN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Grant privileges
GRANT ALL ON ${FAIL2BAN_DB_NAME}.* TO '${FAIL2BAN_DB_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${FAIL2BAN_DB_PASSWD}';

-- Import Amavisd SQL template
USE ${FAIL2BAN_DB_NAME};
SOURCE ${SAMPLE_DIR}/fail2ban/sql/fail2ban.mysql;
FLUSH PRIVILEGES;
EOF

        cat > /root/.my.cnf-${FAIL2BAN_DB_USER} <<EOF
[client]
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
user=${FAIL2BAN_DB_USER}
password="${FAIL2BAN_DB_PASSWD}"
EOF

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp -f ${SAMPLE_DIR}/fail2ban/sql/fail2ban.pgsql /tmp/fail2ban.pgsql
        chmod 0755 /tmp/fail2ban.pgsql

        su - ${SYS_USER_PGSQL} -c "psql -d template1" >> ${INSTALL_LOG} <<EOF
-- Create database
CREATE DATABASE ${FAIL2BAN_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

-- Create user
CREATE USER ${FAIL2BAN_DB_USER} WITH ENCRYPTED PASSWORD '${FAIL2BAN_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

ALTER DATABASE ${FAIL2BAN_DB_NAME} OWNER TO ${FAIL2BAN_DB_USER};
EOF

        su - ${SYS_USER_PGSQL} -c "psql -U ${FAIL2BAN_DB_USER} -d ${FAIL2BAN_DB_NAME}" >> ${INSTALL_LOG} <<EOF
\i /tmp/fail2ban.pgsql;
EOF
        rm -f /tmp/fail2ban.pgsql

        su - ${SYS_USER_PGSQL} -c "psql -U ${FAIL2BAN_DB_USER} -d ${FAIL2BAN_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
ALTER DATABASE ${FAIL2BAN_DB_NAME} SET bytea_output TO 'escape';
EOF
    fi

    # Copy action config file.
    cp -f ${SAMPLE_DIR}/fail2ban/action.d/banned_db.conf ${FAIL2BAN_ACTION_DIR}/
    chmod 0755 ${FAIL2BAN_ACTION_DIR}/banned_db.conf

    # Copy script used to handle sql data.
    cp -f ${SAMPLE_DIR}/fail2ban/bin/fail2ban_banned_db /usr/local/bin/
    chmod 0550 /usr/local/bin/fail2ban_banned_db

    cat >> ${CRON_FILE_ROOT} <<EOF
# Fail2ban: Unban IP addresses pending for removal (stored in SQL db).
* * * * * ${SHELL_BASH} /usr/local/bin/fail2ban_banned_db unban_db
EOF

    echo 'export status_fail2ban_initialize_db="DONE"' >> ${STATUS_FILE}
}

fail2ban_config() {
    ECHO_DEBUG "Disable all default filters in ${FAIL2BAN_JAIL_CONF}."
    perl -pi -e 's#^(enabled).*=.*#${1} = false#' ${FAIL2BAN_JAIL_CONF}

    ECHO_DEBUG "Create main Fail2ban config file: ${FAIL2BAN_MAIN_CONF}."
    backup_file ${FAIL2BAN_MAIN_CONF}
    cp -f ${SAMPLE_DIR}/fail2ban/fail2ban.local ${FAIL2BAN_MAIN_CONF}
    perl -pi -e 's#PH_SYSLOG_SOCKET#$ENV{SYSLOG_SOCKET}#' ${FAIL2BAN_MAIN_CONF}

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        perl -pi -e 's#^(socket).*#${1} = $ENV{FAIL2BAN_SOCKET}#' ${FAIL2BAN_MAIN_CONF}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        perl -pi -e 's/^#(syslogsocket.*)/${1}/' ${FAIL2BAN_MAIN_CONF}
    fi

    ECHO_DEBUG "Create Fail2ban config file: ${FAIL2BAN_JAIL_LOCAL_CONF}."
    backup_file ${FAIL2BAN_JAIL_LOCAL_CONF}
    cp -f ${SAMPLE_DIR}/fail2ban/jail.local ${FAIL2BAN_JAIL_LOCAL_CONF} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Create Fail2ban directory: ${FAIL2BAN_JAIL_CONF_DIR}."
    mkdir -p ${FAIL2BAN_JAIL_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#' ${FAIL2BAN_JAIL_LOCAL_CONF}

    ECHO_DEBUG "Copy modular Fail2ban jail config files to ${FAIL2BAN_JAIL_CONF_DIR}."
    cp -f ${SAMPLE_DIR}/fail2ban/jail.d/*.local ${FAIL2BAN_JAIL_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    # Firewall command
    perl -pi -e 's#PH_FAIL2BAN_ACTION#$ENV{FAIL2BAN_ACTION}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    perl -pi -e 's#PH_SSHD_LOGFILE#$ENV{SSHD_LOGFILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_NGINX_LOG_ERRORLOG#$ENV{NGINX_LOG_ERRORLOG}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_RCM_LOGFILE#$ENV{RCM_LOGFILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_MAILLOG#$ENV{MAILLOG}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_SOGO_LOG_FILE#$ENV{SOGO_LOG_FILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_DIR}/*.log#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_FAIL2BAN_DISABLED_SERVICES#$ENV{FAIL2BAN_DISABLED_SERVICES}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    perl -pi -e 's#PH_SSHD_PORT#$ENV{SSHD_PORTS_WITH_COMMA}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    ECHO_DEBUG "Copy sample Fail2ban filter config files."
    cp -f ${SAMPLE_DIR}/fail2ban/filter.d/*.conf ${FAIL2BAN_FILTER_DIR}

    # Enable jail for optional components.
    [ X"${WEB_SERVER}" == X'NGINX' ]    && _enable_jail nginx-http-auth.local
    [ X"${USE_ROUNDCUBE}" == X'YES' ]   && _enable_jail roundcube.local
    [ X"${USE_SOGO}" == X'YES' ]        && _enable_jail sogo.local

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Copy rc script and enable service.
        cp ${SAMPLE_DIR}/fail2ban/openbsd/rc /etc/rc.d/fail2ban
        chmod 0755 /etc/rc.d/fail2ban
        service_control enable fail2ban
    fi

    echo 'export status_fail2ban_config="DONE"' >> ${STATUS_FILE}
}

fail2ban_syslog_setup() {
    ECHO_DEBUG "Generate modular syslog and log rotate config files for Fail2ban."
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        cp ${SAMPLE_DIR}/rsyslog.d/1-iredmail-fail2ban.conf ${SYSLOG_CONF_DIR}
        perl -pi -e 's#PH_FAIL2BAN_LOG_FILE#$ENV{FAIL2BAN_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/1-iredmail-fail2ban.conf

        touch ${FAIL2BAN_LOG_FILE}
        chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${FAIL2BAN_LOG_FILE}
        chmod 0755 ${FAIL2BAN_LOG_FILE}
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        cp -f ${SAMPLE_DIR}/freebsd/syslog.d/fail2ban.conf ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_FAIL2BAN_SYSLOG_FACILITY#$ENV{FAIL2BAN_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/fail2ban.conf
        perl -pi -e 's#PH_FAIL2BAN_LOG_FILE#$ENV{FAIL2BAN_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/fail2ban.conf
    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        touch ${FAIL2BAN_LOG_FILE}
        chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${FAIL2BAN_LOG_FILE}
        chmod 0755 ${FAIL2BAN_LOG_FILE}

        if ! grep "${FAIL2BAN_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
            # '!!' means abort further evaluation after first match
            echo '' >> ${SYSLOG_CONF}
            echo '!!fail2ban*' >> ${SYSLOG_CONF}
            echo "${FAIL2BAN_SYSLOG_FACILITY}.*        ${FAIL2BAN_LOG_FILE}" >> ${SYSLOG_CONF}
        fi

        if ! grep "${FAIL2BAN_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            cat >> /etc/newsyslog.conf <<EOF
${FAIL2BAN_LOG_FILE}    ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG}   640  7     *    24    Z
EOF
        fi
    fi

    echo 'export status_fail2ban_syslog_setup="DONE"' >> ${STATUS_FILE}
}

fail2ban_setup() {
    ECHO_INFO "Configure Fail2ban (authentication failure monitor)."

    check_status_before_run fail2ban_post_installation
    check_status_before_run fail2ban_initialize_db
    check_status_before_run fail2ban_config
    check_status_before_run fail2ban_syslog_setup

    echo 'export status_fail2ban_setup="DONE"' >> ${STATUS_FILE}
}
