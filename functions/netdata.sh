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
    #
    # NOTE: Install netdata on __LINUX__.
    #
    ECHO_DEBUG "Install netdata with package: ${NETDATA_PKG_NAME}."

    cd ${PKG_MISC_DIR}
    chmod +x ${NETDATA_PKG_NAME}

    # Note: netdata installer will generate rc/systemd script automatically.
    ./${NETDATA_PKG_NAME} --accept > ${RUNTIME_DIR}/netdata-install.log 2>&1

    ln -s ${NETDATA_CONF_DIR} /etc/netdata >> ${INSTALL_LOG} 2>&1

    # netdata will handle logrotate config file automatically.
    if [[ ! -d /var/log/netdata ]]; then
        ln -s ${NETDATA_LOG_DIR} /var/log/netdata >> ${INSTALL_LOG} 2>&1
    fi

    echo 'export status_netdata_install="DONE"' >> ${STATUS_FILE}
}

netdata_config()
{
    ECHO_INFO "Configure netdata (system and application monitor)."

    # Disable sending anonymouse statistics to netdata cloud.
    touch ${NETDATA_CONF_DIR}/.opt-out-from-anonymous-statistics

    # Enable service.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        service_control enable 'netdata_enable' 'YES'
    else
        service_control enable ${NETDATA_RC_SCRIPT_NAME}
    fi

    backup_file ${NETDATA_CONF}

    ECHO_DEBUG "Generate netdata config file: ${SAMPLE_DIR}/netdata/netdata.conf -> ${NETDATA_CONF}."
    cp -f ${SAMPLE_DIR}/netdata/netdata.conf ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    cp -f ${SAMPLE_DIR}/netdata/health_alarm_notify.conf ${NETDATA_HEALTH_ALARM_NOTIFY_CONF} >> ${INSTALL_LOG} 2>&1
    cp -f ${SAMPLE_DIR}/netdata/python.d.conf ${NETDATA_PYTHON_D_CONF} >> ${INSTALL_LOG} 2>&1
    cp -f ${SAMPLE_DIR}/netdata/go.d.conf ${NETDATA_GO_D_CONF} >> ${INSTALL_LOG} 2>&1

    chown ${SYS_USER_NETDATA}:${SYS_GROUP_NETDATA} \
        ${NETDATA_CONF} \
        ${NETDATA_HEALTH_ALARM_NOTIFY_CONF} \
        ${NETDATA_PYTHON_D_CONF} \
        ${NETDATA_GO_D_CONF} >> ${INSTALL_LOG} 2>&1

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        perl -pi -e 's#( *memory mode =).*#${1} save#g' ${NETDATA_CONF}

        # FreeBSD doesn't have Go plugins, have to use Python plugins instead.
        perl -pi -e 's/^(web_log: no)/#${1}/' ${NETDATA_PYTHON_D_CONF}
        perl -pi -e 's/^(nginx: no)/#${1}/' ${NETDATA_PYTHON_D_CONF}
        perl -pi -e 's/^(phpfpm: no)/#${1}/' ${NETDATA_PYTHON_D_CONF}
        perl -pi -e 's/^(mysql: no)/#${1}/' ${NETDATA_PYTHON_D_CONF}
    fi

    perl -pi -e 's#PH_NETDATA_PORT#$ENV{NETDATA_PORT}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1
    perl -pi -e 's#PH_SYS_USER_NETDATA#$ENV{SYS_USER_NETDATA}#g' ${NETDATA_CONF} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Generate htpasswd file: ${NETDATA_HTTPD_AUTH_FILE}."
    touch ${NETDATA_HTTPD_AUTH_FILE}
    chown ${HTTPD_USER}:${HTTPD_GROUP} ${NETDATA_HTTPD_AUTH_FILE}
    chmod 0400 ${NETDATA_HTTPD_AUTH_FILE}

    # Add postmaster@<first-domain> if not present.
    if ! grep "^${DOMAIN_ADMIN_EMAIL}:" ${NETDATA_HTTPD_AUTH_FILE} &>/dev/null; then
        _pw="$(generate_password_hash SSHA ${DOMAIN_ADMIN_PASSWD_PLAIN})"
        echo "${DOMAIN_ADMIN_EMAIL}:${_pw}" >> ${NETDATA_HTTPD_AUTH_FILE}
    fi

    echo 'export status_netdata_config="DONE"' >> ${STATUS_FILE}
}

