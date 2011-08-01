#!/usr/bin/env bash

# Author:   Zhang Huangbin (michaelbibby <at> gmail.com )
# Purpose:  Migrate ExtMail MySQL 'mailbox' table to iRedMail format.
# Project:  iRedMail (http://www.iredmail.org/)
#
# Migration guide wrote in Chinese:
#   http://www.iredmail.org/wiki/index.php?title=Migrate_from_ExtMail_Solution

# Usage:
#   English:
#   * Run into MySQL command line with privilege user, e.g. root.
#       # mysql -uroot -p extmail
#   * Select some column from mailbox table:
#       mysql> SELECT username,password,name,maildir,quota,netdiskquota,domain,createdate,active
#            > INTO OUTFILE '/tmp/mailbox.sql'
#            > FROM mailbox;
#   * Run this script:
#       # sh migrate_extmail_mailbox.sh /tmp/mailbox.sql
#     It will create a new file: /tmp/mailbox.sql.new
#   * Import this new file in MySQL command line:
#       mysql> USE vmail;
#       mysql> SOURCE /tmp/mailbox.sql.new;

usage()
{
    echo -e "\nUsage: sh $0 script\n"
}

[ X"$#" != X"1" ] && usage && exit 255 

OUTPUT_SQL="$1.iRedMail"
echo ''> ${OUTPUT_SQL}

while read line; do
    username="$(echo $line | awk '{print $1}')"
    password="$(echo $line | awk '{print $2}')"
    maildir="$(echo $line | awk '{print $3}' | awk -F'Maildir/' '{print $1}' | tr [A-Z] [a-z] )"
    quota="$(echo $line | awk '{print $4}')"
    netdiskquota="$(echo $line | awk '{print $5}')"
    domain="$(echo $line | awk '{print $6}')"
    createdate="$(echo $line | awk '{print $7, $8}')"
    active="$(echo $line | awk '{print $9}')"

    echo $quota | grep -i 'S$' >/dev/null 2>&1
    if [ X"$?" == X"0" ]; then
        quota="$(echo $quota | sed 's/S$//')"
        quota="$(expr \( $quota / 1024 \) )"
    else
        :
    fi

    cat >> ${OUTPUT_SQL} <<EOF
INSERT INTO mailbox (username, password, maildir, quota, netdiskquota, domain, created, active) values ("$username", "$password", "$maildir", $quota, $quota, "$domain", "$createdate", "$active");
EOF
done < $1

cat <<EOF
Warning: you may want to change 'mail_location' setting in /etc/dovecot.conf like below:

    mail_location = maildir:/%Lh/Maildir/:INDEX=/%Lh/Maildir/

EOF
