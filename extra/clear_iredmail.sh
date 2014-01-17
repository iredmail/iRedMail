#!/usr/bin/env bash

# Author:   Zhang Huangbin (michaelbibby <at> gmail.com)
# Purpose:  Remove main components which installed by iRedMail, so that
#           you can re-install iRedMail.
# Project:  iRedMail (http://www.iredmail.org/)

# ------------ USAGE --------
# Execute this file in the current directory.
#
#   # bash clear_iredmail.sh
#

export CONF_DIR='../conf'

# For Ubuntu & Debian.
export DEBIAN_FRONTEND='noninteractive'

# Source functions.
. ${CONF_DIR}/global
. ${CONF_DIR}/core

# Source configurations.
[ -f ${CONF_DIR}/apache_php ] && . ${CONF_DIR}/apache_php
[ -f ${CONF_DIR}/openldap ] && . ${CONF_DIR}/openldap
[ -f ${CONF_DIR}/phpldapadmin ] && . ${CONF_DIR}/phpldapadmin
[ -f ${CONF_DIR}/mysql ] && . ${CONF_DIR}/mysql
[ -f ${CONF_DIR}/postfix ] && . ${CONF_DIR}/postfix
[ -f ${CONF_DIR}/policyd ] && . ${CONF_DIR}/policyd
[ -f ${CONF_DIR}/dovecot ] && . ${CONF_DIR}/dovecot
[ -f ${CONF_DIR}/managesieve ] && . ${CONF_DIR}/managesieve
[ -f ${CONF_DIR}/procmail ] && . ${CONF_DIR}/procmail
[ -f ${CONF_DIR}/amavisd ] && . ${CONF_DIR}/amavisd
[ -f ${CONF_DIR}/clamav ] && . ${CONF_DIR}/clamav
[ -f ${CONF_DIR}/spamassassin ] && . ${CONF_DIR}/spamassassin
[ -f ${CONF_DIR}/squirrelmail ] && . ${CONF_DIR}/squirrelmail
[ -f ${CONF_DIR}/roundcube ] && . ${CONF_DIR}/roundcube
[ -f ${CONF_DIR}/postfixadmin ] && . ${CONF_DIR}/postfixadmin
[ -f ${CONF_DIR}/phpmyadmin ] && . ${CONF_DIR}/phpmyadmin
[ -f ${CONF_DIR}/awstats ] && . ${CONF_DIR}/awstats
[ -f ${CONF_DIR}/iredadmin ] && . ${CONF_DIR}/iredadmin
[ -f ${CONF_DIR}/iredapd ] && . ${CONF_DIR}/iredapd

# Source user configurations of iRedMail.
. ../config

confirm_to_remove_account()
{
    # Usage: confirm_to_remove_account user USERNAME
    #        confirm_to_remove_account group GROUPNAME
    TYPE="${1}"
    NAME="${2}"

    if [ X"${TYPE}" == X"user" ]; then
        id -u ${NAME} >/dev/null 2>&1
        RETVAL="$?"
        remove_cmd="userdel -r"
    elif [ X"${TYPE}" == X"group" ]; then
        id -g ${NAME} >/dev/null 2>&1
        RETVAL="$?"
        remove_cmd="groupdel"
    fi

    if [ X"${RETVAL}" == X"0" ]; then
        ECHO_INFO -n "Remove ${TYPE} ${NAME}. [Y|n]"

        read ANSWER
        case $ANSWER in
            N|n ) : ;;
            Y|y|* )
                ECHO_INFO -n "Removing ${TYPE} ${NAME} ..."
                ${remove_cmd} ${NAME}
                echo -e "\t[ DONE ]\n--"
                ;;
        esac
    else
        # Account not exist.
        :
    fi
}

remove_pkg()
{
    ECHO_INFO "Removing package(s): $@"
    if [ X"${DISTRO}" == X"RHEL" ]; then
        yum remove $@
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        dpkg -P postfix-policyd mailx bsd-mailx
        dpkg -P $@
    fi
}

