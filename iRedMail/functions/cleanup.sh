#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb(at)iredmail.org)

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
        read ANSWER
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
        read ANSWER
        case $ANSWER in
            N|n ) : ;;
            Y|y|* ) eval ${remove_pkg} mod_python ;;
        esac
    else
        :
    fi

    echo 'export status_cleanup_remove_mod_python="DONE"' >> ${STATUS_FILE}
}

cleanup_replace_iptables_rule()
{
    # Get SSH listen port, replace default port number in iptable rule file.
    export sshd_port="$(grep '^Port' ${SSHD_CONFIG} | awk '{print $2}' )"
    if [ X"${sshd_port}" == X"" -o X"${sshd_port}" == X"22" ]; then
        # No port number defined, use default (22).
        export sshd_port='22'
    else
        # Replace port number in iptable and Fail2ban.
        perl -pi -e 's#(.*multiport.*,)22 (.*)#${1}$ENV{sshd_port} ${2}#' ${SAMPLE_DIR}/iptables.rules
        [ -f ${FAIL2BAN_JAIL_LOCAL_CONF} ] && \
            perl -pi -e 's#(.*port=.*)ssh(.*)#${1}$ENV{sshd_port}${2}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    fi

    ECHO_QUESTION "Would you like to use firewall rules shipped within iRedMail now?"
    ECHO_QUESTION -n "File: ${IPTABLES_CONFIG}, with SSHD port: ${sshd_port}. [Y|n]"
    read ANSWER
    case $ANSWER in
        N|n ) ECHO_INFO "Skip firewall rules." ;;
        Y|y|* ) 
            if [ X"${DISTRO}" != X"SUSE" ]; then
                ECHO_INFO "Copy firewall sample rules: ${IPTABLES_CONFIG}."
                backup_file ${IPTABLES_CONFIG}
                cp -f ${SAMPLE_DIR}/iptables.rules ${IPTABLES_CONFIG}

                # Replace HTTP port.
                [ X"${HTTPD_PORT}" != X"80" ]&& \
                    perl -pi -e 's#(.*)80(,.*)#${1}$ENV{HTTPD_PORT}${2}#' ${IPTABLES_CONFIG}
            fi

            if [ X"${DISTRO}" == X"SUSE" ]; then
                # Below services are not accessable from external network:
                #   - ldaps (636)
                perl -pi -e 's/^(FW_SERVICES_EXT_TCP=)(.*)/${1}"$ENV{'HTTPD_PORT'} 443 25 110 995 143 993 587 465 $ENV{'sshd_port'}"\n#${2}/' ${IPTABLES_CONFIG}

            elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
                # Copy sample rc script for Debian.
                cp -f ${SAMPLE_DIR}/iptables.init.debian ${DIR_RC_SCRIPTS}/iptables
                chmod +x ${DIR_RC_SCRIPTS}/iptables

                eval ${enable_service} iptables >/dev/null

            else
                eval ${enable_service} iptables >/dev/null
            fi

            # Prompt to restart iptables.
            ECHO_QUESTION -n "Restart firewall now (with SSHD port ${sshd_port})? [y|N]"
            read ANSWER
            case $ANSWER in
                Y|y )
                    ECHO_INFO "Restarting firewall ..."

                    # OpenSuSE will use /etc/init.d/{SuSEfirewall2_init, SuSEfirewall2_setup} instead.
                    if [ X"${DISTRO}" != X"SUSE" ]; then
                        ${DIR_RC_SCRIPTS}/iptables restart
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

    echo 'export status_cleanup_replace_iptables_rule="DONE"' >> ${STATUS_FILE}
}

cleanup_replace_mysql_config()
{
    if [ X"${BACKEND}" == X"MYSQL" -o X"${BACKEND}" == X"OPENLDAP" ]; then
        # Both MySQL and OpenLDAP will need MySQL database server, so prompt
        # this config file replacement.
        ECHO_QUESTION "Would you like to use MySQL configuration file shipped within iRedMail now?"
        ECHO_QUESTION -n "File: ${MYSQL_MY_CNF}. [Y|n]"
        read ANSWER
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

cleanup_start_postfix_now()
{
    # Start postfix without reboot your system.
    ECHO_QUESTION -n "Would you like to start postfix now? [y|N]"
    read ANSWER
    case ${ANSWER} in
        Y|y )
            # Disable SELinux.
            SETENFORCE="$(which setenforce 2>/dev/null)"
            if [ ! -z ${SETENFORCE} ]; then
                ECHO_INFO "Temporarily set SELinux policy to 'permissive'."
                ${SETENFORCE} 0
            else
                :
            fi

            # FreeBSD
            if [ X"${DISTRO}" == X"FREEBSD" ]; then
                # Load kernel module 'accf_http' before start.
                kldload accf_http

                # Stop sendmail.
                killall sendmail
            fi

            # Start/Restart necessary services.
            for i in ${ENABLED_SERVICES}
            do
                service_control ${i} restart
            done
            export POSTFIX_STARTED='YES'
            ;;
        N|n|* )
            :
            ;;
    esac

    echo 'export status_cleanup_start_postfix_now="DONE"' >> ${STATUS_FILE}
}

