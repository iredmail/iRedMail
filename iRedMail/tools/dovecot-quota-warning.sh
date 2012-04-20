#!/bin/sh

# Author:   Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose:  Send mail to notify user when his mailbox quota exceeds a
#           specified limit.
# Project:  iRedMail (http://www.iredmail.org/)

PERCENT=$1

cat << EOF | /usr/libexec/dovecot/deliver -d ${USER} -c /etc/dovecot.conf
From: postmaster@iredmail.org
Subject: Mailbox Quota Warning: ${PERCENT}% Full.

Mailbox quota report:

    * Your mailbox is now ${PERCENT}% full, please clear some files for
      further mails.

EOF
