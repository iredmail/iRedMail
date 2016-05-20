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
#
#   AUTO_CLEANUP_REMOVE_SENDMAIL
#   AUTO_CLEANUP_REMOVE_MOD_PYTHON
#   AUTO_CLEANUP_REPLACE_FIREWALL_RULES
#   AUTO_CLEANUP_RESTART_IPTABLES
#   AUTO_CLEANUP_REPLACE_MYSQL_CONFIG
#
# Usage:
#   # AUTO_CLEANUP_REMOVE_SENDMAIL=y [...] bash iRedMail.sh

# -------------------------------------------
# Misc.
# -------------------------------------------
# Set cron file permission to 0600.
cleanup_set_cron_file_permission()
{
    for user in ${SYS_ROOT_USER} ${AMAVISD_SYS_USER} ${SOGO_DAEMON_USER}; do
        cron_file="${CRON_SPOOL_DIR}/${user}"
        if [ -f ${cron_file} ]; then
            ECHO_DEBUG "Set file permission to 0600: ${cron_file}."
            chmod 0600 ${cron_file}
        fi
    done

    echo 'export status_cleanup_set_cron_file_permission="DONE"' >> ${STATUS_FILE}
}

cleanup_disable_selinux()
{
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ECHO_INFO "Disable SELinux in /etc/selinux/config."
        [ -f /etc/selinux/config ] && perl -pi -e 's#^(SELINUX=)(.*)#${1}disabled#' /etc/selinux/config

        setenforce 0 >> ${INSTALL_LOG} 2>&1
    fi

    echo 'export status_cleanup_disable_selinux="DONE"' >> ${STATUS_FILE}
}

cleanup_remove_sendmail()
{
    # Remove sendmail.
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        eval ${LIST_ALL_PKGS} | grep '^sendmail' &>/dev/null

        if [ X"$?" == X"0" ]; then
            ECHO_QUESTION -n "Would you like to *REMOVE* sendmail now? [Y|n]"
            read_setting ${AUTO_CLEANUP_REMOVE_SENDMAIL}
            case ${ANSWER} in
                N|n )
                    ECHO_INFO "Disable sendmail, it is replaced by Postfix." && \
                    service_control disable sendmail
                    ;;
                Y|y|* )
                    eval ${remove_pkg} sendmail
                    ;;
            esac
        fi
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
        case ${ANSWER} in
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
    if [ X"${SSHD_PORT}" != X'22' ]; then
        # Replace port number in iptable, pf and Fail2ban.
        [ X"${USE_FIREWALLD}" == X'YES' ] && \
            perl -pi -e 's#(.*)22(.*)#${1}$ENV{SSHD_PORT}${2}#' ${SAMPLE_DIR}/firewalld/services/ssh.xml

        perl -pi -e 's#(.* )22( .*)#${1}$ENV{SSHD_PORT}${2}#' ${SAMPLE_DIR}/iptables/iptables.rules
        perl -pi -e 's#(.*mail_services=.*)ssh( .*)#${1}$ENV{SSHD_PORT}${2}#' ${SAMPLE_DIR}/openbsd/pf.conf

        [ -f ${FAIL2BAN_JAIL_LOCAL_CONF} ] && \
            perl -pi -e 's#(.*port=.*)ssh(.*)#${1}$ENV{SSHD_PORT}${2}#' ${FAIL2BAN_JAIL_LOCAL_CONF}
    fi

    ECHO_QUESTION "Would you like to use firewall rules provided by iRedMail?"
    ECHO_QUESTION -n "File: ${FIREWALL_RULE_CONF}, with SSHD port: ${SSHD_PORT}. [Y|n]"
    read_setting ${AUTO_CLEANUP_REPLACE_FIREWALL_RULES}
    case ${ANSWER} in
        N|n ) ECHO_INFO "Skip firewall rules." ;;
        Y|y|* ) 
            backup_file ${FIREWALL_RULE_CONF}
            if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
                ECHO_INFO "Copy firewall sample rules: ${FIREWALL_RULE_CONF}."

                if [ X"${USE_FIREWALLD}" == X'YES' ]; then
                    cp -f ${SAMPLE_DIR}/firewalld/zones/iredmail.xml ${FIREWALL_RULE_CONF}
                    perl -pi -e 's#^(DefaultZone=).*#${1}iredmail#g' ${FIREWALLD_CONF}

                    [ X"${SSHD_PORT}" != X'22' ] && \
                        cp -f ${SAMPLE_DIR}/firewalld/services/ssh.xml ${FIREWALLD_CONF_DIR}/services/

                    cp -f ${SAMPLE_DIR}/firewalld/services/{imap,pop3,submission}.xml ${FIREWALLD_CONF_DIR}/services/
                else
                    cp -f ${SAMPLE_DIR}/iptables/iptables.rules ${FIREWALL_RULE_CONF}
                fi

                # Replace HTTP port.
                [ X"${HTTPD_PORT}" != X"80" ]&& \
                    perl -pi -e 's#(.*)80(,.*)#${1}$ENV{HTTPD_PORT}${2}#' ${FIREWALL_RULE_CONF}

                if [ X"${USE_FIREWALLD}" == X'YES' ]; then
                    service_control enable firewalld >> ${INSTALL_LOG} 2>&1
                else
                    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
                        # Copy sample rc script for Debian.
                        cp -f ${SAMPLE_DIR}/iptables/iptables.init.debian ${DIR_RC_SCRIPTS}/iptables
                        chmod +x ${DIR_RC_SCRIPTS}/iptables
                    fi

                    service_control enable iptables >> ${INSTALL_LOG} 2>&1
                fi
            elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
                # Enable pf
                echo 'pf=YES' >> ${RC_CONF_LOCAL}

                # Whitelist file required by spamd(8)
                touch /etc/mail/nospamd

                ECHO_INFO "Copy firewall sample rules: ${FIREWALL_RULE_CONF}."
                cp -f ${SAMPLE_DIR}/openbsd/pf.conf ${FIREWALL_RULE_CONF}
            fi

            # Prompt to restart iptables.
            ECHO_QUESTION -n "Restart firewall now (with SSHD port ${SSHD_PORT})? [y|N]"
            read_setting ${AUTO_CLEANUP_RESTART_IPTABLES}
            case ${ANSWER} in
                Y|y )
                    ECHO_INFO "Restarting firewall ..."

                    if [ X"${DISTRO}" == X'OPENBSD' ]; then
                        /sbin/pfctl -ef ${FIREWALL_RULE_CONF} >> ${INSTALL_LOG} 2>&1
                    else
                        if [ X"${USE_FIREWALLD}" == X'YES' ]; then
                            firewall-cmd --complete-reload >> ${INSTALL_LOG} 2>&1
                        else
                            service_control restart iptables >> ${INSTALL_LOG} 2>&1
                        fi
                    fi
                    ;;
                N|n|* )
                    export "RESTART_IPTABLES='NO'"
                    ;;
            esac
            ;;
    esac

    echo 'export status_cleanup_replace_firewall_rules="DONE"' >> ${STATUS_FILE}
}

