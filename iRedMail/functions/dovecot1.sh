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
# Dovecot & dovecot-sieve.
# -------------------------------------------------------

# For dovecot SSL support.
dovecot_ssl_config()
{
    ECHO_DEBUG "Enable TLS support."

    if [ X"${ENABLE_DOVECOT_SSL}" == X"YES" ]; then
        cat >> ${DOVECOT_CONF} <<EOF
# SSL support.
ssl = required
verbose_ssl = no
ssl_key_file = ${SSL_KEY_FILE}
ssl_cert_file = ${SSL_CERT_FILE}
ssl_ca_file = ${SSL_CERT_FILE}
EOF
    fi

    echo 'export status_dovecot_ssl_config="DONE"' >> ${STATUS_FILE}
}

dovecot_config()
{
    ECHO_INFO "Configure Dovecot (pop3/imap server, version ${DOVECOT_VERSION})."

    [ X"${ENABLE_DOVECOT}" == X"YES" ] && \
        backup_file ${DOVECOT_CONF} && \
        chmod 0664 ${DOVECOT_CONF} && \
        ECHO_DEBUG "Configure dovecot: ${DOVECOT_CONF}."

        cat > ${DOVECOT_CONF} <<EOF
${CONF_MSG}
EOF

        cat >> ${DOVECOT_CONF} <<EOF
# Provided services.
protocols = ${DOVECOT_PROTOCOLS}

# Listen addresses. for Dovecot-1.x.
# ipv4: *
# ipv6: [::]
#listen = *, [::]
listen = *

# mail uid/gid.
mail_uid = ${VMAIL_USER_UID}
mail_gid = ${VMAIL_USER_GID}
first_valid_uid = ${VMAIL_USER_UID}
last_valid_uid = ${VMAIL_USER_UID}

# Master user.
# Master users are able to log in as other users. It's also possible to
# directly log in as any user using a master password, although this isn't
# recommended.
# Reference: http://wiki1.dovecot.org/Authentication/MasterUsers
auth_master_user_separator = *

#
# Debug options.
#
#mail_debug = yes
#auth_verbose = yes
#auth_debug = yes
#auth_debug_passwords = yes

#
# Log file.
#
#log_timestamp = "%Y-%m-%d %H:%M:%S "
log_path = ${DOVECOT_LOG_FILE}

# Set max process size in megabytes. Default is 256.
# Most of the memory goes to mmap()ing files, so it shouldn't harm
# much even if this limit is set pretty high.
#
# Note:
# Some user reported that if mailbox is too large (e.g. 80GB), dovecot
# will disconnect the client with error:
# "pool_system_malloc(100248): Out of memory".
mail_process_size = 1024

# With disable_plaintext_auth=yes, STARTTLS is mandatory.
# Set disable_plaintext_auth=no AND ssl=yes to allow plain password transmitted
# insecurely.
disable_plaintext_auth = yes

# Performance Tuning. Reference:
#   http://wiki.dovecot.org/LoginProcess
#
# High-Security mode. Dovecot default setting.
#
# It works by using a new imap-login or pop3-login process for each
# incoming connection. Since the processes run in a highly restricted
# chroot, running each connection in a separate process means that in
# case there is a security hole in Dovecot's pre-authentication code
# or in the SSL library, the attacker can't see other users'
# connections and can't really do anything destructive.
login_process_per_connection=yes

#
# High-Performance mode.
#
# It works by using a number of long running login processes,
# each handling a number of connections. This loses much of
# the security benefits of the login process design, because
# in case of a security hole the attacker is now able to see
# other users logging in and steal their passwords.
#login_process_per_connection = no

# Default realm/domain to use if none was specified.
# This is used for both SASL realms and appending '@domain.ltd' to username in plaintext logins.
auth_default_realm = ${FIRST_DOMAIN}

# ---- NFS storage ----
# Set to 'no' For NFSv2. Default is 'yes'.
#dotlock_use_excl = yes

#mail_nfs_storage = yes # v1.1+ only

# If indexes are on NFS.
#mail_nfs_index = yes # v1.1+ only
# ----

plugin {
    # Quota warning.
    #
    # You can find sample script from Dovecot wiki:
    # http://wiki.dovecot.org/Quota/1.1#head-03d8c4f6fb28e2e2f1cb63ec623810b45bec1734
    #
    # If user suddenly receives a huge mail and the quota jumps from
    # 85% to 95%, only the 95% script is executed.
    #
    quota_warning = storage=85%% ${DOVECOT_QUOTA_WARNING_SCRIPT} 85
    quota_warning2 = storage=90%% ${DOVECOT_QUOTA_WARNING_SCRIPT} 90
    quota_warning3 = storage=95%% ${DOVECOT_QUOTA_WARNING_SCRIPT} 95
}

EOF

    # Generate dovecot quota warning script.
    mkdir -p $(dirname ${DOVECOT_QUOTA_WARNING_SCRIPT}) 2>/dev/null

    backup_file ${DOVECOT_QUOTA_WARNING_SCRIPT}
    rm -rf ${DOVECOT_QUOTA_WARNING_SCRIPT} 2>/dev/null

    cat > ${DOVECOT_QUOTA_WARNING_SCRIPT} <<FOE
#!/usr/bin/env bash
${CONF_MSG}

PERCENT=\${1}

cat << EOF | ${DOVECOT_DELIVER} -d \${USER} -c ${DOVECOT_CONF}
From: no-reply@${HOSTNAME}
To: \${USER}
Subject: Mailbox Quota Warning: \${PERCENT}% Full.

Your mailbox is now \${PERCENT}% full, please clean up some mails for
further incoming mails.

EOF
FOE

    chown root ${DOVECOT_QUOTA_WARNING_SCRIPT}
    chmod 0755 ${DOVECOT_QUOTA_WARNING_SCRIPT}

    # Use '/usr/local/bin/bash' as shabang line, otherwise quota waning will be failed.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        perl -pi -e 's#(.*)/usr/bin/env bash.*#${1}/usr/local/bin/bash#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    # Enable SSL support.
    [ X"${ENABLE_DOVECOT_SSL}" == X"YES" ] && dovecot_ssl_config

    # Mailbox format.
    if [ X"${MAILBOX_FORMAT}" == X"Maildir" ]; then
        cat >> ${DOVECOT_CONF} <<EOF
# Maildir format and location.
mail_location = maildir:/%Lh/Maildir/:INDEX=/%Lh/Maildir/

plugin {
    # Quota, stored in file 'maildirsize' under user mailbox.
EOF

        if [ X"${DOVECOT_VERSION}" == X"1.2" ]; then
            cat >> ${DOVECOT_CONF} <<EOF
    # Dict quota. Used to store realtime quota in SQL.
    # Dict quota is recalculated only if the quota goes below zero. For example:
    #
    #   mysql> UPDATE mailbox SET bytes=-1,messages=-1 WHERE username='user@domain.ltd';
    #
    quota = dict:user::proxy::quotadict
EOF
        else
            cat >> ${DOVECOT_CONF} <<EOF
    quota = maildir
EOF
        fi

        cat >> ${DOVECOT_CONF} <<EOF
    # Quota rules. Reference: http://wiki.dovecot.org/Quota/1.1
    # The following limit names are supported:
    #   - storage: Quota limit in kilobytes, 0 means unlimited.
    #   - bytes: Quota limit in bytes, 0 means unlimited.
    #   - messages: Quota limit in number of messages, 0 means unlimited. This probably isn't very useful.
    #   - backend: Quota backend-specific limit configuration.
    #   - ignore: Don't include the specified mailbox in quota at all (v1.1.rc5+).
    quota_rule = *:storage=0
    #quota_rule2 = *:messages=0
    #quota_rule3 = Trash:storage=1G
    #quota_rule4 = Junk:ignore
}

dict {
    # NOTE: dict process currently runs as root, so this file will be owned as root.
    #expire = db:${DOVECOT_EXPIRE_DICT_BDB}
}

plugin {
    # ---- Expire plugin ----
    # Expire plugin. Mails are expunged from mailboxes after being there the
    # configurable time. The first expiration date for each mailbox is stored in
    # a dictionary so it can be quickly determined which mailboxes contain
    # expired mails. The actual expunging is done in a nightly cronjob, which
    # you must set up:
    #
    #   1   3   *   *   *   ${DOVECOT_BIN} --exec-mail ext /usr/libexec/dovecot/expire-tool
    #
    # Trash: 7 days
    # Trash's children directories: 7 days
    # Junk: 30 days
    #expire = Trash 7 Trash/* 7 Junk 30
    #expire_dict = proxy::expire

    # If you have a non-default path to auth-master, set also:
    auth_socket_path = ${DOVECOT_AUTH_SOCKET_PATH}
}

# Per-user sieve mail filter.
plugin {
    # For maildir format.
    #sieve = ${SIEVE_DIR}/%Ld/%Ln/${SIEVE_RULE_FILENAME}
    sieve = /%Lh/sieve/${SIEVE_RULE_FILENAME}
}
EOF
    else
        :
    fi

    cat >> ${DOVECOT_CONF} <<EOF
# LDA: Local Deliver Agent
protocol lda {
    postmaster_address = root
    auth_socket_path = ${DOVECOT_AUTH_SOCKET_PATH}
    mail_plugins = ${DOVECOT_LDA_PLUGINS}
    sieve_global_path = ${DOVECOT_GLOBAL_SIEVE_FILE}
    log_path = ${SIEVE_LOG_FILE}
}

# IMAP configuration
protocol imap {
    mail_plugins = ${DOVECOT_IMAP_PLUGINS}

    imap_client_workarounds = tb-extra-mailbox-sep

    # number of connections per-user per-IP
    #mail_max_userip_connections = 10
}

# POP3 configuration
protocol pop3 {
    mail_plugins = quota
    pop3_uidl_format = %08Xu%08Xv
    pop3_client_workarounds = outlook-no-nuls oe-ns-eoh

    # number of connections per-user per-IP
    #mail_max_userip_connections = 10
}

auth default {
    mechanisms = plain login
    user = ${VMAIL_USER_NAME}

    # Master user.
    passdb passwd-file {
        args = ${DOVECOT_MASTER_USER_PASSWORD_FILE}
        master = yes
    }
EOF

    # Master user password file.
    touch ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chmod 0550 ${DOVECOT_MASTER_USER_PASSWORD_FILE}

    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        cat >> ${DOVECOT_CONF} <<EOF
    passdb ldap {
        args = ${DOVECOT_LDAP_CONF}
    }
    userdb ldap {
        args = ${DOVECOT_LDAP_CONF}
    }
EOF

        backup_file ${DOVECOT_LDAP_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-ldap.conf ${DOVECOT_LDAP_CONF}

        perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BIND_VERSION#$ENV{LDAP_BIND_VERSION}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BINDPW#$ENV{LDAP_BINDPW}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#' ${DOVECOT_LDAP_CONF}
        perl -pi -e 's#PH_STORAGE_BASE_DIR#$ENV{STORAGE_BASE_DIR}#' ${DOVECOT_LDAP_CONF}

        # Set file permission.
        chmod 0500 ${DOVECOT_LDAP_CONF}

    else
        # SQL backend.
        cat >> ${DOVECOT_CONF} <<EOF
    passdb sql {
        args = ${DOVECOT_MYSQL_CONF}
    }
    userdb sql {
        args = ${DOVECOT_MYSQL_CONF}
    }
EOF

        backup_file ${DOVECOT_MYSQL_CONF}
        cp -f ${SAMPLE_DIR}/dovecot/dovecot-sql.conf ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#(.*mailbox.)(enable.*Lc)(=1)#${1}`${2}`${3}#' ${DOVECOT_MYSQL_CONF}

        perl -pi -e 's#PH_SQL_DRIVER#mysql#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_SQL_SERVER#$ENV{MYSQL_SERVER}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB#$ENV{VMAIL_DB}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#' ${DOVECOT_MYSQL_CONF}
        perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#' ${DOVECOT_MYSQL_CONF}

        # Set file permission.
        chmod 0550 ${DOVECOT_MYSQL_CONF}
    fi

    cat >> ${DOVECOT_CONF} <<EOF
    socket listen {
        master {
            path = ${DOVECOT_AUTH_SOCKET_PATH}
            mode = 0666
            user = ${VMAIL_USER_NAME}
            group = ${VMAIL_GROUP_NAME}
        }
        client {
            path = ${DOVECOT_SOCKET_MUX}
            mode = 0666
            user = ${POSTFIX_DAEMON_USER}
            group = ${POSTFIX_DAEMON_GROUP}
        }
    }
}
EOF

    # IMAP plugin: autocreate.
    if [ X"${DOVECOT_VERSION}" == X"1.2" ]; then
        cat >> ${DOVECOT_CONF} <<EOF
plugin {
    autocreate = INBOX
    autocreate2 = Sent
    autocreate3 = Trash
    autocreate4 = Drafts
    autocreate5 = Junk

    autosubscribe = INBOX
    autosubscribe2 = Sent
    autosubscribe3 = Trash
    autosubscribe4 = Drafts
    autosubscribe5 = Junk
}
EOF
    fi

    # Create ${DOVECOT_REALTIME_QUOTA_CONF}
    if [ X"${DOVECOT_VERSION}" == X"1.2" ]; then
        backup_file ${DOVECOT_REALTIME_QUOTA_CONF}

        # Enable dict quota in dovecot.
        cat >> ${DOVECOT_CONF} <<EOF
dict {
    # Dict quota. Used to store realtime quota in SQL.
    quotadict = ${DOVECOT_REALTIME_QUOTA_SQLTYPE}:${DOVECOT_REALTIME_QUOTA_CONF}
}
EOF

        if [ X"${BACKEND}" == X"OPENLDAP" ]; then
            export realtime_quota_db_name="${IREDADMIN_DB_NAME}"
            export realtime_quota_db_user="${IREDADMIN_DB_USER}"
            export realtime_quota_db_passwd="${IREDADMIN_DB_PASSWD}"
        else
            export realtime_quota_db_name="${VMAIL_DB}"
            export realtime_quota_db_user="${VMAIL_DB_ADMIN_USER}"
            export realtime_quota_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"
        fi


        # Copy sample config and set file owner/permission
        cp ${SAMPLE_DIR}/dovecot/dovecot-used-quota.conf ${DOVECOT_REALTIME_QUOTA_CONF}
        chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_REALTIME_QUOTA_CONF}
        chmod 0500 ${DOVECOT_REALTIME_QUOTA_CONF}

        # Replace place holders in sample config file
        perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_REALTIME_QUOTA_CONF}
        perl -pi -e 's#PH_REALTIME_QUOTA_DB_NAME#$ENV{realtime_quota_db_name}#' ${DOVECOT_REALTIME_QUOTA_CONF}
        perl -pi -e 's#PH_REALTIME_QUOTA_DB_USER#$ENV{realtime_quota_db_user}#' ${DOVECOT_REALTIME_QUOTA_CONF}
        perl -pi -e 's#PH_REALTIME_QUOTA_DB_PASSWORD#$ENV{realtime_quota_db_passwd}#' ${DOVECOT_REALTIME_QUOTA_CONF}
        perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_TABLE#$ENV{DOVECOT_REALTIME_QUOTA_TABLE}#' ${DOVECOT_REALTIME_QUOTA_CONF}

        # Create MySQL database ${IREDADMIN_DB_USER} and table 'used_quota'
        # which used to store realtime quota.
        if [ X"${BACKEND}" == X"OPENLDAP" -a X"${USE_IREDADMIN}" != X"YES" ]; then
            # If iRedAdmin is not used, create database and import table here.
            mysql -h${MYSQL_SERVER} -P${MYSQL_SERVER_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
# Create databases.
CREATE DATABASE IF NOT EXISTS ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

# Import SQL template.
USE ${IREDADMIN_DB_NAME};
SOURCE ${SAMPLE_DIR}/dovecot/used_quota.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${SQL_HOSTNAME}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";

FLUSH PRIVILEGES;
EOF

        fi
    fi

    # IMAP shared folder
    if [ X"${DOVECOT_VERSION}" == X"1.2" ]; then
        backup_file ${DOVECOT_SHARE_FOLDER_CONF}

        if [ X"${BACKEND}" == X"OPENLDAP" ]; then
            export share_folder_db_name="${IREDADMIN_DB_NAME}"
            export share_folder_db_user="${IREDADMIN_DB_USER}"
            export share_folder_db_passwd="${IREDADMIN_DB_PASSWD}"
        else
            export share_folder_db_name="${VMAIL_DB}"
            export share_folder_db_user="${VMAIL_DB_ADMIN_USER}"
            export share_folder_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"
        fi

        # Enable dict quota in dovecot.
        cat >> ${DOVECOT_CONF} <<EOF
namespace private {
    separator = /
    prefix =
    inbox = yes
    # location defaults to mail_location.
}

namespace shared {
    separator = /
    prefix = Shared/%%u/
    location = maildir:/%%Lh/Maildir/:INDEX=/%%Lh/Maildir/Shared/%%u
    # this namespace should handle its own subscriptions or not.
    subscriptions = yes
    list = children
}

plugin {
    acl = vfile
    acl_shared_dict = proxy::acl

    # By default Dovecot doesn't allow using the IMAP "anyone" or
    # "authenticated" identifier, because it would be an easy way to spam
    # other users in the system. If you wish to allow it,
    #acl_anyone = allow
}
dict {
    acl = ${DOVECOT_SHARE_FOLDER_SQLTYPE}:${DOVECOT_SHARE_FOLDER_CONF}
}
EOF

        # IMAP share folder.
        cp ${SAMPLE_DIR}/dovecot/dovecot-share-folder.conf ${DOVECOT_SHARE_FOLDER_CONF}
        chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_SHARE_FOLDER_CONF}
        chmod 0500 ${DOVECOT_SHARE_FOLDER_CONF}

        # Replace place holders in sample config file
        perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_SHARE_FOLDER_CONF}
        perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_NAME#$ENV{share_folder_db_name}#' ${DOVECOT_SHARE_FOLDER_CONF}
        perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_USER#$ENV{share_folder_db_user}#' ${DOVECOT_SHARE_FOLDER_CONF}
        perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_PASSWORD#$ENV{share_folder_db_passwd}#' ${DOVECOT_SHARE_FOLDER_CONF}
        perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}
        perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}

        # Create MySQL database ${IREDADMIN_DB_USER} and table 'share_folder'
        # which used to store realtime quota.
        if [ X"${BACKEND}" == X"OPENLDAP" -a X"${USE_IREDADMIN}" != X"YES" ]; then
            # If iRedAdmin is not used, create database and import table here.
            mysql -h${MYSQL_SERVER} -P${MYSQL_SERVER_PORT} -u${MYSQL_ROOT_USER} -p"${MYSQL_ROOT_PASSWD}" <<EOF
