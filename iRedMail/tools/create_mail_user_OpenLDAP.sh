#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Add new OpenLDAP user for postfix mail server.
# Project:  iRedMail (http://www.iredmail.org/)

# --------------------------- WARNING ------------------------------
# This script only works under iRedMail >= 0.8.4 due to ldap schema
# changes.
# ------------------------------------------------------------------

# --------------------------- USAGE --------------------------------
# 1) Please change variables below to fit your env:
#
#   - In 'Global Setting' section:
#       * STORAGE_BASE_DIRECTORY
#
#   - In 'LDAP Setting' section:
#       * LDAP_SUFFIX
#       * BINDDN
#       * BINDPW
#       * QUOTA
#
#   - In 'Virtual Domains & Users' section:
#       * QUOTA
#       * TRANSPORT
#       * PASSWORD_SCHEME       # SSHA is recommended.
#       * DEFAULT_PASSWD
#       * USE_DEFAULT_PASSWD
#
#   - Pure-FTPd integration:
#       * PUREFTPD_INTEGRATION      # <- set to 'YES' if you want to integrate it.
#       * FTP_BASE_DIRECTORY        # <- directory used to store FTP data.
#
#   - Optional variables:
#       * SEND_WELCOME_MSG
#
# 2) Execute this script with domain name and username (without @domain) directly:
#
#       shell# bash create_mail_user_OpenLDAP.sh example.com new_user
#
#    It will create a mail user with mail address "new_user@example.com".
#    To add multiple mail users, just list all usernames:
#
#       shell# bash create_mail_user_OpenLDAP.sh example.com new_user new_user2 new_user3
#
# ------------------------------------------------------------------

# Source functions.
. ../conf/global
. ../conf/core

# ----------------------------------------------
# ------------ Global Setting ------------------
# ----------------------------------------------
# Storage base directory used to store users' mail.
# mailbox of LDAP user will be:
#    ${STORAGE_BASE_DIRECTORY}/${DOMAIN_NAME}/${USERNAME}/
# Such as:
#    /var/vmail/vmail1/iredmail.org/zhb/
#   -------------------|===========|-----|
#   STORAGE_BASE_DIRECTORY|DOMAIN_NAME|USERNAME
#
STORAGE_BASE_DIRECTORY="/var/vmail/vmail1"

# ------------------------------------------------------------------
# -------------------------- LDAP Setting --------------------------
# ------------------------------------------------------------------
LDAP_SUFFIX="dc=example,dc=com"

# Setting 'BASE_DN'.
BASE_DN="o=domains,${LDAP_SUFFIX}"

# Setting 'DOMAIN_NAME' and DOMAIN_DN':
#     * DOMAIN will be used in mail address: ${USERNAME}@${DOMAIN}
#    * DOMAIN_DN will be used in LDAP dn.
DOMAIN_NAME="$1"
DOMAIN_DN="domainName=${DOMAIN_NAME}"
OU_USER_DN="ou=Users"

# ---------- rootdn of LDAP Server ----------
# Setting rootdn of LDAP.
BINDDN="cn=Manager,${LDAP_SUFFIX}"

# Setting rootpw of LDAP.
BINDPW='passwd'

# ---------- Virtual Domains & Users --------------
# Set default quota for LDAP users: 104857600 = 100M
QUOTA='1048576000'

# Default MTA Transport (Defined in postfix master.cf).
TRANSPORT='dovecot'

# Password setting.
PASSWORD_SCHEME='SSHA'   # MD5, SSHA. SSHA is recommended.
DEFAULT_PASSWD='888888'
USE_DEFAULT_PASSWD='NO'

# ------------------------------------------------------------------
# -------------------- Pure-FTPd Integration -----------------------
# ------------------------------------------------------------------
# Add objectClass and attributes for pure-ftpd integration.
# Note: You must inlucde pureftpd.schema in OpenLDAP slapd.conf first.
PUREFTPD_INTEGRATION='NO'
FTP_BASE_DIRECTORY='/home/ftp'

# ------------------------------------------------------------------
# ------------------------- Welcome Msg ----------------------------
# ------------------------------------------------------------------
# Send a welcome mail after user created.
SEND_WELCOME_MSG='NO'

# Set welcome mail info.
WELCOME_MSG_SUBJECT="Welcome!"
WELCOME_MSG_BODY="Welcome, new user."

# -------------------------------------------
# ----------- End Global Setting ------------
# -------------------------------------------

# Time stamp, will be appended in maildir.
DATE="$(date +%Y.%m.%d.%H.%M.%S)"

STORAGE_BASE="$(dirname ${STORAGE_BASE_DIRECTORY})"
STORAGE_NODE="$(basename ${STORAGE_BASE_DIRECTORY})"

# Get days since 1970-01-01
EPOCH_SECONDS="$(date +%s)"
DAYS_SINCE_EPOCH="$((EPOCH_SECONDS / 24 / 60 / 60))"

