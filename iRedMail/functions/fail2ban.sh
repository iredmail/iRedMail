#!/usr/bin/env bash

# Author: Zhang Huangbin (zhb _at_ iredmail.org)

#---------------------------------------------------------------------
# This file is part of iRedMail, which is an open source mail server
# solution for Red Hat(R) Enterprise Linux, CentOS, Debian and Ubuntu.
#
# iRedMail is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# iRedMail is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iRedMail.  If not, see <http://www.gnu.org/licenses/>.
#---------------------------------------------------------------------

fail2ban_config()
{
    ECHO_INFO "Configure Fail2ban (authentication failure monitor)."

    ECHO_DEBUG "Log into syslog instead of log file."
    perl -pi -e 's#^(logtarget).*#${1} = $ENV{FAIL2BAN_LOGTARGET}#' ${FAIL2BAN_MAIN_CONF}

    ECHO_DEBUG "Disable all default filters in ${FAIL2BAN_JAIL_CONF}."
    perl -pi -e 's#^(enabled).*=.*#${1} = false#' ${FAIL2BAN_JAIL_CONF}

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        ECHO_DEBUG "Set proper socket path: ${FAIL2BAN_SOCKET}"
        perl -pi -e 's#^(socket).*#${1} = $ENV{FAIL2BAN_SOCKET}#' ${FAIL2BAN_MAIN_CONF}
    fi

    ECHO_DEBUG "Create Fail2ban config file: ${FAIL2BAN_JAIL_LOCAL_CONF}."
    backup_file ${FAIL2BAN_JAIL_LOCAL_CONF}
    cp -f ${SAMPLE_DIR}/fail2ban/jail.local ${FAIL2BAN_JAIL_LOCAL_CONF}

    perl -pi -e 's#PH_FAIL2BAN_JAIL_CONF#$ENV{FAIL2BAN_JAIL_CONF}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#' ${FAIL2BAN_JAIL_LOCAL_CONF}

    perl -pi -e 's#PH_SSHD_LOGFILE#$ENV{SSHD_LOGFILE}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    perl -pi -e 's#PH_RCM_LOGFILE#$ENV{RCM_LOGFILE}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_FILE}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    perl -pi -e 's#PH_MAILLOG#$ENV{MAILLOG}#' ${FAIL2BAN_JAIL_LOCAL_CONF}

    perl -pi -e 's#PH_FAIL2BAN_DISABLED_SERVICES#$ENV{FAIL2BAN_DISABLED_SERVICES}#' ${FAIL2BAN_JAIL_LOCAL_CONF}

    ECHO_DEBUG "Copy sample Fail2ban filter config files."
    cp -f ${SAMPLE_DIR}/fail2ban/filter.d/*.conf ${FAIL2BAN_FILTER_DIR}

    #if [ X"${DISTRO}" == X'FREEBSD' ]; then
    #    # Start service when system start up.
    #    service_control enable 'fail2ban_enable' 'YES'
    #fi

    echo 'export status_fail2ban_config="DONE"' >> ${STATUS_FILE}
}
