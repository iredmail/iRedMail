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

# -------------------------------------------------------
# ---------------------- Postfix ------------------------
# -------------------------------------------------------

postfix_config_basic()
{
    ECHO_INFO "Configure Postfix."

    # OpenBSD: Replace sendmail with Postfix
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        echo 'sendmail_flags=NO' >> ${RC_CONF_LOCAL}
        /usr/local/sbin/postfix-enable &>/dev/null
        perl -pi -e 's/(.*sendmail -L sm-msp-queue.*)/#${1}/' ${CRON_SPOOL_DIR}/root 
        perl -pi -e 's/^(inet_protocols.*)/#${1}/' ${POSTFIX_FILE_MAIN_CF}
    fi

    backup_file ${POSTFIX_FILE_MAIN_CF} ${POSTFIX_FILE_MASTER_CF}

    ECHO_DEBUG "Enable chroot."
    perl -pi -e 's/^(smtp.*inet)(.*)(n)(.*)(n)(.*smtpd)$/${1}${2}${3}${4}-${6}/' ${POSTFIX_FILE_MASTER_CF}

    if [ X"${DISTRO}" == X"SUSE" ]; then
        # Remove duplicate relay_domains on openSUSE
        perl -pi -e 's/^(relay_domains.*)/#${1}/' ${POSTFIX_FILE_MAIN_CF}

        # Uncomment tlsmgr to avoid postfix warning message:
        # 'warning: connect to private/tlsmgr: No such file or directory'
        perl -pi -e 's/^#(tlsmgr.*)/${1}/' ${POSTFIX_FILE_MASTER_CF}

        # Set postfix:myhostname in /etc/sysconfig/postfix.
        perl -pi -e 's#^(POSTFIX_MYHOSTNAME=).*#${1}"$ENV{'HOSTNAME'}"#' ${POSTFIX_SYSCONFIG_CONF}
        #postfix:message_size_limit
        perl -pi -e 's#^(POSTFIX_ADD_MESSAGE_SIZE_LIMIT=).*#${1}"$ENV{'MESSAGE_SIZE_LIMIT'}"#' ${POSTFIX_SYSCONFIG_CONF}

        # Append two lines in /etc/services to avoid below error:
        # '0.0.0.0:smtps: Servname not supported for ai_socktype'
        echo 'smtps            465/udp    # smtp over ssl' >> /etc/services
        echo 'smtps            465/tcp    # smtp over ssl' >> /etc/services

        # Unset below settings since we don't use them.
        postconf -e canonical_maps=''
        postconf -e relocated_maps=''
        postconf -e sender_canonical_maps=''
    fi

    # Do not set virtual_alias_domains.
    postconf -e virtual_alias_domains=''

    ECHO_DEBUG "Copy: /etc/{hosts,resolv.conf,localtime,services} -> ${POSTFIX_CHROOT_DIR}/etc/"
    mkdir -p ${POSTFIX_CHROOT_DIR}/etc/ 2>/dev/null
    for i in /etc/hosts /etc/resolv.conf /etc/localtime /etc/services; do
        [ -f $i ] && cp ${i} ${POSTFIX_CHROOT_DIR}/etc/
    done

    # Normally, myhostname is the same as myorigin.
    postconf -e myhostname="${HOSTNAME}"
    postconf -e myorigin="${HOSTNAME}"

    # Remove the characters before first dot in myhostname is mydomain.
    echo "${HOSTNAME}" | grep '\..*\.' >/dev/null 2>&1
    if [ X"$?" == X"0" ]; then
        mydomain="$(echo "${HOSTNAME}" | awk -F'.' '{print $2 "." $3}')"
        postconf -e mydomain="${mydomain}"
    else
        postconf -e mydomain="${HOSTNAME}"
    fi

    postconf -e inet_protocols="ipv4"
    postconf -e mydestination="\$myhostname, localhost, localhost.localdomain, localhost.\$myhostname"
    postconf -e biff="no"   # Do not notify local user.
    postconf -e inet_interfaces="all"
    postconf -e mynetworks="127.0.0.0/8"
    postconf -e mynetworks_style="subnet"
    postconf -e smtpd_data_restrictions='reject_unauth_pipelining'
    postconf -e smtpd_reject_unlisted_recipient='yes'   # Default
    postconf -e smtpd_sender_restrictions="permit_mynetworks, reject_sender_login_mismatch, permit_sasl_authenticated"
    postconf -e delay_warning_time='0h'
    postconf -e maximal_queue_lifetime='1d'
    postconf -e bounce_queue_lifetime='1d'
    postconf -e recipient_delimiter='+'
    postconf -e proxy_read_maps='$canonical_maps $lmtp_generic_maps $local_recipient_maps $mydestination $mynetworks $recipient_bcc_maps $recipient_canonical_maps $relay_domains $relay_recipient_maps $relocated_maps $sender_bcc_maps $sender_canonical_maps $smtp_generic_maps $smtpd_sender_login_maps $transport_maps $virtual_alias_domains $virtual_alias_maps $virtual_mailbox_domains $virtual_mailbox_maps $smtpd_sender_restrictions'

    postconf -e smtp_data_init_timeout='240s'
    postconf -e smtp_data_xfer_timeout='600s'

    # HELO restriction
    postconf -e smtpd_helo_required="yes"
    postconf -e smtpd_helo_restrictions="permit_mynetworks,permit_sasl_authenticated, check_helo_access pcre:${POSTFIX_FILE_HELO_ACCESS}"

    backup_file ${POSTFIX_FILE_HELO_ACCESS}
    cp -f ${SAMPLE_DIR}/helo_access.pcre ${POSTFIX_FILE_HELO_ACCESS}

    # Reduce queue run delay time.
    postconf -e queue_run_delay='300s'          # default '300s' in postfix-2.4.
    postconf -e minimal_backoff_time='300s'     # default '300s' in postfix-2.4.
    postconf -e maximal_backoff_time='1800s'    # default '4000s' in postfix-2.4.

    # Avoid duplicate recipient messages. Default is 'yes'.
    postconf -e enable_original_recipient="no"

    # Disable the SMTP VRFY command. This stops some techniques used to
    # harvest email addresses.
    postconf -e disable_vrfy_command='yes'

    # We use 'maildir' format, not 'mbox'.
    if [ X"${MAILBOX_FORMAT}" == X"Maildir" ]; then
        postconf -e home_mailbox="Maildir/"
    else
        :
    fi
    postconf -e maximal_backoff_time="4000s"

    # Allow recipient address start with '-'.
    postconf -e allow_min_user='no'

    # Postfix aliases file.
    if  [ ! -f ${POSTFIX_FILE_ALIASES} ]; then
        if [ -f /etc/aliases ]; then
            cp -f /etc/aliases ${POSTFIX_FILE_ALIASES}
        else
            touch ${POSTFIX_FILE_ALIASES}
        fi
    fi

    # Comment out default aliases for root
    perl -pi -e 's/^(root:.*)/#${1}/g' ${POSTFIX_FILE_ALIASES}

    postconf -e alias_maps="hash:${POSTFIX_FILE_ALIASES}"
    postconf -e alias_database="hash:${POSTFIX_FILE_ALIASES}"
    postalias hash:${POSTFIX_FILE_ALIASES} 2>/dev/null
    newaliases >/dev/null 2>&1

    # Set message_size_limit.
    postconf -e message_size_limit="${MESSAGE_SIZE_LIMIT}"
    # Virtual support.
    postconf -e virtual_minimum_uid="${VMAIL_USER_UID}"
    postconf -e virtual_uid_maps="static:${VMAIL_USER_UID}"
    postconf -e virtual_gid_maps="static:${VMAIL_USER_GID}"
    postconf -e virtual_mailbox_base="${STORAGE_BASE_DIR}"

    # Reject unlisted sender
    postconf -e smtpd_reject_unlisted_sender='yes'

    # Simple backscatter block method.
    #postconf -e header_checks="pcre:${POSTFIX_FILE_HEADER_CHECKS}"
    cat >> ${POSTFIX_FILE_HEADER_CHECKS} <<EOF
# *******************************************************************
# Reference:
#   http://www.postfix.org/header_checks.5.html
#   http://www.postfix.org/BACKSCATTER_README.html#real
# *******************************************************************

# Use your real hostname to replace 'porcupine.org'.
#if /^Received:/
#/^Received: +from +(porcupine\.org) +/
#    reject forged client name in Received: header: $1
#/^Received: +from +[^ ]+ +\(([^ ]+ +[he]+lo=|[he]+lo +)(porcupine\.org)\)/
#    reject forged client name in Received: header: $2
#/^Received:.* +by +(porcupine\.org)\b/
#    reject forged mail server name in Received: header: $1
#endif
#/^Message-ID:.* <!&!/ DUNNO
#/^Message-ID:.*@(porcupine\.org)/
#    reject forged domain name in Message-ID: header: $1

# Replace internal IP address by external IP address or whatever you
# want. Required 'smtpd_sasl_authenticated_header=yes' in postfix.
#/(^Received:.*\[).*(\].*Authenticated sender:.*by REPLACED_BY_YOUR_HOSTNAME.*iRedMail.*)/ REPLACE ${1}REPLACED_BY_YOUR_IP_ADDRESS${2}
EOF

    if [ X"${DISTRO}" == X'GENTOO' ]; then
        cat >> ${SYSLOG_CONF} <<EOF
# Maillog
filter f_maillog {facility(mail); };
destination maillog {file("${MAILLOG}"); };
log {source(src); filter(f_maillog); destination(maillog); };
EOF
    fi

    cat >> ${TIP_FILE} <<EOF
Postfix (basic):
    * Configuration files:
        - ${POSTFIX_ROOTDIR}
        - ${POSTFIX_ROOTDIR}/aliases
        - ${POSTFIX_FILE_MAIN_CF}
        - ${POSTFIX_FILE_MASTER_CF}

EOF

    # FreeBSD: Start postfix when system start up.
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        backup_file /etc/mail/mailer.conf
        cat > /etc/mail/mailer.conf <<EOF
#
# Execute the Postfix sendmail program, named /usr/local/sbin/sendmail
#
sendmail    /usr/local/sbin/sendmail
send-mail   /usr/local/sbin/sendmail
mailq       /usr/local/sbin/sendmail
newaliases  /usr/local/sbin/sendmail
EOF

        freebsd_enable_service_in_rc_conf 'postfix_enable' 'YES'
        freebsd_enable_service_in_rc_conf 'sendmail_enable' 'NO'
        freebsd_enable_service_in_rc_conf 'sendmail_submit_enable' 'NO'
        freebsd_enable_service_in_rc_conf 'sendmail_outbound_enable' 'NO'
        freebsd_enable_service_in_rc_conf 'sendmail_msp_queue_enable' 'NO'
        freebsd_enable_service_in_rc_conf 'daily_clean_hoststat_enable' 'NO'
        freebsd_enable_service_in_rc_conf 'daily_status_mail_rejects_enable' 'NO'
        freebsd_enable_service_in_rc_conf 'daily_status_include_submit_mailq' 'NO'
        freebsd_enable_service_in_rc_conf 'daily_submit_queuerun' 'NO'
    fi

    # Create directory, used to store lookup files.
    [ -d ${POSTFIX_LOOKUP_DIR} ] || mkdir -p ${POSTFIX_LOOKUP_DIR}

    echo 'export status_postfix_config_basic="DONE"' >> ${STATUS_FILE}
}

