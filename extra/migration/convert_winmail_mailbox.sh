#!/usr/bin/env bash

# Author:   Zhang Huangbin (michaelbibby <at> gmail.com )
# Purpose:  Convert WinMail user mailboxs to standard IMAP directory
#           structure (mailbox format).

# Migration guide wrote in Chinese:
#   http://code.google.com/p/iRedMail/wiki/iRedMail_tut_Migration

# Description:
#   WinMail stores all mails in user mailbox with email address as mailbox
#   name, such as:
#
#       /path/to/mail/store/user@example.com/
#                           |- xxxxxx.in    # Received (Inbound)
#                           |- xxxxxx.out   # Sent (Outbound)
#                           |- xxxxxx.del   # Deleted
#
#   What this script do is:
#
#       * Creates standard IMAP directory structure (mailbox format).
#       * Copies mails to correct directories.
#

# Usage:
#   1) Specify these variables below:
#
#       * source_dir    -> Where you store WinMail user mailboxes.
#       * target_dir    -> Where you want to store converted mailboxes.
#       * vmail_user    -> Owner (user) of your user mailboxes.
#       * vmail_group   -> Owner (group) of your user mailboxes.
#
#       Default file localtion looks like below:
#
#           /path/to/mail/store/
#                           |- user1@example.com/
#                           |- user2@example.com/
#                           |- user3@example.com/
#                           |- convert_winmail_mailbox.sh   # <- we are here.
#
#   2) Execute command:
#
#       # sh convert_winmail_mailbox.sh
#
#      It will create new directory named as domain name, and user
#      mailbox is named as username (without domain part), such as:
#
#           example.com/
#               |- user1/
#                   |- cur/     # Received, read.
#                   |- new/     # Received, unread.
#                   |- tmp/
#                   |- .Drafts/ # Drafts.
#                   |- .Sent/   # Sent.
#                   |- .Trash/  # Trash, deleted.
#               |- user2/
#
#   3) Copy the 'example.com/' to the location where you store user
#      mailboxes.

# Your original WinMail user mailboxes.
source_dir='./'
# Copy emails to another directory, it will be standard IMAP directory
# structure (mailbox format).
target_dir='./'

# vmail user name/uid.
vmail_user='vmail'
# vmail group name/uid.
vmail_group='vmail'

for i in $(ls -d *@w-ibeda.com)
do
    username="$(echo $i | awk -F'@' '{print $1}')"
    domain="$(echo $i | awk -F'@' '{print $2}')"
    mailbox="${target_dir}/$domain/$username/"
    
    #mailbox="$(echo $i | awk -F'@' '{print $1"/"$2"/"}')"

    # Create necessary directories as mailbox format.
    # Inbox.
    mkdir -p ${mailbox}/{cur,new,tmp}
    # Sent,Junk,Drafts,Trash
    mkdir -p ${mailbox}/.{Sent,Junk,Drafts,Trash}/{cur,new,tmp}

    find_dir="${source_dir}/$i/"

    # Copy inbox.
    for email in $(find ${find_dir} -iname '*.in')
    do
        cp -f $email ${mailbox}/cur/
    done

    # Copy deleted mails.
    for email in $(find ${find_dir} -iname '*.del')
    do
        cp -f $email ${mailbox}/.Trash/
    done

    # Copy sent mails.
    for email in $(find ${find_dir} -iname '*.out')
    do
        cp -f $email ${mailbox}/.Sent/
    done

    chown -R ${vmail_user}:${vmail_group} ${target_dir}/${domain}
done
