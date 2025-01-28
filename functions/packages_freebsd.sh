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

# ASSUMTION - user changed pkg source to latest from quarterly
# ASSUMTION - user ran pkg update and then pkg install bash
# OBSERVATION - it is better if we loose the Mariadb option for FreeBSD
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

    pkg install -y archivers/p5-Archive-Tar p5-Authen-SASL www/sogo archivers/arj archivers/rar net/openslp security/gnupg security/ca_root_nss security/clamav security/amavisd-new
    pkg install -y ${PY_FLAVOR}-sqlalchemy14 ${PY_FLAVOR}-Jinja2 ${PY_FLAVOR}-dnspython ${PY_FLAVOR}-bcrypt ${PY_FLAVOR}-netifaces ${PY_FLAVOR}-requests ${PY_FLAVOR}-pymysql uwsgi-${PY_FLAVOR} ${PY_FLAVOR}-simplejson

    if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
        pkg install -y lang/php${PHP_VER}-extensions
        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            pkg install -y net/php${PHP_VER}-ldap databases/php${PHP_VER}-mysqli databases/mariadb${MARIADB_VER}-server
        #elif [ X"${BACKEND}" == X'MYSQL' ]; then
        #    pkg install -y databases/php${PHP_VER}-mysqli
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            pkg install -y databases/php${PHP_VER}-pgsql
        fi
    fi

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        pkg install -y www/nginx
    fi

    # Roundcube webmail.
    if [ X"${USE_ROUNDCUBE}" == X'YES' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] &&  pkg install -y php${PHP_VER}-pear-Net_LDAP2
        pkg install -y roundcube-php${PHP_VER} www/mod_php${PHP_VER} php${PHP_VER}-pecl-apcu
    fi

     if [ X"${BACKEND}" == X'OPENLDAP' ]; then
         pkg install -y ${PY_FLAVOR}-python-ldap net/openldap${OPENLDAP_VER}-server mail/dovecot dovecot-pigeonhole postfix-ldap
     #elif [ X"${BACKEND}" == X'MYSQL' ]; then
         #pkg install -y databases/mariadb${MARIADB_VER}-server
         # NO PACKAGE FOR POSTFIX WITH MARIADB FOR BACKEND
     elif [ X"${BACKEND}" == X'PGSQL' ]; then
         pkg install -y databases/postgresql${PGSQL_VER}-server databases/postgresql${PGSQL_VER}-contrib ${PY_FLAVOR}-psycopg2 dovecot-pgsql dovecot-pigeonhole-pgsql postfix-pgsql p5-Class-DBI-Pg
    fi

    # Fail2ban.
    #if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
    #    # python-ldap.
    #     pkg install -y security/${PY_FLAVOR}-fail2ban"
    #fi

    # Misc
    pkg install -y mail/mlmmj sysutils/logwatch

    if [ X"${USE_NETDATA}" == X'YES' ]; then
        pkg install -y net-mgmt/netdata
    fi

    ECHO_DEBUG "Create symbol links for python3."
    ln -sf /usr/local/bin/python${PY3_VER} /usr/local/bin/python3

    # Create syslog.d and logrotate.d
    mkdir -p ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
    mkdir -p ${LOGROTATE_DIR} >> ${INSTALL_LOG} 2>&1
}