cleanup_amavisd_preconfig()
{
    # Required on Gentoo and FreeBSD to start Amavisd-new.
    ECHO_INFO "Fetching SpamAssassin rules (sa-update), please wait ..."
    ${BIN_SA_UPDATE} &>/dev/null

    ECHO_INFO "Compiling SpamAssassin rulesets (sa-compile), please wait ..."
    ${BIN_SA_COMPILE} &>/dev/null

    # Update clamav before start clamav-clamd service.
    ECHO_INFO "Updating ClamAV database (freshclam), please wait ..."
    freshclam

    echo 'export status_cleanup_amavisd_preconfig="DONE"' >> ${STATUS_FILE}
}

cleanup_backup_scripts()
{
    ECHO_DEBUG "Updating backup script: ${TOOLS_DIR}/backup_mysql.sh."
    perl -pi -e 's#^(MYSQL_USER=).*#${1}"ENV{MYSQL_ROOT_USER}"#' ${TOOLS_DIR}/backup_mysql.sh
    perl -pi -e 's#^(MYSQL_PASSWD=).*#${1}"ENV{MYSQL_ROOT_PASSWD}"#' ${TOOLS_DIR}/backup_mysql.sh
    perl -pi -e 's#^(DATABASES=).*#${1}"ENV{MYSQL_BACKUP_DATABASES}"#' ${TOOLS_DIR}/backup_mysql.sh

    echo 'export status_cleanup_backup_scripts="DONE"' >> ${STATUS_FILE}
}

cleanup()
{
    cat > /etc/${PROG_NAME_LOWERCASE}-release <<EOF
${PROG_VERSION}
EOF

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

    [ X"${DISTRO}" == X"RHEL" ] && check_status_before_run cleanup_disable_selinux
    check_status_before_run cleanup_remove_sendmail
    check_status_before_run cleanup_remove_mod_python
    [ X"${KERNEL_NAME}" == X"Linux" ] && check_status_before_run cleanup_replace_iptables_rule
    [ X"${DISTRO}" == X"RHEL" ] && check_status_before_run cleanup_replace_mysql_config
    [ X"${DISTRO}" != X'GENTOO' ] && check_status_before_run cleanup_start_postfix_now
    [ X"${DISTRO}" == X"FREEBSD" -o X"${DISTRO}" == X'GENTOO' ] && check_status_before_run cleanup_amavisd_preconfig
    check_status_before_run cleanup_backup_scripts

    # Send tip file to the mail server admin and/or first mail user.
    tip_recipient="${FIRST_USER}@${FIRST_DOMAIN}"
    [ ! -z "${MAIL_ALIAS_ROOT}" -a X"${MAIL_ALIAS_ROOT}" != X"${tip_recipient}" ] && \
        tip_recipient="${tip_recipient},${MAIL_ALIAS_ROOT}"

    cat > /tmp/.tips.eml <<EOF
From: root@${HOSTNAME}
To: ${tip_recipient}
Subject: iRedMail tips for mail server administrator

EOF

    cat ${TIP_FILE} >> /tmp/.tips.eml
    sendmail -t ${tip_recipient} < /tmp/.tips.eml &>/dev/null && rm -f /tmp/.tips.eml &>/dev/null

    cat > /tmp/.links.eml <<EOF
From: root@${HOSTNAME}
To: ${tip_recipient}
Subject: Useful resources for iRedMail administrator

EOF
    cat ${DOC_FILE} >> /tmp/.links.eml
    sendmail -t ${tip_recipient} < /tmp/.links.eml &>/dev/null && rm -f /tmp/.links.eml &>/dev/null

    cat <<EOF
********************************************************************
* URLs of your web applications:
*
EOF

    # Print URL of web applications.
    # Webmail.
    if [ X"${USE_WEBMAIL}" == X"YES" ]; then
        cat <<EOF
* - Webmail: http://${HOSTNAME}/mail/ or httpS://${HOSTNAME}/mail/
*   + Account: ${FIRST_USER}@${FIRST_DOMAIN}, Password: ${FIRST_USER_PASSWD_PLAIN}
*
EOF
    fi

    # iRedAdmin.
    if [ X"${USE_IREDADMIN}" == X"YES" ]; then
        cat <<EOF
* - Admin Panel (iRedAdmin): httpS://${HOSTNAME}/iredadmin/
*   + Account: ${SITE_ADMIN_NAME}, Password: ${SITE_ADMIN_PASSWD}
*
EOF
    fi

    cat <<EOF

********************************************************************
* Congratulations, mail server setup complete. Please refer to tip
* file for more information:
*
*   - ${TIP_FILE}
*
* And it's sent to your mail account ${tip_recipient}.
*
EOF

if [ X"${POSTFIX_STARTED}" != X"YES" \
    -a X"${DISTRO}" != X'FREEBSD' \
    -a X"${DISTRO}" != X'GENTOO' \
    ]; then
    cat <<EOF
* Please reboot your system to enable mail related services or start them
* manually without reboot:
*
EOF

    # Prompt to disable selinux.
    if [ ! -z ${SETENFORCE} ]; then
        cat <<EOF
*   # ${SETENFORCE} 0
EOF
    fi

    cat <<EOF
*   # for i in ${ENABLED_SERVICES}; do ${DIR_RC_SCRIPTS}/\${i} restart; done
*
EOF
fi

    if [ X"${DISTRO}" == X'FREEBSD' \
        -o X"${DISTRO}" == X'GENTOO' \
        ]; then
        # Reboot system to enable mail related services.
        # - FreeBSD: sendmail is binding to port '25'
        # - Gentoo: some services may require system reboot
        cat <<EOF
* Please reboot your system to enable mail related services.
*
EOF
fi

    cat <<EOF
********************************************************************

EOF

    echo 'export status_cleanup="DONE"' >> ${STATUS_FILE}
}
