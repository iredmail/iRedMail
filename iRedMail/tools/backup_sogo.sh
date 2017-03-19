#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)
# Purpose:  Backup SOGo database with `sogo-tool` command.
#           You can run this script manually or via crontab (recommended).
#
#           Backing up SOGo data by exporting SQL database is not ideal because
#           it's hard to restore single user's data, that's why we backup with
#           'sogo-tool backup' command, it's easy to restore with
#           'sogo-tool restore' command.

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
KEEP_DAYS='90'

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
export PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

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
export REMOVE_OLD_BACKUP='NO'
if which python &>/dev/null; then
    export REMOVE_OLD_BACKUP='YES'
    py_cmd="import time; import datetime; t=time.localtime(); print datetime.date(t.tm_year, t.tm_mon, t.tm_mday) - datetime.timedelta(days=${KEEP_DAYS})"
    shift_date=$(python -c "${py_cmd}")
    shift_year="$(echo ${shift_date} | awk -F'-' '{print $1}')"
    shift_month="$(echo ${shift_date} | awk -F'-' '{print $2}')"
    shift_day="$(echo ${shift_date} | awk -F'-' '{print $3}')"
    export REMOVED_BACKUP_DIR="${BACKUP_ROOTDIR}/sogo/${shift_year}/${shift_month}/${shift_day}"
fi

# Check and create directories.
if [ ! -d ${BACKUP_DIR} ]; then
    echo "* Create directory ${BACKUP_DIR}."
    mkdir -p ${BACKUP_DIR} 2>/dev/null
    chown root ${BACKUP_DIR}
    chmod 0700 ${BACKUP_DIR}
fi

# Backup
echo "* Backup all users' data under ${BACKUP_DIR}"
${CMD_SOGO_TOOL} backup ${BACKUP_DIR} ALL

# Get original size of backup files
original_size="$(${CMD_DU} ${BACKUP_DIR} | awk '{print $1}')"

dir_name="$(dirname ${BACKUP_DIR})"
base_name="$(basename ${BACKUP_DIR})"

# Compress the directory.
echo "* Compress backup files."
cd ${dir_name}
    tar cjf ${base_name}.tar.bz2 ${base_name} && \
    rm -rf ${base_name}

compressed_size="$(${CMD_DU} ${base_name}.tar.bz2 | awk '{print $1}')"
if [ -n X"${MYSQL_USER}" -a -f ${MYSQL_DOT_MY_CNF} ]; then
    sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'SOGo data. size: ${compressed_size} (original: ${original_size})', 'cron_backup_sogo', '127.0.0.1', UTC_TIMESTAMP());"
    ${CMD_MYSQL} iredadmin -e "${sql_log_msg}"
fi

# Backup.
if [ X"${REMOVE_OLD_BACKUP}" == X'YES' -a -d ${REMOVED_BACKUP_DIR} ]; then
    echo -e "* Delete old backup: ${REMOVED_BACKUP_DIR}."
    echo -e "* Suppose to delete: ${REMOVED_BACKUP_DIR}"
    rm -rf ${REMOVED_BACKUP_DIR}
fi