netdata_module_config()
{
    ECHO_DEBUG "Generate config files for plugins."

    mkdir -p ${NETDATA_GO_D_CONF_DIR} ${NETDATA_PYTHON_D_CONF_DIR} &>/dev/null

    # go.d modules: phpfpm, nginx.
    cp -f ${SAMPLE_DIR}/netdata/go.d/phpfpm.conf ${NETDATA_GO_D_CONF_PHPFPM} >> ${INSTALL_LOG} 2>&1
    cp -f ${SAMPLE_DIR}/netdata/go.d/nginx.conf ${NETDATA_GO_D_CONF_NGINX} >> ${INSTALL_LOG} 2>&1

    # OpenLDAP
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ECHO_DEBUG "Generate ${NETDATA_PYTHON_D_CONF_OPENLDAP}."

        cp -f ${SAMPLE_DIR}/netdata/python.d/openldap.conf ${NETDATA_PYTHON_D_CONF_OPENLDAP} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#g' ${NETDATA_PYTHON_D_CONF_OPENLDAP} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_LDAP_BINDPW#$ENV{LDAP_BINDPW}#g' ${NETDATA_PYTHON_D_CONF_OPENLDAP} >> ${INSTALL_LOG} 2>&1
    fi

    # MySQL & PostgreSQL
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ECHO_DEBUG "Create MySQL user ${NETDATA_DB_USER} with minimal privilege: USAGE."
        ${MYSQL_CLIENT_ROOT} >> ${INSTALL_LOG} 2>&1 <<EOF
GRANT USAGE ON *.* TO ${NETDATA_DB_USER}@${MYSQL_GRANT_HOST} IDENTIFIED BY '${NETDATA_DB_PASSWD}';
FLUSH PRIVILEGES;
EOF

        ECHO_DEBUG "Generate ${NETDATA_GO_D_CONF_MYSQL}."
        cp -f ${SAMPLE_DIR}/netdata/go.d/mysql.conf ${NETDATA_GO_D_CONF_MYSQL} >> ${INSTALL_LOG} 2>&1

        perl -pi -e 's#PH_MYSQL_SERVER_ADDRESS#$ENV{MYSQL_SERVER_ADDRESS}#g' ${NETDATA_GO_D_CONF_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_MYSQL_SERVER_PORT#$ENV{MYSQL_SERVER_PORT}#g' ${NETDATA_GO_D_CONF_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_USER#$ENV{NETDATA_DB_USER}#g' ${NETDATA_GO_D_CONF_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_PASSWD#$ENV{NETDATA_DB_PASSWD}#g' ${NETDATA_GO_D_CONF_MYSQL} >> ${INSTALL_LOG} 2>&1

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        su - ${SYS_USER_PGSQL} -c "psql -d template1" >> ${INSTALL_LOG} 2>&1 <<EOF
CREATE USER ${NETDATA_DB_USER} WITH ENCRYPTED PASSWORD '${NETDATA_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
EOF

        ECHO_DEBUG "Generate ${NETDATA_PYTHON_D_CONF_PGSQL}."
        backup_file ${NETDATA_PYTHON_D_CONF_PGSQL}
        cp -f ${SAMPLE_DIR}/netdata/python.d/postgres.conf ${NETDATA_PYTHON_D_CONF_PGSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_USER#$ENV{NETDATA_DB_USER}#g' ${NETDATA_PYTHON_D_CONF_PGSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_PASSWD#$ENV{NETDATA_DB_PASSWD}#g' ${NETDATA_PYTHON_D_CONF_PGSQL} >> ${INSTALL_LOG} 2>&1
    fi

    chown -R ${SYS_USER_NETDATA}:${SYS_GROUP_NETDATA} ${NETDATA_GO_D_CONF_DIR} ${NETDATA_PYTHON_D_CONF_DIR}
    chmod 0755 ${NETDATA_GO_D_CONF_DIR} ${NETDATA_PYTHON_D_CONF_DIR}
    chmod 0400 ${NETDATA_GO_D_CONF_DIR}/*.conf &>/dev/null
    chmod 0400 ${NETDATA_PYTHON_D_CONF_DIR}/*.conf &>/dev/null

    echo 'export status_netdata_module_config="DONE"' >> ${STATUS_FILE}
}

netdata_system_tune()
{
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        ECHO_DEBUG "Add sysctl parameters for better netdata performance."
        update_sysctl_param vm.dirty_expire_centisecs 60000
        update_sysctl_param vm.dirty_background_ratio 80
        update_sysctl_param vm.dirty_ratio 90

        ECHO_DEBUG "Increase open files limit."
        if [ X"${USE_SYSTEMD}" == X'YES' ]; then
            mkdir /etc/systemd/system/netdata.service.d >> ${INSTALL_LOG} 2>&1
            cp -f ${SAMPLE_DIR}/netdata/systemd-limits.conf /etc/systemd/system/netdata.service.d/limits.conf >> ${INSTALL_LOG} 2>&1
        fi
    fi

    echo 'export status_netdata_system_tune="DONE"' >> ${STATUS_FILE}
}

netdata_setup()
{
    if [ X"${DISTRO}" != X'OPENBSD' ]; then
        if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
            check_status_before_run netdata_install
        fi

        check_status_before_run netdata_config
        check_status_before_run netdata_module_config
        check_status_before_run netdata_system_tune
    fi

    cat >> ${TIP_FILE} <<EOF
netdata (monitor):
    - Config files:
        - All config files: ${NETDATA_CONF_DIR}
        - Main config file: ${NETDATA_CONF}
        - Modified modular config files:
            - ${NETDATA_GO_D_CONF_DIR}
            - ${NETDATA_PYTHON_D_CONF_DIR}
    - HTTP auth file (if you need a new account to access netdata, please
      update this file with command like 'htpasswd' or edit manually):
        - ${NETDATA_HTTPD_AUTH_FILE}
    - Log directory: ${NETDATA_LOG_DIR}
    - SQL:
        - Username: ${NETDATA_DB_USER}
        - Password: ${NETDATA_DB_PASSWD}
        - NOTE: No database required by netdata.

EOF

    write_iredmail_kv "sql_user_${NETDATA_DB_USER}" "${NETDATA_DB_PASSWD}"
    echo 'export status_netdata_setup="DONE"' >> ${STATUS_FILE}
}
