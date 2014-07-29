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
# ------------------- OpenLDAP --------------------------
# -------------------------------------------------------

openldap_config()
{
    ECHO_INFO "Configure LDAP server: OpenLDAP."

    ECHO_DEBUG "Stoping OpenLDAP."
    ${OPENLDAP_RC_SCRIPT} stop &>/dev/null

    backup_file ${OPENLDAP_SLAPD_CONF} ${OPENLDAP_LDAP_CONF}

    ###########
    # Fix file permission issues, so that slapd can read SSL key.
    #
    # Add ${OPENLDAP_DAEMON_USER} to 'ssl-cert' group.
    [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ] && \
        usermod -G ssl-cert ${OPENLDAP_DAEMON_USER}

    if [ X"${DISTRO}" == X"RHEL" ]; then
        # Run slapd with slapd.conf, not slapd.d.
        perl -pi -e 's/#(SLAPD_OPTIONS=).*/${1}"-f $ENV{OPENLDAP_SLAPD_CONF}"/' ${OPENLDAP_SYSCONFIG_CONF}

        if [ X"${DISTRO_VERSION}" == X'6' ]; then
            # Run slapd with -h "... ldap:/// ..."
            perl -pi -e 's/#(SLAPD_LDAP=).*/${1}yes/' ${OPENLDAP_SYSCONFIG_CONF}

            # Run slapd with -h "... ldaps:/// ...".
            perl -pi -e 's/#(SLAPD_LDAPS=).*/${1}yes/' ${OPENLDAP_SYSCONFIG_CONF}
        fi

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable TLS/SSL support
        cat >> ${RC_CONF_LOCAL} <<EOF
slapd_flags='-u _openldap -h ldap:///\ ldaps:///'
EOF
    fi

    ###################
    # LDAP schema file
    #
    # Copy ${PROG_NAME}.schema.
    cp -f ${SAMPLE_DIR}/iredmail.schema ${OPENLDAP_SCHEMA_DIR}

    # Copy amavisd schema.
    # - On OpenBSD: package amavisd-new will copy schema file to /etc/openldap/schema
    if [ X"${DISTRO}" == X"RHEL" ]; then
        amavisd_schema_file="$( eval ${LIST_FILES_IN_PKG} amavisd-new | grep '/LDAP.schema$')"
        cp -f ${amavisd_schema_file} ${OPENLDAP_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
    elif [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
        cp -f /usr/local/share/doc/amavisd-new/LDAP.schema ${OPENLDAP_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
    fi

    ECHO_DEBUG "Generate new server configuration file: ${OPENLDAP_SLAPD_CONF}."
    cp -f ${SAMPLE_DIR}/openldap/slapd.conf ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_SCHEMA_DIR#$ENV{OPENLDAP_SCHEMA_DIR}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_AMAVISD_LDAP_SCHEMA_NAME#$ENV{AMAVISD_LDAP_SCHEMA_NAME}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_PID_FILE#$ENV{OPENLDAP_PID_FILE}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_OPENLDAP_ARGS_FILE#$ENV{OPENLDAP_ARGS_FILE}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_MODULE_PATH#$ENV{OPENLDAP_MODULE_PATH}#g' ${OPENLDAP_SLAPD_CONF}
    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        perl -pi -e 's/^#(modulepath.*)/${1}/g' ${OPENLDAP_SLAPD_CONF}
        perl -pi -e 's/^#(moduleload.*)/${1}/g' ${OPENLDAP_SLAPD_CONF}
    fi

    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_SSL_KEY_FILE#$ENV{SSL_KEY_FILE}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_DN#$ENV{LDAP_ADMIN_DN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_BASEDN#$ENV{LDAP_ADMIN_BASEDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_DEFAULT_DBTYPE#$ENV{OPENLDAP_DEFAULT_DBTYPE}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_DATA_DIR#$ENV{LDAP_DATA_DIR}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ROOTDN#$ENV{LDAP_ROOTDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ROOTPW_SSHA#$ENV{LDAP_ROOTPW_SSHA}#g' ${OPENLDAP_SLAPD_CONF}

    # Make slapd use slapd.conf insteald of slapd.d (cn=config backend).
    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        perl -pi -e 's#^(SLAPD_CONF=).*#${1}"$ENV{OPENLDAP_SLAPD_CONF}"#' ${OPENLDAP_SYSCONFIG_CONF}
        perl -pi -e 's#^(SLAPD_PIDFILE=).*#${1}"$ENV{OPENLDAP_PID_FILE}"#' ${OPENLDAP_SYSCONFIG_CONF}
    fi

    ECHO_DEBUG "Generate new client configuration file: ${OPENLDAP_LDAP_CONF}"
    cp ${SAMPLE_DIR}/openldap/ldap.conf ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#g' ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#g' ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${OPENLDAP_LDAP_CONF}
    chown ${OPENLDAP_DAEMON_USER}:${OPENLDAP_DAEMON_GROUP} ${OPENLDAP_LDAP_CONF}

    ECHO_DEBUG "Setting up syslog configration file for OpenLDAP."
    if [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
        echo -e '!slapd' >> ${SYSLOG_CONF}
        echo -e "*.*\t\t\t\t\t\t${OPENLDAP_LOGFILE}" >> ${SYSLOG_CONF}
    else
        echo -e "local4.*\t\t\t\t\t\t-${OPENLDAP_LOGFILE}" >> ${SYSLOG_CONF}
    fi

    ECHO_DEBUG "Create empty log file for OpenLDAP: ${OPENLDAP_LOGFILE}."
    touch ${OPENLDAP_LOGFILE}
    chown ${OPENLDAP_DAEMON_USER}:${OPENLDAP_DAEMON_GROUP} ${OPENLDAP_LOGFILE}
    chmod 0600 ${OPENLDAP_LOGFILE}

    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        ECHO_DEBUG "Setting logrotate for openldap log file: ${OPENLDAP_LOGFILE}."
        cat > ${OPENLDAP_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${OPENLDAP_LOGFILE} {
    compress
    weekly
    rotate 10
    create 0600 ${OPENLDAP_DAEMON_USER} ${OPENLDAP_DAEMON_GROUP}
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        ${SYSLOG_POSTROTATE_CMD}
    endscript
}
EOF
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' -o X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep "${OPENLDAP_LOGFILE}" /etc/newsyslog.conf &>/dev/null; then
            cat >> /etc/newsyslog.conf <<EOF
${OPENLDAP_LOGFILE}    ${OPENLDAP_DAEMON_USER}:${OPENLDAP_DAEMON_GROUP}   600  7     *    24    Z
EOF
        fi
    fi

    ECHO_DEBUG "Restarting syslog."
    if [ X"${DISTRO}" == X'RHEL' \
        -o X"${DISTRO}" == X'DEBIAN' \
        -o X"${DISTRO}" == X"UBUNTU" ]; then
        service_control restart rsyslog >/dev/null
    fi

    # FreeBSD: Start openldap when system start up.
    # Warning: Make sure we have 'slapd_enable=YES' before start/stop openldap.
    freebsd_enable_service_in_rc_conf 'slapd_enable' 'YES'
    freebsd_enable_service_in_rc_conf 'slapd_flags' '-h "ldapi://%2fvar%2frun%2fopenldap%2fldapi/ ldap://0.0.0.0/ ldaps://0.0.0.0/"'
    freebsd_enable_service_in_rc_conf 'slapd_sockets' '/var/run/openldap/ldapi'

    echo 'export status_openldap_config="DONE"' >> ${STATUS_FILE}
}

openldap_data_initialize()
{
    # Get DB_CONFIG.example.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        export OPENLDAP_DB_CONFIG_SAMPLE="$( eval ${LIST_FILES_IN_PKG} openldap-servers | grep '/DB_CONFIG.example$')"
    fi

    ECHO_DEBUG "Create instance directory for openldap tree: ${LDAP_DATA_DIR}."
    mkdir -p ${LDAP_DATA_DIR}
    cp -f ${OPENLDAP_DB_CONFIG_SAMPLE} ${LDAP_DATA_DIR}/DB_CONFIG
    chown -R ${OPENLDAP_DAEMON_USER}:${OPENLDAP_DAEMON_GROUP} ${OPENLDAP_DATA_DIR}
    chmod -R 0700 ${OPENLDAP_DATA_DIR}

    ECHO_DEBUG "Starting OpenLDAP."
    service_control restart ${OPENLDAP_RC_SCRIPT_NAME} &>/dev/null

    ECHO_DEBUG "Sleep 5 seconds for LDAP daemon initialization ..."
    sleep 5

    ECHO_DEBUG "Populate LDAP tree."
    ldapadd -x -D "${LDAP_ROOTDN}" -w "${LDAP_ROOTPW}" -f ${LDAP_INIT_LDIF} >/dev/null

    cat >> ${TIP_FILE} <<EOF
OpenLDAP:
    * LDAP suffix: ${LDAP_SUFFIX}
    * LDAP root dn: ${LDAP_ROOTDN}, password: ${LDAP_ROOTPW}
    * LDAP bind dn (read-only): ${LDAP_BINDDN}, password: ${LDAP_BINDPW}
    * LDAP admin dn (used for iRedAdmin): ${LDAP_ADMIN_DN}, password: ${LDAP_ADMIN_PW}
    * LDAP base dn: ${LDAP_BASEDN}
    * LDAP admin base dn: ${LDAP_ADMIN_BASEDN}
    * Configuration files:
        - ${OPENLDAP_CONF_ROOT}
        - ${OPENLDAP_SLAPD_CONF}
        - ${OPENLDAP_LDAP_CONF}
        - ${OPENLDAP_SCHEMA_DIR}/${PROG_NAME_LOWERCASE}.schema
    * Log file related:
        - ${SYSLOG_CONF}
        - ${OPENLDAP_LOGFILE}
        - ${OPENLDAP_LOGROTATE_FILE}
    * Data dir and files:
        - ${OPENLDAP_DATA_DIR}
        - ${LDAP_DATA_DIR}
        - ${LDAP_DATA_DIR}/DB_CONFIG
    * RC script:
        - ${OPENLDAP_RC_SCRIPT}
    * See also:
        - ${LDAP_INIT_LDIF}

EOF

    echo 'export status_openldap_data_initialize="DONE"' >> ${STATUS_FILE}
}

