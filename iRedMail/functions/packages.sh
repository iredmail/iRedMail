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

install_all()
{
    ALL_PKGS=''
    ENABLED_SERVICES=''
    DISABLED_SERVICES=''

    # OpenBSD only
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        PKG_SCRIPTS=''
        OB_PKG_PHP_VER='-7.2.10'

        # 6.4
        OB_PKG_OPENLDAP_SERVER_VER='-2.4.46p0'
        OB_PKG_OPENLDAP_CLIENT_VER='-2.4.46'
    fi

    # Install PHP if there's a web server running -- php is too popular.
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        export IREDMAIL_USE_PHP='YES'
    fi

    # Enable syslog service (rsyslog).
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} rsyslog"

        [ X"${DISTRO_VERSION}" == X'7' ] && ALL_PKGS="${ALL_PKGS} firewalld"

        ENABLED_SERVICES="${ENABLED_SERVICES} rsyslog firewalld"
        DISABLED_SERVICES="${DISABLED_SERVICES} exim"
    elif [ X"${DISTRO}" == X'DEBIAN' ]; then
        # Debian.
        ENABLED_SERVICES="rsyslog ${ENABLED_SERVICES}"
    elif [ X"${DISTRO}" == X'UBUNTU' ]; then
        # Ubuntu >= 9.10.
        ENABLED_SERVICES="rsyslog ${ENABLED_SERVICES}"
    fi

    # Postfix.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${POSTFIX_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} postfix"

        # Exclude postfix package from iRedMail repo.
        # Postfix in iRedMail repo was rebuilt to support PostgreSQL.
        if [ X"${DISTRO_VERSION}" == X'7' ]; then
            if [ X"${BACKEND}" == X'OPENLDAP' ] || [ X"${BACKEND}" == X'MYSQL' ]; then
                if [ -f ${LOCAL_REPO_FILE} ]; then
                    perl -pi -e 's/^#(exclude=postfix.*)/${1}/' ${LOCAL_REPO_FILE}
                fi
            fi
        fi

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        # libsasl2-modules is required for sasl auth (used by relay host which
        # requires sasl auth)
        ALL_PKGS="${ALL_PKGS} postfix postfix-pcre libsasl2-modules"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-ldap%stable"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-mysql%stable"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-pgsql%stable"
    fi

    # Backend: OpenLDAP, MySQL, PGSQL and extra packages.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # OpenLDAP server & client.
        ENABLED_SERVICES="${ENABLED_SERVICES} ${OPENLDAP_RC_SCRIPT_NAME} ${MYSQL_RC_SCRIPT_NAME}"

        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} openldap openldap-clients openldap-servers"

            if [ X"${ENABLE_BACKEND_MYSQL}" == X'NO' ]; then
                ALL_PKGS="${ALL_PKGS} mariadb-server mod_ldap"
            else
                ALL_PKGS="${ALL_PKGS} mysql-server"
            fi

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} postfix-ldap slapd ldap-utils libnet-ldap-perl libdbd-mysql-perl"

            if [ X"${ENABLE_BACKEND_MYSQL}" == X'NO' ]; then
                ALL_PKGS="${ALL_PKGS} mariadb-server mariadb-client"
            else
                ALL_PKGS="${ALL_PKGS} mysql-server mysql-client"
            fi

        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            if [ X"${BACKEND_ORIG}" == X'OPENLDAP' ]; then
                ALL_PKGS="${ALL_PKGS} openldap-server${OB_PKG_OPENLDAP_SERVER_VER}"
                PKG_SCRIPTS="${PKG_SCRIPTS} ${OPENLDAP_RC_SCRIPT_NAME}"
            elif [ X"${BACKEND_ORIG}" == X'LDAPD' ]; then
                ALL_PKGS="${ALL_PKGS} openldap-client${OB_PKG_OPENLDAP_CLIENT_VER}"
                PKG_SCRIPTS="${PKG_SCRIPTS} ${LDAPD_RC_SCRIPT_NAME}"
            fi

            ALL_PKGS="${ALL_PKGS} mariadb-server mariadb-client p5-ldap p5-DBD-mysql"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${MYSQL_RC_SCRIPT_NAME}"

        fi
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        # MySQL server & client.
        ENABLED_SERVICES="${ENABLED_SERVICES} ${MYSQL_RC_SCRIPT_NAME}"
        if [ X"${DISTRO}" == X'RHEL' ]; then
            # Install MySQL client
            [ X"${BACKEND_ORIG}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} mysql"
            [ X"${BACKEND_ORIG}" == X'MARIADB' ] && ALL_PKGS="${ALL_PKGS} mariadb"

            if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
                [ X"${BACKEND_ORIG}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} mysql-server"
                [ X"${BACKEND_ORIG}" == X'MARIADB' ] && ALL_PKGS="${ALL_PKGS} mariadb-server"
            fi

            # Perl module
            ALL_PKGS="${ALL_PKGS} perl-DBD-MySQL"

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # MySQL server and client.
            [ X"${BACKEND_ORIG}" == X'MARIADB' ] && ALL_PKGS="${ALL_PKGS} mariadb-client"
            [ X"${BACKEND_ORIG}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} mysql-client"

            if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
                [ X"${BACKEND_ORIG}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} mysql-server"
                [ X"${BACKEND_ORIG}" == X'MARIADB' ] && ALL_PKGS="${ALL_PKGS} mariadb-server"
            fi

            ALL_PKGS="${ALL_PKGS} postfix-mysql libdbd-mysql-perl"

        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} mariadb-client"

            if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
                ALL_PKGS="${ALL_PKGS} mariadb-server p5-DBD-mysql"
                PKG_SCRIPTS="${PKG_SCRIPTS} ${MYSQL_RC_SCRIPT_NAME}"
            fi
        fi
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} ${PGSQL_RC_SCRIPT_NAME}"

        # PGSQL server & client.
        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} postgresql-server postgresql-contrib perl-DBD-Pg"

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # postgresql-contrib provides extension 'dblink' used in Roundcube password plugin.
            ALL_PKGS="${ALL_PKGS} postgresql postgresql-client postgresql-contrib postfix-pgsql libdbd-pg-perl"

        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} postgresql-client postgresql-server postgresql-contrib p5-DBD-Pg"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${PGSQL_RC_SCRIPT_NAME}"
        fi
    fi

    # PHP
    if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} php-common php-fpm php-gd php-xml php-mysql php-ldap php-pgsql php-imap php-mbstring php-pecl-apc php-intl php-mcrypt"

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # Debian 9, Ubuntu 16.04
            ALL_PKGS="${ALL_PKGS} php-cli php-fpm php-json php-gd php-curl mcrypt php-intl php-xml php-mbstring"

            # Ubuntu 18.04 doesn't have php-mcrypt.
            if [ X"${DISTRO_CODENAME}" == X'stretch' -o X"${DISTRO_CODENAME}" == X'xenial' ]; then
                ALL_PKGS="${ALL_PKGS} php-mcrypt"
            fi

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} php-ldap php-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} php-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} php-pgsql"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} php${OB_PKG_PHP_VER} php-bz2${OB_PKG_PHP_VER} php-imap${OB_PKG_PHP_VER} php-gd${OB_PKG_PHP_VER} php-intl${OB_PKG_PHP_VER}"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} php-ldap${OB_PKG_PHP_VER} php-pdo_mysql${OB_PKG_PHP_VER}"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} php-pdo_mysql${OB_PKG_PHP_VER}"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} php-pdo_pgsql${OB_PKG_PHP_VER}"
        fi
    fi

    # Nginx
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} nginx"
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} nginx-full"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} nginx"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${NGINX_RC_SCRIPT_NAME} ${PHP_FPM_RC_SCRIPT_NAME}"
        fi

        ENABLED_SERVICES="${ENABLED_SERVICES} ${NGINX_RC_SCRIPT_NAME} ${PHP_FPM_RC_SCRIPT_NAME}"
    fi

    # Dovecot.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${DOVECOT_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} dovecot dovecot-pigeonhole"

        if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-mysql"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-pgsql"
        fi

        # We use Dovecot SASL auth instead of saslauthd
        DISABLED_SERVICES="${DISABLED_SERVICES} saslauthd"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-managesieved dovecot-sieve"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-ldap dovecot-mysql"
        elif [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-mysql"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-pgsql"
        fi

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} dovecot dovecot-pigeonhole"
        PKG_SCRIPTS="${PKG_SCRIPTS} ${DOVECOT_RC_SCRIPT_NAME}"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-ldap dovecot-mysql"
        elif [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-mysql"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-postgresql"
        fi

        DISABLED_SERVICES="${DISABLED_SERVICES} saslauthd"
    fi

    # Amavisd-new & ClamAV & Altermime.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${CLAMAV_CLAMD_SERVICE_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} amavisd-new spamassassin altermime perl-LDAP perl-Mail-SPF unrar pax lz4 clamav clamav-update clamav-server clamav-server-systemd"

        # RHEL uses service name 'clamd@amavisd' instead of clamd.
        DISABLED_SERVICES="${DISABLED_SERVICES} clamd spamassassin"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} amavisd-new libcrypt-openssl-rsa-perl libmail-dkim-perl clamav-freshclam clamav-daemon spamassassin altermime arj nomarch cpio lzop cabextract p7zip-full rpm ripole libmail-spf-perl unrar-free pax lrzip"

        ENABLED_SERVICES="${ENABLED_SERVICES} ${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME}"
        DISABLED_SERVICES="${DISABLED_SERVICES} spamassassin"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} rpm2cpio amavisd-new amavisd-new-utils p5-Mail-SPF p5-Mail-SpamAssassin clamav unrar altermime"
        PKG_SCRIPTS="${PKG_SCRIPTS} ${CLAMAV_CLAMD_SERVICE_NAME} ${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    fi

    # mlmmj: mailing list manager
    ALL_PKGS="${ALL_PKGS} mlmmj"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} uwsgi-logger-syslog"
    fi

    # Roundcube
    if [ X"${USE_ROUNDCUBE}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} php-pear-Net-IDNA2"
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} php-net-ldap3"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} php-pspell${OB_PKG_PHP_VER} php-intl${OB_PKG_PHP_VER}"
        fi
    fi

    # SOGo
    if [ X"${USE_SOGO}" == X'YES' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} ${SOGO_RC_SCRIPT_NAME} ${MEMCACHED_RC_SCRIPT_NAME}"

        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} sogo sogo-activesync libwbxml sogo-ealarms-notify sogo-tool"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} sope49-gdl1-mysql sope49-ldap"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} sope49-gdl1-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} sope49-gdl1-postgresql"

            # Copy yum repo file
            ECHO_INFO "Add yum repo for SOGo: ${YUM_REPOS_DIR}/sogo.repo."
            cat > ${YUM_REPOS_DIR}/sogo.repo <<EOF
