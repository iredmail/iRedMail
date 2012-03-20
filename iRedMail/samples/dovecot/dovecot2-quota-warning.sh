#!/usr/bin/env bash
# Purpose: Mail to user when his/her quota exceeds specified percentage.
# Reference: http://wiki2.dovecot.org/Quota/Configuration#Quota_warnings

PERCENT=${1}
USER=${2}

# Use "plugin/quota=maildir:User quota:noenforcing" for maildir quota.
cat << EOF | PH_DOVECOT_DELIVER -d ${USER} -o "plugin/quota=dict:User quota::noenforcing:proxy::quota"
From: no-reply@PH_HOSTNAME
Subject: Mailbox Quota Warning: ${PERCENT}% Full.

Your mailbox is now ${PERCENT}% full, please clean up some mails for
further incoming mails.

EOF
