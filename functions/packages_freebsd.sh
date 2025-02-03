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
    export MARIADB_VER='106'
    export PHP_VER='82'
    export PY3_VER='3.11'
    export PY_FLAVOR='py311'
    export PGSQL_VER='16'

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        export IREDMAIL_USE_PHP='YES'
    fi

    ALL_PKGS="${PY_FLAVOR}-Jinja2 ${PY_FLAVOR}-netifaces ${PY_FLAVOR}-bcrypt ${PY_FLAVOR}-requests"

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ALL_PKGS="${ALL_PKGS} openldap${OPENLDAP_VER}-server ${PY_FLAVOR}-python-ldap"
        ALL_PKGS="${ALL_PKGS} mariadb${MARIADB_VER}-server"

    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ALL_PKGS="${ALL_PKGS} mariadb${MARIADB_VER}-client"

        if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
            ALL_PKGS="${ALL_PKGS} mariadb${MARIADB_VER}-server"
        fi

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ALL_PKGS="${ALL_PKGS} postgresql${PGSQL_VER}-server postgresql${PGSQL_VER}-contrib"
    fi

    # Dovecot
    ALL_PKGS="${ALL_PKGS} dovecot dovecot-pigeonhole"
    if [[ "${BACKEND}" == "OPENLDAP" ]]; then
        ALL_PKGS="${ALL_PKGS} dovecot dovecot-pigeonhole"
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
    elif [[ "${BACKEND}" == 'PGSQL' ]]; then
        ALL_PKGS="${ALL_PKGS} postfix-pgsql p5-Class-DBI-Pg"
    fi

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        ALL_PKGS="${ALL_PKGS} nginx uwsgi"
    fi

    # PHP and extensions
    if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} php${PHP_VER} php${PHP_VER}-extensions"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} php${PHP_VER}-ldap php${PHP_VER}-mysqli"
        elif [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} php${PHP_VER}-mysqli"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} php${PHP_VER}-pgsql"
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
        ALL_PKGS="${ALL_PKGS} sope sogo"

        if [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-psycopg2 dovecot-pgsql dovecot-pigeonhole-pgsql p5-Class-DBI-Pg"
        fi
    fi

    # iRedAPD
    ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-dnspython"

    # iRedAdmin dependencies: Jinja2, bcrypt
    ALL_PKGS="${ALL_PKGS} ${PY_FLAVOR}-simplejson"

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

    # Install all packages.
    pkg -y install ${ALL_PKGS}

    ECHO_DEBUG "Create symbol links for python3."
    ln -sf /usr/local/bin/python${PY3_VER} /usr/local/bin/python3

    # Create syslog.d and logrotate.d
    mkdir -p ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
    mkdir -p ${LOGROTATE_DIR} >> ${INSTALL_LOG} 2>&1
}
