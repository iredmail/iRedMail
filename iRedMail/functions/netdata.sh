#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

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
netdata_install()
{
    ECHO_DEBUG "Install netdata with package: ${NETDATA_PKG_NAME}."

    cd ${PKG_MISC_DIR}
    chmod +x ${NETDATA_PKG_NAME}

    # Note: netdata installer will generate rc/systemd script automatically.
    ./${NETDATA_PKG_NAME} --accept >> ${RUNTIME_DIR}/netdata-install.log

    service_control enable ${NETDATA_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Create directory used to store netdata log files."
    mkdir -p ${NETDATA_LOG_DIR} >> ${INSTALL_LOG} 2>&1
    chown ${SYS_USER_NETDATA}:${SYS_GROUP_NETDATA} ${NETDATA_LOG_DIR} >> ${INSTALL_LOG} 2>&1

    echo 'export status_netdata_install="DONE"' >> ${STATUS_FILE}
}

netdata_config()
{
    backup_file ${NETDATA_CONF}

    ECHO_DEBUG "Generate netdata config file: ${SAMPLE_DIR}/netdata/netdata.conf -> ${NETDATA_CONF}."
    cp -f ${SAMPLE_DIR}/netdata/netdata.conf ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    chown ${SYS_USER_NETDATA}:${SYS_GROUP_NETDATA} ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1

    perl -pi -e 's#PH_NETDATA_PORT#$ENV{NETDATA_PORT}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_SYS_USER_NETDATA#$ENV{SYS_USER_NETDATA}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_NETDATA_LOG_DIR#$ENV{NETDATA_LOG_DIR}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_NETDATA_LOG_ACCESSLOG#$ENV{NETDATA_LOG_ACCESSLOG}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_NETDATA_LOG_ERRORLOG#$ENV{NETDATA_LOG_ERRORLOG}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_NETDATA_LOG_DEBUGLOG#$ENV{NETDATA_LOG_DEBUGLOG}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1

    echo 'export status_netdata_config="DONE"' >> ${STATUS_FILE}
}

netdata_system_tune()
{
    ECHO_DEBUG "Add sysctl parameters for better netdata performance."
    update_sysctl_param vm.dirty_expire_centisecs 60000
    update_sysctl_param vm.dirty_background_ratio 80
    update_sysctl_param vm.dirty_ratio 90

    echo 'export status_netdata_system_tune="DONE"' >> ${STATUS_FILE}
}

netdata_setup()
{
    if [ X"${DISTRO}" != X'OPENBSD' ]; then
        check_status_before_run netdata_install
        check_status_before_run netdata_config
        check_status_before_run netdata_system_tune
    fi
}
