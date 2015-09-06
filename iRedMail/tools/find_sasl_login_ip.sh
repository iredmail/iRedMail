#!/usr/bin/env bash
# Purpose: Find login IP address of specified username which is used for smtp
#          authentication.

MAIL_LOG="$1"
USER="$2"

if [ -z ${MAIL_LOG} -o -z ${USER} ]; then
    echo "Please run script with a log file and email address: $0 /path/to/maillog mail_address"
    exit 255
fi

tmpfile="/tmp/sasl_username_${RANDOM}"

# extract 'client=xxx[__IP__]' lines
grep "sasl_username=${USER}" ${MAIL_LOG} | awk '{print $7}' | sort | uniq -c | sort -n > sort > ${tmpfile}

cat ${tmpfile}

rm -f ${tmpfile}
