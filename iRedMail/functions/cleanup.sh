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

# Available variables for automate installation (value should be 'y' or 'n'):
#   AUTO_CLEANUP_REMOVE_SENDMAIL
#   AUTO_CLEANUP_REMOVE_MOD_PYTHON
#   AUTO_CLEANUP_REPLACE_FIREWALL_RULES
#   AUTO_CLEANUP_RESTART_IPTABLES
#   AUTO_CLEANUP_REPLACE_MYSQL_CONFIG
#   AUTO_CLEANUP_RESTART_POSTFIX
#
# Usage:
#   # AUTO_CLEANUP_REMOVE_SENDMAIL=y [...] bash iRedMail.sh

# -------------------------------------------
# Misc.
# -------------------------------------------
cleanup_disable_selinux()
{
    ECHO_INFO "Disable SELinux in /etc/selinux/config."
    [ -f /etc/selinux/config ] && perl -pi -e 's#^(SELINUX=)(.*)#${1}disabled#' /etc/selinux/config

    setenforce 0 >/dev/null 2>&1

    echo 'export status_cleanup_disable_selinux="DONE"' >> ${STATUS_FILE}
}

cleanup_remove_sendmail()
{
    # Remove sendmail.
    eval ${LIST_ALL_PKGS} | grep 'sendmail' &>/dev/null

    if [ X"$?" == X"0" ]; then
        ECHO_QUESTION -n "Would you like to *REMOVE* sendmail now? [Y|n]"
        read_setting ${AUTO_CLEANUP_REMOVE_SENDMAIL}
        case $ANSWER in
            N|n )
                ECHO_INFO "Disable sendmail, it is replaced by Postfix." && \
                eval ${disable_service} sendmail && \
                export HAS_SENDMAIL='YES'
                ;;
            Y|y|* )
                eval ${remove_pkg} sendmail && \
                export HAS_SENDMAIL='NO'
                ;;
        esac
    else
        :
    fi

    echo 'export status_cleanup_remove_sendmail="DONE"' >> ${STATUS_FILE}
}

cleanup_remove_mod_python()
{
    # Remove mod_python.
    eval ${LIST_ALL_PKGS} | grep 'mod_python' &>/dev/null

    if [ X"$?" == X"0" ]; then
        ECHO_QUESTION -n "iRedAdmin doesn't work with mod_python, *REMOVE* it now? [Y|n]"
        read_setting ${AUTO_CLEANUP_REMOVE_MOD_PYTHON}
        case $ANSWER in
            N|n ) : ;;
            Y|y|* ) eval ${remove_pkg} mod_python ;;
        esac
    else
        :
    fi

    echo 'export status_cleanup_remove_mod_python="DONE"' >> ${STATUS_FILE}
}

