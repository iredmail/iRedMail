#!/usr/bin/env bash
# Purpose: Mail to user when his/her quota exceeds specified percentage.
# Reference: http://wiki2.dovecot.org/Quota/Configuration#Quota_warnings

PERCENT=${1}
USER=${2}

# Use "plugin/quota=maildir:User quota:noenforcing" for maildir quota.
cat << EOF | PH_DOVECOT_DELIVER_BIN -d ${USER} -o "plugin/quota=dict:User quota::noenforcing:proxy::quotadict"
From: no-reply@$(hostname -f)
Subject: Warning: Your mailbox is now ${PERCENT}% full.

Your mailbox is now ${PERCENT}% full, please clean up some mails for further incoming mails.
EOF

# Send a copy to postmaster@ if mailbox is greater than or equal to 95% full.
if [ ${PERCENT} -ge 95 ]; then
    DOMAIN="$(echo ${USER} | awk -F'@' '{print $2}')"
    cat << EOF | PH_DOVECOT_DELIVER_BIN -d postmaster@${DOMAIN} -o "plugin/quota=dict:User quota::noenforcing:proxy::quotadict"
From: no-reply@$(hostname -f)
Subject: Mailbox Quota Warning: ${PERCENT}% full, ${USER}

Mailbox (${USER}) is now ${PERCENT}% full, please clean up some mails for
further incoming mails.
EOF
fi