# ---- Below is code snippet of functions/packages.sh ----
# Get all packages.
get_all_pkgs()
{
    export ALL_PKGS=''
    export ENABLED_SERVICES=''

    # Apache and PHP.
    if [ X"${USE_EXIST_AMP}" != X"YES" ]; then
        # Apache & PHP.
        if [ X"${DISTRO}" == X"RHEL" ]; then
            ALL_PKGS="${ALL_PKGS} httpd mod_ssl php php-common php-imap php-gd php-mbstring libmcrypt php-mcrypt php-pear php-xml php-pecl-fileinfo php-mysql php-ldap"
            ENABLED_SERVICES="${ENABLED_SERVICES} httpd"

        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            ALL_PKGS="${ALL_PKGS} apache2 apache2-mpm-prefork apache2.2-common libapache2-mod-php5 libapache2-mod-auth-mysql apache2-utils libaprutil1 php5-common php5-cli php5-imap php5-gd php5-mcrypt php5-mysql php5-ldap php-pear"
            ENABLED_SERVICES="${ENABLED_SERVICES} apache2"
        else
            :
        fi
    else
        :
    fi

    # Postfix.
    if [ X"${DISTRO}" == X"RHEL" ]; then
        ALL_PKGS="${ALL_PKGS} postfix"
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        ALL_PKGS="${ALL_PKGS} postfix postfix-pcre"
    else
        :
    fi

    ENABLED_SERVICES="${ENABLED_SERVICES} postfix"

    # Awstats.
    if [ X"${USE_AWSTATS}" == X"YES" ]; then
        if [ X"${DISTRO}" == X"RHEL" ]; then
            ALL_PKGS="${ALL_PKGS} awstats"
        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            ALL_PKGS="${ALL_PKGS} awstats"
        else
            :
        fi
    else
        :
    fi

    # Note: mysql server is required, used to store extra data,
    #       such as policyd, roundcube webmail data.
    if [ X"${DISTRO}" == X"RHEL" ]; then
        ALL_PKGS="${ALL_PKGS} mysql-server mysql"
        ENABLED_SERVICES="${ENABLED_SERVICES} mysqld"
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        [ X"${DISTRO_CODENAME}" == X"jaunty" ] && ALL_PKGS="${ALL_PKGS} mysql-server-core-5.0"
        ALL_PKGS="${ALL_PKGS} libdbd-mysql-perl libmysqlclient15off libmysqlclient15-dev mysql-common mysql-server-5.0 mysql-client mysql-client-5.0"
        ENABLED_SERVICES="${ENABLED_SERVICES} mysql"
    else
        :
    fi

    # Backend: OpenLDAP or MySQL.
    if [ X"${BACKEND}" == X"OpenLDAP" ]; then
        # OpenLDAP server & client.
        if [ X"${DISTRO}" == X"RHEL" ]; then
            ALL_PKGS="${ALL_PKGS} openldap-clients openldap-servers"
            ENABLED_SERVICES="${ENABLED_SERVICES} ldap"

        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            ALL_PKGS="${ALL_PKGS} postfix-ldap slapd ldap-utils"
            ENABLED_SERVICES="${ENABLED_SERVICES} slapd"
        else
            :
        fi
    elif [ X"${BACKEND}" == X"MySQL" ]; then
        # MySQL server & client.
        if [ X"${DISTRO}" == X"RHEL" ]; then
            # For Awstats.
            [ X"${USE_AWSTATS}" == X"YES" ] && ALL_PKGS="${ALL_PKGS} mod_auth_mysql"

        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            ALL_PKGS="${ALL_PKGS} postfix-mysql"

            # For Awstats.
            [ X"${USE_AWSTATS}" == X"YES" ] && ALL_PKGS="${ALL_PKGS} libapache2-mod-auth-mysql"
        else
            :
        fi
    else
        :
    fi

    # Policyd.
    if [ X"${DISTRO}" == X"RHEL" ]; then
        ALL_PKGS="${ALL_PKGS} policyd"
        ENABLED_SERVICES="${ENABLED_SERVICES} policyd"
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        ALL_PKGS="${ALL_PKGS} postfix-policyd"
        ENABLED_SERVICES="${ENABLED_SERVICES} postfix-policyd"
    else
        :
    fi

    # Dovecot.
    if [ X"${ENABLE_DOVECOT}" == X"YES" ]; then
        if [ X"${DISTRO}" == X"RHEL" ]; then
            ALL_PKGS="${ALL_PKGS} dovecot dovecot-sieve"

        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-common dovecot-imapd dovecot-pop3d"
        else
            :
        fi

        ENABLED_SERVICES="${ENABLED_SERVICES} dovecot"
    else
        ALL_PKGS="procmail"
        [ X"${DISTRO}" == X"RHEL" ] && ENABLED_SERVICES="${ENABLED_SERVICES} saslauthd"
    fi

    # Amavisd-new & ClamAV & Altermime.
    if [ X"${DISTRO}" == X"RHEL" ]; then
        ALL_PKGS="${ALL_PKGS} amavisd-new clamd clamav clamav-db spamassassin altermime"
        ENABLED_SERVICES="${ENABLED_SERVICES} ${AMAVISD_RC_SCRIPT_NAME} clamd"
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        ALL_PKGS="${ALL_PKGS} amavisd-new libcrypt-openssl-rsa-perl libmail-dkim-perl clamav clamav-base clamav-freshclam clamav-daemon spamassassin altermime"
        ENABLED_SERVICES="${ENABLED_SERVICES} ${AMAVISD_RC_SCRIPT_NAME} clamav-daemon clamav-freshclam"
    else
        :
    fi

    [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO_CODENAME}" == X"hardy" ] && ALL_PKGS="${ALL_PKGS} libclamav5"

    # SPF.
    if [ X"${ENABLE_SPF}" == X"YES" ]; then
        if [ X"${DISTRO}" == X"RHEL" ]; then
            # SPF implemention via perl-Mail-SPF.
            ALL_PKGS="${ALL_PKGS} perl-Mail-SPF perl-Mail-SPF-Query"

        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            ALL_PKGS="${ALL_PKGS} libmail-spf-perl"
        else
            :
        fi
    else
        :
    fi

    # pysieved.
    # Warning: Do *NOT* add 'pysieved' service in 'ENABLED_SERVICES'.
    #          We don't have rc/init script under /etc/init.d/ till
    #          package is installed.
    if [ X"${USE_MANAGESIEVE}" == X"YES" ]; then
        # Note for Ubuntu & Debian:
        # Dovecot shipped in Debian/Ubuntu has managesieve plugin patched.
        [ X"${DISTRO}" == X"RHEL" ] && ALL_PKGS="${ALL_PKGS} pysieved"
    else
        :
    fi

    # SquirrelMail.
    if [ X"${USE_SM}" == X"YES" ]; then
        [ X"${DISTRO}" == X"RHEL" ] && ALL_PKGS="${ALL_PKGS} php-pear-db"
        [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ] && \
            ALL_PKGS="${ALL_PKGS} php-db"
    else
        :
    fi

    # iRedAdmin.
    if [ X"${USE_IREDADMIN}" == X"YES" ]; then
        [ X"${DISTRO}" == X"RHEL" ] && \
        ALL_PKGS="${ALL_PKGS} python-jinja2.${ARCH} python-webpy python-ldap.${ARCH} MySQL-python.${ARCH} mod_wsgi.${ARCH}"

        [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ] && \
            ALL_PKGS="${ALL_PKGS} libapache2-mod-wsgi python-mysqldb python-ldap python-jinja2 python-netifaces python-webpy"
    else
        :
    fi
}

