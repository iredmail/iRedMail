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

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        ln -s ${NETDATA_CONF_DIR} /usr/local/etc/netdata >> ${INSTALL_LOG} 2>&1
    else
        ln -s ${NETDATA_CONF_DIR} /etc/netdata >> ${INSTALL_LOG} 2>&1
    fi

    # netdata will handle logrotate config file automatically.
    ln -s ${NETDATA_LOG_DIR} /var/log/netdata >> ${INSTALL_LOG} 2>&1

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

    ECHO_DEBUG "Generate htpasswd file: ${NETDATA_HTTPD_AUTH_FILE}."
    touch ${NETDATA_HTTPD_AUTH_FILE}
    chown ${HTTPD_USER}:${HTTPD_GROUP} ${NETDATA_HTTPD_AUTH_FILE}
    chmod 0400 ${NETDATA_HTTPD_AUTH_FILE}

    _pw="$(generate_password_hash MD5 ${DOMAIN_ADMIN_PASSWD_PLAIN})"
    echo "${DOMAIN_ADMIN_EMAIL}:${_pw}" >> ${NETDATA_HTTPD_AUTH_FILE}

    echo 'export status_netdata_config="DONE"' >> ${STATUS_FILE}
}

netdata_module_config()
{
    # MySQL & PostgreSQL
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ECHO_DEBUG "Create MySQL user ${NETDATA_DB_USER} with minimal privilege: USAGE."
        ${MYSQL_CLIENT_ROOT} >> ${INSTALL_LOG} 2>&1 <<EOF
GRANT USAGE ON *.* TO ${NETDATA_DB_USER}@${MYSQL_GRANT_HOST} IDENTIFIED BY '${NETDATA_DB_PASSWD}';
FLUSH PRIVILEGES;
EOF

        #ECHO_DEBUG "Create ${NETDATA_DOT_MY_CNF}."
        #cp -f ${SAMPLE_DIR}/netdata/my.cnf ${NETDATA_DOT_MY_CNF} >> ${INSTALL_LOG} 2>&1
        #perl -pi -e 's#PH_MYSQL_SERVER_ADDRESS#$ENV{MYSQL_SERVER_ADDRESS}#g' ${NETDATA_DOT_MY_CNF} >> ${INSTALL_LOG} 2>&1
        #perl -pi -e 's#PH_MYSQL_SERVER_PORT#$ENV{MYSQL_SERVER_PORT}#g' ${NETDATA_DOT_MY_CNF} >> ${INSTALL_LOG} 2>&1
        #perl -pi -e 's#PH_NETDATA_DB_USER#$ENV{NETDATA_DB_USER}#g' ${NETDATA_DOT_MY_CNF} >> ${INSTALL_LOG} 2>&1
        #perl -pi -e 's#PH_NETDATA_DB_PASSWD#$ENV{NETDATA_DB_PASSWD}#g' ${NETDATA_DOT_MY_CNF} >> ${INSTALL_LOG} 2>&1

        #ECHO_DEBUG "Link ${NETDATA_DOT_MY_CNF} to /root/.my.cnf-${NETDATA_DB_USER}."
        #ln -s ${NETDATA_DOT_MY_CNF} /root/.my.cnf-${NETDATA_DB_USER} >> ${INSTALL_LOG} 2>&1

        ECHO_DEBUG "Generate ${NETDATA_CONF_PLUGIN_MYSQL}."
        cp -f ${SAMPLE_DIR}/netdata/python.d/mysql.conf ${NETDATA_CONF_PLUGIN_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_MYSQL_SERVER_ADDRESS#$ENV{MYSQL_SERVER_ADDRESS}#g' ${NETDATA_CONF_PLUGIN_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_MYSQL_SERVER_PORT#$ENV{MYSQL_SERVER_PORT}#g' ${NETDATA_CONF_PLUGIN_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_USER#$ENV{NETDATA_DB_USER}#g' ${NETDATA_CONF_PLUGIN_MYSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_PASSWD#$ENV{NETDATA_DB_PASSWD}#g' ${NETDATA_CONF_PLUGIN_MYSQL} >> ${INSTALL_LOG} 2>&1

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        su - ${PGSQL_SYS_USER} -c "psql -d template1" >> ${INSTALL_LOG} 2>&1 <<EOF
CREATE USER ${NETDATA_DB_USER} WITH ENCRYPTED PASSWORD '${NETDATA_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
EOF

        ECHO_DEBUG "Generate ${NETDATA_CONF_PLUGIN_PGSQL}."
        cp -f ${SAMPLE_DIR}/netdata/python.d/postgres.conf ${NETDATA_CONF_PLUGIN_PGSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_USER#$ENV{NETDATA_DB_USER}#g' ${NETDATA_CONF_PLUGIN_PGSQL} >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's#PH_NETDATA_DB_PASSWD#$ENV{NETDATA_DB_PASSWD}#g' ${NETDATA_CONF_PLUGIN_PGSQL} >> ${INSTALL_LOG} 2>&1
    fi
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
        check_status_before_run netdata_module_config
        check_status_before_run netdata_system_tune
    fi
}
