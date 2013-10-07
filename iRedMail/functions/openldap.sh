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
        if [ X"${DISTRO_VERSION}" == X"6" ]; then
            # Run slapd with slapd.conf, not slapd.d.
            perl -pi -e 's/#(SLAPD_OPTIONS=).*/${1}"-f $ENV{OPENLDAP_SLAPD_CONF}"/' ${OPENLDAP_SYSCONFIG_CONF}

            # Run slapd with -h "... ldap:/// ..."
            perl -pi -e 's/#(SLAPD_LDAP=).*/${1}yes/' ${OPENLDAP_SYSCONFIG_CONF}

            # Run slapd with -h "... ldaps:/// ...".
            perl -pi -e 's/#(SLAPD_LDAPS=).*/${1}yes/' ${OPENLDAP_SYSCONFIG_CONF}
        fi

    elif [ X"${DISTRO}" == X"SUSE" ]; then
        # Fix strict permission.
        chmod 0755 ${SSL_KEY_DIR}

        # Start ldaps.
        perl -pi -e 's#^(OPENLDAP_START_LDAPS=).*#${1}"yes"#' ${OPENLDAP_SYSCONFIG_CONF}

        # Set config backend.
        perl -pi -e 's#^(OPENLDAP_CONFIG_BACKEND=).*#${1}"files"#' ${OPENLDAP_SYSCONFIG_CONF}

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
        if [ X"${DISTRO_VERSION}" == X"6" ]; then
            amavisd_schema_file="$( eval ${LIST_FILES_IN_PKG} amavisd-new | grep '/LDAP.schema$')"
            cp -f ${amavisd_schema_file} ${OPENLDAP_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
        fi
    elif [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
        cp -f /usr/local/share/doc/amavisd-new/LDAP.schema ${OPENLDAP_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
    fi


    ECHO_DEBUG "Generate new server configuration file: ${OPENLDAP_SLAPD_CONF}."
    cat > ${OPENLDAP_SLAPD_CONF} <<EOF
${CONF_MSG}
# Schemas.
include     ${OPENLDAP_SCHEMA_DIR}/core.schema
include     ${OPENLDAP_SCHEMA_DIR}/corba.schema
include     ${OPENLDAP_SCHEMA_DIR}/cosine.schema
include     ${OPENLDAP_SCHEMA_DIR}/inetorgperson.schema
include     ${OPENLDAP_SCHEMA_DIR}/nis.schema
# Integrate Amavisd-new.
include     ${OPENLDAP_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
# Schema provided by ${PROG_NAME}.
include     ${OPENLDAP_SCHEMA_DIR}/${PROG_NAME_LOWERCASE}.schema

# Where the pid file is put. The init.d script will not stop the
# server if you change this.
pidfile     ${OPENLDAP_PID_FILE}

# List of arguments that were passed to the server
argsfile    ${OPENLDAP_ARGS_FILE}

# TLS files.
TLSCACertificateFile ${SSL_CERT_FILE}
TLSCertificateFile ${SSL_CERT_FILE}
TLSCertificateKeyFile ${SSL_KEY_FILE}

EOF

    # Load backend module. Required on Debian/Ubuntu.
    if [ X"${OPENLDAP_VERSION}" == X"2.4" \
        -a X"${DISTRO}" != X'SUSE' \
        -a X"${DISTRO}" != X'OPENBSD' \
        ]; then
        if [ X"${OPENLDAP_DEFAULT_DBTYPE}" == X"bdb" ]; then
            # bdb, Berkeley DB.
            cat >> ${OPENLDAP_SLAPD_CONF} <<EOF
# Modules.
modulepath  ${OPENLDAP_MODULE_PATH}
moduleload  back_bdb

EOF
        elif [ X"${OPENLDAP_DEFAULT_DBTYPE}" == X"hdb" ]; then
            # hdb.
            cat >> ${OPENLDAP_SLAPD_CONF} <<EOF
# Modules.
modulepath  ${OPENLDAP_MODULE_PATH}
moduleload  back_hdb

EOF
        else
            :
        fi
    else
        :
    fi

    cat >> ${OPENLDAP_SLAPD_CONF} <<EOF
# Disallow bind as anonymous.
disallow    bind_anon

# Uncomment below line to allow binding as anonymous.
#allow bind_anon_cred

# Specify LDAP protocol version.
require     LDAPv3
#allow       bind_v2

# Log level.
#   -1:     enable all debugging
#    0:     no debugging
#   128:    access control list processing
#   256:    stats log connections/operations/results
loglevel    0

#
# Access Control List. Used for LDAP bind.
#
# NOTE: Every domain have a administrator. e.g.
#   Domain Name: '${FIRST_DOMAIN}'
#   Admin Name: ${LDAP_ATTR_USER_RDN}=${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}, ${LDAP_ATTR_DOMAIN_RDN}=${FIRST_DOMAIN}, ${LDAP_BASEDN}
#

# Allow users to change their own passwords and mail forwarding addresses.
access to attrs="${LDAP_ATTR_USER_PASSWD},${LDAP_ATTR_USER_FORWARD},${LDAP_ATTR_USER_STORAGE_BASE_DIRECTORY},homeDirectory,mailMessageStore"
    by anonymous    auth
    by self         write
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users        none

# Allow to read others public info.
access to attrs="cn,sn,gn,givenName,telephoneNumber"
    by anonymous    auth
    by self         write
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users        read

# Domain attrs.
access to attrs="objectclass,${LDAP_ATTR_DOMAIN_RDN},${LDAP_ATTR_MTA_TRANSPORT},${LDAP_ENABLED_SERVICE},${LDAP_ATTR_DOMAIN_SENDER_BCC_ADDRESS},${LDAP_ATTR_DOMAIN_RECIPIENT_BCC_ADDRESS},${LDAP_ATTR_DOMAIN_BACKUPMX},${LDAP_ATTR_DOMAIN_MAX_QUOTA_SIZE},${LDAP_ATTR_DOMAIN_MAX_USER_NUMBER}"
    by anonymous    auth
    by self         read
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users        read

access to attrs="${LDAP_ATTR_DOMAIN_ADMIN},${LDAP_ATTR_DOMAIN_GLOBALADMIN},${LDAP_ATTR_DOMAIN_SENDER_BCC_ADDRESS},${LDAP_ATTR_DOMAIN_RECIPIENT_BCC_ADDRESS}"
    by anonymous    auth
    by self         read
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users        none

# User attrs.
access to attrs="employeeNumber,${LDAP_ATTR_USER_RDN},${LDAP_ATTR_ACCOUNT_STATUS},${LDAP_ATTR_USER_SENDER_BCC_ADDRESS},${LDAP_ATTR_USER_RECIPIENT_BCC_ADDRESS},${LDAP_ATTR_USER_QUOTA},${LDAP_ATTR_USER_BACKUP_MAIL_ADDRESS},${LDAP_ATTR_USER_SHADOW_ADDRESS},${LDAP_ATTR_USER_MEMBER_OF_GROUP}"
    by anonymous    auth
    by self         read
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users        read

#
# Set ACL for vmail/vmailadmin.
#
access to dn="${LDAP_BINDDN}"
    by anonymous                    auth
    by self                         write
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users                        none

access to dn="${LDAP_ADMIN_DN}"
    by anonymous                    auth
    by self                         write
    by users                        none

#
# Allow users to access their own domain subtree.
# Allow domain admin to modify accounts under same domain.
#
access to dn.regex="${LDAP_ATTR_DOMAIN_RDN}=([^,]+),${LDAP_BASEDN}\$"
    by anonymous                    auth
    by self                         write
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by dn.regex="${LDAP_ATTR_USER_RDN}=[^,]+@\$1,${LDAP_ADMIN_BASEDN}\$" write
    by dn.regex="${LDAP_ATTR_USER_RDN}=[^,]+@\$1,${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_USERS},${LDAP_ATTR_DOMAIN_RDN}=\$1,${LDAP_BASEDN}\$" read
    by users                        none

#
# Grant correct privileges to vmail/vmailadmin.
#
access to dn.subtree="${LDAP_BASEDN}"
    by anonymous                    auth
    by self                         write
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by dn.regex="${LDAP_ATTR_USER_RDN}=[^,]+,${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_USERS},${LDAP_ATTR_DOMAIN_RDN}=\$1,${LDAP_BASEDN}\$" read
    by users                        read

access to dn.subtree="${LDAP_ADMIN_BASEDN}"
    by anonymous                    auth
    by self                         write
    by dn.exact="${LDAP_BINDDN}"   read
    by dn.exact="${LDAP_ADMIN_DN}"  write
    by users                        none

#
# Set permission for "cn=*,${LDAP_SUFFIX}".
#
access to dn.regex="cn=[^,]+,${LDAP_SUFFIX}"
    by anonymous                    auth
    by self                         write
    by users                        none

#
# Set default permission.
#
access to *
    by anonymous                    auth
    by self                         write
    by users                        read

#######################################################################
# BDB database definitions
#######################################################################

database    ${OPENLDAP_DEFAULT_DBTYPE}
suffix      ${LDAP_SUFFIX}
directory   ${LDAP_DATA_DIR}

rootdn      ${LDAP_ROOTDN}
rootpw      ${LDAP_ROOTPW_SSHA}

sizelimit   10000
cachesize   10000

# This directive specifies how often to checkpoint the BDB transaction log.
# A checkpoint operation flushes the database buffers to disk and writes a
# checkpoint record in the log. The checkpoint will occur if either <kbyte>
# data has been written or <min> minutes have passed since the last checkpoint.
# Both arguments default to zero, in which case they are ignored. When the
# <min> argument is non-zero, an internal task will run every <min> minutes
# to perform the checkpoint. See the Berkeley DB reference guide for more
# details.
#
# OpenLDAP default is NO CHECKPOINTING.
#
# whenever 128kb data bytes written or 5 minutes has elapsed
checkpoint  128 5

# Set directory permission.
mode        0700

#
# Default index.
#
index objectClass                                   eq,pres
index uidNumber,gidNumber,uid,memberUid,loginShell  eq,pres
index homeDirectory,mailMessageStore                eq,pres
index ou,cn,mail,surname,givenname,telephoneNumber  eq,pres,sub
#index nisMapName,nisMapEntry                        eq,pres,sub
index shadowLastChange                              eq,pres

#
# Index for mail attrs.
#
# ---- Domain related ----
index ${LDAP_ATTR_DOMAIN_RDN},${LDAP_ATTR_MTA_TRANSPORT},${LDAP_ATTR_ACCOUNT_STATUS},${LDAP_ENABLED_SERVICE}  eq,pres,sub
index ${LDAP_ATTR_DOMAIN_ALIAS_NAME}    eq,pres,sub
index ${LDAP_ATTR_DOMAIN_MAX_USER_NUMBER} eq,pres
index ${LDAP_ATTR_DOMAIN_ADMIN},${LDAP_ATTR_DOMAIN_GLOBALADMIN},${LDAP_ATTR_DOMAIN_BACKUPMX}    eq,pres,sub
index ${LDAP_ATTR_DOMAIN_SENDER_BCC_ADDRESS},${LDAP_ATTR_DOMAIN_RECIPIENT_BCC_ADDRESS}  eq,pres,sub
# ---- Group related ----
index ${LDAP_ATTR_GROUP_ACCESSPOLICY},${LDAP_ATTR_GROUP_HASMEMBER},${LDAP_ATTR_GROUP_ALLOWED_USER}   eq,pres,sub
# ---- User related ----
index ${LDAP_ATTR_USER_FORWARD},${LDAP_ATTR_USER_SHADOW_ADDRESS}   eq,pres,sub
index ${LDAP_ATTR_USER_BACKUP_MAIL_ADDRESS},${LDAP_ATTR_USER_MEMBER_OF_GROUP}   eq,pres,sub
index ${LDAP_ATTR_USER_RECIPIENT_BCC_ADDRESS},${LDAP_ATTR_USER_SENDER_BCC_ADDRESS}  eq,pres,sub
EOF

    # Make slapd use slapd.conf insteald of slapd.d (cn=config backend).
    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        perl -pi -e 's#^(SLAPD_CONF=).*#${1}"$ENV{OPENLDAP_SLAPD_CONF}"#' ${OPENLDAP_SYSCONFIG_CONF}
        perl -pi -e 's#^(SLAPD_PIDFILE=).*#${1}"$ENV{OPENLDAP_PID_FILE}"#' ${OPENLDAP_SYSCONFIG_CONF}
    fi

    ECHO_DEBUG "Generate new client configuration file: ${OPENLDAP_LDAP_CONF}"
    cat > ${OPENLDAP_LDAP_CONF} <<EOF
BASE    ${LDAP_SUFFIX}
URI     ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}
TLS_CACERT ${SSL_CERT_FILE}
EOF
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
    if [ X"${DISTRO}" == X"RHEL" ]; then
        service_control syslog restart >/dev/null
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        # Debian 4, Ubuntu 9.04 -> ${DIR_RC_SCRIPTS}/sysklogd
        # Debian 5  -> ${DIR_RC_SCRIPTS}/rsyslog
        [ -x ${DIR_RC_SCRIPTS}/sysklogd ] && service_control sysklogd restart >/dev/null
        [ -x ${DIR_RC_SCRIPTS}/rsyslog ] && service_control rsyslog restart >/dev/null
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
    if [ X"${DISTRO}" == X"RHEL" -a X"${DISTRO_VERSION}" == X"6" ]; then
        export OPENLDAP_DB_CONFIG_SAMPLE="$( eval ${LIST_FILES_IN_PKG} openldap-servers | grep '/DB_CONFIG.example$')"
    fi

    ECHO_DEBUG "Create instance directory for openldap tree: ${LDAP_DATA_DIR}."
    mkdir -p ${LDAP_DATA_DIR}
    cp -f ${OPENLDAP_DB_CONFIG_SAMPLE} ${LDAP_DATA_DIR}/DB_CONFIG
    chown -R ${OPENLDAP_DAEMON_USER}:${OPENLDAP_DAEMON_GROUP} ${OPENLDAP_DATA_DIR}
    chmod -R 0700 ${OPENLDAP_DATA_DIR}

    ECHO_DEBUG "Starting OpenLDAP."
    ${OPENLDAP_RC_SCRIPT} restart &>/dev/null

    ECHO_DEBUG "Sleep 5 seconds for LDAP daemon initialize ..."
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

