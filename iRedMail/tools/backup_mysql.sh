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
#   * It stores all backup copies in directory '/var/vmail/backup' by default,
#     You can change it in variable $BACKUP_ROOTDIR below.
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

#########################################################
# Modify below variables to fit your need ----
#########################################################
# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

# MySQL user and password.
export MYSQL_USER='root'
export MYSQL_PASSWD='passwd'

# Databases we should backup.
# Multiple databases MUST be seperated by SPACE.
# Your iRedMail server might have below databases:
# mysql, roundcubemail, policyd (or postfixpolicyd), amavisd, iredadmin
export DATABASES='mysql roundcubemail policyd amavisd iredadmin'

# Database character set for ALL databases.
# Note: Currently, it doesn't support to specify character set for each databases.
export DB_CHARACTER_SET="utf8"

# Compress plain SQL file: YES, NO.
export COMPRESS="YES"

# Delete plain SQL files after compressed. Compressed copy will be remained.
export DELETE_PLAIN_SQL_FILE="YES"

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
export PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

# Commands.
export CMD_DATE='/bin/date'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'
export CMD_MYSQLDUMP='mysqldump'
export CMD_MYSQL='mysql'

# Date.
export YEAR="$(${CMD_DATE} +%Y)"
export MONTH="$(${CMD_DATE} +%m)"
export DAY="$(${CMD_DATE} +%d)"
export TIME="$(${CMD_DATE} +%H.%M.%S)"
export TIMESTAMP="${YEAR}.${MONTH}.${DAY}.${TIME}"

# Pre-defined backup status
export BACKUP_SUCCESS='YES'

# Define, check, create directories.
export BACKUP_DIR="${BACKUP_ROOTDIR}/mysql/${YEAR}/${MONTH}/${DAY}"

# Log file
export LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

# Check required variables.
if [ X"${MYSQL_USER}" == X"" -o X"${MYSQL_PASSWD}" == X"" -o X"${DATABASES}" == X"" ]; then
    echo "[ERROR] You don't have correct MySQL related configurations in file: ${0}" 1>&2
    echo -e "\t- MYSQL_USER\n\t- MYSQL_PASSWD\n\t- DATABASES" 1>&2
    echo "Please configure them first." 1>&2

    exit 255
fi

# Verify MySQL connection.
${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" -e "show databases" &>/dev/null
if [ X"$?" != X"0" ]; then
    echo "[ERROR] MySQL username or password is incorrect in file ${0}." 1>&2
    echo "Please fix them first." 1>&2

    exit 255
fi

# Check and create directories.
[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} 2>/dev/null

# Initialize log file.
echo "* Starting backup: ${TIMESTAMP}." >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}

backup_db()
{
    # USAGE:
    #  # backup dbname
    db="${1}"
    output_sql="${BACKUP_DIR}/${db}-${TIMESTAMP}.sql"

    ${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" -e "use ${db}" &>/dev/null

    if [ X"$?" == X'0' ]; then
        # Dump
        ${CMD_MYSQLDUMP} \
            -u"${MYSQL_USER}" \
            -p"${MYSQL_PASSWD}" \
            --default-character-set=${DB_CHARACTER_SET} \
            ${db} > ${output_sql}

        # Compress
        if [ X"${COMPRESS}" == X"YES" ]; then
            ${CMD_COMPRESS} ${output_sql} >>${LOGFILE}

            if [ X"$?" == X'0' -a X"${DELETE_PLAIN_SQL_FILE}" == X'YES' ]; then
                rm -f ${output_sql} >> ${LOGFILE}
            fi
        fi
    fi

}

# Backup.
echo "* Backing up databases ..." >> ${LOGFILE}
for db in ${DATABASES}; do
    backup_db ${db} >>${LOGFILE}

    if [ X"$?" == X"0" ]; then
        echo "  - ${db} [DONE]" >> ${LOGFILE}
    else
        [ X"${BACKUP_SUCCESS}" == X"YES" ] && export BACKUP_SUCCESS='NO'
    fi
done

# Append file size of backup files.
echo -e "* File size:\n----" >>${LOGFILE}
${CMD_DU} ${BACKUP_DIR}/*${TIMESTAMP}*sql* >>${LOGFILE}
echo "----" >>${LOGFILE}

echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >>${LOGFILE}

if [ X"${BACKUP_SUCCESS}" == X"YES" ]; then
    echo "==> Backup completed successfully."
else
    echo -e "==> Backup completed with !!!ERRORS!!!.\n" 1>&2
fi

echo "==> Detailed log (${LOGFILE}):"
echo "========================="
cat ${LOGFILE}
