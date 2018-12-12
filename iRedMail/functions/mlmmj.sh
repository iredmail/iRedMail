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
# ------------------ mlmmj & mlmmjadmin ----------------
# -------------------------------------------------------

mlmmj_config()
{
    ECHO_INFO "Configure mlmmj (mailing list manager)."

    ECHO_DEBUG "Generate script: ${CMD_MLMMJ_AMIME_RECEIVE}."
    cp -f ${SAMPLE_DIR}/mlmmj/mlmmj-amime-receive ${CMD_MLMMJ_AMIME_RECEIVE}
    chown ${SYS_USER_MLMMJ}:${SYS_GROUP_MLMMJ} ${CMD_MLMMJ_AMIME_RECEIVE}
    chmod 0550 ${CMD_MLMMJ_AMIME_RECEIVE}

    perl -pi -e 's#PH_CMD_MLMMJ_RECEIVE#$ENV{CMD_MLMMJ_RECEIVE}#g' ${CMD_MLMMJ_AMIME_RECEIVE}
    perl -pi -e 's#PH_CMD_ALTERMIME#$ENV{CMD_ALTERMIME}#g' ${CMD_MLMMJ_AMIME_RECEIVE}

    ECHO_DEBUG "Create required directories: ${MLMMJ_SPOOL_DIR}, ${MLMMJ_ARCHIVE_DIR}."
    mkdir -p ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}
    chown ${SYS_USER_MLMMJ}:${SYS_GROUP_MLMMJ} ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}
    chmod 0700 ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}

    ECHO_DEBUG "Setting cron job for mlmmj maintenance."
    cat >> ${CRON_FILE_MLMMJ} <<EOF
${CONF_MSG}
# mlmmj: mailing list maintenance
10   */2   *   *   *   find ${MLMMJ_SPOOL_DIR} -mindepth 1 -maxdepth 1 -type d -exec ${CMD_MLMMJ_MAINTD} -F -d {} \\;

EOF

    chmod 0600 ${CRON_FILE_MLMMJ}
    ECHO_DEBUG "Enable mlmmj transport in postfix: ${POSTFIX_FILE_MAIN_CF}."
    cat ${SAMPLE_DIR}/postfix/main.cf.mlmmj >> ${POSTFIX_FILE_MAIN_CF}

    echo 'export status_mlmmj_config="DONE"' >> ${STATUS_FILE}
}

