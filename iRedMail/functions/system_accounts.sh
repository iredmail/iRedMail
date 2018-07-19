#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# Add required system accounts

add_user_vmail()
{
    ECHO_DEBUG "Create system account: ${SYS_USER_VMAIL}:${SYS_GROUP_VMAIL} (${SYS_USER_VMAIL_UID}:${SYS_GROUP_VMAIL_GID})."

    # Create STORAGE_BASE_DIR and set correct owner and permission.
    if [ ! -d ${STORAGE_BASE_DIR} ]; then
        mkdir -p ${STORAGE_BASE_DIR} >> ${INSTALL_LOG} 2>&1
        chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${STORAGE_BASE_DIR} >> ${INSTALL_LOG} 2>&1
        chmod -R 0755 ${STORAGE_BASE_DIR} >> ${INSTALL_LOG} 2>&1
    fi

    [ -d ${STORAGE_MAILBOX_DIR} ] || mkdir -p ${STORAGE_MAILBOX_DIR} >> ${INSTALL_LOG} 2>&1
    [ -d ${PUBLIC_MAILBOX_DIR} ] || mkdir -p ${PUBLIC_MAILBOX_DIR} >> ${INSTALL_LOG} 2>&1

    # vmail/vmail must has the same UID/GID on all supported Linux/BSD
    # distributions, required by cluster environment. e.g. GlusterFS.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        pw groupadd -g ${SYS_GROUP_VMAIL_GID} -n ${SYS_GROUP_VMAIL}
        pw useradd -m \
            -u ${SYS_USER_VMAIL_UID} \
            -g ${SYS_GROUP_VMAIL} \
            -s ${SHELL_NOLOGIN} \
            -n ${SYS_USER_VMAIL} >> ${INSTALL_LOG} 2>&1
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        groupadd -g ${SYS_GROUP_VMAIL_GID} ${SYS_GROUP_VMAIL} >> ${INSTALL_LOG} 2>&1
        # Don't use -m to create new home directory
        useradd \
            -u ${SYS_USER_VMAIL_UID} \
            -g ${SYS_GROUP_VMAIL} \
            -s ${SHELL_NOLOGIN} \
            ${SYS_USER_VMAIL} >> ${INSTALL_LOG} 2>&1
    else
        groupadd -g ${SYS_GROUP_VMAIL_GID} ${SYS_GROUP_VMAIL} >> ${INSTALL_LOG} 2>&1
        useradd -m \
            -u ${SYS_USER_VMAIL_UID} \
            -g ${SYS_GROUP_VMAIL} \
            -s ${SHELL_NOLOGIN} \
            ${SYS_USER_VMAIL} >> ${INSTALL_LOG} 2>&1
    fi

    if [ -n "${MAILBOX_INDEX_DIR}" ]; then
        if [ ! -d ${MAILBOX_INDEX_DIR} ]; then
            ECHO_DEBUG "Create directory used to store mailbox indexes: ${MAILBOX_INDEX_DIR}."
            mkdir -p ${MAILBOX_INDEX_DIR} >> ${INSTALL_LOG} 2>&1
            chown -R ${SYS_USER_VMAIL}:${SYS_GROUP_VMAIL} ${MAILBOX_INDEX_DIR}
            chmod -R 0700 ${MAILBOX_INDEX_DIR}
        fi
    fi

    ECHO_DEBUG "Create directory used to store global sieve filters: ${SIEVE_DIR}."
    mkdir -p ${SIEVE_DIR} &>/dev/null

    export DOMAIN_ADMIN_MAILDIR_HASH_PART="${FIRST_DOMAIN}/$(hash_maildir --no-timestamp ${DOMAIN_ADMIN_NAME})"
    export DOMAIN_ADMIN_MAILDIR_FULL_PATH="${STORAGE_MAILBOX_DIR}/${DOMAIN_ADMIN_MAILDIR_HASH_PART}"

    # Create maildir.
    # We will deliver emails with sensitive info of iRedMail installation
    # to postmaster immediately after installation completed.
    # NOTE: 'Maildir/' is appended by Dovecot (defined in dovecot.conf).
    export DOMAIN_ADMIN_MAILDIR_INBOX="${DOMAIN_ADMIN_MAILDIR_FULL_PATH}/Maildir/new"
    mkdir -p ${DOMAIN_ADMIN_MAILDIR_INBOX} >> ${INSTALL_LOG} 2>&1

    # set owner/group and permission.
    chown -R ${SYS_USER_VMAIL}:${SYS_GROUP_VMAIL} ${STORAGE_MAILBOX_DIR} ${PUBLIC_MAILBOX_DIR} ${SIEVE_DIR}
    chmod -R 0700 ${STORAGE_MAILBOX_DIR} ${PUBLIC_MAILBOX_DIR} ${SIEVE_DIR}

    # backup directory
    [ -d ${BACKUP_DIR} ] || mkdir -p ${BACKUP_DIR} &>/dev/null
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${BACKUP_DIR}
    chmod 0700 ${BACKUP_DIR}

    cat >> ${TIP_FILE} <<EOF
Mail Storage:
    - Mailboxes: ${STORAGE_MAILBOX_DIR}
    - Mailbox indexes: ${MAILBOX_INDEX_DIR}
    - Global sieve filters: ${SIEVE_DIR}
    - Backup scripts and backup copies: ${BACKUP_DIR}

EOF

    echo 'export status_add_user_vmail="DONE"' >> ${STATUS_FILE}
}

add_user_iredadmin()
{
    add_sys_user_group \
        ${SYS_USER_IREDADMIN} \
        ${SYS_GROUP_IREDADMIN} \
        ${SYS_USER_IREDADMIN_UID} \
        ${SYS_GROUP_IREDADMIN_GID}

    echo 'export status_add_user_iredadmin="DONE"' >> ${STATUS_FILE}
}

add_user_mlmmj()
{
    add_sys_user_group \
        ${SYS_USER_MLMMJ} \
        ${SYS_GROUP_MLMMJ} \
        ${SYS_USER_MLMMJ_UID} \
        ${SYS_GROUP_MLMMJ_GID} \
        ${MLMMJ_HOME_DIR}

    echo 'export status_add_user_mlmmj="DONE"' >> ${STATUS_FILE}
}

add_user_iredapd()
{
    add_sys_user_group \
        ${SYS_USER_IREDAPD} \
        ${SYS_GROUP_IREDAPD} \
        ${SYS_USER_IREDAPD_UID} \
        ${SYS_GROUP_IREDAPD_GID}

    echo 'export status_add_user_iredapd="DONE"' >> ${STATUS_FILE}
}

add_user_netdata()
{
    add_sys_user_group \
        ${SYS_USER_NETDATA} \
        ${SYS_GROUP_NETDATA} \
        ${SYS_USER_NETDATA_UID} \
        ${SYS_GROUP_NETDATA_GID}

    echo 'export status_add_user_netdata="DONE"' >> ${STATUS_FILE}
}


add_required_users()
{
    ECHO_INFO "Create required system accounts."

    check_status_before_run add_user_vmail
    check_status_before_run add_user_mlmmj
    check_status_before_run add_user_iredadmin
    check_status_before_run add_user_iredapd

    [ X"${USE_NETDATA}" == X'YES' ] && check_status_before_run add_user_netdata
}
