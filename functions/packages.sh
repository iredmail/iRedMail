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
    PIP3_MODULES=''
    ENABLED_SERVICES=''
    DISABLED_SERVICES=''

    # Specify version numbers while installing Python modules with pip.
    PIP_VERSION_PYTHON_LDAP='>=3.3.1'
    PIP_VERSION_UWSGI='>=2.0.20'
    PIP_VERSION_REQUESTS='>=2.24.0'
    PIP_VERSION_PYMYSQL='>=0.10.0'
    PIP_VERSION_PSYCOPG2='>=2.8.5'
    PIP_VERSION_PYCURL='>=7.43.0.5'

    # OpenBSD only
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        PKG_SCRIPTS=''

        OB_PKG_POSTFIX_FLAVOR="stable"
        if [[ "${BACKEND}" == "PGSQL" ]]; then
            # Workaround.
            #
            # postfix-3.7-sasl2-pgsql doesn't work with PostgreSQL. For example,
            # `postmap` command always get `core dump` error like this:
            #
            # # postmap -q "<email>" pgsql:/etc/postfix/pgsql/virtual_mailbox_maps.cf
            # postmap(76889) in free(): bogus pointer (double free?) 0x80
            # Abort trap (core dumped)
            OB_PKG_POSTFIX_FLAVOR="stable35"
        fi

        # Stick to PHP-8.1 for better Roundcube compatibility.
        OB_PKG_PHP_VER="%${OB_PHP_VERSION}"
        OB_PKG_OPENLDAP_SERVER_VER='-2.6.4v0'
        OB_PKG_OPENLDAP_CLIENT_VER='-2.6.4v0'
    fi

    # Install PHP if there's a web server running -- php is too popular.
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        export IREDMAIL_USE_PHP='YES'
    fi

    # Enable rsyslog on Linux.
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} rsyslog"
        DISABLED_SERVICES="${DISABLED_SERVICES} exim sendmail"

        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} rsyslog firewalld"
            ENABLED_SERVICES="${ENABLED_SERVICES} firewalld"
        fi
    fi

    # Python 3.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        # `python3` is 3.6. `python3-*` packages are bulit for Python 3.6.
        ALL_PKGS="${ALL_PKGS} python3 python3-pip python3-pip-wheel python3-requests"
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} python3-setuptools python3-pip python3-wheel python3-requests"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py3-setuptools py3-pip py3-wheel py3-requests"
    fi

    # uwsgi.
    # Required by mlmmjadmin, iredadmin.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} uwsgi-logger-syslog uwsgi-plugin-python3"
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} uwsgi uwsgi-plugin-python3"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        PIP3_MODULES="${PIP3_MODULES} uwsgi${PIP_VERSION_UWSGI}"
    fi

    # Postfix.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${POSTFIX_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} postfix cyrus-sasl cyrus-sasl-lib cyrus-sasl-plain"

        # pcre support is required and available in iRedMail yum repo.
        ALL_PKGS="${ALL_PKGS} postfix-pcre"

        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} postfix-ldap"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} postfix-mysql"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} postfix-pgsql"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        # libsasl2-modules is required for sasl auth (used by relay host which
        # requires sasl auth)
        ALL_PKGS="${ALL_PKGS} postfix postfix-pcre libsasl2-modules"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-ldap%${OB_PKG_POSTFIX_FLAVOR}"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-mysql%${OB_PKG_POSTFIX_FLAVOR}"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-pgsql%${OB_PKG_POSTFIX_FLAVOR}"
    fi

    # Backend: OpenLDAP, MySQL, PGSQL and extra packages.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # OpenLDAP server & client.
        ENABLED_SERVICES="${ENABLED_SERVICES} ${OPENLDAP_RC_SCRIPT_NAME} ${MYSQL_RC_SCRIPT_NAME}"

        if [ X"${DISTRO}" == X'RHEL' ]; then
            if [ X"${DISTRO_VERSION}" == X'8' ]; then
                # Install packages from Symas yum repo.
                ALL_PKGS="${ALL_PKGS} symas-openldap-servers symas-openldap-clients mariadb-server"

                if [ ! -f ${YUM_REPOS_DIR}/symas-openldap.repo ]; then
                    cp -f ${SAMPLE_DIR}/yum/symas-openldap.repo ${YUM_REPOS_DIR}/
                fi
            else
                # openldap-servers is available in EPEL.
                # openldap-clients is available in BaseOS repo.
                ALL_PKGS="${ALL_PKGS} openldap-servers openldap-clients mariadb-server"
            fi

            # Perl module
            [[ X"${DISTRO_VERSION}" == X'8' ]] && ALL_PKGS="${ALL_PKGS} perl-DBD-MySQL"
            [[ X"${DISTRO_VERSION}" == X'9' ]] && ALL_PKGS="${ALL_PKGS} perl-DBD-mysql"

            # Python driver.
            ALL_PKGS="${ALL_PKGS} python3-ldap"
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} slapd ldap-utils postfix-ldap libnet-ldap-perl libdbd-mysql-perl mariadb-server mariadb-client"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} openldap-server${OB_PKG_OPENLDAP_SERVER_VER}"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${OPENLDAP_RC_SCRIPT_NAME}"

            ALL_PKGS="${ALL_PKGS} mariadb-server mariadb-client p5-ldap p5-DBD-mysql"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${MYSQL_RC_SCRIPT_NAME}"
        fi
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        # MySQL server & client.
        ENABLED_SERVICES="${ENABLED_SERVICES} ${MYSQL_RC_SCRIPT_NAME}"
        if [ X"${DISTRO}" == X'RHEL' ]; then
            # Install MySQL client
            ALL_PKGS="${ALL_PKGS} mariadb"

            if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
                ALL_PKGS="${ALL_PKGS} mariadb-server"
            fi

            # Perl module
            [[ X"${DISTRO_VERSION}" == X'8' ]] && ALL_PKGS="${ALL_PKGS} perl-DBD-MySQL"
            [[ X"${DISTRO_VERSION}" == X'9' ]] && ALL_PKGS="${ALL_PKGS} perl-DBD-mysql"

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # MySQL server and client.
            ALL_PKGS="${ALL_PKGS} mariadb-client"

            if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
                ALL_PKGS="${ALL_PKGS} mariadb-server"
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
            ALL_PKGS="${ALL_PKGS} php-cli php-common php-fpm php-gd php-xml php-mysqlnd php-ldap php-pgsql php-mbstring php-pecl-apcu php-intl php-json php-pecl-zip"

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            # Debian 9
            ALL_PKGS="${ALL_PKGS} php-cli php-fpm php-json php-gd php-curl mcrypt php-intl php-xml php-mbstring php-zip"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} php-ldap php-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} php-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} php-pgsql"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} php${OB_PKG_PHP_VER} php-bz2${OB_PKG_PHP_VER} php-imap${OB_PKG_PHP_VER} php-gd${OB_PKG_PHP_VER} php-intl${OB_PKG_PHP_VER} php-zip${OB_PKG_PHP_VER}"

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

    # Amavisd-new, ClamAV, Altermime.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${CLAMAV_CLAMD_SERVICE_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} amavis spamassassin altermime perl-Mail-SPF lz4 clamav clamav-update clamav-server clamav-server-systemd"
        ENABLED_SERVICES="${ENABLED_SERVICES} clamav-freshclam"

        # RHEL uses service name 'clamd@amavisd' instead of clamd.
        DISABLED_SERVICES="${DISABLED_SERVICES} clamd spamassassin"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} amavisd-new libcrypt-openssl-rsa-perl libmail-dkim-perl clamav-freshclam clamav-daemon spamassassin altermime arj nomarch cpio lzop cabextract p7zip-full rpm libmail-spf-perl unrar-free pax lrzip gpg-agent"

        if [ X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} libclamunrar9"
        fi

        ENABLED_SERVICES="${ENABLED_SERVICES} ${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME}"
        DISABLED_SERVICES="${DISABLED_SERVICES} spamassassin"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} rpm2cpio amavisd-new amavisd-new-utils p5-Mail-SPF p5-Mail-SpamAssassin clamav unrar altermime"
        PKG_SCRIPTS="${PKG_SCRIPTS} ${CLAMAV_CLAMD_SERVICE_NAME} ${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    fi

    # mlmmj: mailing list manager
    ALL_PKGS="${ALL_PKGS} mlmmj"

    # mlmmjadmin: RESTful API server used to manage mlmmj.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} python3-ldap python3-PyMySQL"
        fi

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} python3-PyMySQL"
        fi

        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} python3-psycopg2"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            if [ X"${DISTRO}" == X'DEBIAN' -a X"${DISTRO_VERSION}" == X'9' ]; then
                # Debian 9. `pyldap` is a fork of python-ldap.
                ALL_PKGS="${ALL_PKGS} python3-pyldap"
            else
                ALL_PKGS="${ALL_PKGS} python3-ldap"
            fi

            ALL_PKGS="${ALL_PKGS} python3-pymysql"
        fi

        [ X"${BACKEND}" == X'MYSQL' ]   && ALL_PKGS="${ALL_PKGS} python3-pymysql"
        [ X"${BACKEND}" == X'PGSQL' ]   && ALL_PKGS="${ALL_PKGS} python3-psycopg2"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py3-sqlalchemy py3-dnspython py3-pymysql"

        [ X"${BACKEND}" == X'OPENLDAP' ]    && ALL_PKGS="${ALL_PKGS} py3-ldap py3-mysqlclient"
        [ X"${BACKEND}" == X'MYSQL' ]       && ALL_PKGS="${ALL_PKGS} py3-mysqlclient"
        [ X"${BACKEND}" == X'PGSQL' ]       && ALL_PKGS="${ALL_PKGS} py3-psycopg2"

        PKG_SCRIPTS="${PKG_SCRIPTS} mlmmjadmin"
    fi

    # Roundcube
    if [ X"${USE_ROUNDCUBE}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            [[ X"${DISTRO_CODENAME}" == X'rhel' ]] && ALL_PKGS="${ALL_PKGS} php-enchant"
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            if [ X"${BACKEND}" == X'OPENLDAP' ]; then
                ALL_PKGS="${ALL_PKGS} php-ldap"
            fi
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

            if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
                ALL_PKGS="${ALL_PKGS} mysql-libs"
            fi

            ${FETCH_CMD} \
                -O /etc/pki/rpm-gpg/sogo-nightly \
                https://keys.openpgp.org/vks/v1/by-fingerprint/74FFC6D72B925A34B5D356BDF8A27B36A6E2EAE9

            if [ X"$?" != X'0' ]; then
                ECHO_ERROR "Failed in import GPG key for SOGo yum repository."
                ECHO_ERROR "Please try to import it manually with command below:"
                ECHO_ERROR "wget -O /etc/pki/rpm-gpg/sogo-nightly https://keys.openpgp.org/vks/v1/by-fingerprint/74FFC6D72B925A34B5D356BDF8A27B36A6E2EAE9"
            fi

            # Copy yum repo file
            ECHO_INFO "Add yum repo for SOGo: ${YUM_REPOS_DIR}/sogo.repo."
            cat > ${YUM_REPOS_DIR}/sogo.repo <<EOF
[SOGo]
name=SOGo Groupware
baseurl=${SOGO_PKG_MIRROR}/nightly/${SOGO_VERSION}/rhel/\$releasever/\$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/sogo-nightly
EOF

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} memcached sogo sogo-activesync"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} sope4.9-gdl1-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} sope4.9-gdl1-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} sope4.9-gdl1-postgresql"

            ECHO_INFO "Add apt repo for SOGo: ${SOGO_PKG_MIRROR}"
            if [ X"${DISTRO}" == X'DEBIAN' ]; then
                echo "deb ${SOGO_PKG_MIRROR}/nightly/${SOGO_VERSION}/debian ${DISTRO_CODENAME} ${DISTRO_CODENAME}" > /etc/apt/sources.list.d/sogo-nightly.list
            elif [ X"${DISTRO}" == X'UBUNTU' ]; then
                echo "deb ${SOGO_PKG_MIRROR}/nightly/${SOGO_VERSION}/ubuntu ${DISTRO_CODENAME} ${DISTRO_CODENAME}" > /etc/apt/sources.list.d/sogo-nightly.list
            fi

            ECHO_DEBUG "Add GPG key for SOGo apt repo."
            wget -q -O /tmp/sogo-nightly "https://keys.openpgp.org/vks/v1/by-fingerprint/74FFC6D72B925A34B5D356BDF8A27B36A6E2EAE9" >/dev/null
            gpg --dearmor /tmp/sogo-nightly
            mv /tmp/sogo-nightly.gpg /etc/apt/trusted.gpg.d/
            rm -f /tmp/sogo-nightly

            ECHO_INFO "Resynchronizing the package index files (apt update) ..."
            ${APTGET} update

        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} sogo memcached--"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} sope-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} sope-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} sope-postgres"

            PKG_SCRIPTS="${PKG_SCRIPTS} ${MEMCACHED_RC_SCRIPT_NAME} ${SOGO_RC_SCRIPT_NAME}"
        fi
    fi

    # iRedAPD. Requires Python-3.
    # Don't append service name 'iredapd' to ${ENABLED_SERVICES} since we don't
    # have RC script ready in this stage.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} python3-sqlalchemy python3-setuptools python3-dns python3-six"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} python3-ldap python3-PyMySQL"
        fi

        if [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} python3-PyMySQL"
        fi

        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} python3-psycopg2"

    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} python3-sqlalchemy python3-dnspython"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            if [ X"${DISTRO}" == X'DEBIAN' -a X"${DISTRO_VERSION}" == X'9' ]; then
                # pyldap is a fork of python-ldap.
                ALL_PKGS="${ALL_PKGS} python3-pyldap"
            else
                ALL_PKGS="${ALL_PKGS} python3-ldap"
            fi
            ALL_PKGS="${ALL_PKGS} python3-pymysql"
        fi

        [ X"${BACKEND}" == X'MYSQL' ]    && ALL_PKGS="${ALL_PKGS} python3-pymysql"
        [ X"${BACKEND}" == X'PGSQL' ]    && ALL_PKGS="${ALL_PKGS} python3-psycopg2"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py3-sqlalchemy py3-dnspython"
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} py3-ldap py3-mysqlclient"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} py3-mysqlclient"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} py3-psycopg2"
        PKG_SCRIPTS="${PKG_SCRIPTS} iredapd"
    fi

    # OpenBSD: List postfix as last startup script.
    export PKG_SCRIPTS="${PKG_SCRIPTS} ${POSTFIX_RC_SCRIPT_NAME}"

    # iRedAdmin.
    # Force install all dependent packages to help customers install iRedAdmin-Pro.
    # web.py, dnspython, requests, jinja2, mysqldb or pymysql, simplejson.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} python3-jinja2 python3-PyMySQL python3-dns python3-simplejson"
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} python3-jinja2 python3-netifaces python3-bcrypt python3-dnspython python3-simplejson"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            if [ X"${DISTRO}" == X'DEBIAN' -a X"${DISTRO_VERSION}" == X'9' ]; then
                # Debian 9. `pyldap` is a fork of python-ldap.
                ALL_PKGS="${ALL_PKGS} python3-pyldap"
            else
                ALL_PKGS="${ALL_PKGS} python3-ldap"
            fi

            ALL_PKGS="${ALL_PKGS} python3-pymysql"
        fi

        [ X"${BACKEND}" == X'MYSQL' ]   && ALL_PKGS="${ALL_PKGS} python3-pymysql"
        [ X"${BACKEND}" == X'PGSQL' ]   && ALL_PKGS="${ALL_PKGS} python3-psycopg2"

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py3-jinja2 py3-flup py3-bcrypt py3-curl py3-netifaces py3-dnspython py3-simplejson"

        [ X"${BACKEND}" == X'OPENLDAP' ]    && ALL_PKGS="${ALL_PKGS} py3-ldap py3-mysqlclient"
        [ X"${BACKEND}" == X'MYSQL' ]       && ALL_PKGS="${ALL_PKGS} py3-mysqlclient"
        [ X"${BACKEND}" == X'PGSQL' ]       && ALL_PKGS="${ALL_PKGS} py3-psycopg2"
    fi

    # Fail2ban. Install fail2ban and geoip.
    if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} fail2ban"

        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} fail2ban"

            if [ X"${DISTRO_VERSION}" == X'8' ]; then
                # GeoIP is available on CentOS 8.
                ALL_PKGS="${ALL_PKGS} GeoIP GeoIP-GeoLite-data"
            fi

            DISABLED_SERVICES="${DISABLED_SERVICES} shorewall gamin gamin-python"
        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            ALL_PKGS="${ALL_PKGS} fail2ban geoip-bin geoip-database"
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            # No port for fail2ban. Install from source tarball with pip later.
            # rc script will be generated from sample file later.
            ALL_PKGS="${ALL_PKGS} py3-pip geolite2-country geolite2-city"
        fi
    fi

    # netdata
    # Note: netdata installer will generate rc/systemd script and enable the
    #       service automatically.
    if [ X"${USE_NETDATA}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'RHEL' ]; then
            ALL_PKGS="${ALL_PKGS} curl libmnl libuuid lm_sensors nc zlib iproute"
            ALL_PKGS="${ALL_PKGS} python3-pyyaml"

        elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            if [[ X"${DISTRO_CODENAME}" == X"bookworm" ]]; then
                # Note: netcat is a virtual package in Debian 12, so use netcat-traditional
                ALL_PKGS="${ALL_PKGS} zlib1g libuuid1 libmnl0 curl lm-sensors netcat-traditional"
            else
                ALL_PKGS="${ALL_PKGS} zlib1g libuuid1 libmnl0 curl lm-sensors netcat"
            fi    
        elif [ X"${DISTRO}" == X'OPENBSD' ]; then
            # netdata doesn't work on OpenBSD
            :
        fi
    fi

    # Misc packages & services.
    if [ X"${DISTRO}" == X'RHEL' ]; then
        ALL_PKGS="${ALL_PKGS} unzip bzip2 acl patch tmpwatch crontabs dos2unix logwatch lz4"
        ENABLED_SERVICES="${ENABLED_SERVICES} crond"

        [[ ${DISTRO_VERSION} == X'9' ]] && ALL_PKGS="${ALL_PKGS} rsyslog rsyslog-logrotate"
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        ALL_PKGS="${ALL_PKGS} bzip2 acl patch cron tofrodos logwatch unzip bsdutils liblz4-tool rsyslog"
        ENABLED_SERVICES="${ENABLED_SERVICES} cron"
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} bzip2 lz4 unzip--"
    fi

    # Firewall
    if [ X"${DISTRO}" == X'DEBIAN' ]; then
        ALL_PKGS="${ALL_PKGS} nftables"
        [[ ${USE_NFTABLES} == "YES" ]] && ENABLED_SERVICES="${ENABLED_SERVICES} nftables"
    elif [ X"${DISTRO}" == X'UBUNTU' ]; then
        # Disable ufw service.
        export DISABLED_SERVICES="${DISABLED_SERVICES} ufw"

        # Use nftables since Ubuntu 20.04.
        ALL_PKGS="${ALL_PKGS} nftables"
        ENABLED_SERVICES="${ENABLED_SERVICES} nftables"
    fi

    export ALL_PKGS ENABLED_SERVICES DISABLED_SERVICES PKG_SCRIPTS

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
                service_control enable ${srv}
            done
        else
            service_control enable ${ENABLED_SERVICES}
            service_control disable ${DISABLED_SERVICES}
        fi

        cat >> ${TIP_FILE} <<EOF
