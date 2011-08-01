#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)
# Date:     05/02/2010
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
#       COMPRESS
#       DELETE_PLAIN_SQL_FILE
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

###########################
# DIRECTORY STRUCTURE
###########################
#
#   $BACKUP_ROOTDIR             # Default is /backup
#       |- ldap/                # Used to store all backed up copies.
#           |- YEAR.MONTH/
#               |- DAY/
#                   |- YEAR.MONTH.DAY.MIN.HOUR.SECOND.ldif
#                               # Backup copy, plain LDIF file.
#                               # Note: it will be removed immediately after
#                               # it was compressed with success and 
#                               # DELETE_PLAIN_SQL_FILE='YES'
#
#                   |- YEAR.MONTH.DAY.HOUR.MINUTE.SECOND.ldif.bz2
#                               # Backup copy, compressed LDIF file.
#
#       |- logs/
#           |- YEAR.MONTH/
#               |- ldap-YEAR.MONTH.DAY.MIN.HOUR.SECOND.log     # Log file
#

#########################################################
# Modify below variables to fit your need ----
#########################################################

# Where to store backup copies.
BACKUP_ROOTDIR='/backup'

# Compress plain SQL file: YES, NO.
COMPRESS="YES"

# Delete plain LDIF files after compressed. Compressed copy will be remained.
DELETE_PLAIN_LDIF_FILE="YES"

#########################################################
# You do *NOT* need to modify below lines.
#########################################################

export PATH="$PATH:/usr/sbin:/usr/local/sbin/"

# Commands.
CMD_DATE='/bin/date'
CMD_DU='du -sh'
CMD_COMPRESS='bzip2 -9'

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
export MONTH="$(${CMD_DATE} +%Y.%m)"
export DAY="$(${CMD_DATE} +%d)"
export DATE="$(${CMD_DATE} +%Y.%m.%d.%H.%M.%S)"

export BACKUP_SUCCESS='NO'

#########
# Define, check, create directories.
#
# Backup directory.
export BACKUP_DIR="${BACKUP_ROOTDIR}/ldap/${MONTH}/${DAY}"
export BACKUP_FILE="${BACKUP_DIR}/${DATE}.ldif"

# Logfile directory. Default is /backup/logs/YYYY.MM/.
export LOG_DIR="${BACKUP_ROOTDIR}/logs/${MONTH}"

# Check and create directories.
if [ ! -d ${BACKUP_DIR} ]; then
    echo "* Create data directory: ${BACKUP_DIR}."
    mkdir -p ${BACKUP_DIR}
fi

if [ ! -d ${LOG_DIR} ]; then
    echo "* Create log directory: ${LOG_DIR}."
    mkdir -p ${LOG_DIR} 2>/dev/null
fi

# Log file. Default is /backup/logs/YYYY.MM/mysql-YYYY.MM.DD.log.
LOGFILE="${LOG_DIR}/ldap-${DATE}.log"

############
# Initialize log file.
#
echo "* Starting backup: ${DATE}." >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}
echo "* Log file: ${LOGFILE}." >>${LOGFILE}

##############
# Backing up
#

echo "* Dumping LDAP data into file: ${BACKUP_FILE}..." >>${LOGFILE}
${CMD_SLAPCAT} > ${BACKUP_FILE}
if [ X"$?" == X"0" ]; then
    export BACKUP_SUCCESS='YES'
fi

# Compress plain SQL file.
if [ X"${COMPRESS}" == X"YES" ]; then
    echo "* Compressing LDIF file with command: '${CMD_COMPRESS}' ..." >> ${LOGFILE}
    ${CMD_COMPRESS} ${BACKUP_FILE} >>${LOGFILE} 2>&1

    if [ X"$?" == X"0" ]; then
        echo "* [DONE]" >>${LOGFILE}

        # Delete plain LDIF file after compressed.
        if [ X"${DELETE_PLAIN_LDIF_FILE}" == X"YES" -a -f ${BACKUP_FILE} ]; then
            echo -n "* Removing plain LDIF file: ${BACKUP_FILE}..." >>${LOGFILE}
            rm -f ${BACKUP_DIR}/*.ldif >>${LOGFILE} 2>&1
            [ X"$?" == X"0" ] && echo -e "\t[DONE]" >>${LOGFILE}

        fi
    fi
fi


# Append file size of backup files.
echo "* File size:" >>${LOGFILE}
echo "=================" >>${LOGFILE}
${CMD_DU} ${BACKUP_FILE}* >>${LOGFILE}
echo "=================" >>${LOGFILE}

echo "* Backup completed (Successfully: ${BACKUP_SUCCESS})." >>${LOGFILE}

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

