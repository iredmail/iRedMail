#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)

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

# -------------------------------------------------------
# ------------------- uwsgi -----------------------------
# -------------------------------------------------------

uwsgi_config()
{
    ECHO_DEBUG "Configure uwsgi."

    # Create uwsgi config directory
    [ -d ${UWSGI_CONF_DIR} ] || mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    backup_file ${UWSGI_CONF}

    if [ X"${DISTRO}" == X'RHEL' ]; then
        cp -f ${SAMPLE_DIR}/uwsgi/uwsgi.ini ${UWSGI_CONF}

        perl -pi -e 's#^(daemonize .*=).*#${1} $ENV{UWSGI_LOG_FILE}#' ${UWSGI_CONF}
        perl -pi -e 's/^(daemonize.*)/#${1}/' ${UWSGI_CONF}
        perl -pi -e 's#^(pidfile.*=).*#${1} $ENV{UWSGI_PID}#' ${UWSGI_CONF}
        perl -pi -e 's#^(emperor *=).*#${1} $ENV{UWSGI_CONF_DIR}#' ${UWSGI_CONF}
        perl -pi -e 's#^(emperor-tyrant.*=).*#${1} false#' ${UWSGI_CONF}
        perl -pi -e 's#^(stats.*=).*#${1} $ENV{UWSGI_SOCKET}#' ${UWSGI_CONF}

        ECHO_DEBUG "Setting logrotate for uwsgi log file: ${UWSGI_LOG_FILE}."
        mkdir -p ${UWSGI_LOG_DIR} >> ${INSTALL_LOG} 2>&1
        cp -f ${SAMPLE_DIR}/logrotate/uwsgi ${UWSGI_LOGROTATE_FILE}

        perl -pi -e 's#PH_UWSGI_LOG_FILE#$ENV{UWSGI_LOG_FILE}#g' ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_ROOT_USER#$ENV{SYS_ROOT_USER}#g' ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYS_ROOT_GROUP#$ENV{SYS_ROOT_GROUP}#g' ${UWSGI_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYSLOG_POSTROTATE_CMD#$ENV{SYSLOG_POSTROTATE_CMD}#g' ${UWSGI_LOGROTATE_FILE}

    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1

        _uwsgi_profiles="mlmmjadmin"
        if [ X"${USE_IREDADMIN}" == X'YES' ]; then
            _uwsgi_profiles="${_uwsgi_profiles} iredadmin"
        fi

        service_control enable 'uwsgi_enable' 'YES'
        service_control enable 'uwsgi_profiles' "${_uwsgi_profiles}"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        mkdir -p ${UWSGI_CONF_DIR} >> ${INSTALL_LOG} 2>&1

        update_sysctl_param kern.seminfo.semmni 1024
        update_sysctl_param kern.seminfo.semmns 1200
        update_sysctl_param kern.seminfo.semmnu 60
        update_sysctl_param kern.seminfo.semmsl 120
        update_sysctl_param kern.seminfo.semopm 200

        # Start uWSGI
        cp ${SAMPLE_DIR}/openbsd/rc.d/uwsgi ${DIR_RC_SCRIPTS}/${UWSGI_RC_SCRIPT_NAME}
        chmod +x ${DIR_RC_SCRIPTS}/${UWSGI_RC_SCRIPT_NAME}
        service_control enable ${UWSGI_RC_SCRIPT_NAME}
    fi

    cat >> ${TIP_FILE} <<EOF
uWSGI:
    * Configuration files: ${UWSGI_CONF_DIR}
    * Logrotate config file: ${UWSGI_LOGROTATE_FILE}

EOF
}
