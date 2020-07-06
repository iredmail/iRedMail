#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)
# Purpose:  Backup SOGo database with `sogo-tool` command.
#           You can run this script manually or via crontab (recommended).
#
# Backing up SOGo data by dumping SQL database to a plain SQL file is not ideal
# because:
#
#   - it's hard to restore single user's data
#   - if SOGo changes some SQL structure, it's hard to restore all data.
#
# This script does backup with 'sogo-tool backup' command to avoid issues
# mentioned above, it stores each user's data in a single file, so you can
# restore a single user's data or all users data with 'sogo-tool restore'.

# Required commands:
#
#       + sogo-tool
#       + tar
#       + bzip2

# USAGE
#
#   * It stores backup copies under '/var/vmail/backup/sogo' by default,
#     feel free to change it with variable BACKUP_ROOTDIR below.
#
#   * If you want to log a message in iRedAdmin database (`iredadmin.log`),
#     please specify correct MySQL username in variable MYSQL_USER, and
#     write the same MySQL username and password in file /root/.my.cnf.
#
#   * Add crontab job for root user:
#
#       # crontab -e -u root
#       1   4   *   *   *   bash /var/vmail/backup/backup_sogo.sh

# Keep backup for how many days. Defaults to 90 days.
export KEEP_DAYS='90'

# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

# MySQL username. Root user is required to dump all databases.
export MYSQL_USER='root'

# ~/.my.cnf
export MYSQL_DOT_MY_CNF='/root/.my.cnf'

export CMD_MYSQL="mysql --defaults-file=${MYSQL_DOT_MY_CNF} -u${MYSQL_USER}"

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
# FreeBSD has 'sogo-tool' in different directory.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/GNUstep/Local/Tools/Admin:$PATH

# Commands.
export CMD_DATE='/bin/date'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'
export COMPRESS_SUFFIX='bz2'

# Path to sogo-tool command.
export CMD_SOGO_TOOL='sogo-tool'

# Date.
export YEAR="$(${CMD_DATE} +%Y)"
export MONTH="$(${CMD_DATE} +%m)"
export DAY="$(${CMD_DATE} +%d)"
export TIME="$(${CMD_DATE} +%H-%M-%S)"
export TIMESTAMP="${YEAR}-${MONTH}-${DAY}-${TIME}"

# Pre-defined backup status
export BACKUP_SUCCESS='YES'

# Define, check, create directories.
export BACKUP_DIR="${BACKUP_ROOTDIR}/sogo/${YEAR}/${MONTH}/${DAY}"

# Find the old backup which should be removed.
export REMOVE_OLD_BACKUP='YES'

export KERNEL="$(uname -s)"
if [[ X"${KERNEL}" == X'Linux' ]]; then
    shift_year=$(date --date="${KEEP_DAYS} days ago" "+%Y")
    shift_month=$(date --date="${KEEP_DAYS} days ago" "+%m")
    shift_day=$(date --date="${KEEP_DAYS} days ago" "+%d")
elif [[ X"${KERNEL}" == X'FreeBSD' ]]; then
    shift_year=$(date -j -v-${KEEP_DAYS}d "+%Y")
    shift_month=$(date -j -v-${KEEP_DAYS}d "+%m")
    shift_day=$(date -j -v-${KEEP_DAYS}d "+%d")
elif [[ X"${KERNEL}" == X'OpenBSD' ]]; then
    epoch_seconds_now="$(date +%s)"
    epoch_shift="$((${KEEP_DAYS} * 86400))"
    epoch_seconds_old="$((epoch_seconds_now - epoch_shift))"

    shift_year=$(date -r ${epoch_seconds_old} "+%Y")
    shift_month=$(date -r ${epoch_seconds_old} "+%m")
    shift_day=$(date -r ${epoch_seconds_old} "+%d")
else
    export REMOVE_OLD_BACKUP='NO'
fi

export REMOVED_BACKUP="${BACKUP_ROOTDIR}/sogo/${shift_year}/${shift_month}/${shift_day}.tar.bz2"
export REMOVED_BACKUP_MONTH_DIR="${BACKUP_ROOTDIR}/sogo/${shift_year}/${shift_month}"
export REMOVED_BACKUP_YEAR_DIR="${BACKUP_ROOTDIR}/sogo/${shift_year}"

# Check and create directories.
if [ ! -d ${BACKUP_DIR} ]; then
    mkdir -p ${BACKUP_DIR} 2>/dev/null
    chown -R root ${BACKUP_DIR}
    chmod -R 0700 ${BACKUP_DIR}
fi

# Backup
echo "* Backup all users' data under ${BACKUP_DIR}"
${CMD_SOGO_TOOL} backup ${BACKUP_DIR} ALL

dir_name="$(dirname ${BACKUP_DIR})"
base_name="$(basename ${BACKUP_DIR})"

if ls ${BACKUP_DIR} | grep -i '[a-z0-9]' &>/dev/null; then
    # Backup is not empty.
    chown -R root ${BACKUP_DIR}
    chmod -R 0700 ${BACKUP_DIR}

    # Get original size of backup files
    original_size="$(${CMD_DU} ${BACKUP_DIR} | awk '{print $1}')"

    # Compress the directory.
    echo "* Compress backup files."
    cd ${dir_name} &&\
        tar cjf ${base_name}.tar.bz2 ${base_name} && \
        chown root ${base_name}.tar.bz2 && \
        chmod 0400 ${base_name}.tar.bz2 && \
        rm -rf ${base_name}

    compressed_size="$(${CMD_DU} ${base_name}.tar.bz2 | awk '{print $1}')"
    if [ -n X"${MYSQL_USER}" -a -f ${MYSQL_DOT_MY_CNF} ]; then
        sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'SOGo data. size: ${compressed_size} (original: ${original_size})', 'cron_backup_sogo', '127.0.0.1', UTC_TIMESTAMP());"
        ${CMD_MYSQL} iredadmin -e "${sql_log_msg}"
    fi
else
    echo "* Backup is empty, remove temporary backup directory: ${BACKUP_DIR}."
    rm -rf ${BACKUP_DIR} &>/dev/null
fi

if [ X"${REMOVE_OLD_BACKUP}" == X'YES' -a -f ${REMOVED_BACKUP} ]; then
    echo -e "* Old backup found. Deleting: ${REMOVED_BACKUP}."
    rm -rf ${REMOVED_BACKUP} &>/dev/null

    # Try to remove empty directory.
    rmdir ${REMOVED_BACKUP_MONTH_DIR} 2>/dev/null
    rmdir ${REMOVED_BACKUP_YEAR_DIR} 2>/dev/null
fi

exit 0