get_all_misc()
{
    export EXTRA_FILES=''

    # SSL keys.
    EXTRA_FILES="${EXTRA_FILES} ${SSL_CERT_FILE} ${SSL_KEY_FILE}"

    # Apache & PHP.
    EXTRA_FILES="${EXTRA_FILES} ${HTTPD_CONF_ROOT} ${PHP_INI} /etc/php.d"

    # MySQL.
    EXTRA_FILES="${EXTRA_FILES} ${MYSQL_MY_CNF} /var/lib/mysql /var/log/mysqld.log /var/log/mysql.log /etc/mysql"

    # OpenLDAP.
    EXTRA_FILES="${EXTRA_FILES} ${OPENLDAP_CONF_ROOT} ${OPENLDAP_DATA_DIR} ${OPENLDAP_LOGFILE} ${OPENLDAP_LOGROTATE_FILE}"

    # Postfix.
    EXTRA_FILES="${EXTRA_FILES} ${POSTFIX_ROOTDIR}"

    # Dovecot.
    EXTRA_FILES="${EXTRA_FILES} ${DOVECOT_CONF} ${DOVECOT_LDAP_CONF} ${DOVECOT_MYSQL_CONF} ${DOVECOT_LOG_FILE} ${SIEVE_LOG_FILE} ${DOVECOT_LOGROTATE_FILE} ${SIEVE_LOGROTATE_FILE} ${DOVECOT_EXPIRE_DICT_BDB} ${GLOBAL_SIEVE_FILE} ${DOVECOT_QUOTA_WARNING_BIN}"

    # Procmail.
    EXTRA_FILES="${EXTRA_FILES} ${PROCMAILRC} ${PROCMAIL_LOGFILE} ${PROCMAIL_LOGROTATE_FILE}"

    # Policyd.
    EXTRA_FILES="${EXTRA_FILES} ${POLICYD_CONF} ${POLICYD_SENDER_THROTTLE_CONF} ${POLICYD_LOGFILE} ${POLICYD_LOGROTATE_FILE}"

    # Pysieved.
    EXTRA_FILES="${EXTRA_FILES} ${PYSIEVED_INI} /etc/init.d/pysieved"

    # Amavisd.
    EXTRA_FILES="${EXTRA_FILES} ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF} ${AMAVISD_DKIM_DIR} ${AMAVISD_LOGFILE} ${AMAVISD_LOGROTATE_FILE} ${DISCLAIMER_DIR}"

    # ClamAV.
    EXTRA_FILES="${EXTRA_FILES} ${CLAMD_CONF} ${FRESHCLAM_CONF} ${CLAMD_LOGFILE} ${FRESHCLAM_LOGFILE}"

    # Awstats.
    EXTRA_FILES="${EXTRA_FILES} ${AWSTATS_CONF_DIR} ${AWSTATS_HTTPD_ROOT} ${AWSTATS_CGI_DIR}"

    # phpLDAPadmin.
    EXTRA_FILES="${EXTRA_FILES} ${PLA_HTTPD_ROOT} ${HTTPD_SERVERROOT}/phpldapadmin"

    # phpMyAdmin.
    EXTRA_FILES="${EXTRA_FILES} ${PHPMYADMIN_HTTPD_ROOT} ${HTTPD_SERVERROOT}/phpmyadmin"

    # Roundcube webmail.
    EXTRA_FILES="${EXTRA_FILES} ${RCM_HTTPD_ROOT} ${HTTPD_SERVERROOT}/roundcubemail ${RCM_LOGFILE} ${RCM_LOGROTATE_FILE}"

    # PostfixAdmin.
    EXTRA_FILES="${EXTRA_FILES} ${POSTFIXADMIN_HTTPD_ROOT} ${HTTPD_SERVERROOT}/postfixadmin"

    # SquirrelMail.
    EXTRA_FILES="${EXTRA_FILES} ${SM_HTTPD_ROOT} ${HTTPD_SERVERROOT}/squirrelmail"

    # iRedAdmin.
    EXTRA_FILES="${EXTRA_FILES} ${IREDADMIN_HTTPD_ROOT} ${HTTPD_SERVERROOT}/iredadmin"

    # Misc.
    EXTRA_FILES="${EXTRA_FILES} ${LOCAL_REPO_FILE}"
}

