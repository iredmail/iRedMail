#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# Add required system accounts

add_user_vmail()
{
    ECHO_DEBUG "Create HOME folder for vmail user."

    homedir="$(dirname $(echo ${VMAIL_USER_HOME_DIR} | sed 's#/$##'))"
    [ -L ${homedir} ] && rm -f ${homedir}
    [ -d ${homedir} ] || mkdir -p ${homedir}
    [ -d ${STORAGE_BASE_DIR}/${STORAGE_NODE} ] || mkdir -p ${STORAGE_BASE_DIR}/${STORAGE_NODE}

    ECHO_DEBUG "Create system user/group: vmail:vmail."

    # It will create a group with the same name as vmail user name.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        pw useradd -n ${VMAIL_USER_NAME} -s ${SHELL_NOLOGIN} -d ${VMAIL_USER_HOME_DIR} -m 2>/dev/null
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        groupadd ${VMAIL_GROUP_NAME}
        useradd -d ${VMAIL_USER_HOME_DIR} -s ${SHELL_NOLOGIN} -g ${VMAIL_GROUP_NAME} ${VMAIL_USER_NAME}
    elif [ X"${DISTRO}" == X"SUSE" ]; then
        # Note: package 'postfix-mysql' will create vmail:vmail, with uid/gid=303.
        groupadd ${VMAIL_GROUP_NAME} 2>/dev/null
        useradd -m -d ${VMAIL_USER_HOME_DIR} -s ${SHELL_NOLOGIN} -g ${VMAIL_GROUP_NAME} ${VMAIL_USER_NAME} 2>/dev/null
    else
        useradd -m -d ${VMAIL_USER_HOME_DIR} -s ${SHELL_NOLOGIN} ${VMAIL_USER_NAME} 2>/dev/null
    fi
    rm -f ${VMAIL_USER_HOME_DIR}/.* 2>/dev/null

    # Export vmail user uid/gid.
    export VMAIL_USER_UID="$(id -u ${VMAIL_USER_NAME})"
    export VMAIL_USER_GID="$(id -g ${VMAIL_USER_NAME})"

    # Set permission for exist home directory.
    if [ -d ${VMAIL_USER_HOME_DIR} ]; then
        chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${VMAIL_USER_HOME_DIR}
        chmod -R 0700 ${VMAIL_USER_HOME_DIR}
    fi

    ECHO_DEBUG "Create directory to store user sieve rule files: ${SIEVE_DIR}."
    mkdir -p ${SIEVE_DIR} && \
    chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${SIEVE_DIR} && \
    chmod -R 0700 ${SIEVE_DIR}

    cat >> ${TIP_FILE} <<EOF
Mail Storage:
    - Path:
        + ${VMAIL_USER_HOME_DIR}
        + ${STORAGE_BASE_DIR}/${STORAGE_NODE}

EOF

    echo 'export status_add_user_vmail="DONE"' >> ${STATUS_FILE}
}

add_user_iredadmin()
{
    ECHO_DEBUG "Create system user: iredadmin."

    # Low privilege user used to run iRedAdmin.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        pw useradd -m -d ${IREDADMIN_HOME_DIR} -s ${SHELL_NOLOGIN} -n ${IREDADMIN_HTTPD_USER}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        groupadd ${IREDADMIN_HTTPD_GROUP} 2>/dev/null
        useradd -m -d ${IREDADMIN_HOME_DIR} -s ${SHELL_NOLOGIN} -g ${IREDADMIN_HTTPD_GROUP} ${IREDADMIN_HTTPD_USER} 2>/dev/null
    elif [ X"${DISTRO}" == X"SUSE" ]; then
        groupadd ${IREDADMIN_HTTPD_GROUP}
        useradd -m -d ${IREDADMIN_HOME_DIR} -s ${SHELL_NOLOGIN} -g ${IREDADMIN_HTTPD_GROUP} ${IREDADMIN_HTTPD_USER} 2>/dev/null
    else
        useradd -m -d ${IREDADMIN_HOME_DIR} -s ${SHELL_NOLOGIN} ${IREDADMIN_HTTPD_GROUP}
    fi

    echo 'export status_add_user_iredadmin="DONE"' >> ${STATUS_FILE}
}

add_user_iredapd()
{
    ECHO_DEBUG "Create system user: iredapd."

    # Low privilege user used to run iRedAPD daemon.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        pw useradd -m -d ${IREDAPD_HOME_DIR} -s ${SHELL_NOLOGIN} -c "iRedAPD daemon user" -n ${IREDAPD_DAEMON_USER}
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        groupadd ${IREDAPD_DAEMON_GROUP}
        useradd -m -d ${IREDAPD_HOME_DIR} -s ${SHELL_NOLOGIN} -g ${IREDAPD_DAEMON_GROUP} ${IREDAPD_DAEMON_USER} 2>/dev/null
    elif [ X"${DISTRO}" == X"SUSE" ]; then
        groupadd ${IREDAPD_DAEMON_GROUP}
        useradd -m -d ${IREDAPD_HOME_DIR} -s ${SHELL_NOLOGIN} -g ${IREDAPD_DAEMON_GROUP} ${IREDAPD_DAEMON_USER} 2>/dev/null
    else
        useradd -m -d ${IREDAPD_HOME_DIR} -s ${SHELL_NOLOGIN} -c "iRedAPD daemon user" ${IREDAPD_DAEMON_USER}
    fi

    echo 'export status_add_user_iredapd="DONE"' >> ${STATUS_FILE}
}

add_required_users()
{
    ECHO_INFO "Create required system accounts: vmail, iredapd, iredadmin."
    check_status_before_run add_user_vmail
    check_status_before_run add_user_iredadmin
    check_status_before_run add_user_iredapd
}