postfix_config_vhost_ldap()
{
    ECHO_DEBUG "Configure Postfix for LDAP lookup."

    # LDAP search filters.
    ldap_search_base_domain="${LDAP_ATTR_DOMAIN_RDN}=%d,${LDAP_BASEDN}"
    ldap_search_base_user="${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_USERS},${LDAP_ATTR_DOMAIN_RDN}=%d,${LDAP_BASEDN}"
    ldap_search_base_group="${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_GROUPS},${LDAP_ATTR_DOMAIN_RDN}=%d,${LDAP_BASEDN}"

    postconf -e transport_maps="proxy:ldap:${ldap_transport_maps_user_cf}, proxy:ldap:${ldap_transport_maps_domain_cf}"
    postconf -e virtual_alias_maps="proxy:ldap:${ldap_virtual_alias_maps_cf}, proxy:ldap:${ldap_virtual_group_maps_cf}, proxy:ldap:${ldap_virtual_group_members_maps_cf}, proxy:ldap:${ldap_catch_all_maps_cf}"
    postconf -e virtual_mailbox_domains="proxy:ldap:${ldap_virtual_mailbox_domains_cf}"
    postconf -e virtual_mailbox_maps="proxy:ldap:${ldap_virtual_mailbox_maps_cf}"
    postconf -e sender_bcc_maps="proxy:ldap:${ldap_sender_bcc_maps_user_cf}, proxy:ldap:${ldap_sender_bcc_maps_domain_cf}"
    postconf -e recipient_bcc_maps="proxy:ldap:${ldap_recipient_bcc_maps_user_cf}, proxy:ldap:${ldap_recipient_bcc_maps_domain_cf}"
    postconf -e relay_domains="\$mydestination, proxy:ldap:${ldap_relay_domains_cf}"
    #postconf -e relay_recipient_maps="proxy:ldap:${ldap_virtual_mailbox_maps_cf}"

    postconf -e smtpd_sender_login_maps="proxy:ldap:${ldap_sender_login_maps_cf}"

    cat > ${ldap_virtual_mailbox_domains_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
bind            = ${LDAP_BIND}
start_tls       = no
version         = ${LDAP_BIND_VERSION}
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = one
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILDOMAIN})(|(${LDAP_ATTR_DOMAIN_RDN}=%s)(&(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DOMAIN_ALIAS})(${LDAP_ATTR_DOMAIN_ALIAS_NAME}=%s)))(!(${LDAP_ATTR_DOMAIN_BACKUPMX}=${LDAP_VALUE_DOMAIN_BACKUPMX}))(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL}))
result_attribute= ${LDAP_ATTR_DOMAIN_RDN}
debuglevel      = 0
EOF

    # LDAP relay domains.
    cat > ${ldap_relay_domains_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
bind            = ${LDAP_BIND}
start_tls       = no
version         = ${LDAP_BIND_VERSION}
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = one
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILDOMAIN})(|(${LDAP_ATTR_DOMAIN_RDN}=%s)(&(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DOMAIN_ALIAS})(${LDAP_ATTR_DOMAIN_ALIAS_NAME}=%s)))(${LDAP_ATTR_DOMAIN_BACKUPMX}=${LDAP_VALUE_DOMAIN_BACKUPMX})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL}))
result_attribute= ${LDAP_ATTR_DOMAIN_RDN}
debuglevel      = 0
EOF

    #
    # LDAP transport maps
    #
    # Per-domain transport maps
    cat > ${ldap_transport_maps_domain_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = one
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILDOMAIN})(|(${LDAP_ATTR_DOMAIN_RDN}=%s)(${LDAP_ATTR_DOMAIN_ALIAS_NAME}=%s))(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL}))
result_attribute= ${LDAP_ATTR_MTA_TRANSPORT}
debuglevel      = 0
EOF

    # Per-user transport maps
    cat > ${ldap_transport_maps_user_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${ldap_search_base_user}
scope           = one
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_USER_RDN}=%s)(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL}))
result_attribute= ${LDAP_ATTR_MTA_TRANSPORT}
debuglevel      = 0
EOF

    #
    # LDAP Virtual Users.
    #
    cat > ${ldap_virtual_mailbox_maps_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = sub
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(|(${LDAP_ATTR_USER_RDN}=%s)(&(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_SHADOW_ADDRESS})(${LDAP_ATTR_USER_SHADOW_ADDRESS}=%s)))(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DELIVER}))
result_attribute= mailMessageStore
debuglevel      = 0
EOF

    cat > ${ldap_sender_login_maps_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = sub
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_SMTP})(|(${LDAP_ATTR_USER_RDN}=%s)(&(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_SHADOW_ADDRESS})(${LDAP_ATTR_USER_SHADOW_ADDRESS}=%s))))
result_attribute= ${LDAP_ATTR_USER_RDN}
debuglevel      = 0
EOF

    cat > ${ldap_virtual_alias_maps_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = sub
query_filter    = (&(|(${LDAP_ATTR_USER_RDN}=%s)(${LDAP_ATTR_USER_SHADOW_ADDRESS}=%s))(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DELIVER})(|(objectClass=${LDAP_OBJECTCLASS_MAILALIAS})(&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_FORWARD}))))
result_attribute= ${LDAP_ATTR_USER_FORWARD}
debuglevel      = 0
EOF

    cat > ${ldap_virtual_group_maps_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = sub
query_filter    = (&(${LDAP_ATTR_USER_MEMBER_OF_GROUP}=%s)(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DELIVER})(|(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(objectClass=${LDAP_OBJECTCLASS_MAIL_EXTERNAL_USER})))
result_attribute= ${LDAP_ATTR_USER_RDN}
debuglevel      = 0
EOF

    cat > ${ldap_virtual_group_members_maps_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = sub
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DELIVER})(|(${LDAP_ATTR_USER_RDN}=%s)(&(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_SHADOW_ADDRESS})(${LDAP_ATTR_USER_SHADOW_ADDRESS}=%s))))
result_attribute= ${LDAP_ATTR_USER_RDN}
debuglevel      = 0
EOF

    cat > ${ldap_catch_all_maps_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = sub
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(|(mail=@%d)(${LDAP_ATTR_USER_SHADOW_ADDRESS}=@%d)))
result_attribute= ${LDAP_ATTR_USER_FORWARD}
debuglevel      = 0
EOF

    cat > ${ldap_recipient_bcc_maps_domain_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = one
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILDOMAIN})(|(${LDAP_ATTR_DOMAIN_RDN}=%d)(${LDAP_ATTR_DOMAIN_ALIAS_NAME}=%d))(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_RECIPIENT_BCC}))
result_attribute= ${LDAP_ATTR_DOMAIN_RECIPIENT_BCC_ADDRESS}
debuglevel      = 0
EOF

    cat > ${ldap_recipient_bcc_maps_user_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${ldap_search_base_user}
scope           = one
query_filter    = (&(${LDAP_ATTR_USER_RDN}=%s)(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_RECIPIENT_BCC}))
result_attribute= ${LDAP_ATTR_USER_RECIPIENT_BCC_ADDRESS}
debuglevel      = 0
EOF

    cat > ${ldap_sender_bcc_maps_domain_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${LDAP_BASEDN}
scope           = one
query_filter    = (&(objectClass=${LDAP_OBJECTCLASS_MAILDOMAIN})(|(${LDAP_ATTR_DOMAIN_RDN}=%d)(${LDAP_ATTR_DOMAIN_ALIAS_NAME}=%d))(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_SENDER_BCC}))
result_attribute= ${LDAP_ATTR_DOMAIN_SENDER_BCC_ADDRESS}
debuglevel      = 0
EOF

    cat > ${ldap_sender_bcc_maps_user_cf} <<EOF
