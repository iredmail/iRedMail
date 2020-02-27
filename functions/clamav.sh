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

# --------------------------------------------
# ClamAV.
# --------------------------------------------

clamav_config()
{
    ECHO_INFO "Configure ClamAV (anti-virus toolkit)."
    backup_file ${CLAMD_CONF} ${FRESHCLAM_CONF}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        perl -pi -e 's/^(Example)/#${1}/' ${CLAMD_CONF} ${FRESHCLAM_CONF}
        mkdir /var/log/clamav
        chown ${SYS_USER_CLAMAV}:${SYS_GROUP_CLAMAV} /var/log/clamav
    fi

    [ -f ${FRESHCLAM_CONF} ] && perl -pi -e 's#^Example##' ${FRESHCLAM_CONF}

    export CLAMD_LOCAL_SOCKET CLAMD_BIND_HOST
    ECHO_DEBUG "Configure ClamAV: ${CLAMD_CONF}."
    perl -pi -e 's/^(TCPSocket .*)/#${1}/' ${CLAMD_CONF}
    perl -pi -e 's#^(TCPAddr ).*#${1} $ENV{CLAMD_BIND_HOST}#' ${CLAMD_CONF}

    # Disable log file
    perl -pi -e 's/^(LogFile .*)/#${1}/' ${CLAMD_CONF}

    # Set CLAMD_LOCAL_SOCKET
    perl -pi -e 's/^(LocalSocket ).*/${1}$ENV{CLAMD_LOCAL_SOCKET}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(LocalSocket ).*/${1}$ENV{CLAMD_LOCAL_SOCKET}/' ${CLAMD_CONF}

    ECHO_DEBUG "Configure freshclam: ${FRESHCLAM_CONF}."
    perl -pi -e 's#^(UpdateLogFile ).*#${1}$ENV{FRESHCLAM_LOGFILE}#' ${FRESHCLAM_CONF}

    # Official database only
    perl -pi -e 's/^#(OfficialDatabaseOnly ).*/${1} yes/' ${CLAMD_CONF}

    # Enable AllowSupplementaryGroups
    perl -pi -e 's/^(AllowSupplementaryGroups.*)/#${1}/' ${CLAMD_CONF}
    if [ X"${DISTRO_CODENAME}" != X'stretch' \
        -a X"${DISTRO_CODENAME}" != X'bionic' \
        -a X"${DISTRO_CODENAME}" != X'disco' \
        -a X"${DISTRO}" != X'FREEBSD' ]; then
        echo 'AllowSupplementaryGroups true' >> ${CLAMD_CONF}
    fi

    if [ X"${DISTRO}" == X'RHEL' ]; then
        ECHO_DEBUG "Add clamav and freshclam daemon users to amavid group."
        usermod ${SYS_USER_CLAMAV} -G ${SYS_GROUP_AMAVISD}
        usermod clamupdate -G ${SYS_GROUP_AMAVISD} 2>/dev/null

        ECHO_DEBUG "Set correct permission for database directory."
        chmod 0775 /var/lib/clamav 2>/dev/null

        ECHO_DEBUG "Set permission to 750: ${AMAVISD_TEMP_DIR}, ${AMAVISD_QUARANTINE_DIR},"
        chmod -R 750 ${AMAVISD_TEMP_DIR} ${AMAVISD_QUARANTINE_DIR}

        if [ X"${DISTRO_VERSION}" == X'7' ]; then
            # Enable freshclam
            perl -pi -e 's/^(FRESHCLAM_DELAY.*)/#${1}/g' ${ETC_SYSCONFIG_DIR}/freshclam

            # Increase clamd timeout.
            mkdir -p /etc/systemd/system/${CLAMAV_CLAMD_SERVICE_NAME}.service.d >> ${INSTALL_LOG} 2>&1
            cp -f ${SAMPLE_DIR}/systemd/clamd.service.d/override.conf /etc/systemd/system/${CLAMAV_CLAMD_SERVICE_NAME}.service.d/ >> ${INSTALL_LOG} 2>&1
            systemctl daemon-reload
        fi
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        ECHO_DEBUG "Add clamav user to amavid group."
        pw usermod ${SYS_USER_CLAMAV} -G ${SYS_GROUP_AMAVISD}

        # Start service when system start up.
        service_control enable 'clamav_clamd_enable' 'YES'
        service_control enable 'clamav_freshclam_enable' 'YES'
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        usermod -G ${SYS_GROUP_AMAVISD} ${SYS_USER_CLAMAV}

        perl -pi -e 's#^(AllowSupplementaryGroups.*)##g' ${CLAMD_CONF}
        # Remove all `StatsXXX` parameters
        perl -pi -e 's#^(Stats.*)##g' ${CLAMD_CONF}
    fi

    # Add user alias in Postfix
    add_postfix_alias ${SYS_USER_CLAMAV} ${SYS_USER_ROOT}

    cat >> ${TIP_FILE} <<EOF
ClamAV:
    * Configuration files:
        - ${CLAMD_CONF}
        - ${FRESHCLAM_CONF}
        - /etc/logrotate.d/clamav
    * RC scripts:
            + ${DIR_RC_SCRIPTS}/${CLAMAV_CLAMD_SERVICE_NAME}
            + ${DIR_RC_SCRIPTS}/${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME}

EOF

    echo 'export status_clamav_config="DONE"' >> ${STATUS_FILE}
}
