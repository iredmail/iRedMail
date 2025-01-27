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
    export PREFERRED_OPENLDAP_VER='26'
    export PREFERRED_MARIADB_VER='106'
    export PREFERRED_PHP_VER='82'
    export PREFERRED_PY3_VER='3.11'
    export PREFERRED_PY_FLAVOR='py311'
    export PREFERRED_PGSQL_VER='16'

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        export IREDMAIL_USE_PHP='YES'
    fi

    pkg install -y archivers/p5-Archive-Tar
    pkg install -y p5-Authen-SASL
    pkg install -y www/sogo

    pkg install -y ${PREFERRED_PY_FLAVOR}-sqlalchemy14
    pkg install -y ${PREFERRED_PY_FLAVOR}-Jinja2
    pkg install -y ${PREFERRED_PY_FLAVOR}-dnspython
    pkg install -y ${PREFERRED_PY_FLAVOR}-bcrypt
    pkg install -y ${PREFERRED_PY_FLAVOR}-netifaces
    pkg install -y ${PREFERRED_PY_FLAVOR}-requests
    pkg install -y ${PREFERRED_PY_FLAVOR}-pymysql
    pkg install -y uwsgi-${PREFERRED_PY_FLAVOR}
    pkg install -y ${PREFERRED_PY_FLAVOR}-simplejson

    # probably not needed
    pkg install -y archivers/arj
    pkg install -y archivers/rar

    pkg install -y net/openslp
    pkg install -y security/gnupg
    pkg install -y security/ca_root_nss
    pkg install -y security/clamav
    pkg install -y security/amavisd-new

    if [ X"${IREDMAIL_USE_PHP}" == X'YES' ]; then
        pkg install -y lang/php${PREFERRED_PHP_VER}-extensions
        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            pkg install -y net/php${PREFERRED_PHP_VER}-ldap
            pkg install -y databases/php${PREFERRED_PHP_VER}-mysqli 
            pkg install -y databases/mariadb${PREFERRED_MARIADB_VER}-server
        #elif [ X"${BACKEND}" == X'MYSQL' ]; then
        #    pkg install -y databases/php${PREFERRED_PHP_VER}-mysqli
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            pkg install -y databases/php${PREFERRED_PHP_VER}-pgsql
        fi
    fi

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        pkg install -y www/nginx
    fi

    # Roundcube webmail.
    if [ X"${USE_ROUNDCUBE}" == X'YES' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] &&  pkg install -y php${PREFERRED_PHP_VER}-pear-Net_LDAP2
        pkg install -y roundcube-php${PREFERRED_PHP_VER}
        pkg install -y www/mod_php${PREFERRED_PHP_VER}
        pkg install -y php${PREFERRED_PHP_VER}-pecl-apcu
    fi

     if [ X"${BACKEND}" == X'OPENLDAP' ]; then
         pkg install -y ${PREFERRED_PY_FLAVOR}-python-ldap
         pkg install -y net/openldap${PREFERRED_OPENLDAP_VER}-server
         pkg install -y mail/dovecot
         pkg install -y dovecot-pigeonhole
         pkg install -y mail/postfix
     #elif [ X"${BACKEND}" == X'MYSQL' ]; then
         #pkg install -y databases/mariadb${PREFERRED_MARIADB_VER}-server
         # NO PACKAGE FOR POSTFIX WITH MARIADB FOR BACKEND
     elif [ X"${BACKEND}" == X'PGSQL' ]; then
         pkg install -y databases/postgresql${PREFERRED_PGSQL_VER}-server
         pkg install -y databases/postgresql${PREFERRED_PGSQL_VER}-contrib
         pkg install -y ${PREFERRED_PY_FLAVOR}-psycopg2
         pkg install -y mail/dovecot-pgsql
         pkg install -y dovecot-pigeonhole-pgsql
         pkg install -y postfix-pgsql
         pkg install -y p5-Class-DBI-Pg # for amavisd-new
    fi

    # Fail2ban.
    #if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
    #    # python-ldap.
    #     pkg install -y security/${PREFERRED_PY_FLAVOR}-fail2ban"
    #fi

    # Misc
    pkg install -y mail/mlmmj
    pkg install -y sysutils/logwatch

    if [ X"${USE_NETDATA}" == X'YES' ]; then
        pkg install -y net-mgmt/netdata
    fi

    ECHO_DEBUG "Create symbol links for python3."
    ln -sf /usr/local/bin/python${PREFERRED_PY3_VER} /usr/local/bin/python3

    # Create syslog.d and logrotate.d
    mkdir -p ${SYSLOG_CONF_DIR} >> ${INSTALL_LOG} 2>&1
    mkdir -p ${LOGROTATE_DIR} >> ${INSTALL_LOG} 2>&1
}