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
#       + bzip2 or gzip     # If bzip2 is not available, change 'CMD_COMPRESS'
#                           # to use 'gzip'.
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

#########################################################
# Modify below variables to fit your need ----
#########################################################

# Where to store backup copies.
export BACKUP_ROOTDIR='/var/vmail/backup'

# Compress plain SQL file: YES, NO.
export COMPRESS="YES"

# Delete plain LDIF files after compressed. Compressed copy will be remained.
export DELETE_PLAIN_LDIF_FILE="YES"

#########################################################
# You do *NOT* need to modify below lines.
#########################################################

export PATH="$PATH:/usr/sbin:/usr/local/sbin/"

# Commands.
export CMD_DATE='/bin/date'
export CMD_DU='du -sh'
export CMD_COMPRESS='bzip2 -9'

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

# Log file
export LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

# Check and create directories.
if [ ! -d ${BACKUP_DIR} ]; then
    echo "* Create data directory: ${BACKUP_DIR}."
    mkdir -p ${BACKUP_DIR}
fi

############
# Initialize log file.
#
echo "* Starting backup at ${TIMESTAMP}" >${LOGFILE}
echo "* Backup directory: ${BACKUP_DIR}." >>${LOGFILE}

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

echo "==> Detailed log (${LOGFILE}):"
echo "========================="
cat ${LOGFILE}
