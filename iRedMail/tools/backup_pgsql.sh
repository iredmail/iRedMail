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
#       PGSQL_ADMIN
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
# System user used to run PostgreSQL daemon.
#   - On Linux, it's postgres.
#   - On FreeBSD, it's pgsql.
#   - On OpenBSD, it's _postgresql.
export PGSQL_SYS_USER='postgres'

# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

# Databases we should backup.
# Multiple databases MUST be seperated by SPACE.
# Your iRedMail server might have below databases:
# vmail, roundcubemail, cluebringer, amavisd, iredadmin.
export DATABASES='vmail roundcubemail policyd amavisd iredadmin'

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
export PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

# Commands.
export CMD_DATE='/bin/date'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'
export CMD_PG_DUMP='pg_dump'

# Date.
export YEAR="$(${CMD_DATE} +%Y)"
export MONTH="$(${CMD_DATE} +%m)"
export DAY="$(${CMD_DATE} +%d)"
export TIME="$(${CMD_DATE} +%H:%M:%S)"
export TIMESTAMP="${YEAR}-${MONTH}-${DAY}-${TIME}"

# Pre-defined backup status
export BACKUP_SUCCESS='YES'

# Define, check, create directories.
export BACKUP_DIR="${BACKUP_ROOTDIR}/pgsql/${YEAR}/${MONTH}/${DAY}"

# Log file
export LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

# Check and create directories.
[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} 2>/dev/null

# Get HOME directory of PGSQL_SYS_USER
export PGSQL_SYS_USER_HOME="$(su - ${PGSQL_SYS_USER} -c 'echo $HOME')"

# Initialize log file.
echo "* Starting at: ${YEAR}-${MONTH}-${DAY}-${TIME}." >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}

# Backup.
echo "* Backing up databases ..." >> ${LOGFILE}
for db in ${DATABASES}; do
    output_sql="${db}-${TIMESTAMP}.sql"

    # Check database existence
    su - "${PGSQL_SYS_USER}" -c "psql -d ${db} -c '\q' >/dev/null 2>&1"

    # Dump
    if [ X"$?" == X'0' ]; then
        su - "${PGSQL_SYS_USER}" -c "${CMD_PG_DUMP} ${db} > ${PGSQL_SYS_USER_HOME}/${output_sql}"

        if [ X"$?" == X'0' ]; then
            # Move to backup directory.
            mv ${PGSQL_SYS_USER_HOME}/${output_sql} ${BACKUP_DIR}

            cd ${BACKUP_DIR}

            # Get original SQL file size
            original_size="$(${CMD_DU} ${output_sql} | awk '{print $1}')"

            # Compress
            ${CMD_COMPRESS} ${output_sql} >>${LOGFILE}

            rm -f ${output_sql} >> ${LOGFILE}
            echo -e "  + ${db} [DONE]" >> ${LOGFILE}

            # Get compressed file size
            if echo ${CMD_COMPRESS} | grep '^bzip2' >/dev/null; then
                compressed_file_name="${output_sql}.bz2"
            else
                compressed_file_name="${output_sql}.gz"
            fi
            compressed_size="$(${CMD_DU} ${compressed_file_name} | awk '{print $1}')"

            # Log to SQL table `iredadmin.log`, so that global domain admins
            # can check backup status
            sql_success="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Database backup: ${db}. Original file size: ${original_size}, compressed: ${compressed_size}, backup file: ${compressed_file_name}', 'cron_backup_sql_db', '127.0.0.1', NOW());"

            su - "${PGSQL_SYS_USER}" >/dev/null <<EOF
psql -d iredadmin <<EOF2
${sql_success}
EOF2
EOF
        else
            [ X"${BACKUP_SUCCESS}" == X'YES' ] && export BACKUP_SUCCESS='NO'
            # TODO Log failure
            :
        fi
    fi
done

# Append file size of backup files.
echo -e "* File size:\n----" >>${LOGFILE}
${CMD_DU} ${BACKUP_DIR}/*${TIMESTAMP}*sql* >>${LOGFILE}
echo "----" >>${LOGFILE}

echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >>${LOGFILE}

if [ X"${BACKUP_SUCCESS}" == X"YES" ]; then
    echo -e "\n[OK] Backup successfully completed.\n"
else
    echo -e "\n[ERROR] Backup completed with ERRORS.\n" 1>&2
fi

echo "* Backup log: ${LOGFILE}:"
cat ${LOGFILE}
