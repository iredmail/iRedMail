#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)
# Date:     16/09/2007
# Purpose:  Backup specified mysql databases with command 'mysqldump'.
# License:  This shell script is part of iRedMail project, released under
#           GPL v2.

###########################
# REQUIREMENTS
###########################
#
#   * Required commands:
#       + mysqldump
#       + du
#       + bzip2 or gzip     # If bzip2 is not available, change 'CMD_COMPRESS'
#                           # to use 'gzip'.
#

###########################
# USAGE
###########################
#
#   * It stores all backup copies in directory '/backup' by default, you can
#     change it in variable $BACKUP_ROOTDIR below.
#
#   * Set correct values for below variables:
#
#       BACKUP_ROOTDIR
#       MYSQL_USER
#       MYSQL_PASSWD
#       DATABASES
#       DB_CHARACTER_SET
#       COMPRESS
#       DELETE_PLAIN_SQL_FILE
#
#   * Add crontab job for root user (or whatever user you want):
#
#       # crontab -e -u root
#       1   4   *   *   *   bash /path/to/backup_mysql.sh
#   
#   * Make sure 'crond' service is running, and will start automatically when
#     system startup:
#
#       # ---- On RHEL/CentOS ----
#       # chkconfig --level 345 crond on
#       # /etc/init.d/crond status
#
#       # ---- On Debian/Ubuntu ----
#       # update-rc.d cron defaults
#       # /etc/init.d/cron status
#

###########################
# DIRECTORY STRUCTURE
###########################
#
#   $BACKUP_ROOTDIR             # Default is /backup
#       |- mysql/               # Used to store all backed up databases.
#           |- YEAR.MONTH/
#               |- YEAR.MONTH.DAY/
#                   |- DB.YEAR.MONTH.DAY.MIN.HOUR.SECOND.sql
#                               # Backup copy, plain SQL file.
#                               # Note: it will be removed immediately after
#                               # it was compressed with success and 
#                               # DELETE_PLAIN_SQL_FILE='YES'
#
#                   |- DB.YEAR.MONTH.DAY.HOUR.MINUTE.SECOND.sql.bz2
#                               # Backup copy, compressed SQL file.
#
#       |- logs/
#           |- YEAR.MONTH/
#               |- mysql-YEAR.MONTH.DAY.MIN.HOUR.SECOND.log     # Log file
#

#########################################################
# Modify below variables to fit your need ----
#########################################################
# Where to store backup copies.
BACKUP_ROOTDIR='/backup'

# MySQL user and password.
MYSQL_USER='root'
MYSQL_PASSWD='passwd'

# Which database(s) we should backup. Multiple databases MUST be seperated by
# a SPACE.
# Your iRedMail server might have below databases:
# mysql, roundcubemail, policyd (or postfixpolicyd), amavisd, iredadmin
DATABASES='mysql roundcubemail postfixpolicyd amavisd iredadmin'

# Database character set for ALL databases.
# Note: Currently, it doesn't support to specify character set for each databases.
DB_CHARACTER_SET="utf8"

# Compress plain SQL file: YES, NO.
COMPRESS="YES"

# Delete plain SQL files after compressed. Compressed copy will be remained.
DELETE_PLAIN_SQL_FILE="YES"

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
# Commands.
CMD_DATE='/bin/date'
CMD_DU='du -sh'
CMD_COMPRESS='bzip2 -9'
CMD_MYSQLDUMP='mysqldump'
CMD_MYSQL='mysql'

# Date.
MONTH="$(${CMD_DATE} +%Y.%m)"
DAY="$(${CMD_DATE} +%d)"
DATE="$(${CMD_DATE} +%Y.%m.%d.%H.%M.%S)"

export BACKUP_SUCCESS='YES'

# Define, check, create directories.
BACKUP_DIR="${BACKUP_ROOTDIR}/mysql/${MONTH}/${DAY}"