cleanup_replace_firewall_rules()
{
    # Get SSH listen port, replace default port number in iptable rule file.
    export sshd_port="$(grep '^Port' ${SSHD_CONFIG} | awk '{print $2}' )"
    if [ X"${sshd_port}" == X"" -o X"${sshd_port}" == X"22" ]; then
        # No port number defined, use default (22).
        export sshd_port='22'
    else
        # Replace port number in iptable, pf and Fail2ban.
        perl -pi -e 's#(.* )22( .*)#${1}$ENV{sshd_port}${2}#' ${SAMPLE_DIR}/iptables.rules
        perl -pi -e 's#(.*mail_services=.*)ssh( .*)#${1}$ENV{sshd_port}${2}#' ${SAMPLE_DIR}/pf.conf

        [ -f ${FAIL2BAN_JAIL_LOCAL_CONF} ] && \
            perl -pi -e 's#(.*port=.*)ssh(.*)#${1}$ENV{sshd_port}${2}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    fi

    ECHO_QUESTION "Would you like to use firewall rules provided by iRedMail now?"
    ECHO_QUESTION -n "File: ${FIREWALL_RULE_CONF}, with SSHD port: ${sshd_port}. [Y|n]"
    read_setting ${AUTO_CLEANUP_REPLACE_FIREWALL_RULES}
    case $ANSWER in
        N|n ) ECHO_INFO "Skip firewall rules." ;;
        Y|y|* ) 
            backup_file ${FIREWALL_RULE_CONF}
            if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
                if [ X"${DISTRO}" != X"SUSE" ]; then
                    ECHO_INFO "Copy firewall sample rules: ${FIREWALL_RULE_CONF}."
                    cp -f ${SAMPLE_DIR}/iptables.rules ${FIREWALL_RULE_CONF}

                    # Replace HTTP port.
                    [ X"${HTTPD_PORT}" != X"80" ]&& \
                        perl -pi -e 's#(.*)80(,.*)#${1}$ENV{HTTPD_PORT}${2}#' ${FIREWALL_RULE_CONF}
                fi

                if [ X"${DISTRO}" == X"SUSE" ]; then
                    # Below services are not accessable from external network:
                    #   - ldaps (636)
                    perl -pi -e 's/^(FW_SERVICES_EXT_TCP=)(.*)/${1}"$ENV{HTTPD_PORT} 443 25 110 995 143 993 587 465 $ENV{sshd_port}"\n#${2}/' ${FIREWALL_RULE_CONF}

                elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
                    # Copy sample rc script for Debian.
                    cp -f ${SAMPLE_DIR}/iptables.init.debian ${DIR_RC_SCRIPTS}/iptables
                    chmod +x ${DIR_RC_SCRIPTS}/iptables

                    eval ${enable_service} iptables >/dev/null

                else
                    eval ${enable_service} iptables >/dev/null
                fi
            elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
                ECHO_INFO "Copy firewall sample rules: ${FIREWALL_RULE_CONF}."
                cp -f ${SAMPLE_DIR}/pf.conf ${FIREWALL_RULE_CONF}
            fi

            # Prompt to restart iptables.
            ECHO_QUESTION -n "Restart firewall now (with SSHD port ${sshd_port})? [y|N]"
            read_setting ${AUTO_CLEANUP_RESTART_IPTABLES}
            case $ANSWER in
                Y|y )
                    ECHO_INFO "Restarting firewall ..."

                    if [ X"${DISTRO}" == X'OPENBSD' ]; then
                        /sbin/pfctl -ef ${FIREWALL_RULE_CONF}
                    else
                        # openSUSE will use /etc/init.d/SuSEfirewall2_{init,setup} instead.
                        if [ X"${DISTRO}" != X"SUSE" ]; then
                            ${DIR_RC_SCRIPTS}/iptables restart &>/dev/null
                        fi
                    fi
                    ;;
                N|n|* )
                    export "RESTART_IPTABLES='NO'"
                    ;;
            esac
            ;;
    esac

    if [ X"${DISTRO}" != X"SUSE" ]; then
        # Restarting iptables before restarting fail2ban.
        ENABLED_SERVICES="iptables ${ENABLED_SERVICES}"
    fi

    echo 'export status_cleanup_replace_firewall_rules="DONE"' >> ${STATUS_FILE}
}

