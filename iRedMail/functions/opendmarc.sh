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

opendmarc_config()
{
    ECHO_INFO "Configure OpenDMARC."

    backup_file ${OPENDMARC_CONF}
    mkdir -p ${OPENDMARC_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Copy opendmarc config file: ${OPENDMARC_CONF}."
    cp -f ${SAMPLE_DIR}/opendmarc/opendmarc.conf ${OPENDMARC_CONF} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Update ${OPENDMARC_CONF}."
    perl -pi -e 's#PH_SYS_USER_OPENDMARC#$ENV{SYS_USER_OPENDMARC}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_SYS_GROUP_OPENDMARC#$ENV{SYS_GROUP_OPENDMARC}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_OPENDMARC_PID_FILE#$ENV{OPENDMARC_PID_FILE}#g' ${OPENDMARC_CONF}

    perl -pi -e 's#PH_OPENDMARC_PORT#$ENV{OPENDMARC_PORT}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_OPENDMARC_BIND_HOST#$ENV{OPENDMARC_BIND_HOST}#g' ${OPENDMARC_CONF}

    perl -pi -e 's#PH_OPENDMARC_CONF_IGNORE_HOSTS#$ENV{OPENDMARC_CONF_IGNORE_HOSTS}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_OPENDMARC_CONF_HISTORY_FILE#$ENV{OPENDMARC_CONF_HISTORY_FILE}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_OPENDMARC_CONF_PUBLIC_SUFFIX_LIST#$ENV{OPENDMARC_CONF_PUBLIC_SUFFIX_LIST}#g' ${OPENDMARC_CONF}
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#g' ${OPENDMARC_CONF}

    ECHO_DEBUG "Copy public_suffix_list.dat."
    cd ${OPENDMARC_CONF_DIR}
    rm -f public_suffix_list.dat &>/dev/null
    cp -f ${SAMPLE_DIR}/opendmarc/public_suffix_list.dat.bz2 .
    bunzip2 public_suffix_list.dat.bz2

    ECHO_DEBUG "Generate ${OPENDMARC_CONF_IGNORE_HOSTS}."
    touch ${OPENDMARC_CONF_IGNORE_HOSTS}

    ECHO_DEBUG "Add default ignore host: 127.0.0.1."
    if ! grep '^127.0.0.1\>' ${OPENDMARC_CONF_IGNORE_HOSTS} &>/dev/null; then
        echo '127.0.0.1' > ${OPENDMARC_CONF_IGNORE_HOSTS}
    fi

    ECHO_DEBUG "Create ${OPENDMARC_SPOOL_DIR}."
    mkdir -p ${OPENDMARC_SPOOL_DIR} &>/dev/null
    chown ${SYS_USER_OPENDMARC}:${SYS_GROUP_OPENDMARC} ${OPENDMARC_SPOOL_DIR}

    # Add postfix alias for OpenDMARC daemon user.
    add_postfix_alias ${SYS_USER_OPENDMARC} ${SYS_USER_ROOT}

    ECHO_DEBUG "Enable OpenDMARC integration."

    cat ${SAMPLE_DIR}/postfix/main.cf.opendmarc >> ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_OPENDMARC_PORT#$ENV{OPENDMARC_PORT}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_OPENDMARC_BIND_HOST#$ENV{OPENDMARC_BIND_HOST}#g' ${POSTFIX_FILE_MAIN_CF}

    echo 'export status_opendmarc_config="DONE"' >> ${STATUS_FILE}
}