# Logfile directory. Default is /backup/logs/YYYY.MM/.
LOG_DIR="${BACKUP_ROOTDIR}/logs/${MONTH}"
LOGFILE="${LOG_DIR}/mysql-${DATE}.log"

# Check required variables.
if [ X"${MYSQL_USER}" == X"" -o X"${MYSQL_PASSWD}" == X"" -o X"${DATABASES}" == X"" ]; then
    echo "[ERROR] You don't have correct MySQL related configurations in file: ${0}" 1>&2
    echo -e "\t- MYSQL_USER\n\t- MYSQL_PASSWD\n\t- DATABASES" 1>&2
    echo "Please configure them first." 1>&2

    exit 255
fi

# Verify MySQL connection.
${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" -e "show databases" >/dev/null 2>&1
if [ X"$?" != X"0" ]; then
    echo "[ERROR] MySQL username or password is incorrect in file ${0}." 1>&2
    echo "Please fix them first." 1>&2

    exit 255
fi

# Check and create directories.
if [ ! -d ${BACKUP_DIR} ]; then
    echo "* Create data directory: ${BACKUP_DIR} ..."
    mkdir -p ${BACKUP_DIR} 2>/dev/null
fi

if [ ! -d ${LOG_DIR} ]; then
    echo "* Create log directory: ${LOG_DIR} ..."
    mkdir -p ${LOG_DIR} 2>/dev/null
fi

# Initialize log file.
echo "* Starting backup: ${DATE}." >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}
echo "* Log file: ${LOGFILE}." >>${LOGFILE}

backup_db()
{
    # USAGE:
    #  # backup dbname
    db="${1}"
    output_sql="${BACKUP_DIR}/${DATE}-${db}.sql"

    ${CMD_MYSQLDUMP} \
        -u"${MYSQL_USER}" \
        -p"${MYSQL_PASSWD}" \
        --default-character-set=${DB_CHARACTER_SET} \
        ${db} > ${output_sql}
}

# Backup.
echo "* Backing up databases ..." >> ${LOGFILE}
for db in ${DATABASES}; do
    backup_db ${db} >>${LOGFILE} 2>&1

    if [ X"$?" == X"0" ]; then
        echo "  - [DONE] ${db}" >> ${LOGFILE}
    else
        [ X"${BACKUP_SUCCESS}" == X"YES" ] && export BACKUP_SUCCESS='NO'
    fi
done

# Compress plain SQL file.
if [ X"${COMPRESS}" == X"YES" ]; then
    echo "* Compressing plain SQL files ..." >>${LOGFILE}
    for sql_file in $(ls ${BACKUP_DIR}/*${DATE}*); do
        ${CMD_COMPRESS} ${sql_file} >>${LOGFILE} 2>&1

        if [ X"$?" == X"0" ]; then
            echo "  - [DONE] $(basename ${sql_file})" >>${LOGFILE}

            # Delete plain SQL file after compressed.
            if [ X"${DELETE_PLAIN_SQL_FILE}" == X"YES" -a -f ${sql_file} ]; then
                echo -n "* Removing plain SQL file: ${sql_file}..." >>${LOGFILE}
                rm -f ${BACKUP_DIR}/*${DATE}*sql >>${LOGFILE} 2>&1
            fi
        fi
    done
fi

# Append file size of backup files.
echo "* File size:" >>${LOGFILE}
echo "=================" >>${LOGFILE}
${CMD_DU} ${BACKUP_DIR}/*${DATE}* >>${LOGFILE}
echo "=================" >>${LOGFILE}

echo "* Backup complete (Successfully: ${BACKUP_SUCCESS})." >>${LOGFILE}

if [ X"${BACKUP_SUCCESS}" == X"YES" ]; then
    cat <<EOF
* Backup completed successfully.
EOF
else
    echo -e "\n* Backup completed with !!!ERRORS!!!.\n" 1>&2
fi

cat << EOF
    + Data: ${BACKUP_FILE}*
    + Log: ${LOGFILE}
EOF

