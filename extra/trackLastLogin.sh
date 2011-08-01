#!/bin/sh

# =========================================================
# Author:   Zhang Huangbin (michaelbibby@gmail.com)
# Date:     2009.07.28
# Purpose:  Track user last login date & ip address with Dovecot.
# Project:  iRedMail open source mail server solution.
#           http://www.iredmail.org/
# =========================================================

# $USER -> login username. It should be a valid email address.
# $IP   -> remote ip address (IPv4).
# ${1}  -> mail protocol: imap, pop3

# ------------------------------------------------------------------
# Update to plain text file..
# Note: user 'dovecot' should have write permission on this file.
# ------------------------------------------------------------------
#echo "$(date +%Y.%m.%d-%H:%M:%S), $USER, $IP, ${1}" >> /tmp/tracking.log 2>&1

# ------------------------------------------------------------------
# Update to MySQL database.
# Note: ${MYSQL_USER} must have SELECT and UPDATE privileges.
# ------------------------------------------------------------------
#MYSQL_USER='vmailadmin'
#PASSWD='plain_passwd'
#VMAIL_DB_NAME='vmail'
#
#if [ X"${USER}" != X"dump-capability" ]; then
#   mysql -u${MYSQL_USER} -p${PASSWD} ${VMAIL_DB_NAME} >/dev/null 2>&1 <<EOF
#       UPDATE mailbox SET \
#       lastloginipv4=INET_ATON('$IP'), \
#       lastlogindate=NOW(), \
#       lastloginprotocol="${1}" \
#       WHERE username='$USER';
#EOF
#fi

# ------------------------------------------------------------------
# Update to LDAP (OpenLDAP) directory server.
# ------------------------------------------------------------------
# Convert username to LDAP dn.
# -c         continuous operation mode (do not stop on errors)
# -x            Simple authentication
# -H URI        Uniform Resource Identifier(s)
# -D binddn     Bind dn. Default is 'cn=vmailadmin,dc=iredmail,dc=org'
# -w bindpw     Bind password (for simple authentication)

LDAP_URI='ldap://127.0.0.1:389'
LDAP_BASEDN='o=domains,dc=iredmail,dc=org'
BIND_DN='cn=vmailadmin,dc=iredmail,dc=org'
BIND_PW='plain_passwd'

if [ X"${USER}" != X"dump-capability" ]; then
    ldapmodify -c -x \
        -H "${LDAP_URI}" \
        -D "${BIND_DN}" \
        -w "${BIND_PW}" >/dev/null 2>&1 <<EOF
dn: mail=${USER},ou=Users,domainName=$(echo ${USER} | awk -F'@' '{print $2}'),${LDAP_BASEDN}
changetype: modify
replace: lastLoginDate
lastLoginDate: $(date +%Y%m%d%H%M%SZ)
-
replace: lastLoginIP
lastLoginIP: ${IP}
-
replace: lastLoginProtocol
lastLoginProtocol: ${1}
EOF

fi

# Execute POP3/IMAP process.
if [ -f /etc/redhat-release ]; then
    # RHEL/CentOS.
    exec /usr/libexec/dovecot/${1} $*
elif [ -f /etc/debian_version ]; then
    # Debian & Ubuntu:
    exec /usr/lib/dovecot/${1} $*
fi
