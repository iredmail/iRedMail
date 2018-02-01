#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Date:     2012-09-06
# Purpose:  Backup specified PostgreSQL databases with command 'pg_dump'.
# License:  This shell script is part of iRedMail project, released under GPLv2.

###########################
# REQUIREMENTS
###########################
#
#   * Required commands:
#       + pg_dump
#       + du
#       + bzip2     # If bzip2 is not available, change 'CMD_COMPRESS'
#                   # to use 'gzip'.
#

###########################
# USAGE
###########################
#
#   * It stores all backup copies in directory '/var/vmail/backup' by default,
#     You can change it in variable $BACKUP_ROOTDIR below.
#
#   * Set correct values for below variables:
#
#       SYS_USER_PGSQL
#       BACKUP_ROOTDIR
#       DATABASES
#
#   * Add crontab job for root user (or whatever user you want):
#
#       # crontab -e -u root
#       1   4   *   *   *   bash /path/to/backup_pgsql.sh
#
#   * Make sure 'crond' service is running.
#

#########################################################
# Modify below variables to fit your need ----
#########################################################
# Keep backup for how many days. Default is 90 days.
KEEP_DAYS='90'

# System user used to run PostgreSQL daemon.
#   - On Linux, it's postgres.
#   - On FreeBSD, it's pgsql.
#   - On OpenBSD, it's _postgresql.
export SYS_USER_PGSQL='postgres'

# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

# Databases we should backup.
# Multiple databases MUST be seperated by SPACE.
# Your iRedMail server might have below databases:
# vmail, roundcubemail, cluebringer, amavisd, iredadmin.
export DATABASES='vmail roundcubemail amavisd iredadmin sogo iredapd'

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
export PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

# Commands.
export CMD_DATE='/bin/date'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'
export COMPRESS_SUFFIX='bz2'
export CMD_PG_DUMP='pg_dump'

# Date.
export YEAR="$(${CMD_DATE} +%Y)"
export MONTH="$(${CMD_DATE} +%m)"
export DAY="$(${CMD_DATE} +%d)"
export TIME="$(${CMD_DATE} +%H-%M-%S)"
export TIMESTAMP="${YEAR}-${MONTH}-${DAY}-${TIME}"

# Pre-defined backup status
export BACKUP_SUCCESS='YES'

# Define, check, create directories.
export BACKUP_DIR="${BACKUP_ROOTDIR}/pgsql/${YEAR}/${MONTH}/${DAY}"

# Find the old backup which should be removed.
export REMOVE_OLD_BACKUP='NO'
if which python &>/dev/null; then
    export REMOVE_OLD_BACKUP='YES'
    py_cmd="import time; import datetime; t=time.localtime(); print datetime.date(t.tm_year, t.tm_mon, t.tm_mday) - datetime.timedelta(days=${KEEP_DAYS})"
    shift_date=$(python -c "${py_cmd}")
    shift_year="$(echo ${shift_date} | awk -F'-' '{print $1}')"
    shift_month="$(echo ${shift_date} | awk -F'-' '{print $2}')"
    shift_day="$(echo ${shift_date} | awk -F'-' '{print $3}')"
    export REMOVED_BACKUP_DIR="${BACKUP_ROOTDIR}/pgsql/${shift_year}/${shift_month}/${shift_day}"
fi

# Log file
export LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

# Check and create directories.
[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} 2>/dev/null
chown root ${BACKUP_DIR}
chmod 0700 ${BACKUP_DIR}

# Get HOME directory of SYS_USER_PGSQL
export PGSQL_USER_HOMEDIR="$(su - ${SYS_USER_PGSQL} -c 'echo $HOME')"

# Initialize log file.
echo "* Starting at: ${YEAR}-${MONTH}-${DAY}-${TIME}." >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}

# Backup.
echo "* Backing up databases: ${DATABASES}." >> ${LOGFILE}
for db in ${DATABASES}; do
    output_sql="${db}-${TIMESTAMP}.sql"

    # Check database existence
    su - "${SYS_USER_PGSQL}" -c "psql -d ${db} -c '\q' >/dev/null 2>&1"

    # Dump
    if [ X"$?" == X'0' ]; then
        su - "${SYS_USER_PGSQL}" -c "${CMD_PG_DUMP} ${db} > ${PGSQL_USER_HOMEDIR}/${output_sql}"

        if [ X"$?" == X'0' ]; then
            # Move to backup directory.
            mv ${PGSQL_USER_HOMEDIR}/${output_sql} ${BACKUP_DIR}

            cd ${BACKUP_DIR}

            # Get original SQL file size
            original_size="$(${CMD_DU} ${output_sql} | awk '{print $1}')"

            # Compress
            ${CMD_COMPRESS} ${output_sql} >>${LOGFILE}

            rm -f ${output_sql} >> ${LOGFILE}
            echo -e "  + ${db} [DONE]" >> ${LOGFILE}

            # Get compressed file size
            compressed_file_name="${output_sql}.${COMPRESS_SUFFIX}"
            compressed_size="$(${CMD_DU} ${compressed_file_name} | awk '{print $1}')"

            # Log to SQL table `iredadmin.log`, so that global domain admins
            # can check backup status
            sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Database: ${db}, size: ${compressed_size} (original: ${original_size})', 'cron_backup_sql', '127.0.0.1', NOW());"
        else
            export BACKUP_SUCCESS='NO'
            sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Database backup failed: ${db}, check log file ${LOGFILE} for more details.', 'cron_backup_sql', '127.0.0.1', NOW());"
        fi

        su - "${SYS_USER_PGSQL}" >/dev/null <<EOF
psql -d iredadmin <<EOF2
${sql_log_msg}
EOF2
EOF
    fi
done

# Append file size of backup files.
echo -e "* File size:\n----" >>${LOGFILE}
cd ${BACKUP_DIR} && \
${CMD_DU} *${TIMESTAMP}*sql* >>${LOGFILE}
echo "----" >>${LOGFILE}

echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >>${LOGFILE}

if [ X"${BACKUP_SUCCESS}" == X'YES' ]; then
    echo -e "\n[OK] Backup successfully completed.\n"
else
    echo -e "\n[ERROR] Backup completed with ERRORS.\n" 1>&2
fi

if [ X"${REMOVE_OLD_BACKUP}" == X'YES' -a -d ${REMOVED_BACKUP_DIR} ]; then
    echo -e "* Old backup found. Deleting: ${REMOVED_BACKUP_DIR}." >>${LOGFILE}
    rm -rf ${REMOVED_BACKUP_DIR} >> ${LOGFILE} 2>&1

    su - ${SYS_USER_PGSQL} -c "psql -d iredadmin" <<EOF
INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES
    ('backup', 'info', 'Remove old backup: ${REMOVED_BACKUP_DIR}.', 'cron_backup_sql', '127.0.0.1', NOW());
EOF
fi

echo "* Backup log: ${LOGFILE}:"
cat ${LOGFILE}
