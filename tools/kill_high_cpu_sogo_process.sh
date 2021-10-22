#!/usr/bin/env bash
#
# Purpose: Kill SOGo child processes which have been running too long, they
#          may cause high CPU usage.
# Author: Zhang Huangbin <zhb@iredmail.org>
# Based on Jan-Frode Myklebust's script published on 04 Apr 2013:
#   https://www.mail-archive.com/users@sogo.nu/msg14152.html

# Allow to run for how long (in minutes). e.g. 15, 25.
LONGEST=10

# Kill a pid.
k() {
    # Usage: k <pid>
    pid="${1}"

    echo "Killing PID $pid"
    ps -fp $pid
    kill -9 $pid
}

ps -u sogo -opid,ppid,cputime | grep -v PPID | while read pid ppid time; do
    # Don't kill main daemon (ppid=1).
    if [[ X"$ppid" != X"1" ]]; then
        hours="$(echo $time | cut -d: -f1 | sed 's/^0//')"
        minutes="$(echo $time | cut -d: -f2 | sed 's/^0//')"

        if [[ $minutes -gt ${LONGEST} ]] || [[ $hours -gt 0 ]]; then
            k ${pid}
        fi
    fi
done
