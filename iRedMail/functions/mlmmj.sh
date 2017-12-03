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
# ------------------ mlmmj & mlmmj-admin ----------------
# -------------------------------------------------------

mlmmj_config()
{
    ECHO_INFO "Configure mlmmj (mailing list manager)."

    ECHO_DEBUG "Generate script: ${CMD_MLMMJ_AMIME_RECEIVE}."
    cp -f ${SAMPLE_DIR}/mlmmj/mlmmj-amime-receive ${CMD_MLMMJ_AMIME_RECEIVE}
    chown ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME} ${CMD_MLMMJ_AMIME_RECEIVE}
    chmod 0550 ${CMD_MLMMJ_AMIME_RECEIVE}

    perl -pi -e 's#PH_CMD_MLMMJ_RECEIVE#$ENV{CMD_MLMMJ_RECEIVE}#g' ${CMD_MLMMJ_AMIME_RECEIVE}
    perl -pi -e 's#PH_CMD_ALTERMIME#$ENV{CMD_ALTERMIME}#g' ${CMD_MLMMJ_AMIME_RECEIVE}

    ECHO_DEBUG "Create required directories: ${MLMMJ_SPOOL_DIR}, ${MLMMJ_ARCHIVE_DIR}."
    mkdir -p ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}
    chown ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME} ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}
    chmod 0700 ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}

    ECHO_DEBUG "Setting cron job for mlmmj maintenance."
    cat >> ${CRON_FILE_MLMMJ} <<EOF
${CONF_MSG}
# mlmmj: mailing list maintenance
10   */2   *   *   *   find ${MLMMJ_SPOOL_DIR} -mindepth 1 -maxdepth 1 -type d -exec ${CMD_MLMMJ_MAINTD} -F -d {} \\;

EOF

    ECHO_DEBUG "Enable mlmmj transport in postfix: ${POSTFIX_FILE_MAIN_CF}."
    cat ${SAMPLE_DIR}/postfix/main.cf.mlmmj >> ${POSTFIX_FILE_MAIN_CF}
}

