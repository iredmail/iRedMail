#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)
# Date:     April 30, 2016
# Purpose:  Dump whole LDAP tree from OpenBSD ldapd(8) server with 'ldapsearch'.
# License:  This shell script is part of iRedMail project, released under
#           GPL v2.

###########################
# REQUIREMENTS
###########################
#
#   * Required commands:
#       + ldapsearch
#       + du
#       + bzip2 # If bzip2 is not available, change 'CMD_COMPRESS' to use 'gzip'.
#       + python
#

###########################
# USAGE
###########################
#
#   * Update settings to match your need:
#
#       - LDAP_BASE_DN: base dn
#       - LDAP_BIND_DN: bind dn used to query ldap tree.
#       - LDAP_BIND_PASSWORD: password of bind dn
#       - BACKUP_ROOTDIR: store all backup copies
#
#   * Add crontab job for root user (or whatever user you want):
#
#       # crontab -e -u root
#       1   4   *   *   *   bash /path/to/backup_ldapd.sh
#
#   * Make sure 'crond' service is running, and will start automatically when
#     system startup:
#
#       # rcctl enable cron
#

###############################
# How to restore backup file:
###############################
# Please refer to wiki tutorial for detail steps:
#   - http://www.iredmail.org/docs/backup.restore.html
#
# Note: you have to restore backup LDIF file with command 'ldapadd'.
#

#########################################################
# Modify below variables to fit your need ----
#########################################################
# LDAP base dn, bind dn and password.
export LDAP_BASE_DN='dc=example,dc=com'
export LDAP_BIND_DN='cn=Manager,dc=example,dc=com'
export LDAP_BIND_PASSWORD='password'

# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

# Keep backup for how many days. Default is 90 days.
export KEEP_DAYS='90'

#########################################################
# You do *NOT* need to modify below lines.
#########################################################

export PATH="$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin/"

# Commands.
export CMD_DATE='/bin/date'
export CMD_LDAPSEARCH='/usr/local/bin/ldapsearch'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'
export COMPRESS_SUFFIX='bz2'
export CMD_MYSQL='mysql'

# MySQL user and password, used to log backup status to sql table `iredadmin.log`.
# You can find password of SQL user 'iredadmin' in iRedAdmin config file 'settings.py'.
export MYSQL_USER='iredadmin'
export MYSQL_PASSWD=''

# Date.
export YEAR="$(${CMD_DATE} +%Y)"
export MONTH="$(${CMD_DATE} +%m)"
export DAY="$(${CMD_DATE} +%d)"
export TIME="$(${CMD_DATE} +%H-%M-%S)"
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
[ -d ${BACKUP_DIR} ] || mkdir -p ${BACKUP_DIR} &>/dev/null
chown root ${BACKUP_DIR}
chmod 0700 ${BACKUP_DIR}

# Initialize log file.
echo "* Starting backup at ${TIMESTAMP}" >> ${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >> ${LOGFILE}

# Backup
echo "* Dumping LDAP data into file: ${BACKUP_FILE}..." >> ${LOGFILE}
${CMD_LDAPSEARCH} -x \
    -b "${LDAP_BASE_DN}" \
    -D "${LDAP_BIND_DN}" \
    -w"${LDAP_BIND_PASSWORD}" > ${BACKUP_FILE}

if [ X"$?" == X"0" ]; then
    export BACKUP_SUCCESS='YES'

    # Get original backup file size
    original_size="$(${CMD_DU} ${BACKUP_FILE} | awk '{print $1}')"

    # Compress backup file.
    echo "* Compressing LDIF file with command: '${CMD_COMPRESS}' ..." >> ${LOGFILE}
    ${CMD_COMPRESS} ${BACKUP_FILE} >> ${LOGFILE} 2>&1

    echo "* [DONE]" >>${LOGFILE}

    # Get compressed file size
    compressed_file_name="${BACKUP_FILE}.${COMPRESS_SUFFIX}"
    compressed_size="$(${CMD_DU} ${compressed_file_name} | awk '{print $1}')"

    echo -n "* Removing plain LDIF file: ${BACKUP_FILE}..." >>${LOGFILE}
    rm -f ${BACKUP_FILE} >> ${LOGFILE} 2>&1
    [ X"$?" == X"0" ] && echo -e "\t[DONE]" >>${LOGFILE}

    sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Backup LDAP data, size: ${original_size}, compressed: ${compressed_size}', 'cron_backup_ldap', '127.0.0.1', UTC_TIMESTAMP());"
else
    # Log failure
    sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Backup LDAP data failed, check log file ${LOGFILE} for more details.', 'cron_backup_ldap', '127.0.0.1', UTC_TIMESTAMP());"
fi

# Log to SQL table `iredadmin.log`, so that global domain admins can
# check backup status (System -> Admin Log)
if [ -n ${MYSQL_USER} ] && [ -n ${MYSQL_PASSWD} ]; then
    ${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" iredadmin -e "${sql_log_msg}" >>${LOGFILE} 2>&1
fi

# Append file size of backup files to log file.
echo "* File size:" >>${LOGFILE}
echo "=================" >>${LOGFILE}
${CMD_DU} ${BACKUP_FILE}* >>${LOGFILE}
echo "=================" >>${LOGFILE}

# Print some message. It will cause cron generates an email to root user.
if [ X"${BACKUP_SUCCESS}" == X'YES' ]; then
    echo "* [ OK ] Backup completes successfully." >> ${LOGFILE}
else
    echo "* <<< ERROR >>> Backup not successfully complete." >> ${LOGFILE}
fi

if [ X"${REMOVE_OLD_BACKUP}" == X'YES' ] && [ -d ${REMOVED_BACKUP_DIR} ]; then
    echo -e "* Delete old backup under ${REMOVED_BACKUP_DIR}." >> ${LOGFILE}
    echo -e "* Suppose to delete: ${REMOVED_BACKUPS}" >> ${LOGFILE}
    rm -rf ${REMOVED_BACKUPS} >> ${LOGFILE} 2>&1

    if [ -n ${MYSQL_USER} ] && [ -n ${MYSQL_PASSWD} ]; then
        sql_log_msg="INSERT INTO log (event, loglevel, msg, admin, ip, timestamp) VALUES ('backup', 'info', 'Remove old backup: ${REMOVED_BACKUPS}.', 'cron_backup_sql', '127.0.0.1', UTC_TIMESTAMP());"
        ${CMD_MYSQL} -u"${MYSQL_USER}" -p"${MYSQL_PASSWD}" iredadmin -e "${sql_log_msg}"
    fi
fi

cat ${LOGFILE}