mlmmjadmin_config()
{
    ECHO_DEBUG "Configure mlmmjadmin (RESTful API server used to manage mlmmj)."

    # Extract source tarball.
    cd ${PKG_MISC_DIR}
    [ -d ${MLMMJADMIN_PARENT_DIR} ] || mkdir -p ${MLMMJADMIN_PARENT_DIR}
    extract_pkg ${MLMMJADMIN_TARBALL} ${MLMMJADMIN_PARENT_DIR}

    # Set file permission.
    chown -R ${SYS_USER_MLMMJ}:${SYS_GROUP_MLMMJ} ${MLMMJADMIN_ROOT_DIR}
    chmod -R 0755 ${MLMMJADMIN_ROOT_DIR}

    # Create symbol link.
    ln -s ${MLMMJADMIN_ROOT_DIR} ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

    # Generate main config file
    cp ${SAMPLE_DIR}/mlmmj/mlmmjadmin.settings.py ${MLMMJADMIN_CONF}
    chown -R ${SYS_USER_MLMMJ}:${SYS_GROUP_MLMMJ} ${MLMMJADMIN_CONF}
    chmod 0400 ${MLMMJADMIN_CONF}

    perl -pi -e 's#PH_MLMMJADMIN_BIND_HOST#$ENV{MLMMJADMIN_BIND_HOST}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_MLMMJADMIN_LISTEN_PORT#$ENV{MLMMJADMIN_LISTEN_PORT}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_SYS_USER_MLMMJ#$ENV{SYS_USER_MLMMJ}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_SYS_GROUP_MLMMJ#$ENV{SYS_GROUP_MLMMJ}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_MLMMJADMIN_PID_FILE#$ENV{MLMMJADMIN_PID_FILE}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_MLMMJADMIN_API_AUTH_TOKEN#$ENV{MLMMJADMIN_API_AUTH_TOKEN}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_SPOOL_DIR#$ENV{MLMMJ_SPOOL_DIR}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ARCHIVE_DIR#$ENV{MLMMJ_ARCHIVE_DIR}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_SKEL_DIR#$ENV{MLMMJ_SKEL_DIR}#g' ${MLMMJADMIN_CONF}
    perl -pi -e 's#PH_AMAVISD_MLMMJ_PORT#$ENV{AMAVISD_MLMMJ_PORT}#g' ${MLMMJADMIN_CONF}

    perl -pi -e 's#^(backend_api =)(.*)#${1} "bk_none"#g' ${MLMMJADMIN_CONF}

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#^(backend_cli =)(.*)#${1} "bk_iredmail_ldap"#g' ${MLMMJADMIN_CONF}

        cat >> ${MLMMJADMIN_CONF} <<EOF
# LDAP server info. Required by backend 'bk_iredmail_ldap'.
iredmail_ldap_uri = 'ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}'
iredmail_ldap_basedn = '${LDAP_BASEDN}'
iredmail_ldap_bind_dn = '${LDAP_ADMIN_DN}'
iredmail_ldap_bind_password = '${LDAP_ADMIN_PW}'
EOF
    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(backend_cli =)(.*)#${1} "bk_iredmail_sql"#g' ${MLMMJADMIN_CONF}

        cat >> ${MLMMJADMIN_CONF} <<EOF
# SQL database which stores meta data of mailing list accounts.
# Required by backend 'bk_iredmail_sql'.
EOF

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            echo 'iredmail_sql_db_type = "mysql"' >> ${MLMMJADMIN_CONF}
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            echo 'iredmail_sql_db_type = "pgsql"' >> ${MLMMJADMIN_CONF}
        fi

        cat >> ${MLMMJADMIN_CONF} <<EOF
iredmail_sql_db_server = '${SQL_SERVER_ADDRESS}'
iredmail_sql_db_port = ${SQL_SERVER_PORT}
iredmail_sql_db_name = '${VMAIL_DB_NAME}'
iredmail_sql_db_user = '${VMAIL_DB_ADMIN_USER}'
iredmail_sql_db_password = '${VMAIL_DB_ADMIN_PASSWD}'
EOF
    fi

    # FreeBSD uses different path for syslog socket.
    if [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        echo "SYSLOG_SERVER = '/var/run/log'" >> ${MLMMJADMIN_CONF}
    fi

    # Create log directory and empty log file
    mkdir -p ${MLMMJADMIN_LOG_DIR}
    touch ${MLMMJADMIN_LOG_FILE}
    chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${MLMMJADMIN_LOG_DIR} ${MLMMJADMIN_LOG_FILE}
    chmod 0640 ${MLMMJADMIN_LOG_FILE}

    ECHO_DEBUG "Generate modular syslog and log rotate config files for mlmmjadmin."
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        #
        # modular syslog config file
        #
        cp ${SAMPLE_DIR}/rsyslog.d/1-iredmail-mlmmjadmin.conf ${SYSLOG_CONF_DIR}

        perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/1-iredmail-mlmmjadmin.conf
        perl -pi -e 's#PH_MLMMJADMIN_LOG_FILE#$ENV{MLMMJADMIN_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/1-iredmail-mlmmjadmin.conf

        #
        # modular logrotate config file
        #
        cp -f ${SAMPLE_DIR}/logrotate/mlmmjadmin ${MLMMJADMIN_LOGROTATE_FILE}
        chmod 0644 ${MLMMJADMIN_LOGROTATE_FILE}

        perl -pi -e 's#PH_MLMMJADMIN_LOG_DIR#$ENV{MLMMJADMIN_LOG_DIR}#g' ${MLMMJADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYSLOG_POSTROTATE_CMD#$ENV{SYSLOG_POSTROTATE_CMD}#g' ${MLMMJADMIN_LOGROTATE_FILE}
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        #
        # modular syslog config file
        #
        cp -f ${SAMPLE_DIR}/freebsd/syslog.d/mlmmjadmin.conf ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/mlmmjadmin.conf
        perl -pi -e 's#PH_MLMMJADMIN_LOG_FILE#$ENV{MLMMJADMIN_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/mlmmjadmin.conf

        #
        # modular newsyslog (log rotate) config file
        #
        cp -f ${SAMPLE_DIR}/freebsd/newsyslog.conf.d/mlmmjadmin ${MLMMJADMIN_LOGROTATE_FILE}

        perl -pi -e 's#PH_MLMMJADMIN_LOG_FILE#$ENV{MLMMJADMIN_LOG_FILE}#g' ${MLMMJADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_MLMMJADMIN_PID_FILE#$ENV{MLMMJADMIN_PID_FILE}#g' ${MLMMJADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_USER_SYSLOG#$ENV{SYS_USER_SYSLOG}#g' ${MLMMJADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_GROUP_SYSLOG#$ENV{SYS_GROUP_SYSLOG}#g' ${MLMMJADMIN_LOGROTATE_FILE}

    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep "${MLMMJADMIN_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
            # '!!' means abort further evaluation after first match
            echo '' >> ${SYSLOG_CONF}
            echo '!!mlmmjadmin' >> ${SYSLOG_CONF}
            echo "${IREDMAIL_SYSLOG_FACILITY}.*        ${MLMMJADMIN_LOG_FILE}" >> ${SYSLOG_CONF}
        fi

        if ! grep "${MLMMJADMIN_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            cat >> /etc/newsyslog.conf <<EOF
${MLMMJADMIN_LOG_FILE}    ${SYS_USER_MLMMJ}:${SYS_GROUP_MLMMJ}   600  7     *    24    Z
EOF
        fi
    fi

    # Copy rc script file
    if [ X"${USE_SYSTEMD}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            cp -f ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/systemd/rhel.service ${SYSTEMD_SERVICE_DIR}/${MLMMJADMIN_RC_SCRIPT_NAME}.service >> ${INSTALL_LOG} 2>&1
            chmod 0644 ${SYSTEMD_SERVICE_DIR}/${MLMMJADMIN_RC_SCRIPT_NAME}.service
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            cp -f ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/systemd/debian.service ${SYSTEMD_SERVICE_DIR}/${MLMMJADMIN_RC_SCRIPT_NAME}.service >> ${INSTALL_LOG} 2>&1
            chmod 0644 ${SYSTEMD_SERVICE_DIR}/${MLMMJADMIN_RC_SCRIPT_NAME}.service
        fi

        systemctl daemon-reload >> ${INSTALL_LOG} 2>&1
    else
        if [ X"${DISTRO}" == X'RHEL' ]; then
            cp ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/${MLMMJADMIN_RC_SCRIPT_NAME}.rhel ${MLMMJADMIN_RC_SCRIPT_PATH} >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            cp ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/${MLMMJADMIN_RC_SCRIPT_NAME}.debian ${MLMMJADMIN_RC_SCRIPT_PATH} >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'FREEBSD' ]; then
            cp ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/${MLMMJADMIN_RC_SCRIPT_NAME}.freebsd ${MLMMJADMIN_RC_SCRIPT_PATH} >> ${INSTALL_LOG} 2>&1
            service_control enable 'mlmmjadmin_enable' 'YES' >> ${INSTALL_LOG} 2>&1
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            cp ${MLMMJADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.openbsd ${MLMMJADMIN_RC_SCRIPT_PATH} >> ${INSTALL_LOG} 2>&1
            chmod 0755 ${MLMMJADMIN_RC_SCRIPT_PATH} >> ${INSTALL_LOG} 2>&1
            rcctl enable mlmmjadmin
        fi
    fi

    ECHO_DEBUG "Make mlmmjadmin starting after system startup."
    service_control enable ${MLMMJADMIN_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1
    export ENABLED_SERVICES="${ENABLED_SERVICES} ${MLMMJADMIN_RC_SCRIPT_NAME}"

    echo 'export status_mlmmjadmin_config="DONE"' >> ${STATUS_FILE}
}
