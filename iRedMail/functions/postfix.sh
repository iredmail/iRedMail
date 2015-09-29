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

# -------------------------------------------------------
# ---------------------- Postfix ------------------------
# -------------------------------------------------------

postfix_config_basic()
{
    ECHO_INFO "Configure Postfix (Message Transfer Agent)."

    # OpenBSD: Replace sendmail, opensmtpd by Postfix
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        echo 'sendmail_flags=NO' >> ${RC_CONF_LOCAL}
        echo 'smtpd_flags=NO' >> ${RC_CONF_LOCAL}
        /usr/local/sbin/postfix-enable >> ${INSTALL_LOG} 2>&1
        perl -pi -e 's/(.*sendmail -L sm-msp-queue.*)/#${1}/' ${CRON_SPOOL_DIR}/root 
    fi

    backup_file ${POSTFIX_FILE_MAIN_CF} ${POSTFIX_FILE_MASTER_CF}

    ECHO_DEBUG "Copy: /etc/{hosts,resolv.conf,localtime,services} -> ${POSTFIX_CHROOT_DIR}/etc/"
    mkdir -p ${POSTFIX_CHROOT_DIR}/etc/ >> ${INSTALL_LOG} 2>&1
    for i in /etc/hosts /etc/resolv.conf /etc/localtime /etc/services; do
        [ -f $i ] && cp ${i} ${POSTFIX_CHROOT_DIR}/etc/
    done

    #
    # main.cf
    #
    ECHO_DEBUG "Copy sample main.cf and update values."
    export queue_directory="$(postconf queue_directory | awk '{print $NF}')"
    export command_directory="$(postconf command_directory | awk '{print $NF}')"
    export daemon_directory="$(postconf daemon_directory | awk '{print $NF}')"
    export data_directory="$(postconf data_directory | awk '{print $NF}')"
    export mail_owner="$(postconf mail_owner | awk '{print $NF}')"

    cp ${SAMPLE_DIR}/postfix/main.cf ${POSTFIX_FILE_MAIN_CF}

    perl -pi -e 's#PH_QUEUE_DIRECTORY#$ENV{queue_directory}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_COMMAND_DIRECTORY#$ENV{command_directory}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_DAEMON_DIRECTORY#$ENV{daemon_directory}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_DATA_DIRECTORY#$ENV{data_directory}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_MAIL_OWNER#$ENV{mail_owner}#g' ${POSTFIX_FILE_MAIN_CF}

    unset queue_directory command_directory daemon_directory data_directory mail_owner

    # Update normal settings.
    perl -pi -e 's#PH_SSL_DHPARAM_FILE#$ENV{SSL_DHPARAM_FILE}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_MESSAGE_SIZE_LIMIT#$ENV{MESSAGE_SIZE_LIMIT}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_SSL_KEY_FILE#$ENV{SSL_KEY_FILE}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_STORAGE_BASE_DIR#$ENV{STORAGE_BASE_DIR}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_VMAIL_USER_UID#$ENV{VMAIL_USER_UID}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_POSTFIX_FILE_ALIASES#$ENV{POSTFIX_FILE_ALIASES}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_POSTFIX_FILE_HELO_ACCESS#$ENV{POSTFIX_FILE_HELO_ACCESS}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_VMAIL_USER_GID#$ENV{VMAIL_USER_GID}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_VMAIL_USER_UID#$ENV{VMAIL_USER_UID}#g' ${POSTFIX_FILE_MAIN_CF}

    # iRedAPD
    perl -pi -e 's#PH_IREDAPD_BIND_HOST#$ENV{IREDAPD_BIND_HOST}#g' ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_IREDAPD_LISTEN_PORT#$ENV{IREDAPD_LISTEN_PORT}#g' ${POSTFIX_FILE_MAIN_CF}

    #
    # master.cf
    #
    ECHO_DEBUG "Enable chroot."
    perl -pi -e 's/^(smtp.*inet)(.*)(n)(.*)(n)(.*smtpd)$/${1}${2}${3}${4}-${6}/' ${POSTFIX_FILE_MASTER_CF}

    ECHO_DEBUG "Enable submission."
    cat ${SAMPLE_DIR}/postfix/master.cf >> ${POSTFIX_FILE_MASTER_CF}

    # Amavisd integration.
    perl -pi -e 's#PH_AMAVISD_SERVER#$ENV{AMAVISD_SERVER}#g' ${POSTFIX_FILE_MASTER_CF}
    perl -pi -e 's#PH_AMAVISD_MAX_SERVERS#$ENV{AMAVISD_MAX_SERVERS}#g' ${POSTFIX_FILE_MASTER_CF}
    perl -pi -e 's#PH_AMAVISD_MYNETWORKS#$ENV{AMAVISD_MYNETWORKS}#g' ${POSTFIX_FILE_MASTER_CF}

    backup_file ${POSTFIX_FILE_HELO_ACCESS}
    cp -f ${SAMPLE_DIR}/postfix/helo_access.pcre ${POSTFIX_FILE_HELO_ACCESS}

    # Update Postfix aliases file.
    add_postfix_alias nobody ${SYS_ROOT_USER}
    add_postfix_alias ${VMAIL_USER_NAME} ${SYS_ROOT_USER}
    add_postfix_alias ${SYS_ROOT_USER} ${FIRST_USER}@${FIRST_DOMAIN}

    cat >> ${TIP_FILE} <<EOF
Postfix:
    * Configuration files:
        - ${POSTFIX_ROOTDIR}
        - ${POSTFIX_ROOTDIR}/aliases
        - ${POSTFIX_FILE_MAIN_CF}
        - ${POSTFIX_FILE_MASTER_CF}

    * SQL/LDAP lookup config files:
        - ${POSTFIX_LOOKUP_DIR}
EOF

    # FreeBSD: Start postfix when system start up.
    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        backup_file /etc/mail/mailer.conf
        cat > /etc/mail/mailer.conf <<EOF
#
# Execute the Postfix sendmail program, named /usr/local/sbin/sendmail
#
sendmail    /usr/local/sbin/sendmail
send-mail   /usr/local/sbin/sendmail
mailq       /usr/local/sbin/sendmail
newaliases  /usr/local/sbin/sendmail
EOF

        # Start service when system start up.
        service_control enable 'postfix_enable' 'YES'
        service_control enable 'sendmail_enable' 'NO'
        service_control enable 'sendmail_submit_enable' 'NO'
        service_control enable 'sendmail_outbound_enable' 'NO'
        service_control enable 'sendmail_msp_queue_enable' 'NO'
        service_control enable 'daily_clean_hoststat_enable' 'NO'
        service_control enable 'daily_status_mail_rejects_enable' 'NO'
        service_control enable 'daily_status_include_submit_mailq' 'NO'
        service_control enable 'daily_submit_queuerun' 'NO'
    fi

    # Create directory, used to store lookup files.
    [ -d ${POSTFIX_LOOKUP_DIR} ] || mkdir -p ${POSTFIX_LOOKUP_DIR}

    echo 'export status_postfix_config_basic="DONE"' >> ${STATUS_FILE}
}