cleanup_replace_mysql_config()
{
    if [ X"${BACKEND}" == X"MYSQL" -o X"${BACKEND}" == X"OPENLDAP" ]; then
        # Both MySQL and OpenLDAP backend need MySQL database server, so prompt
        # this config file replacement.
        ECHO_QUESTION "Would you like to use MySQL configuration file shipped within iRedMail now?"
        ECHO_QUESTION -n "File: ${MYSQL_MY_CNF}. [Y|n]"
        read_setting ${AUTO_CLEANUP_REPLACE_MYSQL_CONFIG}
        case $ANSWER in
            N|n ) ECHO_INFO "Skip copy and modify MySQL config file." ;;
            Y|y|* )
                backup_file ${MYSQL_MY_CNF}
                ECHO_INFO "Copy MySQL sample file: ${MYSQL_MY_CNF}."
                cp -f ${SAMPLE_DIR}/my.cnf ${MYSQL_MY_CNF}

                ECHO_INFO "Enable SSL support for MySQL server."
                perl -pi -e 's/^#(ssl-cert.*=)(.*)/${1} $ENV{'SSL_CERT_FILE'}/' ${MYSQL_MY_CNF}
                perl -pi -e 's/^#(ssl-key.*=)(.*)/${1} $ENV{'SSL_KEY_FILE'}/' ${MYSQL_MY_CNF}
                perl -pi -e 's/^#(ssl-cipher.*)/${1}/' ${MYSQL_MY_CNF}
                ;;
        esac
    else
        :
    fi

    echo 'export status_cleanup_replace_mysql_config="DONE"' >> ${STATUS_FILE}
}

cleanup_update_compile_spamassassin_rules()
{
    # Required on FreeBSD to start Amavisd-new.
    ECHO_INFO "Updating SpamAssassin rules (sa-update), please wait ..."
    ${BIN_SA_UPDATE} &>/dev/null

    ECHO_INFO "Compiling SpamAssassin rulesets (sa-compile), please wait ..."
    ${BIN_SA_COMPILE} &>/dev/null

    echo 'export status_cleanup_update_compile_spamassassin_rules="DONE"' >> ${STATUS_FILE}
}

cleanup_update_clamav_signatures()
{
    # Update clamav before start clamav-clamd service.
    ECHO_INFO "Updating ClamAV database (freshclam), please wait ..."
    freshclam

    echo 'export status_cleanup_update_clamav_signatures="DONE"' >> ${STATUS_FILE}
}

cleanup_backup_scripts()
{
    [ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} &>/dev/null

    # Backup OpenLDAP data
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ECHO_DEBUG "Setup backup script: ${BACKUP_SCRIPT_OPENLDAP}"

        backup_file ${BACKUP_SCRIPT_OPENLDAP}
        cp ${TOOLS_DIR}/backup_openldap.sh ${BACKUP_SCRIPT_OPENLDAP}
        chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${BACKUP_SCRIPT_OPENLDAP}
        chmod 0700 ${BACKUP_SCRIPT_OPENLDAP}

        perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${BACKUP_SCRIPT_OPENLDAP}

        # Add cron job
        cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Backup OpenLDAP data on 03:00 AM
0   3   *   *   *   ${SHELL_BASH} ${BACKUP_SCRIPT_OPENLDAP}
EOF

        cat >> ${TIP_FILE} <<EOF
Backup OpenLDAP data:
    * Script: ${BACKUP_SCRIPT_OPENLDAP}
    * See also:
        # crontab -l -u ${SYS_ROOT_USER}

EOF
    fi

    # Backup MySQL databases
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ECHO_DEBUG "Setup backup script: ${BACKUP_SCRIPT_MYSQL}"

        backup_file ${BACKUP_SCRIPT_MYSQL}
        cp ${TOOLS_DIR}/backup_mysql.sh ${BACKUP_SCRIPT_MYSQL}
        chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${BACKUP_SCRIPT_MYSQL}
        chmod 0700 ${BACKUP_SCRIPT_MYSQL}

        export MYSQL_ROOT_PASSWD MYSQL_BACKUP_DATABASES
        perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${BACKUP_SCRIPT_MYSQL}
        perl -pi -e 's#^(export MYSQL_USER=).*#${1}"$ENV{MYSQL_ROOT_USER}"#' ${BACKUP_SCRIPT_MYSQL}
        perl -pi -e 's#^(export MYSQL_PASSWD=).*#${1}"$ENV{MYSQL_ROOT_PASSWD}"#' ${BACKUP_SCRIPT_MYSQL}
        perl -pi -e 's#^(export DATABASES=).*#${1}"$ENV{MYSQL_BACKUP_DATABASES}"#' ${BACKUP_SCRIPT_MYSQL}

        # Add cron job
        cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Backup MySQL databases on 03:30 AM
30   3   *   *   *   ${SHELL_BASH} ${BACKUP_SCRIPT_MYSQL}
EOF

        cat >> ${TIP_FILE} <<EOF
Backup MySQL database:
    * Script: ${BACKUP_SCRIPT_MYSQL}
    * See also:
        # crontab -l -u ${SYS_ROOT_USER}
EOF
    fi

    # Backup PostgreSQL databases
    if [ X"${BACKEND}" == X'PGSQL' ]; then
        ECHO_DEBUG "Setup backup script: ${BACKUP_SCRIPT_PGSQL}"

        backup_file ${BACKUP_SCRIPT_PGSQL}
        cp ${TOOLS_DIR}/backup_pgsql.sh ${BACKUP_SCRIPT_PGSQL}
        chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${BACKUP_SCRIPT_PGSQL}
        chmod 0700 ${BACKUP_SCRIPT_PGSQL}

        perl -pi -e 's#^(export PGSQL_SYS_USER=).*#${1}"$ENV{PGSQL_SYS_USER}"#' ${BACKUP_SCRIPT_PGSQL}
        perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${BACKUP_SCRIPT_PGSQL}
        perl -pi -e 's#^(export DATABASES=).*#${1}"$ENV{PGSQL_BACKUP_DATABASES}"#' ${BACKUP_SCRIPT_PGSQL}

        # Add cron job
        cat >> ${CRON_SPOOL_DIR}/root <<EOF
# Backup on 03:01 AM
1   3   *   *   *   ${SHELL_BASH} ${BACKUP_SCRIPT_PGSQL}
EOF
    fi

    echo 'export status_cleanup_backup_scripts="DONE"' >> ${STATUS_FILE}
}