add_new_domain()
{
    domain="$(echo ${1} | tr '[A-Z]' '[a-z]')"
    ldapsearch -x -D "${BINDDN}" -w "${BINDPW}" -b "${BASE_DN}" | grep "domainName: ${domain}" >/dev/null

    if [ X"$?" != X"0" ]; then
        echo "Add new domain: ${domain}."

        ldapadd -x -D "${BINDDN}" -w "${BINDPW}" <<EOF
dn: ${DOMAIN_DN},${BASE_DN}
objectClass: mailDomain
domainName: ${domain}
mtaTransport: ${TRANSPORT}
accountStatus: active
enabledService: mail
EOF
    else
        :
    fi

    ldapadd -x -D "${BINDDN}" -w "${BINDPW}" <<EOF
dn: ${OU_USER_DN},${DOMAIN_DN},${BASE_DN}
objectClass: organizationalUnit
objectClass: top
ou: Users
EOF

    ldapadd -x -D "${BINDDN}" -w "${BINDPW}" <<EOF
dn: ou=Groups,${DOMAIN_DN},${BASE_DN}
objectClass: organizationalUnit
objectClass: top
ou: Groups
EOF

    ldapadd -x -D "${BINDDN}" -w "${BINDPW}" <<EOF
dn: ou=Aliases,${DOMAIN_DN},${BASE_DN}
objectClass: organizationalUnit
objectClass: top
ou: Aliases
EOF

    ldapadd -x -D "${BINDDN}" -w "${BINDPW}" <<EOF
dn: ou=Externals,${DOMAIN_DN},${BASE_DN}
objectClass: organizationalUnit
objectClass: top
ou: Externals
EOF
}

add_new_user()
{
    USERNAME="$(echo $1 | tr [A-Z] [a-z])"
    MAIL="$( echo $2 | tr [A-Z] [a-z])"

    maildir="${DOMAIN_NAME}/$(hash_maildir ${USERNAME})"

    # Generate user password.
    if [ X"${USE_DEFAULT_PASSWD}" == X'YES' ]; then
        PASSWD="$(python ./generate_password_hash.py ${PASSWORD_SCHEME} ${DEFAULT_PASSWD})"
    else
        PASSWD="$(python ./generate_password_hash.py ${PASSWORD_SCHEME} ${USERNAME})"
    fi

    if [ X"${PUREFTPD_INTEGRATION}" == X'YES' ]; then
        LDIF_PUREFTPD_USER="objectClass: PureFTPdUser
FTPStatus: enabled
FTPQuotaFiles: 50
FTPQuotaMBytes: 10
FTPDownloadBandwidth: 50
FTPUploadBandwidth: 50
FTPDownloadRatio: 5
FTPUploadRatio: 1
FTPHomeDir: ${FTP_BASE_DIRECTORY}/${DOMAIN_NAME}/${USERNAME}/
"
    else
        LDIF_PUREFTPD_USER=''
    fi

    ldapadd -x -D "${BINDDN}" -w "${BINDPW}" <<EOF
dn: mail=${MAIL},${OU_USER_DN},${DOMAIN_DN},${BASE_DN}
objectClass: inetOrgPerson
objectClass: shadowAccount
objectClass: amavisAccount
objectClass: mailUser
objectClass: top
accountStatus: active
storageBaseDirectory: ${STORAGE_BASE}
homeDirectory: ${STORAGE_BASE_DIRECTORY}/${maildir}
mailMessageStore: ${STORAGE_NODE}/${maildir}
mail: ${MAIL}
mailQuota: ${QUOTA}
userPassword: ${PASSWD}
cn: ${USERNAME}
sn: ${USERNAME}
givenName: ${USERNAME}
uid: ${USERNAME}
shadowLastChange: ${DAYS_SINCE_EPOCH}
amavisLocal: TRUE
enabledService: internal
enabledService: doveadm
enabledService: lib-storage
enabledService: indexer-worker
enabledService: dsync
enabledService: mail
enabledService: pop3
enabledService: pop3secured
enabledService: pop3tls
enabledService: imap
enabledService: imapsecured
enabledService: imaptls
enabledService: smtp
enabledService: smtpsecured
enabledService: smtptls
enabledService: managesieve
enabledService: managesievesecured
enabledService: sieve
enabledService: sievesecured
enabledService: deliver
enabledService: lda
enabledService: lmtp
enabledService: forward
enabledService: senderbcc
enabledService: recipientbcc
enabledService: shadowaddress
enabledService: displayedInGlobalAddressBook
enabledService: sogo
${LDIF_PUREFTPD_USER}
EOF
}

send_welcome_mail()
{
    MAIL="$1"
    echo "Send a welcome mail to new user: ${MAIL}"

    echo "${WELCOME_MSG_BODY}" | mail -s "${WELCOME_MSG_SUBJECT}" ${MAIL}
}

usage()
{
    echo "Usage:"
    echo -e "\t$0 DOMAIN USERNAME"
    echo -e "\t$0 DOMAIN USER1 USER2 USER3 ..."
}

if [ $# -lt 2 ]; then
    usage
else
    # Promopt to check settings.
    [ X"${LDAP_SUFFIX}" == X"dc=example,dc=com" ] && echo "You should change 'LDAP_SUFFIX' in $0."

    # Get domain name.
    DOMAIN_NAME="$(echo $1 | tr '[A-Z]' '[a-z]')"
    shift 1

    add_new_domain ${DOMAIN_NAME}
    for i in $@; do
        USERNAME="$(echo $i | tr '[A-Z]' '[a-z]')"
        MAIL="${USERNAME}@${DOMAIN_NAME}"

        # Add new user in LDAP.
        add_new_user ${USERNAME} ${MAIL}

        # Send welcome msg to new user.
        [ X"${SEND_WELCOME_MSG}" == X'YES' ] && send_welcome_mail ${MAIL}
    done
fi
