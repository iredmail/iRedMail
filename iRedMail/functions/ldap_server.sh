
ldap_generate_populate_ldif()
{
    ECHO_DEBUG "Generate LDIF file used to populate LDAP tree."
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
cn: ${VMAIL_USER_NAME}
sn: ${VMAIL_USER_NAME}
uid: ${VMAIL_USER_NAME}
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

dn: mail=${FIRST_USER}@${FIRST_DOMAIN},${LDAP_ATTR_GROUP_RDN}=${LDAP_ATTR_GROUP_USERS},${LDAP_ATTR_DOMAIN_RDN}=${FIRST_DOMAIN},${LDAP_BASEDN}
objectClass: inetOrgPerson
objectClass: shadowAccount
objectClass: amavisAccount
objectClass: mailUser
objectClass: top
cn: ${FIRST_USER}
sn: ${FIRST_USER}
uid: ${FIRST_USER}
givenName: ${FIRST_USER}
mail: ${FIRST_USER}@${FIRST_DOMAIN}
accountStatus: active
storageBaseDirectory: ${STORAGE_BASE_DIR}
mailMessageStore: ${STORAGE_NODE}/${FIRST_USER_MAILDIR_HASH_PART}
homeDirectory: ${FIRST_USER_MAILDIR_FULL_PATH}
mailQuota: 104857600
userPassword: $(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} "${FIRST_USER_PASSWD}")
enabledService: mail
enabledService: internal
enabledService: doveadm
enabledService: smtp
enabledService: smtpsecured
enabledService: pop3
enabledService: pop3secured
enabledService: imap
enabledService: imapsecured
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

    if [ X"${BACKEND_ORIG}" == X'LDAPD' ]; then
        . ${FUNCTIONS_DIR}/ldapd.sh

        check_status_before_run ldapd_config
    else
        . ${FUNCTIONS_DIR}/openldap.sh

        check_status_before_run openldap_config && \
        check_status_before_run openldap_data_initialize
    fi
}

ldap_server_cron_backup()
{
    ECHO_INFO "Setup daily cron job to backup LDAP data with ${BACKUP_SCRIPT_LDAP}"

    [ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR} &>/dev/null

    backup_file ${BACKUP_SCRIPT_LDAP}

    backup_script_name="$(basename ${BACKUP_SCRIPT_LDAP})"
    cp ${TOOLS_DIR}/${backup_script_name} ${BACKUP_SCRIPT_LDAP}
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${BACKUP_SCRIPT_LDAP}
    chmod 0500 ${BACKUP_SCRIPT_LDAP}

    perl -pi -e 's#^(export BACKUP_ROOTDIR=).*#${1}"$ENV{BACKUP_DIR}"#' ${BACKUP_SCRIPT_LDAP}
    perl -pi -e 's#^(export MYSQL_USER=).*#${1}"$ENV{IREDADMIN_DB_USER}"#' ${BACKUP_SCRIPT_LDAP}
    perl -pi -e 's#^(export MYSQL_PASSWD=).*#${1}"$ENV{IREDADMIN_DB_PASSWD}"#' ${BACKUP_SCRIPT_LDAP}

    if [ X"${BACKEND_ORIG}" == X'LDAPD' ]; then
        perl -pi -e 's#(export LDAP_BASE_DN=).*#${1}"$ENV{LDAP_SUFFIX}"#g' ${BACKUP_SCRIPT_LDAP}
        perl -pi -e 's#(export LDAP_BIND_DN=).*#${1}"$ENV{LDAP_ROOTDN}"#g' ${BACKUP_SCRIPT_LDAP}
        perl -pi -e 's#(export LDAP_BIND_PASSWORD=).*#${1}"$ENV{LDAP_ROOTPW}"#g' ${BACKUP_SCRIPT_LDAP}
    fi

    # Add cron job
    cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Backup LDAP data (at 03:00 AM)
0   3   *   *   *   ${SHELL_BASH} ${BACKUP_SCRIPT_LDAP}

EOF

    cat >> ${TIP_FILE} <<EOF
Backup LDAP data:
    * Script: ${BACKUP_SCRIPT_LDAP}
    * See also:
        # crontab -l -u ${SYS_ROOT_USER}

EOF

    echo 'export status_ldap_server_cron_backup="DONE"' >> ${STATUS_FILE}
}