[SOGo]
name=Inverse SOGo Repository
enabled=1
gpgcheck=0

# SOGo v3 stable release.
# WARNING: A proper support contract from Inverse is required:
# https://sogo.nu/support/index.html#support-plans
#baseurl=${SOGO_PKG_MIRROR}/SOGo/release/${SOGO_VERSION}/rhel/${DISTRO_VERSION}/\$basearch

# SOGo v3 nightly builds
baseurl=${SOGO_PKG_MIRROR}/SOGo/nightly/${SOGO_VERSION}/rhel/${DISTRO_VERSION}/\$basearch
EOF

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} sogo sogo-activesync"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} sope4.9-gdl1-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} sope4.9-gdl1-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} sope4.9-gdl1-postgresql"

            ECHO_INFO "Add apt repo for SOGo: ${SOGO_PKG_MIRROR}"
            if [ X"${DISTRO}" == X'DEBIAN' ]; then
                echo "deb ${SOGO_PKG_MIRROR}/SOGo/nightly/${SOGO_VERSION}/debian ${DISTRO_CODENAME} ${DISTRO_CODENAME}" > /etc/apt/sources.list.d/sogo-nightly.list
            elif [ X"${DISTRO}" == X'UBUNTU' ]; then
                echo "deb ${SOGO_PKG_MIRROR}/SOGo/nightly/${SOGO_VERSION}/ubuntu ${DISTRO_CODENAME} ${DISTRO_CODENAME}" > /etc/apt/sources.list.d/sogo-nightly.list
            fi

            ECHO_INFO "Import apt key (${SOGO_PKG_MIRROR_APT_KEY}) for SOGo repo (${SOGO_PKG_MIRROR})."
            apt-key adv --keyserver keyserver.ubuntu.com --recv-key ${SOGO_PKG_MIRROR_APT_KEY}

            # Try another PGP key server if `keyserver.ubuntu.com` failed
            if [ X"$?" != X'0' ]; then
                apt-key adv --keyserver pgp.mit.edu --recv-key ${SOGO_PKG_MIRROR_APT_KEY}
            fi

            ECHO_INFO "Resynchronizing the package index files (apt-get update) ..."
            apt-get update

        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} sogo memcached--"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} sope-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} sope-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} sope-postgres"

            PKG_SCRIPTS="${PKG_SCRIPTS} ${MEMCACHED_RC_SCRIPT_NAME} ${SOGO_RC_SCRIPT_NAME}"
        fi
    fi

    # iRedAPD.
    # Don't append 'iredapd' to ${ENABLED_SERVICES} since we don't have
    # RC script ready in early stage.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} python-sqlalchemy python-setuptools python-dns"
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} python-ldap MySQL-python"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} MySQL-python"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} python-psycopg2"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} python-sqlalchemy python-dnspython"
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} python-ldap python-mysqldb"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} python-mysqldb"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} python-psycopg2"

        [ X"${DISTRO}" == X'UBUNTU' ] && ALL_PKGS="${ALL_PKGS} python-pymysql"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py-sqlalchemy py-dnspython"
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} py-ldap py-mysql"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} py-mysql"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} py-psycopg2"
        PKG_SCRIPTS="${PKG_SCRIPTS} iredapd"
    fi

    # OpenBSD: List postfix as last startup script.
    export PKG_SCRIPTS="${PKG_SCRIPTS} ${POSTFIX_RC_SCRIPT_NAME}"

    # iRedAdmin.
    # Force install all dependence to help customers install iRedAdmin-Pro.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} python-jinja2 python-webpy python-netifaces python-beautifulsoup4 python-lxml python-pycurl python-requests"
        [ X"${DISTRO_VERSION}" == X'7' ] && ALL_PKGS="${ALL_PKGS} py-bcrypt"

        [ X"${WEB_SERVER}" == X'NGINX' ] && ALL_PKGS="${ALL_PKGS} uwsgi uwsgi-plugin-python2"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} python-jinja2 python-netifaces python-webpy python-beautifulsoup python-lxml python-pycurl python-requests"

        [ X"${WEB_SERVER}" == X'NGINX' ] && ALL_PKGS="${ALL_PKGS} uwsgi uwsgi-plugin-python"

        # Ubuntu
        [ X"${DISTRO}" == X'UBUNTU' ] && ALL_PKGS="${ALL_PKGS} python-bcrypt"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py-jinja2 py-webpy py-flup py-bcrypt py-beautifulsoup4 py-lxml py-curl py-requests py-netifaces"
    fi

    # Fail2ban
    if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # No port available.
            :
        else
            ALL_PKGS="${ALL_PKGS} fail2ban"
            ENABLED_SERVICES="${ENABLED_SERVICES} ${FAIL2BAN_RC_SCRIPT_NAME}"

            if [ X"${DISTRO}" == X'RHEL' ]; then
                DISABLED_SERVICES="${DISABLED_SERVICES} shorewall gamin gamin-python"
            fi
        fi
    fi

    # netdata
    # Note: netdata installer will generate rc/systemd script and enable the
    #       service automatically.
    if [ X"${USE_NETDATA}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} curl libmnl libuuid lm_sensors nc PyYAML zlib iproute"
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} zlib1g libuuid1 libmnl0 curl lm-sensors netcat"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            # netdata doesn't work on OpenBSD
            :
        fi
    fi

    # Misc packages & services.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} unzip bzip2 acl patch tmpwatch crontabs dos2unix logwatch lz4"
        ENABLED_SERVICES="${ENABLED_SERVICES} crond"
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} bzip2 acl patch cron tofrodos logwatch unzip bsdutils liblz4-tool"
        ENABLED_SERVICES="${ENABLED_SERVICES} cron"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} bzip2 lz4"
    fi

    # Disable ufw service and use iptables init script and rule file
    # shipped in iRedMail instead.
    [ X"${DISTRO}" == X'UBUNTU' ] && export DISABLED_SERVICES="${DISABLED_SERVICES} ufw"

    export ALL_PKGS ENABLED_SERVICES PKG_SCRIPTS

    # Install all packages.
    install_all_pkgs()
    {
        eval ${install_pkg} ${ALL_PKGS} | tee ${PKG_INSTALL_LOG}

        if [ -f ${RUNTIME_DIR}/.pkg_install_failed ]; then
            ECHO_ERROR "Installation failed, please check the terminal output."
            ECHO_ERROR "If you're not sure what the problem is, try to get help in iRedMail"
            ECHO_ERROR "forum: https://forum.iredmail.org/"
            exit 255
        fi
    }

    # Enable/Disable services.
    enable_all_services()
    {
        if [ X"${DISTRO}" == X'RHEL' ]; then
            if [ -f /usr/lib/systemd/system/clamd\@.service ]; then
                if ! grep '\[Install\]' /usr/lib/systemd/system/clamd\@.service &>/dev/null; then
                    echo '[Install]' >> /usr/lib/systemd/system/clamd\@.service
                    echo 'WantedBy=multi-user.target' >> /usr/lib/systemd/system/clamd\@.service
                fi
            fi
        fi

        # Enable/Disable services.
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            for srv in ${PKG_SCRIPTS}; do
                service_control enable ${srv} >> ${INSTALL_LOG} 2>&1
            done
        else
            service_control enable ${ENABLED_SERVICES} >> ${INSTALL_LOG} 2>&1
            service_control disable ${DISABLED_SERVICES} >> ${INSTALL_LOG} 2>&1
        fi

        cat >> ${TIP_FILE} <<EOF
* Enabled services: ${ENABLED_SERVICES}

EOF
    }

    after_package_installation()
    {
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # Create symbol links for Python.
            ln -sf /usr/local/bin/python2.7 /usr/local/bin/python >> ${INSTALL_LOG} 2>&1
            ln -sf /usr/local/bin/python2.7-2to3 /usr/local/bin/2to3 >> ${INSTALL_LOG} 2>&1
            ln -sf /usr/local/bin/python2.7-config /usr/local/bin/python-config >> ${INSTALL_LOG} 2>&1
            ln -sf /usr/local/bin/pydoc2.7  /usr/local/bin/pydoc >> ${INSTALL_LOG} 2>&1

            # Create symbol links for php.
            if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
                ln -sf /usr/local/bin/php-${OB_PHP_VERSION} /usr/local/bin/php >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/php-config-${OB_PHP_VERSION} /usr/local/bin/php-config >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/phpize-${OB_PHP_VERSION} /usr/local/bin/phpize >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/php-fpm-${OB_PHP_VERSION} /usr/local/bin/php-fpm >> ${INSTALL_LOG} 2>&1
            fi

            # uwsgi. Required by iRedAdmin.
            ECHO_INFO "Installing uWSGI from source tarball, please wait."
            cd ${PKG_MISC_DIR}
            tar zxf uwsgi-*.tar.gz
            cd uwsgi-*/
            python setup.py install > ${RUNTIME_DIR}/uwsgi_install.log 2>&1

            # Required by uwsgi applications.
            update_sysctl_param kern.seminfo.semmni 1024
            update_sysctl_param kern.seminfo.semmns 1200
            update_sysctl_param kern.seminfo.semmnu 60
            update_sysctl_param kern.seminfo.semmsl 120
            update_sysctl_param kern.seminfo.semopm 200
        fi

        echo 'export status_after_package_installation="DONE"' >> ${STATUS_FILE}
    }

    # Do not run them with 'check_status_before_run', so that we can always
    # install missed packages and enable/disable new services while re-run
    # iRedMail installer.
    install_all_pkgs
    enable_all_services

    check_status_before_run after_package_installation
}