cleanup_replace_mysql_config()
{
    if [ X"${DISTRO}" == X'RHEL' ]; then
        if [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'OPENLDAP' ]; then
            # Both MySQL and OpenLDAP backend need MySQL database server, so prompt
            # this config file replacement.
            ECHO_QUESTION "Would you like to use MySQL configuration file shipped within iRedMail now?"
            ECHO_QUESTION -n "File: ${MYSQL_MY_CNF}. [Y|n]"
            read_setting ${AUTO_CLEANUP_REPLACE_MYSQL_CONFIG}
            case ${ANSWER} in
                N|n ) ECHO_INFO "Skip copy and modify MySQL config file." ;;
                Y|y|* )
                    backup_file ${MYSQL_MY_CNF}
                    ECHO_INFO "Copy MySQL sample file: ${MYSQL_MY_CNF}."
                    cp -f ${SAMPLE_DIR}/mysql/my.cnf ${MYSQL_MY_CNF}

                    ECHO_INFO "Enable SSL support for MySQL server."
                    perl -pi -e 's/^#(ssl-cert.*=)(.*)/${1} $ENV{SSL_CERT_FILE}/' ${MYSQL_MY_CNF}
                    perl -pi -e 's/^#(ssl-key.*=)(.*)/${1} $ENV{SSL_KEY_FILE}/' ${MYSQL_MY_CNF}
                    perl -pi -e 's/^#(ssl-cipher.*)/${1}/' ${MYSQL_MY_CNF}
                    ;;
            esac
        fi
    fi

    echo 'export status_cleanup_replace_mysql_config="DONE"' >> ${STATUS_FILE}
}

cleanup_update_compile_spamassassin_rules()
{
    # Required on FreeBSD to start Amavisd-new.
    ECHO_INFO "Updating SpamAssassin rules (sa-update), please wait ..."
    ${BIN_SA_UPDATE} >> ${INSTALL_LOG} 2>&1

    ECHO_INFO "Compiling SpamAssassin rulesets (sa-compile), please wait ..."
    ${BIN_SA_COMPILE} >> ${INSTALL_LOG} 2>&1

    echo 'export status_cleanup_update_compile_spamassassin_rules="DONE"' >> ${STATUS_FILE}
}

cleanup_update_clamav_signatures()
{
    # Update clamav before start clamav-clamd service.
    ECHO_INFO "Updating ClamAV database (freshclam), please wait ..."
    freshclam

    echo 'export status_cleanup_update_clamav_signatures="DONE"' >> ${STATUS_FILE}
}