# Ge all users & groups
get_all_accounts()
{
    export ALL_USERS=''
    export ALL_GROUPS=''

    # Vmail.
    ALL_USERS="${ALL_USERS} ${VMAIL_USER_NAME}"
    ALL_GROUPS="${ALL_GROUPS} ${VMAIL_GROUP_NAME}"

    # Apache.
    #ALL_USERS="${ALL_USERS} ${HTTPD_USER}"
    #ALL_GROUPS="${ALL_GROUPS} ${HTTPD_GROUP}"

    # OpenLDAP.
    #ALL_USERS="${ALL_USERS} ${LDAP_USER}"
    #ALL_GROUPS="${ALL_GROUPS} ${LDAP_GROUP}"

    # Dovecot.
    #ALL_USERS="${ALL_USERS} ${DOVECOT_USER}"
    #ALL_GROUPS="${ALL_GROUPS} ${DOVECOT_GROUP}"

    # Policyd.
    ALL_USERS="${ALL_USERS} ${POLICYD_USER}"
    ALL_GROUPS="${ALL_GROUPS} ${POLICYD_GROUP}"

    # Amavisd.
    if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        ALL_USERS="${ALL_USERS} ${AMAVISD_SYS_USER}"
        ALL_GROUPS="${ALL_GROUPS} ${AMAVISD_SYS_GROUP}"
    fi

    # ClamAV.
    #ALL_USERS="${ALL_USERS} ${CLAMAV_USER}"
    #ALL_GROUPS="${ALL_GROUPS} ${CLAMAV_GROUP}"

    # iRedAPD.
    ALL_USERS="${ALL_USERS} ${IREDAPD_DAEMON_USER}"
    ALL_GROUPS="${ALL_GROUPS} ${IREDAPD_DAEMON_GROUP}"

    # iRedAdmin.
    ALL_USERS="${ALL_USERS} ${IREDADMIN_HTTPD_USER}"
    ALL_GROUPS="${ALL_GROUPS} ${IREDADMIN_HTTPD_GROUP}"
}

