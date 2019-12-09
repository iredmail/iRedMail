#!/usr/bin/env bash
# Author: Zhang Huangbin <zhb@iredmail.org>
# Purpose: Find usernames used for smtp authentication in Postfix log file,
#          sorted by login times.

MAILLOG_FILE="$1"

# Detect mail log file if not specified on command line.
if [ -z ${MAILLOG_FILE} ]; then
    for f in /var/log/maillog /var/log/mail.log; do
        if [ -f ${f} ]; then
            MAILLOG_FILE="${f}"
            break
        fi
    done
fi

if [ -z ${MAILLOG_FILE} ]; then
    echo "Please specify Postfix log file on command line: $0 /path/to/maillog"
    exit 255
fi

grep 'sasl_username=' ${MAILLOG_FILE} \
    | awk -F'sasl_username=' '{print $2}' \
    | awk '{print $NF}' \
    | sort \
    | uniq -c \
    | sort -nr
