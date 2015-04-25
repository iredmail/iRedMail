#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)
# Date:     Mar 15, 2012
# Purpose:  Dump whole LDAP tree with command 'slapcat'.
# License:  This shell script is part of iRedMail project, released under
#           GPL v2.

###########################
# REQUIREMENTS
###########################
#
#   * Required commands:
#       + slapcat
#       + du
#       + bzip2 # If bzip2 is not available, change 'CMD_COMPRESS' to use 'gzip'.
#

###########################
# USAGE
###########################
#
#   * It stores all backup copies in directory '/var/vmail/backup' by default,
#     You can change it with variable $BACKUP_ROOTDIR below.
#
#   * Set correct values for below variables:
#
#       BACKUP_ROOTDIR
#
#   * Add crontab job for root user (or whatever user you want):
#
#       # crontab -e -u root
#       1   4   *   *   *   bash /path/to/backup_openldap.sh
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

###############################
# How to restore backup file:
###############################
# Please refer to wiki tutorial for detail steps:
# http://www.iredmail.org/wiki/index.php?title=IRedMail/FAQ/Backup#How_to_restore_from_LDIF_file
#

#########################################################
# Modify below variables to fit your need ----
#########################################################
# Keep backup for how many days. Default is 90 days.
KEEP_DAYS='90'

# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

#########################################################
# You do *NOT* need to modify below lines.
#########################################################

export PATH="$PATH:/usr/sbin:/usr/local/sbin/"

# Commands.
export CMD_DATE='/bin/date'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'
export CMD_MYSQL='mysql'

# MySQL user and password, used to log backup status to sql table `iredadmin.log`.
# You can find password of SQL user 'iredadmin' in iRedAdmin config file 'settings.py'.
export MYSQL_USER='iredadmin'
export MYSQL_PASSWD='passwd'

if [ -f /etc/ldap/slapd.conf ]; then
    export CMD_SLAPCAT='slapcat -f /etc/ldap/slapd.conf'
elif [ -f /etc/openldap/slapd.conf ]; then
    export CMD_SLAPCAT='slapcat -f /etc/openldap/slapd.conf'
elif [ -f /usr/local/etc/openldap/slapd.conf ]; then
    export CMD_SLAPCAT='slapcat -f /usr/local/etc/openldap/slapd.conf'
else
    export CMD_SLAPCAT='slapcat'
fi

# Date.
export YEAR="$(${CMD_DATE} +%Y)"
export MONTH="$(${CMD_DATE} +%m)"
export DAY="$(${CMD_DATE} +%d)"
export TIME="$(${CMD_DATE} +%H:%M:%S)"
export TIMESTAMP="${YEAR}-${MONTH}-${DAY}-${TIME}"

# Pre-defined backup status
export BACKUP_SUCCESS='NO'

#########
# Define, check, create directories.
#
# Backup directory.
export BACKUP_DIR="${BACKUP_ROOTDIR}/ldap/${YEAR}/${MONTH}"
export BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}.ldif"

# Find the old backup which should be removed.
export REMOVE_OLD_BACKUP='NO'
if which python &>/dev/null; then
    export REMOVE_OLD_BACKUP='YES'
    py_cmd="import time; import datetime; t=time.localtime(); print datetime.date(t.tm_year, t.tm_mon, t.tm_mday) - datetime.timedelta(days=${KEEP_DAYS})"
    shift_date=$(python -c "${py_cmd}")
    shift_year="$(echo ${shift_date} | awk -F'-' '{print $1}')"
    shift_month="$(echo ${shift_date} | awk -F'-' '{print $2}')"
    shift_day="$(echo ${shift_date} | awk -F'-' '{print $3}')"
    export REMOVED_BACKUP_DIR="${BACKUP_ROOTDIR}/ldap/${shift_year}/${shift_month}"
    export REMOVED_BACKUPS="${BACKUP_ROOTDIR}/ldap/${shift_year}/${shift_month}/${shift_date}*"
fi

# Log file
export LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

# Check and create directories.
if [ ! -d ${BACKUP_DIR} ]; then
    echo "* Create data directory: ${BACKUP_DIR}."
    mkdir -p ${BACKUP_DIR}
fi

# Initialize log file.
echo "* Starting backup at ${TIMESTAMP}" >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}

# Backup
echo "* Dumping LDAP data into file: ${BACKUP_FILE}..." >>${LOGFILE}
${CMD_SLAPCAT} > ${BACKUP_FILE}

if [ X"$?" == X"0" ]; then
    export BACKUP_SUCCESS='YES'

    # Get original backup file size
    original_size="$(${CMD_DU} ${BACKUP_FILE} | awk '{print $1}')"

    # Compress backup file.
    echo "* Compressing LDIF file with command: '${CMD_COMPRESS}' ..." >> ${LOGFILE}
    ${CMD_COMPRESS} ${BACKUP_FILE} &>${LOGFILE}

    echo "* [DONE]" >>${LOGFILE}

    # Get compressed file size
    if echo ${CMD_COMPRESS} | grep '^bzip2' >/dev/null; then
        compressed_file_name="${BACKUP_FILE}.bz2"
    else
        compressed_file_name="${BACKUP_FILE}.gz"
    fi
    compressed_size="$(${CMD_DU} ${compressed_file_name} | awk '{print $1}')"

    echo -n "* Removing plain LDIF file: ${BACKUP_FILE}..." >>${LOGFILE}
    rm -f ${BACKUP_FILE} &>${LOGFILE}
    [ X"$?" == X"0" ] && echo -e "\t[DONE]" >>${LOGFILE}

    sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Backup LDAP data. Original file size: ${original_size}, compressed: ${compressed_size}, backup file: ${compressed_file_name}', 'cron_backup_ldap', '127.0.0.1', NOW());"
else
    # Log failure
    sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Backup LDAP data failed, check log file ${LOGFILE} for more details.', 'cron_backup_ldap', '127.0.0.1', NOW());"
fi

# Log to SQL table `iredadmin.log`, so that global domain admins can
# check backup status (System -> Admin Log)
${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" iredadmin -e "${sql_log_msg}" >>${LOGFILE} 2>&1

# Append file size of backup files to log file.
echo "* File size:" >>${LOGFILE}
echo "=================" >>${LOGFILE}
${CMD_DU} ${BACKUP_FILE}* >>${LOGFILE}
echo "=================" >>${LOGFILE}

echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >>${LOGFILE}

# Print some message. It will cause cron generates an email to root user.
if [ X"${BACKUP_SUCCESS}" == X"YES" ]; then
    echo "==> Backup completed successfully."
else
    echo -e "==> Backup completed with !!!ERRORS!!!.\n" 1>&2
fi

if [ X"${REMOVE_OLD_BACKUP}" == X'YES' -a -d ${REMOVED_BACKUP_DIR} ]; then
    echo -e "* Delete old backup under ${REMOVED_BACKUP_DIR}." >> ${LOGFILE}
    rm -rf ${REMOVED_BACKUPS} >/dev/null 2>${LOGFILE}

    sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Remove old backup: ${REMOVED_BACKUPS}.', 'cron_backup_sql', '127.0.0.1', NOW());"
    ${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" iredadmin -e "${sql_log_msg}"
fi

echo "==> Detailed log (${LOGFILE}):"
echo "========================="
cat ${LOGFILE}
