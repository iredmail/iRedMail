#!/usr/bin/env bash
# Purpose: Find and sort usernames used for smtp authentication in Postfix log
#          file.

MAIL_LOG="$1"

if [ -z ${MAIL_LOG} ]; then
    echo "Please specify the mail log file: $0 /path/to/maillog"
    exit 255
fi

tmpfile="/tmp/sasl_username_${RANDOM}"
grep 'sasl_username=' ${MAIL_LOG} > ${tmpfile}
awk '{print $NF}' ${tmpfile}  | sort | uniq -c | sort -n

rm -f ${tmpfile}