${CONF_MSG}
server_host     = ${LDAP_SERVER_HOST}
server_port     = ${LDAP_SERVER_PORT}
version         = ${LDAP_BIND_VERSION}
bind            = ${LDAP_BIND}
start_tls       = no
bind_dn         = ${LDAP_BINDDN}
bind_pw         = ${LDAP_BINDPW}
search_base     = ${ldap_search_base_user}
scope           = one
query_filter    = (&(${LDAP_ATTR_USER_RDN}=%s)(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_SENDER_BCC}))
result_attribute= ${LDAP_ATTR_USER_SENDER_BCC_ADDRESS}
debuglevel      = 0
EOF

    ECHO_DEBUG "Set file permission: Owner/Group -> root/root, Mode -> 0640."

    cat >> ${TIP_FILE} <<EOF
Postfix (LDAP):
    * Configuration files:
EOF

    for i in ${ldap_virtual_mailbox_domains_cf} \
        ${ldap_transport_maps_domain_cf} \
        ${ldap_transport_maps_user_cf} \
        ${ldap_virtual_mailbox_maps_cf} \
        ${ldap_virtual_alias_maps_cf} \
        ${ldap_virtual_group_maps_cf} \
        ${ldap_virtual_group_members_maps_cf} \
        ${ldap_recipient_bcc_maps_domain_cf} \
        ${ldap_recipient_bcc_maps_user_cf} \
        ${ldap_sender_bcc_maps_domain_cf} \
        ${ldap_sender_bcc_maps_user_cf}
    do
        chown ${SYS_ROOT_USER}:${POSTFIX_DAEMON_GROUP} ${i}
        chmod 0640 ${i}
        cat >> ${TIP_FILE} <<EOF
        - ${i}

