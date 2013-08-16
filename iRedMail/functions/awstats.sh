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

awstats_config_basic()
{
    ECHO_INFO "Configure Awstats (logfile analyzer for mail and web server)."
    [ -f ${AWSTATS_CONF_SAMPLE} ] && dos2unix ${AWSTATS_CONF_SAMPLE} >/dev/null 2>&1

    ECHO_DEBUG "Generate apache config file for awstats: ${AWSTATS_HTTPD_CONF}."
    backup_file ${AWSTATS_HTTPD_CONF}

    # Move awstats.pl to ${AWSTATS_CGI_DIR} on Debian/Ubuntu, so that it won't
    # conflict with other cgi programs, e.g. mailman.
    #if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" -o X"${DISTRO}" == X"SUSE" ]; then
    #    mkdir -p ${AWSTATS_CGI_DIR}/awstats/ 2>/dev/null
    #    mv ${AWSTATS_CGI_DIR}/awstats.pl ${AWSTATS_CGI_DIR}/awstats/ 2>/dev/null
    #    export AWSTATS_CGI_DIR="${AWSTATS_CGI_DIR}/awstats"
    #fi

    # Assign Apache daemon user to group 'adm', so that Awstats cron job can read log files.
    if [ X"${DISTRO}" == X"DEBIAN" \
        -o X"${DISTRO}" == X"UBUNTU" \
        ]; then
        usermod -G adm ${HTTPD_USER} >/dev/null
    fi

    cat > ${AWSTATS_HTTPD_CONF} <<EOF
${CONF_MSG}
# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.
#Alias /awstats/icon "${AWSTATS_ICON_DIR}/"
#Alias /awstats/css "${AWSTATS_CSS_DIR}/"
#Alias /awstats/js "${AWSTATS_JS_DIR}/"
#ScriptAlias /awstats "${AWSTATS_CGI_DIR}/"

<Directory ${AWSTATS_CGI_DIR}/>
    DirectoryIndex awstats.pl
    Options ExecCGI
    Order allow,deny
    allow from all
    #allow from ${LOCAL_ADDRESS}

    AuthName "Authorization Required"
EOF

    ECHO_DEBUG "Setup user auth for awstats: ${AWSTATS_HTTPD_CONF}."
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        # Use LDAP auth.
        cat >> ${AWSTATS_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthBasicProvider ldap
    AuthzLDAPAuthoritative   Off

    AuthLDAPUrl   ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}/${LDAP_BASEDN}?${LDAP_ATTR_USER_RDN}?sub?(&(objectclass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_DOMAIN_ADMIN})(${LDAP_ATTR_DOMAIN_GLOBALADMIN}=${LDAP_VALUE_DOMAIN_GLOBALADMIN}))

    AuthLDAPBindDN "${LDAP_BINDDN}"
    AuthLDAPBindPassword "${LDAP_BINDPW}"
