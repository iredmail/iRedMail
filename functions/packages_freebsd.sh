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
    export OPENLDAP_VER='26'
    export MYSQL_VER='80'
    export PHP_VER='83'
    export PY3_VER='3.11'
    export PY_FLAVOR='py311'

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        export IREDMAIL_USE_PHP='YES'
    fi

    ALL_PKGS="${PY_FLAVOR}-sqlalchemy14"

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ALL_PKGS="${ALL_PKGS} openldap${OPENLDAP_VER}-server"
        ALL_PKGS="${ALL_PKGS} mysql${MYSQL_VER}-server"

        # Python modules.
        ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-python-ldap ${PY_FLAVOR}-pymysql"

        # Perl modules.
        ALL_PKGS="${ALL_PKGS} p5-DBD-LDAP p5-DBD-mysql"

    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ALL_PKGS="${ALL_PKGS} mysql${MYSQL_VER}-client"

        if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
            ALL_PKGS="${ALL_PKGS} mysql${MYSQL_VER}-server"
        fi

        # Python modules.
        ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-pymysql"

        # Perl modules.
        ALL_PKGS="${ALL_PKGS} p5-DBD-mysql"

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ALL_PKGS="${ALL_PKGS} postgresql${PGSQL_VERSION}-server postgresql${PGSQL_VERSION}-contrib"

        # Python modules.
        ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-psycopg2"

        # Perl modules.
        ALL_PKGS="${ALL_PKGS} p5-DBD-Pg"
    fi

    # Dovecot
    if [[ "${BACKEND}" == "OPENLDAP" ]]; then
        # We need both LDAP and MySQL support.
        ALL_PKGS="${ALL_PKGS} dovecot-mysql dovecot-pigeonhole-mysql"
    elif [[ "${BACKEND}" == "MYSQL" ]]; then
        ALL_PKGS="${ALL_PKGS} dovecot-mysql dovecot-pigeonhole-mysql"
    elif [[ "${BACKEND}" == "PGSQL" ]]; then
        ALL_PKGS="${ALL_PKGS} dovecot-pgsql dovecot-pigeonhole-pgsql"
    fi

    # SpamAssassin
    ALL_PKGS="${ALL_PKGS} spamassassin"

    # Amavisd-new.
    ALL_PKGS="${ALL_PKGS} amavisd-new"

    # Postfix.
    if [[ "${BACKEND}" == 'OPENLDAP' ]]; then
        ALL_PKGS="${ALL_PKGS} postfix-ldap"
    elif [[ "${BACKEND}" == 'MYSQL' ]]; then
        ALL_PKGS="${ALL_PKGS} postfix-mysql"
    elif [[ "${BACKEND}" == 'PGSQL' ]]; then
        ALL_PKGS="${ALL_PKGS} postfix-pgsql p5-Class-DBI-Pg"
    fi

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        ALL_PKGS="${ALL_PKGS} nginx uwsgi-${PY_FLAVOR}"
    fi

    # PHP and extensions
    if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} php${PHP_VER} php${PHP_VER}-extensions"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} php${PHP_VER}-ldap php${PHP_VER}-mysqli"
        elif [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} php${PHP_VER}-mysqli"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} php${PHP_VER}-pdo_pgsql"
        fi
    fi

    ALL_PKGS="${ALL_PKGS} p5-Exporter-Tiny ca_root_nss clamav"

    # mlmmj: mailing list manager
    ALL_PKGS="${ALL_PKGS} mlmmj"

    # Roundcube webmail.
    if [ X"${USE_ROUNDCUBE}" == X'YES' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} php${PHP_VER}-pear-Net_LDAP2"
        ALL_PKGS="${ALL_PKGS} roundcube-php${PHP_VER} mod_php${PHP_VER}"
    fi

    # SOGo groupware.
    if [ X"${USE_SOGO}" == X'YES' ]; then
        if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} sope-mysql sogo-mysqlactivesync"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} sope-pgsql sogo-pgsqlactivesync"
        fi
    fi

    # iRedAPD
    ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-dnspython"

    # iRedAdmin dependencies.
    ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-Jinja2 ${PY_FLAVOR}-bcrypt ${PY_FLAVOR}-simplejson ${PY_FLAVOR}-requests ${PY_FLAVOR}-netifaces"

    # Fail2ban.
    if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-fail2ban"
    fi

    # netdata
    if [ X"${USE_NETDATA}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} netdata"
    fi

    # Misc
    ALL_PKGS="${ALL_PKGS} logwatch"

#    ECHO_INFO "Set pkg repo to: ${FREEBSD_PKG_MIRROR_URL}."
#    [[ -d /usr/local/etc/pkg/repos ]] || mkdir -p /usr/local/etc/pkg/repos
#    cat > /usr/local/etc/pkg/repos/FreeBSD.conf <<EOF
#FreeBSD: {
#  url: "${FREEBSD_PKG_MIRROR_URL}",
#EOF
#
#    if [[ ${FREEBSD_PKG_MIRROR_TYPE} != "" ]]; then
#        cat >> /usr/local/etc/pkg/repos/FreeBSD.conf <<EOF
#  mirror_type: "${FREEBSD_PKG_MIRROR_TYPE}",
#EOF
#    fi
#
#echo "}" >> /usr/local/etc/pkg/repos/FreeBSD.conf

    ECHO_INFO "Run: pkg update -f"
    pkg update -f || exit 255

    # Install all packages.
    ECHO_INFO "Install packages: pkg install -y ${ALL_PKGS}"
    pkg install -y ${ALL_PKGS} || exit 255

    ECHO_DEBUG "Create symbol links for python3."
    ln -sf /usr/local/bin/python${PY3_VER} /usr/local/bin/python3

    # Create syslog.d and logrotate.d
    mkdir -p ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
    mkdir -p ${LOGROTATE_DIR} >> ${INSTALL_LOG} 2>&1
}
