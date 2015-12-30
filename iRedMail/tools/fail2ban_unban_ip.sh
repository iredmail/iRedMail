#!/usr/bin/env bash

# Purpose: Unban specified IP address(es) from all Fail2ban jails.
# Author: Zhang Huangbin

# Usage:
#
#   bash fail2ban_unban_ip.sh 192.168.1.1 [192.168.2.2 ...]

# Get all IP addresses from command line.
IPS="$@"

# Path to command 'fail2ban-client'
F2B='fail2ban-client'

# Get all jails.
JAILS="$(${F2B} status | grep 'Jail list:' | awk -F'Jail list:' '{print $2}' | sed 's/,//g')"

for jail in ${JAILS}; do
    for ip in ${IPS}; do
        ${F2B} set ${jail} unbanip ${ip} &>/dev/null
        if [ X"$?" == X'0' ]; then
            echo "Removed ${ip} from jail '${jail}'"
        fi
    done
done