cleanup_feedback()
{
    # Send names of chosen package to iRedMail project to help developers
    # understand which packages are most important to users.
    url="${BACKEND_ORIG}=YES"
    url="${url}&NGINX=${WEB_SERVER_IS_NGINX}&APACHE=${WEB_SERVER_IS_APACHE}"
    url="${url}&ROUNDCUBE=${USE_RCM}"
    url="${url}&SOGO=${USE_SOGO}"
    url="${url}&AWSTATS=${USE_AWSTATS}"
    url="${url}&FAIL2BAN=${USE_FAIL2BAN}"
    url="${url}&IREDADMIN=${USE_IREDADMIN}"

    ECHO_DEBUG "Send info of chosed packages to iRedMail team to help improve iRedMail:"
    ECHO_DEBUG ""
    ECHO_DEBUG "\t${BACKEND_ORIG}=YES"
    ECHO_DEBUG "\tNGINX=${WEB_SERVER_IS_NGINX}"
    ECHO_DEBUG "\tAPACHE=${WEB_SERVER_IS_APACHE}"
    ECHO_DEBUG "\tROUNDCUBE=${USE_RCM}"
    ECHO_DEBUG "\tSOGO=${USE_SOGO}"
    ECHO_DEBUG "\tAWSTATS=${USE_AWSTATS}"
    ECHO_DEBUG "\tFAIL2BAN=${USE_FAIL2BAN}"
    ECHO_DEBUG "\tIREDADMIN=${USE_IREDADMIN}"
    ECHO_DEBUG ""

    cd /tmp
    ${FETCH_CMD} "${IREDMAIL_MIRROR}/version/check.py/iredmail_pkgs?${url}" &>/dev/null

    echo 'export status_cleanup_feedback="DONE"' >> ${STATUS_FILE}
}

cleanup()
{
    # Store iRedMail version number in /etc/iredmail-release
    cat > /etc/${PROG_NAME_LOWERCASE}-release <<EOF
${PROG_VERSION}     # Get professional upgrade support from iRedMail Team: http://www.iredmail.org/support.html
EOF

    # Remove temporary file used with 'mysql --defaults-file'
    rm -f ${MYSQL_DEFAULTS_FILE_ROOT} &>/dev/null

    cat <<EOF

*************************************************************************
* ${PROG_NAME}-${PROG_VERSION} installation and configuration complete.
*************************************************************************

EOF

    # Mail installation related info to postmaster@
    ECHO_DEBUG "Mail sensitive administration info to ${tip_recipient}."
    tip_recipient="${FIRST_USER}@${FIRST_DOMAIN}"
    FILE_IREDMAIL_INSTALLATION_DETAILS="${FIRST_USER_MAILDIR_INBOX}/details.eml"
    FILE_IREDMAIL_LINKS="${FIRST_USER_MAILDIR_INBOX}/links.eml"

    cat > ${FILE_IREDMAIL_INSTALLATION_DETAILS} <<EOF
From: root@${HOSTNAME}
To: ${tip_recipient}
Subject: Details of this iRedMail installation

EOF

    cat ${TIP_FILE} >> ${FILE_IREDMAIL_INSTALLATION_DETAILS}

    cat > ${FILE_IREDMAIL_LINKS} <<EOF
From: root@${HOSTNAME}
To: ${tip_recipient}
Subject: Useful resources for iRedMail administrator

EOF
    cat ${DOC_FILE} >> ${FILE_IREDMAIL_LINKS}

    chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${FILE_IREDMAIL_INSTALLATION_DETAILS} ${FILE_IREDMAIL_LINKS}
    chmod -R 0700 ${FILE_IREDMAIL_INSTALLATION_DETAILS} ${FILE_IREDMAIL_LINKS}

    check_status_before_run cleanup_set_cron_file_permission
    check_status_before_run cleanup_disable_selinux
    check_status_before_run cleanup_remove_sendmail
    check_status_before_run cleanup_remove_mod_python

    [ X"${KERNEL_NAME}" == X'LINUX' -o X"${KERNEL_NAME}" == X'OPENBSD' ] && \
        check_status_before_run cleanup_replace_firewall_rules

    check_status_before_run cleanup_replace_mysql_config

    if [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
        check_status_before_run cleanup_update_compile_spamassassin_rules
    fi

    check_status_before_run cleanup_update_clamav_signatures
    check_status_before_run cleanup_feedback

    cat <<EOF
********************************************************************
* URLs of installed web applications:
*
EOF

    if [ X"${USE_RCM}" == X'YES' ]; then
cat <<EOF
* - Roundcube webmail: httpS://${HOSTNAME}/mail/
EOF
    fi

    if [ X"${USE_SOGO}" == X'YES' ]; then
cat <<EOF
* - SOGo groupware: httpS://${HOSTNAME}/SOGo/
EOF
    fi

    cat <<EOF
*
* - Web admin panel (iRedAdmin): httpS://${HOSTNAME}/iredadmin/
*
* You can login to above links with below credential:
*
* - Username: ${SITE_ADMIN_NAME}
* - Password: ${SITE_ADMIN_PASSWD}
*
*
********************************************************************
* Congratulations, mail server setup completed successfully. Please
* read below file for more information:
*
*   - ${TIP_FILE}
*
* And it's sent to your mail account ${tip_recipient}.
*
********************* WARNING **************************************
*
* Please reboot your system to enable all mail services.
*
********************************************************************
EOF

    echo 'export status_cleanup="DONE"' >> ${STATUS_FILE}
}