cleanup_pgsql_force_password()
{
    ECHO_DEBUG "Force all users to connect PGSQL server with password."

    if [ X"${DISTRO}" == X'RHEL' ]; then
        perl -pi -e 's#^(local.*)ident#${1}md5#' ${PGSQL_CONF_PG_HBA}
        perl -pi -e 's#^(host.*)ident#${1}md5#' ${PGSQL_CONF_PG_HBA}
    elif [ X"${DISTRO}" == X'UBUNTU' ]; then
        perl -pi -e 's#^(local.*)peer#${1}md5#' ${PGSQL_CONF_PG_HBA}
    elif [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
        # FreeBSD
        perl -pi -e 's#^(local.*)trust#${1}md5#' ${PGSQL_CONF_PG_HBA}
        perl -pi -e 's#^(host.*)trust#${1}md5#' ${PGSQL_CONF_PG_HBA}
    fi
}

cleanup()
{
    cat > /etc/${PROG_NAME_LOWERCASE}-release <<EOF
${PROG_VERSION}
EOF

    rm -f ${MYSQL_DEFAULTS_FILE_ROOT} &>/dev/null

    cat <<EOF

*************************************************************************
* ${PROG_NAME}-${PROG_VERSION} installation and configuration complete.
*************************************************************************

EOF

    ECHO_DEBUG "Decrease sshd service start order via chkconfig."
    if [ X"${DISTRO}" == X"RHEL" ]; then
        # Unclearly power off might cause damage to OpenLDAP database, it will
        # hangs while system startup. Decrease sshd start order to make sure you
        # can always log into server for maintaince.
        #
        # 10 -> network, 12 -> syslog, rsyslog.
        disable_service_rh sshd
        perl -pi -e 's#(.*chkconfig.*)55(.*)#${1}13${2}#' ${DIR_RC_SCRIPTS}/sshd
        enable_service_rh sshd
    fi

    # Start Dovecot to deliver emails.
    ECHO_INFO "Mail sensitive administration info to ${FIRST_USER}@${FIRST_DOMAIN}."
    [ X"${BACKEND}" == X'OPENLDAP' ] && ${DIR_RC_SCRIPTS}/${OPENLDAP_RC_SCRIPT_NAME} restart &>/dev/null
    [ X"${BACKEND}" == X'MYSQL' ] && ${DIR_RC_SCRIPTS}/${MYSQL_RC_SCRIPT_NAME} restart &>/dev/null
    [ X"${BACKEND}" == X'PGSQL' ] && ${DIR_RC_SCRIPTS}/${PGSQL_RC_SCRIPT_NAME} restart &>/dev/null
    ${DIR_RC_SCRIPTS}/${DOVECOT_RC_SCRIPT_NAME} restart &>/dev/null
    sleep 3

    # Send tip file to the mail server admin and/or first mail user.
    tip_recipient="${FIRST_USER}@${FIRST_DOMAIN}"

    cat > /tmp/.tips.eml <<EOF
From: root@${HOSTNAME}
To: ${tip_recipient}
Subject: Details of this iRedMail installation

EOF

    cat ${TIP_FILE} >> /tmp/.tips.eml
    ${DOVECOT_DELIVER} -c ${DOVECOT_CONF} -f root@${HOSTNAME} -d ${tip_recipient} < /tmp/.tips.eml
    rm -f /tmp/.tips.eml &>/dev/null

    cat > /tmp/.links.eml <<EOF
From: root@${HOSTNAME}
To: ${tip_recipient}
Subject: Useful resources for iRedMail administrator

EOF
    cat ${DOC_FILE} >> /tmp/.links.eml
    ${DOVECOT_DELIVER} -c ${DOVECOT_CONF} -f root@${HOSTNAME} -d ${tip_recipient} < /tmp/.links.eml
    rm -f /tmp/.links.eml &>/dev/null

    [ X"${DISTRO}" == X"RHEL" ] && check_status_before_run cleanup_disable_selinux
    [ X"${DISTRO}" != X'OPENBSD' ] && check_status_before_run cleanup_remove_sendmail
    check_status_before_run cleanup_remove_mod_python
    [ X"${KERNEL_NAME}" == X'LINUX' \
        -o X"${KERNEL_NAME}" == X'OPENBSD' \
        ] && check_status_before_run cleanup_replace_firewall_rules
    [ X"${DISTRO}" == X"RHEL" ] && check_status_before_run cleanup_replace_mysql_config
    check_status_before_run cleanup_backup_scripts
    [ X"${BACKEND}" == X'PGSQL' ] && check_status_before_run cleanup_pgsql_force_password

    if [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
        check_status_before_run cleanup_update_compile_spamassassin_rules
    fi

    check_status_before_run cleanup_update_clamav_signatures

    cat <<EOF
********************************************************************
* URLs of installed web applications:
*
EOF

    # Print URL of web applications.
    # Webmail.
    if [ X"${USE_WEBMAIL}" == X"YES" ]; then
        cat <<EOF
* - Webmail: httpS://${HOSTNAME}/mail/
EOF
    fi

    # iRedAdmin.
    if [ X"${USE_IREDADMIN}" == X"YES" ]; then
        cat <<EOF
* - Admin Panel (iRedAdmin): httpS://${HOSTNAME}/iredadmin/
EOF
    fi

    cat <<EOF
*   + Username: ${SITE_ADMIN_NAME}, Password: ${SITE_ADMIN_PASSWD}
*
EOF

    # Reboot system to enable mail related services.
    # - FreeBSD: sendmail is binding to port '25'
    cat <<EOF

********************************************************************
* Congratulations, mail server setup completed successfully. Please
* read below file for more information:
*
*   - ${TIP_FILE}
*
* And it's sent to your mail account ${tip_recipient}.
*
* Please reboot your system to enable mail services.
*
********************************************************************
EOF

    echo 'export status_cleanup="DONE"' >> ${STATUS_FILE}
}