mlmmj_admin_config()
{
    ECHO_DEBUG "Configure mlmmj-admin (RESTful API server used to manage mlmmj)."

    # Extract source tarball.
    cd ${PKG_MISC_DIR}
    [ -d ${MLMMJ_ADMIN_PARENT_DIR} ] || mkdir -p ${MLMMJ_ADMIN_PARENT_DIR}
    extract_pkg ${MLMMJ_ADMIN_TARBALL} ${MLMMJ_ADMIN_PARENT_DIR}

    # Set file permission.
    chown -R ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME} ${MLMMJ_ADMIN_ROOT_DIR}
    chmod -R 0500 ${MLMMJ_ADMIN_ROOT_DIR}

    # Create symbol link.
    ln -s ${MLMMJ_ADMIN_ROOT_DIR} ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

    # Generate main config file
    cp ${SAMPLE_DIR}/mlmmj/mlmmj-admin.settings.py ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_BIND_HOST#$ENV{MLMMJ_ADMIN_BIND_HOST}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_LISTEN_PORT#$ENV{MLMMJ_ADMIN_LISTEN_PORT}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_USER_NAME#$ENV{MLMMJ_USER_NAME}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_GROUP_NAME#$ENV{MLMMJ_GROUP_NAME}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_PID_FILE#$ENV{MLMMJ_ADMIN_PID_FILE}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_API_AUTH_TOKEN#$ENV{MLMMJ_ADMIN_API_AUTH_TOKEN}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_SPOOL_DIR#$ENV{MLMMJ_SPOOL_DIR}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ARCHIVE_DIR#$ENV{MLMMJ_ARCHIVE_DIR}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_SKEL_DIR#$ENV{MLMMJ_SKEL_DIR}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_AMAVISD_MLMMJ_PORT#$ENV{AMAVISD_MLMMJ_PORT}#g' ${MLMMJ_ADMIN_CONF}

    if [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(backend_api =)(.*)#${1} "bk_none"#g' ${MLMMJ_ADMIN_CONF}
        perl -pi -e 's#^(backend_cli =)(.*)#${1} "bk_iredmail_sql"#g' ${MLMMJ_ADMIN_CONF}

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            perl -pi -e 's#^(iredmail_sql_db_type =)(.*)#${1} "mysql"#g' ${MLMMJ_ADMIN_CONF}
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            perl -pi -e 's#^(iredmail_sql_db_type =)(.*)#${1} "pgsql"#g' ${MLMMJ_ADMIN_CONF}
        fi

        perl -pi -e 's#^(iredmail_sql_db_server =)(.*)#${1} "$ENV{SQL_SERVER_ADDRESS}"#g' ${MLMMJ_ADMIN_CONF}
        perl -pi -e 's#^(iredmail_sql_db_port =)(.*)#${1} "$ENV{SQL_SERVER_PORT}"#g' ${MLMMJ_ADMIN_CONF}
        perl -pi -e 's#^(iredmail_sql_db_name =)(.*)#${1} "$ENV{VMAIL_DB_NAME}"#g' ${MLMMJ_ADMIN_CONF}
        perl -pi -e 's#^(iredmail_sql_db_user =)(.*)#${1} "$ENV{VMAIL_DB_ADMIN_USER}"#g' ${MLMMJ_ADMIN_CONF}
        perl -pi -e 's#^(iredmail_sql_db_password =)(.*)#${1} "$ENV{VMAIL_DB_ADMIN_PASSWD}"#g' ${MLMMJ_ADMIN_CONF}
    fi

    # Create log directory
    mkdir -p ${MLMMJ_ADMIN_LOG_DIR}
    chown ${SYSLOG_DAEMON_USER}:${SYSLOG_DAEMON_GROUP} ${MLMMJ_ADMIN_LOG_DIR}

    # Copy init rc script.
    if [ X"${USE_SYSTEMD}" == X'YES' ]; then
        ECHO_DEBUG "Create symbol link: ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.service -> ${SYSTEMD_SERVICE_DIR}/mlmmjadmin.service."
        ln -s ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.service ${SYSTEMD_SERVICE_DIR}/mlmmjadmin.service >> ${INSTALL_LOG} 2>&1
        systemctl daemon-reload >> ${INSTALL_LOG} 2>&1
    else
        if [ X"${DISTRO}" == X'RHEL' ]; then
            cp ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.rhel ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            cp ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.debian ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'FREEBSD' ]; then
            cp ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.freebsd ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
            service_control enable 'mlmmjadmin_enable' 'YES' >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            cp ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.openbsd ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
        else
            cp ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.rhel ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
        fi

        chmod 0755 ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
    fi

    ECHO_DEBUG "Make mlmmjadmin start after system startup."
    service_control enable mlmmjadmin >> ${INSTALL_LOG} 2>&1
    export ENABLED_SERVICES="${ENABLED_SERVICES} mlmmjadmin"

    ECHO_DEBUG "Generate modular syslog config file for mlmmj-admin."
    if [ X"${USE_RSYSLOG}" == X'YES' ]; then
        # Use rsyslog.
        # Copy rsyslog config file used to filter Dovecot log
        cp ${SAMPLE_DIR}/rsyslog.d/1-iredmail-mlmmj-admin.conf ${SYSLOG_CONF_DIR}

        perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/1-iredmail-mlmmj-admin.conf
        perl -pi -e 's#PH_MLMMJ_ADMIN_LOG_FILE#$ENV{MLMMJ_ADMIN_LOG_DIR}#g' ${SYSLOG_CONF_DIR}/1-iredmail-mlmmj-admin.conf
    elif [ X"${USE_BSD_SYSLOG}" == X'YES' ]; then
        # Log to a dedicated file
        if [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
            if ! grep "${MLMMJ_ADMIN_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
                echo '' >> ${SYSLOG_CONF}
                echo '!mlmmj-admin' >> ${SYSLOG_CONF}
                echo "${IREDMAIL_SYSLOG_FACILITY}.*        -${MLMMJ_ADMIN_LOG_FILE}" >> ${SYSLOG_CONF}
            fi
        elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
            if ! grep "${MLMMJ_ADMIN_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
                # '!!' means abort further evaluation after first match
                echo '' >> ${SYSLOG_CONF}
                echo '!!mlmmj-admin' >> ${SYSLOG_CONF}
                echo "${IREDMAIL_SYSLOG_FACILITY}.*        -${MLMMJ_ADMIN_LOG_FILE}" >> ${SYSLOG_CONF}
            fi
        fi
    fi
}