EOF

        [ X"${LDAP_USE_TLS}" == X"YES" ] && \
            perl -pi -e 's#(AuthLDAPUrl.*)(ldap://)(.*)#${1}ldaps://${3}#' ${AWSTATS_HTTPD_CONF}

        # openSUSE-13.1 (bottle) ships Apache-2.4 which removes directive 'AuthzLDAPAuthoritative'.
        [ X"${DISTRO}" == X'SUSE' -a X"${DISTRO_CODENAME}" == X'bottle' ] && \
            perl -pi -e 's/(.*)(AuthzLDAPAuthoritative.*)/${1}#${2}/g' ${AWSTATS_HTTPD_CONF}

    elif [ X"${BACKEND}" == X"MYSQL" ]; then
        # Use mod_auth_mysql.
        if [ X"${DISTRO}" == X"RHEL" \
            -o X"${DISTRO}" == X"SUSE" \
            -o X"${DISTRO}" == X"FREEBSD" \
            ]; then
            cat >> ${AWSTATS_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthMYSQLEnable On
    AuthMySQLHost ${SQL_SERVER}
    AuthMySQLPort ${SQL_SERVER_PORT}
    AuthMySQLUser ${VMAIL_DB_BIND_USER}
    AuthMySQLPassword ${VMAIL_DB_BIND_PASSWD}
    AuthMySQLDB ${VMAIL_DB}
    AuthMySQLUserTable mailbox
    AuthMySQLNameField username
    AuthMySQLPasswordField password
    AuthMySQLUserCondition "isadmin=1 AND isglobaladmin=1"
EOF

            # FreeBSD special.
            if [ X"${DISTRO}" == X"FREEBSD" ]; then
                # Enable mod_auth_mysql module in httpd.conf.
                perl -pi -e 's/^#(LoadModule.*mod_auth_mysql.*)/${1}/' ${HTTPD_CONF}
            fi

            # openSUSE & FreeBSD special.
            if [ X"${DISTRO}" == X"SUSE" \
                -o X"${DISTRO}" == X"FREEBSD" \
                ]; then
                echo "    AuthBasicAuthoritative Off" >> ${AWSTATS_HTTPD_CONF}
            fi


        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            cat >> ${AWSTATS_HTTPD_CONF} <<EOF
    AuthType Basic

    AuthMYSQL on
    AuthBasicAuthoritative Off
    AuthUserFile /dev/null

    # Database related.
    AuthMySQL_Password_Table mailbox
    Auth_MySQL_Username_Field username
    Auth_MySQL_Password_Field password

    # Password related.
    AuthMySQL_Empty_Passwords off
    AuthMySQL_Encryption_Types Crypt_MD5
    Auth_MySQL_Authoritative On
    #AuthMySQLUserCondition "isadmin=1 AND isglobaladmin=1"
EOF

            # Set file permission.
            chmod 0600 ${AWSTATS_HTTPD_CONF}

            cat >> ${HTTPD_CONF} <<EOF
# MySQL auth (libapache2-mod-auth-apache2).
# Global config of MySQL server, username, password.
Auth_MySQL_Info ${SQL_SERVER} ${VMAIL_DB_BIND_USER} ${VMAIL_DB_BIND_PASSWD}
Auth_MySQL_General_DB ${VMAIL_DB}
EOF
        fi

    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        # Use PGSQL auth.
        cat >> ${AWSTATS_HTTPD_CONF} <<EOF
    AuthType Basic
    Auth_PG_authoritative on
    Auth_PG_host ${SQL_SERVER}
    Auth_PG_port ${SQL_SERVER_PORT}
    Auth_PG_database ${VMAIL_DB}
    Auth_PG_user ${VMAIL_DB_BIND_USER}
    Auth_PG_pwd ${VMAIL_DB_BIND_PASSWD}
    Auth_PG_pwd_table mailbox
    Auth_PG_pwd_whereclause 'AND isadmin=1 AND isglobaladmin=1'
    Auth_PG_uid_field username
    Auth_PG_pwd_field password
    Auth_PG_lowercase_uid on
    Auth_PG_encrypted on
    Auth_PG_hash_type CRYPT
EOF

    else
        # Use basic auth mech.
        cat >> ${AWSTATS_HTTPD_CONF} <<EOF
    AllowOverride AuthConfig
    AuthType Basic
    AuthUserFile ${AWSTATS_HTPASSWD_FILE}
EOF

        # Set username, password for web access.
        htpasswd -bcm ${AWSTATS_HTPASSWD_FILE} "${AWSTATS_USERNAME}" "${AWSTATS_PASSWD}" >/dev/null 2>&1
    fi

    # Close <Directory> container.
    cat >> ${AWSTATS_HTTPD_CONF} <<EOF

    Require valid-user
</Directory>
EOF

    if [ X"${DISTRO}" == X"SUSE" ]; then
        perl -pi -e 's#(</VirtualHost>)#Alias /awstats/icon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#(</VirtualHost>)#Alias /awstats/js "$ENV{AWSTATS_JS_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#(</VirtualHost>)#Alias /awstats/css "$ENV{AWSTATS_CSS_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}

        if [ X"${BACKEND}" == X'PGSQL' ]; then
            # Don't enable Awstats since we don't have Apache module mod_auth_pgsql
            backup_file ${AWSTATS_HTTPD_CONF}
            rm ${AWSTATS_HTTPD_CONF} &>/dev/null
        fi
    fi

    # Make Awstats can be accessed via HTTPS.
    perl -pi -e 's#(</VirtualHost>)#Alias /awstats/icon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
    perl -pi -e 's#(</VirtualHost>)#Alias /awstatsicon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
    perl -pi -e 's#(</VirtualHost>)#ScriptAlias /awstats "$ENV{AWSTATS_CGI_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}

    cat >> ${TIP_FILE} <<EOF
Awstats:
    * Configuration files:
        - ${AWSTATS_CONF_DIR}
        - ${AWSTATS_CONF_WEB}
        - ${AWSTATS_CONF_MAIL}
        - ${AWSTATS_HTTPD_CONF}
    * Login account:
        - Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}, password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * URL:
        - https://${HOSTNAME}/awstats/awstats.pl
        - https://${HOSTNAME}/awstats/awstats.pl?config=web
        - https://${HOSTNAME}/awstats/awstats.pl?config=smtp
    * Crontab job:
        shell> crontab -l root

