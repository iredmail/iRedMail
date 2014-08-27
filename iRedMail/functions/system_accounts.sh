#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# Add required system accounts

add_user_vmail()
{
    ECHO_INFO "Create required system account: ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME}."

    ECHO_DEBUG "Create HOME folder for vmail user."
    homedir="$(dirname $(echo ${VMAIL_USER_HOME_DIR} | sed 's#/$##'))"
    [ -L ${homedir} ] && rm -f ${homedir}
    [ -d ${homedir} ] || mkdir -p ${homedir}
    [ -d ${STORAGE_MAILBOX_DIR} ] || mkdir -p ${STORAGE_MAILBOX_DIR}

    ECHO_DEBUG "Create system account: ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} (${VMAIL_USER_UID}:${VMAIL_USER_GID})."

    # vmail/vmail must has the same UID/GID on all supported Linux/BSD
    # distributions, required by cluster environment. e.g. GlusterFS.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        pw groupadd -g ${VMAIL_USER_GID} -n ${VMAIL_GROUP_NAME} &>/dev/null
        pw useradd -m \
            -u ${VMAIL_USER_UID} \
            -g ${VMAIL_GROUP_NAME} \
            -s ${SHELL_NOLOGIN} \
            -d ${VMAIL_USER_HOME_DIR} \
            -n ${VMAIL_USER_NAME} &>/dev/null
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        groupadd -g ${VMAIL_USER_GID} ${VMAIL_GROUP_NAME} &>/dev/null
        # Don't use -m to create new home directory
        useradd \
            -u ${VMAIL_USER_UID} \
            -g ${VMAIL_GROUP_NAME} \
            -s ${SHELL_NOLOGIN} \
            -d ${VMAIL_USER_HOME_DIR} \
            ${VMAIL_USER_NAME} &>/dev/null
    else
        groupadd -g ${VMAIL_USER_GID} ${VMAIL_GROUP_NAME} &>/dev/null
        useradd -m \
            -u ${VMAIL_USER_UID} \
            -g ${VMAIL_GROUP_NAME} \
            -s ${SHELL_NOLOGIN} \
            -d ${VMAIL_USER_HOME_DIR} \
            ${VMAIL_USER_NAME} &>/dev/null
    fi
    rm -f ${VMAIL_USER_HOME_DIR}/.* &>/dev/null

    export FIRST_USER_MAILDIR_HASH_PART="$(hash_domain ${FIRST_DOMAIN})/$(hash_maildir ${FIRST_USER})"
    export FIRST_USER_MAILDIR_FULL_PATH="${STORAGE_MAILBOX_DIR}/${FIRST_USER_MAILDIR_HASH_PART}"
    # Create maildir.
    # We will deliver emails with sensitive info of iRedMail installation
    # to postmaster immediately after installation completed.
    # NOTE: 'Maildir/' is appended by Dovecot (defined in dovecot.conf).
    export FIRST_USER_MAILDIR_INBOX="${FIRST_USER_MAILDIR_FULL_PATH}/Maildir/new"
    mkdir -p ${FIRST_USER_MAILDIR_INBOX} &>/dev/null

    # Reset permission for home directory. Required by FIRST_USER_MAILDIR_FULL_PATH.
    chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${VMAIL_USER_HOME_DIR}
    chmod -R 0700 ${VMAIL_USER_HOME_DIR}

    ECHO_DEBUG "Create directory to store user sieve rule files: ${SIEVE_DIR}."
    mkdir -p ${SIEVE_DIR} && \
    chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${SIEVE_DIR} && \
    chmod -R 0700 ${SIEVE_DIR}

    cat >> ${TIP_FILE} <<EOF
Mail Storage:
    - Root directory: ${VMAIL_USER_HOME_DIR}
    - Mailboxes: ${STORAGE_MAILBOX_DIR}
    - Backup scripts and copies: ${BACKUP_DIR}

EOF

    echo 'export status_add_user_vmail="DONE"' >> ${STATUS_FILE}
}

add_user_iredadmin()
{
    ECHO_INFO "Create required system account: ${IREDADMIN_USER_NAME}:${IREDADMIN_GROUP_NAME}."

    ECHO_DEBUG "Create system account: ${IREDADMIN_USER_NAME}:${IREDADMIN_GROUP_NAME} (${IREDADMIN_USER_UID}:${IREDADMIN_USER_GID})"
    # Low privilege user used to run iRedAdmin.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        pw groupadd -g ${IREDADMIN_USER_GID} -n ${IREDADMIN_USER_NAME} &>/dev/null
        pw useradd -m \
            -u ${IREDADMIN_USER_GID} \
            -g ${IREDADMIN_GROUP_NAME} \
            -s ${SHELL_NOLOGIN} \
            -d ${IREDADMIN_HOME_DIR} \
            -n ${IREDADMIN_USER_NAME} &>/dev/null
    else
        groupadd -g ${IREDADMIN_USER_GID} ${IREDADMIN_GROUP_NAME} &>/dev/null
        useradd -m \
            -u ${IREDADMIN_USER_UID} \
            -g ${IREDADMIN_GROUP_NAME} \
            -s ${SHELL_NOLOGIN} \
            -d ${IREDADMIN_HOME_DIR} \
            ${IREDADMIN_USER_NAME} &>/dev/null
    fi

    echo 'export status_add_user_iredadmin="DONE"' >> ${STATUS_FILE}
}

add_user_iredapd()
{
    ECHO_INFO "Create required system account: ${IREDAPD_DAEMON_USER}:${IREDAPD_DAEMON_GROUP}."
    ECHO_DEBUG "Create system account: ${IREDAPD_DAEMON_USER}:${IREDAPD_DAEMON_GROUP} (${IREDAPD_DAEMON_USER_UID}:${IREDAPD_DAEMON_USER_GID})."

    # Low privilege user used to run iRedAPD daemon.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        pw groupadd -g ${IREDAPD_DAEMON_USER_GID} -n ${IREDAPD_DAEMON_GROUP} &>/dev/null
        pw useradd -m \
            -u ${IREDAPD_DAEMON_USER_GID} \
            -g ${IREDAPD_DAEMON_GROUP} \
            -s ${SHELL_NOLOGIN} \
            -d ${IREDAPD_HOME_DIR} \
            -n ${IREDAPD_DAEMON_USER} &>/dev/null
    else
        groupadd -g ${IREDAPD_DAEMON_USER_GID} ${IREDAPD_DAEMON_GROUP} &>/dev/null
        useradd -m \
            -u ${IREDAPD_DAEMON_USER_UID} \
            -g ${IREDAPD_DAEMON_GROUP} \
            -s ${SHELL_NOLOGIN} \
            -d ${IREDAPD_HOME_DIR} \
            ${IREDAPD_DAEMON_USER} &>/dev/null
    fi

    echo 'export status_add_user_iredapd="DONE"' >> ${STATUS_FILE}
}

add_required_users()
{
    check_status_before_run add_user_vmail
    check_status_before_run add_user_iredadmin
    check_status_before_run add_user_iredapd

    echo 'export status_add_required_users="DONE"' >> ${STATUS_FILE}
}