EOF
    done

    echo 'export status_postfix_config_vhost_ldap="DONE"' >> ${STATUS_FILE}
}

postfix_config_vhost_mysql()
{
    ECHO_DEBUG "Configure Postfix for MySQL lookup."

    # Postfix doesn't work while mysql server is 'localhost', should be
    # changed to '127.0.0.1'.

    postconf -e transport_maps="proxy:mysql:${mysql_transport_maps_user_cf}, proxy:mysql:${mysql_transport_maps_domain_cf}"
    postconf -e virtual_mailbox_domains="proxy:mysql:${mysql_virtual_mailbox_domains_cf}"
    postconf -e virtual_mailbox_maps="proxy:mysql:${mysql_virtual_mailbox_maps_cf}"
    postconf -e virtual_alias_maps="proxy:mysql:${mysql_virtual_alias_maps_cf}, proxy:mysql:${mysql_domain_alias_maps_cf}, proxy:mysql:${mysql_catchall_maps_cf}, proxy:mysql:${mysql_domain_alias_catchall_maps_cf}"
    postconf -e sender_bcc_maps="proxy:mysql:${mysql_sender_bcc_maps_user_cf}, proxy:mysql:${mysql_sender_bcc_maps_domain_cf}"
    postconf -e recipient_bcc_maps="proxy:mysql:${mysql_recipient_bcc_maps_user_cf}, proxy:mysql:${mysql_recipient_bcc_maps_domain_cf}"
    postconf -e relay_domains="\$mydestination, proxy:mysql:${mysql_relay_domains_cf}"
    #postconf -e relay_recipient_maps="proxy:mysql:${mysql_virtual_mailbox_maps_cf}"

    postconf -e smtpd_sender_login_maps="proxy:mysql:${mysql_sender_login_maps_cf}"

    # Per-domain transport maps.
    cat > ${mysql_transport_maps_domain_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT transport FROM domain WHERE domain='%s' AND active=1
EOF

    # Per-user transport maps.
    cat > ${mysql_transport_maps_user_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT mailbox.transport FROM mailbox,domain WHERE mailbox.username='%s' AND mailbox.domain='%d' AND mailbox.domain=domain.domain AND mailbox.transport<>'' AND mailbox.active=1 AND mailbox.enabledeliver=1 AND domain.backupmx=0 AND domain.active=1
EOF

    cat > ${mysql_virtual_mailbox_domains_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT domain FROM domain WHERE domain='%s' AND backupmx=0 AND active=1 UNION SELECT alias_domain.alias_domain FROM alias_domain,domain WHERE alias_domain.alias_domain='%s' AND alias_domain.active=1 AND alias_domain.target_domain=domain.domain AND domain.active=1 AND domain.backupmx=0
EOF

    cat > ${mysql_relay_domains_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT domain FROM domain WHERE domain='%s' AND backupmx=1 AND active=1
EOF

    cat > ${mysql_virtual_mailbox_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT CONCAT(mailbox.storagenode, '/', mailbox.maildir, '/Maildir/') FROM mailbox,domain WHERE mailbox.username='%s' AND mailbox.active=1 AND mailbox.enabledeliver=1 AND domain.domain = mailbox.domain AND domain.active=1
EOF

    cat > ${mysql_virtual_alias_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,domain WHERE alias.address='%s' AND alias.domain='%d' AND alias.domain=domain.domain AND alias.active=1 AND domain.backupmx=0 AND domain.active=1
EOF

    cat > ${mysql_domain_alias_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,alias_domain,domain WHERE alias_domain.alias_domain='%d' AND alias.address=CONCAT('%u', '@', alias_domain.target_domain) AND alias_domain.target_domain=domain.domain AND alias.active=1 AND alias_domain.active=1 AND domain.backupmx=0
EOF

    cat > ${mysql_catchall_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,domain WHERE alias.address='%d' AND alias.address=domain.domain AND alias.active=1 AND domain.active=1 AND domain.backupmx=0
EOF

    cat > ${mysql_domain_alias_catchall_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,alias_domain,domain WHERE alias_domain.alias_domain='%d' AND alias.address=alias_domain.target_domain AND alias_domain.target_domain=domain.domain AND alias.active=1 AND alias_domain.active=1
EOF

    cat > ${mysql_sender_login_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT mailbox.username FROM mailbox,domain WHERE mailbox.username='%s' AND mailbox.domain='%d' AND mailbox.domain=domain.domain AND mailbox.enablesmtp=1 AND mailbox.active=1 AND domain.backupmx=0 AND domain.active=1
EOF

    cat > ${mysql_sender_bcc_maps_domain_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT bcc_address FROM sender_bcc_domain WHERE domain='%d' AND active=1
EOF

    cat > ${mysql_sender_bcc_maps_user_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT sender_bcc_user.bcc_address FROM sender_bcc_user,domain WHERE sender_bcc_user.username='%s' AND sender_bcc_user.domain='%d' AND sender_bcc_user.domain=domain.domain AND domain.backupmx=0 AND domain.active=1 AND sender_bcc_user.active=1
EOF

    cat > ${mysql_recipient_bcc_maps_domain_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT bcc_address FROM recipient_bcc_domain WHERE domain='%d' AND active=1
EOF

    cat > ${mysql_recipient_bcc_maps_user_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${MYSQL_SERVER}
port        = ${MYSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT recipient_bcc_user.bcc_address FROM recipient_bcc_user,domain WHERE recipient_bcc_user.username='%s' AND recipient_bcc_user.domain='%d' AND recipient_bcc_user.domain=domain.domain AND domain.backupmx=0 AND domain.active=1 AND recipient_bcc_user.active=1
EOF

    ECHO_DEBUG "Set file permission: Owner/Group -> postfix/postfix, Mode -> 0640."
    cat >> ${TIP_FILE} <<EOF
Postfix (MySQL):
    * Configuration files:
EOF
    for i in ${mysql_virtual_mailbox_domains_cf} \
        ${mysql_transport_maps_domain_cf} \
        ${mysql_transport_maps_user_cf} \
        ${mysql_virtual_mailbox_maps_cf} \
        ${mysql_virtual_alias_maps_cf} \
        ${mysql_domain_alias_maps_cf} \
        ${mysql_catchall_maps_cf} \
        ${mysql_domain_alias_catchall_maps_cf} \
        ${mysql_sender_login_maps_cf} \
        ${mysql_sender_bcc_maps_domain_cf} \
        ${mysql_sender_bcc_maps_user_cf} \
        ${mysql_recipient_bcc_maps_domain_cf} \
        ${mysql_recipient_bcc_maps_user_cf}
    do
        chown ${SYS_ROOT_USER}:${POSTFIX_DAEMON_GROUP} ${i}
        chmod 0640 ${i}

        cat >> ${TIP_FILE} <<EOF
        - $i
EOF
    done

    echo 'export status_postfix_config_vhost_mysql="DONE"' >> ${STATUS_FILE}
}

postfix_config_vhost_pgsql()
{
    ECHO_DEBUG "Configure Postfix for PostgreSQL lookup."

    postconf -e transport_maps="proxy:pgsql:${pgsql_transport_maps_user_cf}, proxy:pgsql:${pgsql_transport_maps_domain_cf}"
    postconf -e virtual_mailbox_domains="proxy:pgsql:${pgsql_virtual_mailbox_domains_cf}"
    postconf -e virtual_mailbox_maps="proxy:pgsql:${pgsql_virtual_mailbox_maps_cf}"
    postconf -e virtual_alias_maps="proxy:pgsql:${pgsql_virtual_alias_maps_cf}, proxy:pgsql:${pgsql_domain_alias_maps_cf}, proxy:pgsql:${pgsql_catchall_maps_cf}, proxy:pgsql:${pgsql_domain_alias_catchall_maps_cf}"
    postconf -e sender_bcc_maps="proxy:pgsql:${pgsql_sender_bcc_maps_user_cf}, proxy:pgsql:${pgsql_sender_bcc_maps_domain_cf}"
    postconf -e recipient_bcc_maps="proxy:pgsql:${pgsql_recipient_bcc_maps_user_cf}, proxy:pgsql:${pgsql_recipient_bcc_maps_domain_cf}"
    postconf -e relay_domains="\$mydestination, proxy:pgsql:${pgsql_relay_domains_cf}"
    #postconf -e relay_recipient_maps="proxy:pgsql:${pgsql_virtual_mailbox_maps_cf}"

    postconf -e smtpd_sender_login_maps="proxy:pgsql:${pgsql_sender_login_maps_cf}"

    # Per-domain transport maps.
    cat > ${pgsql_transport_maps_domain_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT transport FROM domain WHERE domain='%s' AND active=1
EOF

    # Per-user transport maps.
    cat > ${pgsql_transport_maps_user_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT mailbox.transport FROM mailbox,domain WHERE mailbox.username='%s' AND mailbox.domain='%d' AND mailbox.domain=domain.domain AND mailbox.transport<>'' AND mailbox.active=1 AND mailbox.enabledeliver=1 AND domain.backupmx=0 AND domain.active=1
EOF

    cat > ${pgsql_virtual_mailbox_domains_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT domain FROM domain WHERE domain='%s' AND backupmx=0 AND active=1 UNION SELECT alias_domain.alias_domain FROM alias_domain,domain WHERE alias_domain.alias_domain='%s' AND alias_domain.active=1 AND alias_domain.target_domain=domain.domain AND domain.active=1 AND domain.backupmx=0
EOF

    cat > ${pgsql_relay_domains_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT domain FROM domain WHERE domain='%s' AND backupmx=1 AND active=1
EOF

    cat > ${pgsql_virtual_mailbox_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT (mailbox.storagenode || '/' || mailbox.maildir || '/Maildir/') FROM mailbox,domain WHERE mailbox.username='%s' AND mailbox.active=1 AND mailbox.enabledeliver=1 AND domain.domain = mailbox.domain AND domain.active=1
EOF

    cat > ${pgsql_virtual_alias_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,domain WHERE alias.address='%s' AND alias.domain='%d' AND alias.domain=domain.domain AND alias.active=1 AND domain.backupmx=0 AND domain.active=1
EOF

    cat > ${pgsql_domain_alias_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,alias_domain,domain WHERE alias_domain.alias_domain='%d' AND alias.address=('%u' || '@' || alias_domain.target_domain) AND alias_domain.target_domain=domain.domain AND alias.active=1 AND alias_domain.active=1 AND domain.backupmx=0
EOF

    cat > ${pgsql_catchall_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,domain WHERE alias.address='%d' AND alias.address=domain.domain AND alias.active=1 AND domain.active=1 AND domain.backupmx=0
EOF

    cat > ${pgsql_domain_alias_catchall_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT alias.goto FROM alias,alias_domain,domain WHERE alias_domain.alias_domain='%d' AND alias.address=alias_domain.target_domain AND alias_domain.target_domain=domain.domain AND alias.active=1 AND alias_domain.active=1
EOF

    cat > ${pgsql_sender_login_maps_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT mailbox.username FROM mailbox,domain WHERE mailbox.username='%s' AND mailbox.domain='%d' AND mailbox.domain=domain.domain AND mailbox.enablesmtp=1 AND mailbox.active=1 AND domain.backupmx=0 AND domain.active=1
EOF

    cat > ${pgsql_sender_bcc_maps_domain_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT bcc_address FROM sender_bcc_domain WHERE domain='%d' AND active=1
EOF

    cat > ${pgsql_sender_bcc_maps_user_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT sender_bcc_user.bcc_address FROM sender_bcc_user,domain WHERE sender_bcc_user.username='%s' AND sender_bcc_user.domain='%d' AND sender_bcc_user.domain=domain.domain AND domain.backupmx=0 AND domain.active=1 AND sender_bcc_user.active=1
EOF

    cat > ${pgsql_recipient_bcc_maps_domain_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT bcc_address FROM recipient_bcc_domain WHERE domain='%d' AND active=1
EOF

    cat > ${pgsql_recipient_bcc_maps_user_cf} <<EOF
${CONF_MSG}
user        = ${VMAIL_DB_BIND_USER}
password    = ${VMAIL_DB_BIND_PASSWD}
hosts       = ${PGSQL_SERVER}
port        = ${PGSQL_SERVER_PORT}
dbname      = ${VMAIL_DB}
query       = SELECT recipient_bcc_user.bcc_address FROM recipient_bcc_user,domain WHERE recipient_bcc_user.username='%s' AND recipient_bcc_user.domain='%d' AND recipient_bcc_user.domain=domain.domain AND domain.backupmx=0 AND domain.active=1 AND recipient_bcc_user.active=1
EOF

    ECHO_DEBUG "Set file permission: Owner/Group -> postfix/postfix, Mode -> 0640."
    cat >> ${TIP_FILE} <<EOF
Postfix (PostgreSQL):
    * Configuration files:
EOF
    for i in ${pgsql_virtual_mailbox_domains_cf} \
        ${pgsql_transport_maps_domain_cf} \
        ${pgsql_transport_maps_user_cf} \
        ${pgsql_virtual_mailbox_maps_cf} \
        ${pgsql_virtual_alias_maps_cf} \
        ${pgsql_domain_alias_maps_cf} \
        ${pgsql_catchall_maps_cf} \
        ${pgsql_domain_alias_catchall_maps_cf} \
        ${pgsql_sender_login_maps_cf} \
        ${pgsql_sender_bcc_maps_domain_cf} \
        ${pgsql_sender_bcc_maps_user_cf} \
        ${pgsql_recipient_bcc_maps_domain_cf} \
        ${pgsql_recipient_bcc_maps_user_cf}
    do
        chown ${SYS_ROOT_USER}:${POSTFIX_DAEMON_GROUP} ${i}
        chmod 0640 ${i}

        cat >> ${TIP_FILE} <<EOF
        - $i
EOF
    done

        echo '' >> ${TIP_FILE}
    echo 'export status_postfix_config_vhost_pgsql="DONE"' >> ${STATUS_FILE}
}

# Starting config.
postfix_config_virtual_host()
{
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        check_status_before_run postfix_config_vhost_ldap
    elif [ X"${BACKEND}" == X"MYSQL" ]; then
        check_status_before_run postfix_config_vhost_mysql
    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        check_status_before_run postfix_config_vhost_pgsql
    fi

    echo 'export status_postfix_config_virtual_host="DONE"' >> ${STATUS_FILE}
}

postfix_config_sasl()
{
    ECHO_DEBUG "Configure SMTP SASL authentication."

    # For SASL auth
    postconf -e smtpd_sasl_auth_enable="yes"
    postconf -e smtpd_sasl_local_domain=''
    postconf -e broken_sasl_auth_clients="yes"
    postconf -e smtpd_sasl_security_options="noanonymous"
    [ X"${DISTRO}" == X"SUSE" ] && \
        perl -pi -e 's#^(POSTFIX_SMTP_AUTH_OPTIONS=).*#${1}"noanonymous"#' ${POSTFIX_SYSCONFIG_CONF}

    # Report the SASL authenticated user name in Received message header.
    # Default is 'no'.
    postconf -e smtpd_sasl_authenticated_header="no"

    POSTCONF_IREDAPD=''
    if [ X"${USE_IREDAPD}" == X"YES" ]; then
        POSTCONF_IREDAPD="check_policy_service inet:${IREDAPD_LISTEN_ADDR}:${IREDAPD_LISTEN_PORT},"
    fi

    POSTCONF_CLUEBRINGER=''
    if [ X"${USE_CLUEBRINGER}" == X"YES" ]; then
        POSTCONF_CLUEBRINGER="check_policy_service inet:${CLUEBRINGER_BINDHOST}:${CLUEBRINGER_BINDPORT},"
    fi

    if [ X"${USE_CLUEBRINGER}" == X"YES" ]; then
        postconf -e smtpd_recipient_restrictions="reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_non_fqdn_sender, reject_non_fqdn_recipient, reject_unlisted_recipient, ${POSTCONF_IREDAPD} ${POSTCONF_CLUEBRINGER} permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_non_fqdn_helo_hostname, reject_invalid_helo_hostname"
        postconf -e smtpd_end_of_data_restrictions="check_policy_service inet:${CLUEBRINGER_BINDHOST}:${CLUEBRINGER_BINDPORT}"
    elif [ X"${USE_POLICYD}" == X"YES" ]; then
        postconf -e smtpd_recipient_restrictions="reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_non_fqdn_sender, reject_non_fqdn_recipient, reject_unlisted_recipient, ${POSTCONF_IREDAPD} permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_non_fqdn_helo_hostname, reject_invalid_helo_hostname, check_policy_service inet:${POLICYD_BINDHOST}:${POLICYD_BINDPORT}"
    else
        postconf -e smtpd_recipient_restrictions="reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_non_fqdn_sender, reject_non_fqdn_recipient, reject_unlisted_recipient, ${POSTCONF_IREDAPD} permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_non_fqdn_helo_hostname, reject_invalid_helo_hostname"
    fi

    echo 'export status_postfix_config_sasl="DONE"' >> ${STATUS_FILE}
}

postfix_config_tls()
{
    ECHO_DEBUG "Enable TLS/SSL support in Postfix."

    postconf -e smtpd_tls_security_level='may'
    postconf -e smtpd_enforce_tls='no'
    postconf -e smtpd_tls_loglevel='0'
    postconf -e smtpd_tls_key_file="${SSL_KEY_FILE}"
    postconf -e smtpd_tls_cert_file="${SSL_CERT_FILE}"
    postconf -e smtpd_tls_CAfile="${SSL_CERT_FILE}"
    postconf -e tls_random_source='dev:/dev/urandom'

    if [ X"${DISTRO}" == X"SUSE" ]; then
        perl -pi -e 's#^(POSTFIX_SMTP_TLS_SERVER=).*#${1}"yes"#' ${POSTFIX_SYSCONFIG_CONF}
        perl -pi -e 's#^(POSTFIX_SSL_PATH=).*#${1}""#' ${POSTFIX_SYSCONFIG_CONF}
        perl -pi -e 's#^(POSTFIX_TLS_CAFILE=).*#${1}""#' ${POSTFIX_SYSCONFIG_CONF}
        perl -pi -e 's#^(POSTFIX_TLS_CERTFILE=).*#${1}"$ENV{'SSL_CERT_FILE'}"#' ${POSTFIX_SYSCONFIG_CONF}
        perl -pi -e 's#^(POSTFIX_TLS_KEYFILE=).*#${1}"$ENV{'SSL_KEY_FILE'}"#' ${POSTFIX_SYSCONFIG_CONF}
    fi

    cat >> ${POSTFIX_FILE_MASTER_CF} <<EOF
submission inet n       -       n       -       -       smtpd
  -o smtpd_enforce_tls=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
#  -o content_filter=smtp-amavis:[${AMAVISD_SERVER}]:10026

EOF

    echo 'export status_postfix_config_tls="DONE"' >> ${STATUS_FILE}
}