cat <<EOF
This script is deprecated. To reinstall iRedMail,  please consider reinstalling
server OS then reinstall iRedMail instead, this is the best way.

================== WARNING =================
This script will remove below data without addition confirm, please make sure
you want to do this:

- System accounts created by iRedMail. e.g. vmail, iredapd, iredadmin.
- Binary packages installed by iRedMail. e.g. Apache, MySQL, Dovecot.
- SQL database. e.g. MySQL database.
- Config files and other directories/files created by installed software.
================== WARNING =================
EOF

read -p "Do you really want to do this? Please type YES to continue. " confirm
if [ X"${confirm}" != X'YES' ]; then
    echo "Exit."
    exit 255
fi

get_all_pkgs
get_all_misc
get_all_accounts

ECHO_INFO "=================== Stop services ================"
for i in ${ENABLED_SERVICES}; do
    [ -x /etc/init.d/$i ] && /etc/init.d/$i stop
done

if [ X"${DISTRO}" == X"RHEL" ]; then
    /usr/bin/killall -u ${IREDAPD_DAEMON_USER} python
fi

ECHO_INFO "=================== Remove binary packages ================"
remove_pkg ${ALL_PKGS}

ECHO_INFO "=================== Remove users ================"
for user in ${ALL_USERS}; do
    confirm_to_remove_account user ${user}
done

ECHO_INFO "=================== Remove groups ================"
for group in ${ALL_GROUPS}; do
    confirm_to_remove_account group ${group}
done

ECHO_INFO "=================== Remove configuration files ================"
for i in ${EXTRA_FILES}; do
    [ -e ${i} -o -L ${i} ] && rm -rfi ${i}
done

if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
    for i in $(dpkg-statoverride --list); do
        file="$(echo $i | awk '{print $NF}')"
        #rm -rf $file 2>/dev/null
        [ ! -z ${file} ] && dpkg-statoverride --remove $file
    done
fi
