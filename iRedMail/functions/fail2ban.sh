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
# ---------------------- Fail2ban -----------------------
# -------------------------------------------------------


fail2ban_config()
{
    ECHO_INFO "Configure Fail2ban (authentication failure monitor)."

    ECHO_DEBUG "Log into syslog instead of log file."
    perl -pi -e 's#^(logtarget).*#${1} = $ENV{FAIL2BAN_LOGTARGET}#' ${FAIL2BAN_MAIN_CONF}

    ECHO_DEBUG "Disable all default filters in ${FAIL2BAN_JAIL_CONF}."
    perl -pi -e 's#^(enabled).*=.*#${1} = false#' ${FAIL2BAN_JAIL_CONF}

    ECHO_DEBUG "Enable mail server related components."
    cat > ${FAIL2BAN_JAIL_LOCAL_CONF} <<EOF
${CONF_MSG}

# Please refer to ${FAIL2BAN_JAIL_CONF} for more examples.

[ssh-iredmail]
enabled     = true
filter      = sshd
action      = iptables[name=ssh, port="ssh", protocol=tcp]
#               sendmail-whois[name=ssh, dest=root, sender=fail2ban@mail.com]
logpath     = ${FAIL2BAN_SSHD_LOGFILE}
maxretry    = 5
ignoreip    = ${LOCAL_ADDRESS} 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

[roundcube-iredmail]
enabled     = true
filter      = ${FAIL2BAN_FILTER_ROUNDCUBE}
action      = iptables-multiport[name=roundcube, port="${FAIL2BAN_DISABLED_SERVICES}", protocol=tcp]
logpath     = ${RCM_LOGFILE}
findtime    = 3600
maxretry    = 5
bantime     = 3600
ignoreip    = ${LOCAL_ADDRESS} 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

[dovecot-iredmail]
enabled     = true
filter      = ${FAIL2BAN_FILTER_DOVECOT}
action      = iptables-multiport[name=dovecot, port="${FAIL2BAN_DISABLED_SERVICES}", protocol=tcp]
logpath     = ${DOVECOT_LOG_FILE}
maxretry    = 5
findtime    = 300
bantime     = 3600
ignoreip    = ${LOCAL_ADDRESS} 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

[postfix-iredmail]
enabled     = true
filter      = ${FAIL2BAN_FILTER_POSTFIX}
action      = iptables-multiport[name=postfix, port="${FAIL2BAN_DISABLED_SERVICES}", protocol=tcp]
#           sendmail[name=Postfix, dest=you@mail.com]
logpath     = ${MAILLOG}
bantime     = 3600
maxretry    = 5
ignoreip    = ${LOCAL_ADDRESS} 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
EOF

    ECHO_DEBUG "Create filter: ${FAIL2BAN_FILTER_DIR}/${FAIL2BAN_FILTER_ROUNDCUBE}.conf."
    cat > ${FAIL2BAN_FILTER_DIR}/${FAIL2BAN_FILTER_ROUNDCUBE}.conf <<EOF
[Definition]
failregex = roundcube: (.*) Error: Login failed for (.*) from <HOST>\.
ignoreregex =
EOF

    ECHO_DEBUG "Create filter: ${FAIL2BAN_FILTER_DIR}/${FAIL2BAN_FILTER_DOVECOT}.conf."
    cat > ${FAIL2BAN_FILTER_DIR}/${FAIL2BAN_FILTER_DOVECOT}.conf <<EOF
[Definition]
failregex = (?: pop3-login|imap-login): .*(?:Authentication failure|Aborted login \(auth failed|Aborted login \(tried to use disabled|Disconnected \(auth failed).*rip=(?P<host>\S*),.*
ignoreregex =
EOF

    ECHO_DEBUG "Create filter: ${FAIL2BAN_FILTER_DIR}/${FAIL2BAN_FILTER_POSTFIX}.conf."
    cat > ${FAIL2BAN_FILTER_DIR}/${FAIL2BAN_FILTER_POSTFIX}.conf <<EOF
[Definition]
failregex = \[<HOST>\]: SASL (PLAIN|LOGIN) authentication failed
            reject: RCPT from (.*)\[<HOST>\]: 550 5.1.1
            reject: RCPT from (.*)\[<HOST>\]: 450 4.7.1
            reject: RCPT from (.*)\[<HOST>\]: 554 5.7.1
ignoreregex =
EOF

    # FreeBSD: Start fail2ban when system start up.
    freebsd_enable_service_in_rc_conf 'fail2ban_enable' 'YES'

    echo 'export status_fail2ban_config="DONE"' >> ${STATUS_FILE}
}
