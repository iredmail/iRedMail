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
    cp -f ${SAMPLE_DIR}/fail2ban/jail.local ${FAIL2BAN_JAIL_LOCAL_CONF} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Create Fail2ban directory: ${FAIL2BAN_JAIL_CONF_DIR}."
    mkdir -p ${FAIL2BAN_JAIL_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#' ${FAIL2BAN_JAIL_LOCAL_CONF}

    ECHO_DEBUG "Copy modular Fail2ban jail config files to ${FAIL2BAN_JAIL_CONF_DIR}."
    cp -f ${SAMPLE_DIR}/fail2ban/jail.d/*.local ${FAIL2BAN_JAIL_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    # Firewall command
    perl -pi -e 's#PH_FAIL2BAN_ACTION#$ENV{FAIL2BAN_ACTION}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    perl -pi -e 's#PH_SSHD_LOGFILE#$ENV{SSHD_LOGFILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_HTTPD_LOG_ERRORLOG#$ENV{HTTPD_LOG_ERRORLOG}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_RCM_LOGFILE#$ENV{RCM_LOGFILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_MAILLOG#$ENV{MAILLOG}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_SOGO_LOG_FILE#$ENV{SOGO_LOG_FILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_DIR}/*.log#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_FAIL2BAN_DISABLED_SERVICES#$ENV{FAIL2BAN_DISABLED_SERVICES}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    perl -pi -e 's#PH_SSHD_PORT#$ENV{SSHD_PORTS_WITH_COMMA}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    ECHO_DEBUG "Copy sample Fail2ban filter config files."
    cp -f ${SAMPLE_DIR}/fail2ban/filter.d/*.conf ${FAIL2BAN_FILTER_DIR}

    # Enable Nginx
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        perl -pi -e 's#(enabled.*=.*)false#${1}true#' ${FAIL2BAN_JAIL_CONF_DIR}/nginx-http-auth.local
    fi

    if [ X"${USE_ROUNDCUBE}" == X'YES' ]; then
        perl -pi -e 's#(enabled.*=.*)false#${1}true#' ${FAIL2BAN_JAIL_CONF_DIR}/roundcube.local
    fi

    if [ X"${USE_SOGO}" == X'YES' ]; then
        perl -pi -e 's#(enabled.*=.*)false#${1}true#' ${FAIL2BAN_JAIL_CONF_DIR}/sogo.local
    fi

    echo 'export status_fail2ban_config="DONE"' >> ${STATUS_FILE}
}