EOF

    echo 'export status_awstats_config_basic="DONE"' >> ${STATUS_FILE}
}

awstats_config_weblog()
{
    ECHO_DEBUG "Config awstats to analyze apache web access log: ${AWSTATS_CONF_WEB}."
    if [ X"${DISTRO}" != X"SUSE" ]; then
        cd ${AWSTATS_CONF_DIR}
        cp -f ${AWSTATS_CONF_SAMPLE} ${AWSTATS_CONF_WEB}
    fi

    perl -pi -e 's#^(SiteDomain=)(.*)#${1}"$ENV{HOSTNAME}"#' ${AWSTATS_CONF_WEB}
    perl -pi -e 's#^(LogFile=)(.*)#${1}"$ENV{HTTPD_LOG_ACCESSLOG}"#' ${AWSTATS_CONF_WEB}
    perl -pi -e 's#^(Lang=)(.*)#${1}$ENV{AWSTATS_LANGUAGE}#' ${AWSTATS_CONF_WEB}

    perl -pi -e 's#^(DirIcons=)(.*)#${1}"/awstats/icon#' ${AWSTATS_CONF_WEB}

    # On RHEL/CentOS/Debian, ${AWSTATS_CONF_SAMPLE} is default config file. Overrided here.
    backup_file ${AWSTATS_CONF_SAMPLE}
    [ X"${DISTRO}" != X"SUSE" ] && cp -f ${AWSTATS_CONF_WEB} ${AWSTATS_CONF_SAMPLE}

    echo 'export status_awstats_config_weblog="DONE"' >> ${STATUS_FILE}
}

awstats_config_maillog()
{
    ECHO_DEBUG "Config awstats to analyze postfix mail log: ${AWSTATS_CONF_MAIL}."

    cd ${AWSTATS_CONF_DIR}

    # Create a default config file.
    [ X"${DISTRO}" != X"SUSE" ] && \
        cp -f ${AWSTATS_CONF_SAMPLE} ${AWSTATS_CONF_MAIL} && \
        cp -f ${AWSTATS_CONF_MAIL} ${AWSTATS_CONF_DIR}/awstats.conf

    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        export maillogconvert_pl="$( eval ${LIST_FILES_IN_PKG} "/var/db/pkg/awstats-*" | grep 'maillogconvert.pl')"
    else
        export maillogconvert_pl="$( eval ${LIST_FILES_IN_PKG} awstats | grep 'maillogconvert.pl')"
    fi

    perl -pi -e 's#^(SiteDomain=)(.*)#${1}"mail"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogFile=)(.*)#${1}"perl $ENV{maillogconvert_pl} standard < $ENV{MAILLOG} |"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogType=)(.*)#${1}M#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogFormat=)(.*)#${1}"%time2 %email %email_r %host %host_r %method %url %code %bytesd"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForBrowsersDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForOSDetection=)(.*)#${1}0##' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForRefererAnalyze=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForRobotsDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForWormsDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForSearchEnginesDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForFileTypesDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDomainsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowAuthenticatedUsers=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowRobotsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSessionsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowPagesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowFileTypesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowFileSizesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowBrowsersStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowOSStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowOriginStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowKeyphrasesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowKeywordsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowMiscStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHTTPErrorsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDownloadsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowLinksOnUrl=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(ShowMenu=)(.*)#${1}1#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSummary=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowMonthStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDaysOfMonthStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDaysOfWeekStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHoursStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSMTPErrorsStats=)(.*)#${1}1#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHostsStats=)(.*)#${1}HBL#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowEMailSenders=)(.*)#${1}HBML#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowEMailReceivers=)(.*)#${1}HBML#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(Lang=)(.*)#${1}$ENV{AWSTATS_LANGUAGE}#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(DirIcons=)(.*)#${1}"/awstats/icon#' ${AWSTATS_CONF_MAIL}

    echo 'export status_awstats_config_maillog="DONE"' >> ${STATUS_FILE}
}

awstats_config_crontab()
{
    ECHO_DEBUG "Setting cronjob for awstats."

    cat >> ${CRON_SPOOL_DIR}/root <<EOF
1   */1   *   *   *   perl ${AWSTATS_CGI_DIR}/awstats.pl -config=web -update >/dev/null
1   */1   *   *   *   perl ${AWSTATS_CGI_DIR}/awstats.pl -config=smtp -update >/dev/null
EOF

    echo 'export status_awstats_config_crontab="DONE"' >> ${STATUS_FILE}
}