# Create databases.
CREATE DATABASE IF NOT EXISTS ${IREDADMIN_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

# Import SQL template.
USE ${IREDADMIN_DB_NAME};
SOURCE ${SAMPLE_DIR}/dovecot/imap_share_folder.sql;
GRANT SELECT,INSERT,UPDATE,DELETE ON ${IREDADMIN_DB_NAME}.* TO "${IREDADMIN_DB_USER}"@"${SQL_HOSTNAME}" IDENTIFIED BY "${IREDADMIN_DB_PASSWD}";

FLUSH PRIVILEGES;
EOF
        fi
    fi

    ECHO_DEBUG "Copy sample sieve global filter rule file: ${DOVECOT_GLOBAL_SIEVE_FILE}.sample."
    cp -f ${SAMPLE_DIR}/dovecot/dovecot.sieve ${DOVECOT_GLOBAL_SIEVE_FILE}.sample
    chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${DOVECOT_GLOBAL_SIEVE_FILE}.sample
    chmod 0500 ${DOVECOT_GLOBAL_SIEVE_FILE}.sample

    ECHO_DEBUG "Create dovecot log file: ${DOVECOT_LOG_FILE}, ${SIEVE_LOG_FILE}."
    touch ${DOVECOT_LOG_FILE} ${SIEVE_LOG_FILE}
    chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${DOVECOT_LOG_FILE} ${SIEVE_LOG_FILE}
    chmod 0600 ${DOVECOT_LOG_FILE}

    # Sieve log file must be world-writable.
    chmod 0666 ${SIEVE_LOG_FILE}

    ECHO_DEBUG "Enable dovecot SASL support in postfix: ${POSTFIX_FILE_MAIN_CF}."
    postconf -e mailbox_command="${DOVECOT_DELIVER}"
    [ X"${DISTRO}" == X"SUSE" ] && \
        perl -pi -e 's#^(POSTFIX_MDA=).*#${1}"dovecot"#' ${POSTFIX_SYSCONFIG_CONF}
    postconf -e virtual_transport="${TRANSPORT}"
    postconf -e dovecot_destination_recipient_limit='1'

    postconf -e smtpd_sasl_type='dovecot'
    # It's '/var/spool/postfix/dovecot-auth'.
    # Prepend './' to make postfix recognize it as socket path.
    postconf -e smtpd_sasl_path='./dovecot-auth'

    ECHO_DEBUG "Create directory for Dovecot plugin: Expire."
    dovecot_expire_dict_dir="$(dirname ${DOVECOT_EXPIRE_DICT_BDB})"
    mkdir -p ${dovecot_expire_dict_dir} && \
    chown -R ${DOVECOT_USER}:${DOVECOT_GROUP} ${dovecot_expire_dict_dir} && \
    chmod -R 0750 ${dovecot_expire_dict_dir}

    if [ X"${DISTRO}" == X"RHEL" ]; then
        ECHO_DEBUG "Setting cronjob for Dovecot plugin: Expire."
        cat >> ${CRON_SPOOL_DIR}/root <<EOF
${CONF_MSG}
#1   5   *   *   *   ${DOVECOT_BIN} --exec-mail ext $(eval ${LIST_FILES_IN_PKG} dovecot | grep 'expire-tool$')
EOF
    fi

    cat >> ${POSTFIX_FILE_MASTER_CF} <<EOF
# Use dovecot deliver program as LDA.
dovecot unix    -       n       n       -       -      pipe
    flags=DRhu user=${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} argv=${DOVECOT_DELIVER} -f \${sender} -d \${user}@\${domain} -m \${extension}

EOF

    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        ECHO_DEBUG "Setting logrotate for dovecot log file."
        cat > ${DOVECOT_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${DOVECOT_LOG_FILE} {
    compress
    weekly
    rotate 10
    create 0600 ${VMAIL_USER_NAME} ${VMAIL_GROUP_NAME}
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        /bin/kill -USR1 \$(cat ${DOVECOT_MASTER_PID} 2>/dev/null) 2> /dev/null || true
    endscript
}
EOF

    cat > ${SIEVE_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${SIEVE_LOG_FILE} {
    compress
    weekly
    rotate 10
    create 0666 ${VMAIL_USER_NAME} ${VMAIL_GROUP_NAME}
    missingok
    postrotate
        /bin/kill -USR1 \`cat ${DOVECOT_MASTER_PID} 2>/dev/null\` 2> /dev/null || true
    endscript
}
EOF
    else
        :
    fi

    cat >> ${TIP_FILE} <<EOF
Dovecot:
    * Configuration files:
        - ${DOVECOT_CONF}
        - ${DOVECOT_LDAP_CONF} (For OpenLDAP backend)
        - ${DOVECOT_MYSQL_CONF} (For MySQL backend)
        - ${DOVECOT_REALTIME_QUOTA_CONF}
        - ${DOVECOT_SHARE_FOLDER_CONF} (share folder)
    * RC script: ${DIR_RC_SCRIPTS}/dovecot
    * Log files:
        - ${DOVECOT_LOGROTATE_FILE}
        - ${DOVECOT_LOG_FILE}
        - ${SIEVE_LOG_FILE}
    * See also:
        - ${DOVECOT_GLOBAL_SIEVE_FILE}

EOF

    echo 'export status_enable_dovecot="DONE"' >> ${STATUS_FILE}
}

enable_dovecot1()
{
    if [ X"${ENABLE_DOVECOT}" == X"YES" ]; then
        check_status_before_run dovecot_config
    fi

    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        # It seems there's a bug in Dovecot port, it will try to invoke '/usr/lib/sendmail'
        # to send vacation response which should be '/usr/sbin/mailwrapper'.
        [ ! -e /usr/lib/sendmail ] && ln -s /usr/sbin/mailwrapper /usr/lib/sendmail 2>/dev/null

        # Start dovecot when system start up.
        freebsd_enable_service_in_rc_conf 'dovecot_enable' 'YES'
    fi

    echo 'export status_enable_dovecot1="DONE"' >> ${STATUS_FILE}
}
