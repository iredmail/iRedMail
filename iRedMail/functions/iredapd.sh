#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Install & config necessary packages for iRedAPD.

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


iredapd_config()
{
    ECHO_INFO "Configure iRedAPD (postfix policy daemon)."

    # Extract source tarball.
    cd ${PKG_MISC_DIR}
    [ -d ${IREDAPD_ROOT_DIR} ] || mkdir -p ${IREDAPD_ROOT_DIR}
    extract_pkg ${IREDAPD_TARBALL} ${IREDAPD_ROOT_DIR}

    ECHO_DEBUG "Configure iRedAPD."
    # Create symbol link.
    ln -s ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION} ${IREDAPD_ROOT_DIR}/iredapd 2>/dev/null

    # Copy init rc script.
    if [ X"${DISTRO}" == X"RHEL" ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.rhel ${DIR_RC_SCRIPTS}/iredapd
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.debian ${DIR_RC_SCRIPTS}/iredapd
    elif [ X"${DISTRO}" == X"FREEBSD" ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.freebsd ${DIR_RC_SCRIPTS}/iredapd
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.openbsd ${DIR_RC_SCRIPTS}/iredapd
    else
        cp ${IREDAPD_ROOT_DIR}/iredapd/rc_scripts/iredapd.rhel ${DIR_RC_SCRIPTS}/iredapd
    fi

    chmod 0755 ${DIR_RC_SCRIPTS}/iredapd

    ECHO_DEBUG "Make iredapd start after system startup."
    eval ${enable_service} iredapd &>/dev/null
    export ENABLED_SERVICES="${ENABLED_SERVICES} iredapd"

    # Set file permission.
    chown -R ${IREDAPD_DAEMON_USER}:${IREDAPD_DAEMON_USER} ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION}
    chmod -R 0555 ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION}

    # Copy sample config file.
    cd ${IREDAPD_ROOT_DIR}/iredapd/
    cp settings.py.sample settings.py
    chmod -R 0500 settings.py

    # General settings.
    perl -pi -e 's#^(listen_address).*#${1} = "$ENV{IREDAPD_BIND_HOST}"#' settings.py
    perl -pi -e 's#^(listen_port).*#${1} = "$ENV{IREDAPD_LISTEN_PORT}"#' settings.py
    perl -pi -e 's#^(run_as_user).*#${1} = "$ENV{IREDAPD_DAEMON_USER}"#' settings.py
    perl -pi -e 's#^(log_level).*#${1} = "info"#' settings.py

    # Backend.
    [ X"${BACKEND}" == X'OPENLDAP' ] && perl -pi -e 's#^(backend).*#${1} = "ldap"#' settings.py
    [ X"${BACKEND}" == X'MYSQL' ] && perl -pi -e 's#^(backend).*#${1} = "mysql"#' settings.py
    [ X"${BACKEND}" == X'PGSQL' ] && perl -pi -e 's#^(backend).*#${1} = "pgsql"#' settings.py

    # Backend related parameters.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#^(ldap_uri).*#${1} = "ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(ldap_binddn).*#${1} = "$ENV{LDAP_BINDDN}"#' settings.py
        perl -pi -e 's#^(ldap_bindpw).*#${1} = "$ENV{LDAP_BINDPW}"#' settings.py
        perl -pi -e 's#^(ldap_basedn).*#${1} = "$ENV{LDAP_BASEDN}"#' settings.py

        perl -pi -e 's#^(plugins).*#${1} = ["ldap_maillist_access_policy", "ldap_amavisd_block_blacklisted_senders", "ldap_recipient_restrictions"]#' settings.py

    elif [ X"${BACKEND}" == X"MYSQL" -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(sql_server).*#${1} = "$ENV{SQL_SERVER}"#' settings.py
        perl -pi -e 's#^(sql_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' settings.py
        perl -pi -e 's#^(sql_db).*#${1} = "$ENV{VMAIL_DB}"#' settings.py
        perl -pi -e 's#^(sql_user).*#${1} = "$ENV{VMAIL_DB_BIND_USER}"#' settings.py
        perl -pi -e 's#^(sql_password).*#${1} = "$ENV{VMAIL_DB_BIND_PASSWD}"#' settings.py

        perl -pi -e 's#^(plugins).*#${1} = ["sql_alias_access_policy", "sql_user_restrictions"]#' settings.py
    fi

    # FreeBSD: Start iredapd when system start up.
    freebsd_enable_service_in_rc_conf 'iredapd_enable' 'YES'

    # Log rotate
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        ECHO_DEBUG "Setting logrotate for iRedAPD log file."
        cat > ${IREDAPD_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${IREDAPD_LOG_FILE} {
    compress
    weekly
    rotate 10
    create 0600 ${SYS_ROOT_USER} ${SYS_ROOT_GROUP}
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        ${DIR_RC_SCRIPTS}/iredapd restart
    endscript
}
EOF
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        if ! grep 'iredapd.log' /etc/newsyslog.conf &>/dev/null; then
            # Define path of PID file to restart iRedAPD service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${IREDAPD_LOG_FILE}    ${SYS_ROOT_USER}:${SYS_ROOT_GROUP}   640  7     *    24    Z ${IREDAPD_PID_FILE}
EOF
        fi

    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep 'iredapd.log' /etc/newsyslog.conf &>/dev/null; then
            # Define command used to restart iRedAPD service after rotated
            cat >> /etc/newsyslog.conf <<EOF
${IREDAPD_LOG_FILE}    ${SYS_ROOT_USER}:${SYS_ROOT_GROUP}   640  7     *    24    Z "${DIR_RC_SCRIPTS}/iredapd restart >/dev/null"
EOF
        fi
    fi

    cat >> ${TIP_FILE} <<EOF
iRedAPD - Postfix Policy Daemon:
    * Version: ${IREDAPD_VERSION}
    * Listen address: ${IREDAPD_BIND_HOST}, port: ${IREDAPD_LISTEN_PORT}
    * Related files:
        - ${IREDAPD_ROOT_DIR}/iRedAPD-${IREDAPD_VERSION}/
        - ${IREDAPD_ROOT_DIR}/iredapd/
        - ${IREDAPD_ROOT_DIR}/iredapd/etc/settings.py

EOF

    echo 'export status_iredapd_config="DONE"' >> ${STATUS_FILE}
}
