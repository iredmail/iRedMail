
ldap_generate_populate_ldif()
{
    ECHO_DEBUG "Generate LDIF file used to populate LDAP tree."

    export LDAP_SUFFIX_MAJOR="$(echo ${LDAP_SUFFIX} | sed -e 's/dc=//g' -e 's/,/./g' | awk -F'.' '{print $1}')"

    cat > ${LDAP_INIT_LDIF} <<EOF
dn: ${LDAP_SUFFIX}
objectclass: dcObject
objectclass: organization
dc: ${LDAP_SUFFIX_MAJOR}
o: ${LDAP_SUFFIX_MAJOR}

dn: ${LDAP_BINDDN}
objectClass: person
objectClass: shadowAccount
objectClass: top
cn: ${SYS_USER_VMAIL}
sn: ${SYS_USER_VMAIL}
uid: ${SYS_USER_VMAIL}
userPassword: $(generate_password_hash SSHA "${LDAP_BINDPW}")

dn: ${LDAP_ADMIN_DN}
objectClass: person
objectClass: shadowAccount
objectClass: top
cn: ${VMAIL_DB_ADMIN_USER}
sn: ${VMAIL_DB_ADMIN_USER}
uid: ${VMAIL_DB_ADMIN_USER}
userPassword: $(generate_password_hash SSHA "${LDAP_ADMIN_PW}")

dn: ${LDAP_BASEDN}
objectClass: Organization
o: ${LDAP_BASEDN_NAME}

dn: ${LDAP_ADMIN_BASEDN}
objectClass: Organization
o: ${LDAP_ATTR_DOMAINADMIN_DN_NAME}

dn: domainName=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: mailDomain
domainName: ${FIRST_DOMAIN}
mtaTransport: ${TRANSPORT}
accountStatus: active
accountSetting: minPasswordLength:8
accountSetting: defaultQuota:1024
enabledService: mail

dn: ou=Users,domainName=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: organizationalUnit
objectClass: top
ou: Users

dn: ou=Groups,domainName=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: organizationalUnit
objectClass: top
ou: Groups

dn: ou=Aliases,domainName=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: organizationalUnit
objectClass: top
ou: Aliases

dn: ou=Externals,domainName=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: organizationalUnit
objectClass: top
ou: Externals

dn: mail=${DOMAIN_ADMIN_EMAIL},${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_USERS},${LDAP_ATTR_DOMAIN_RDN}=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: inetOrgPerson
objectClass: shadowAccount
objectClass: amavisAccount
objectClass: mailUser
objectClass: top
cn: ${DOMAIN_ADMIN_NAME}
sn: ${DOMAIN_ADMIN_NAME}
uid: ${DOMAIN_ADMIN_NAME}
givenName: ${DOMAIN_ADMIN_NAME}
mail: ${DOMAIN_ADMIN_EMAIL}
accountStatus: active
storageBaseDirectory: ${STORAGE_BASE_DIR}
mailMessageStore: ${STORAGE_NODE}/${DOMAIN_ADMIN_MAILDIR_HASH_PART}
homeDirectory: ${DOMAIN_ADMIN_MAILDIR_FULL_PATH}
mailQuota: 104857600
userPassword: ${DOMAIN_ADMIN_PASSWD_HASH}
enabledService: mail
enabledService: internal
enabledService: doveadm
enabledService: smtp
enabledService: smtpsecured
enabledService: smtptls
enabledService: pop3
enabledService: pop3secured
enabledService: pop3tls
enabledService: imap
enabledService: imapsecured
enabledService: imaptls
enabledService: deliver
enabledService: lda
enabledService: lmtp
enabledService: forward
enabledService: senderbcc
enabledService: recipientbcc
enabledService: managesieve
enabledService: managesievesecured
enabledService: sieve
enabledService: sievesecured
enabledService: sievetls
enabledService: displayedInGlobalAddressBook
enabledService: shadowaddress
enabledService: lib-storage
enabledService: indexer-worker
enabledService: dsync
enabledService: domainadmin
enabledService: sogo
domainGlobalAdmin: yes
EOF
}

ldap_server_config()
{
    ldap_generate_populate_ldif

    # Always use SSHA for root dn so that ldap server can verify the password.
    # SSHA512, BCRYPT is not supported by OpenLDAP.
    export LDAP_ROOTPW_SSHA="$(generate_password_hash SSHA ${LDAP_ROOTPW})"

    . ${FUNCTIONS_DIR}/openldap.sh

    check_status_before_run openldap_config && \
    check_status_before_run openldap_data_initialize
}

ldap_server_cron_backup()
{
    ldap_backup_script="${BACKUP_DIR}/${BACKUP_SCRIPT_LDAP_NAME}"

    ECHO_INFO "Setup daily cron job to backup LDAP data with ${ldap_backup_script}"

    [ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} &>/dev/null

    backup_file ${ldap_backup_script}

    cp ${TOOLS_DIR}/${BACKUP_SCRIPT_LDAP_NAME} ${ldap_backup_script}
    chown ${SYS_USER_ROOT}:${SYS_GROUP_ROOT} ${ldap_backup_script}
    chmod 0500 ${ldap_backup_script}

    perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${ldap_backup_script}
    perl -pi -e 's#^(export MYSQL_USER=).*#${1}"$ENV{IREDADMIN_DB_USER}"#' ${ldap_backup_script}
    perl -pi -e 's#^(export MYSQL_PASSWD=).*#${1}"$ENV{IREDADMIN_DB_PASSWD}"#' ${ldap_backup_script}

    # Add cron job
    cat >> ${CRON_FILE_ROOT} <<EOF
# ${PROG_NAME}: Backup LDAP data (at 03:00 AM)
0   3   *   *   *   ${SHELL_BASH} ${ldap_backup_script}

EOF

    cat >> ${TIP_FILE} <<EOF
Backup LDAP data:
    * Script: ${ldap_backup_script}
    * See also:
        # crontab -l -u ${SYS_USER_ROOT}

EOF

    echo 'export status_ldap_server_cron_backup="DONE"' >> ${STATUS_FILE}
}