* Enabled services: ${ENABLED_SERVICES}

EOF
    }

    after_package_installation()
    {
        pip_args=''
        if [ X"${PIP_MIRROR_SITE}" != X'' -a X"${PIP_TRUSTED_HOST}" != X'' ]; then
            pip_args="-i ${PIP_MIRROR_SITE} --trusted-host ${PIP_TRUSTED_HOST}"
        fi

        if [ X"${PIP3_MODULES}" != X'' ]; then
            ECHO_INFO "Installing required Python-3 modules with pip3:${PIP3_MODULES}"
            ${CMD_PIP3} install ${pip_args} -U ${PIP3_MODULES} 2>&1 | tee ${RUNTIME_DIR}/pip3.log
        fi

        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # Create symbol links for php.
            if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
                ln -sf /usr/local/bin/php-${OB_PHP_VERSION} /usr/local/bin/php >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/php-config-${OB_PHP_VERSION} /usr/local/bin/php-config >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/phpize-${OB_PHP_VERSION} /usr/local/bin/phpize >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/php-fpm-${OB_PHP_VERSION} /usr/local/bin/php-fpm >> ${INSTALL_LOG} 2>&1
            fi

            ECHO_DEBUG "Create symbol link: /usr/local/bin/python${PYTHON_VERSION} -> /usr/local/bin/python3"
            if [ ! -e /usr/local/bin/python3 ]; then
                ln -sf /usr/local/bin/python${PYTHON_VERSION} /usr/local/bin/python3
            fi

            # Fail2ban.
            if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
                # https://github.com/fail2ban/fail2ban/wiki/How-to-install-or-upgrade-fail2ban-manually
                ECHO_INFO "Installing Fail2ban from source tarball, please wait for a moment."

                cd ${PKG_MISC_DIR}
                tar zxf fail2ban-${FAIL2BAN_VERSION}.tar.gz
                cd fail2ban-${FAIL2BAN_VERSION}
                bash fail2ban-2to3 &>${RUNTIME_DIR}/fail2ban-2to3.log
                python3 setup.py install --without-tests &> ${RUNTIME_DIR}/fail2ban_install.log
                cd .. && rm -rf fail2ban-${FAIL2BAN_VERSION}
            fi

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