postfix_config_vhost()
{
    ECHO_DEBUG "Configure Postfix for SQL/LDAP lookup."

    cat ${SAMPLE_DIR}/postfix/main.cf.${POSTFIX_LOOKUP_DB} >> ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_POSTFIX_LOOKUP_DIR#$ENV{POSTFIX_LOOKUP_DIR}#g' ${POSTFIX_FILE_MAIN_CF}

    cp -f ${SAMPLE_DIR}/postfix/${POSTFIX_LOOKUP_DB}/*.cf ${POSTFIX_LOOKUP_DIR}

    chown ${SYS_ROOT_USER}:${POSTFIX_DAEMON_GROUP} ${POSTFIX_LOOKUP_DIR}/*.cf
    chmod 0640 ${POSTFIX_LOOKUP_DIR}/*.cf

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # LDAP server and bind dn/password
        perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_LDAP_BIND_VERSION#$ENV{LDAP_BIND_VERSION}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_LDAP_BINDPW#$ENV{LDAP_BINDPW}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        # SQL server and bind username/password
        perl -pi -e 's#PH_SQL_SERVER_ADDRESS#$ENV{SQL_SERVER_ADDRESS}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_BIND_USER}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_BIND_PASSWD}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
        perl -pi -e 's#PH_VMAIL_DB#$ENV{VMAIL_DB}#g' ${POSTFIX_LOOKUP_DIR}/*.cf
    fi

    echo 'export status_postfix_config_vhost="DONE"' >> ${STATUS_FILE}
}

postfix_config_postscreen()
{
    ECHO_DEBUG "Enable postscreen service."

    bash ${TOOLS_DIR}/enable_postscreen.sh >> ${INSTALL_LOG} 2>&1

    echo 'export status_postfix_config_postscreen="DONE"' >> ${STATUS_FILE}
}

postfix_config()
{
    # Include all sub-steps
    check_status_before_run postfix_config_basic && \
    check_status_before_run postfix_config_vhost && \
    check_status_before_run postfix_config_postscreen

    echo 'export status_postfix_config="DONE"' >> ${STATUS_FILE}
}
