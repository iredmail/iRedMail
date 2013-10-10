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
    ALL_PORTS=''            # Port name under /usr/ports/. e.g. mail/dovecot2.
    ENABLED_SERVICES=''     # Scripts under /usr/local/etc/rc.d/
    DISABLED_SERVICES=''    # Scripts under /usr/local/etc/rc.d/

    # Extension used for backup file during in-place editing.
    SED_EXTENSION="iredmail"
    CMD_SED="sed -i ${SED_EXTENSION}"

    # Make it don't popup dialog while building ports.
    export PACKAGE_BUILDING='yes'
    export BATCH='yes'
    export WANT_OPENLDAP_VER='24'
    export WANT_MYSQL_VER='55'
    export WANT_PGSQL_VER='91'
    export WANT_POSTFIX_VER='27'
    export WANT_BDB_VER='48'

    freebsd_add_make_conf 'WITHOUT_X11' 'yes'
    freebsd_add_make_conf 'WANT_OPENLDAP_VER' "${WANT_OPENLDAP_VER}"
    freebsd_add_make_conf 'WANT_MYSQL_VER' "${WANT_MYSQL_VER}"
    freebsd_add_make_conf 'WANT_PGSQL_VER' "${WANT_PGSQL_VER}"
    freebsd_add_make_conf 'DEFAULT_VERSIONS' 'python=2.7 python2=2.7'
    freebsd_add_make_conf 'APACHE_PORT' 'www/apache22'
    freebsd_add_make_conf 'WITH_SASL' 'yes'
    freebsd_add_make_conf 'WANT_BDB_VER' "${WANT_BDB_VER}"

    for p in \
        openldap${WANT_OPENLDAP_VER} \
        openldap${WANT_OPENLDAP_VER}-sasl-client \
        openldap${WANT_OPENLDAP_VER}-client \
        mysql mysql${WANT_MYSQL_VER}-client \
        postgresql${WANT_PGSQL_VER} postgresql${WANT_PGSQL_VER}-contrib \
        m4 libiconv cyrus-sasl2 perl openslp dovecot2 policyd2 \
        ca_root_nss libssh2 curl libusb pth gnupg p5-IO-Socket-SSL \
        p5-Archive-Tar p5-Net-DNS p5-Mail-SpamAssassin p5-Authen-SASL \
        amavisd-new clamav apr python27 apache22 php5 php5-extensions \
        php5-gd roundcube postfix MySQLdb p7zip phpMyAdmin; do
        mkdir -p /var/db/ports/${p} 2>/dev/null
    done

    # m4. DEPENDENCE.
    cat > /var/db/ports/m4/options <<EOF
WITHOUT_LIBSIGSEGV=true
EOF

    # libiconv. DEPENDENCE.
    cat > /var/db/ports/libiconv/options <<EOF
WITH_EXTRA_ENCODINGS=true
WITH_EXTRA_PATCHES=true
EOF

    # Cyrus-SASL2. DEPENDENCE.
    cat > /var/db/ports/cyrus-sasl2/options <<EOF
_FILE_COMPLETE_OPTIONS_LIST= BDB MYSQL PGSQL SQLITE SQLITE3 ALWAYSTRUE AUTHDAEMOND DEV_URANDOM KEEP_DB_OPEN OBSOLETE_CRAM_ATTR CRAM DIGEST LOGIN NTLM OTP PLAIN SCRAM
OPTIONS_FILE_SET+=BDB
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=SQLITE
OPTIONS_FILE_UNSET+=SQLITE3
OPTIONS_FILE_UNSET+=ALWAYSTRUE
OPTIONS_FILE_UNSET+=AUTHDAEMOND
OPTIONS_FILE_UNSET+=DEV_URANDOM
OPTIONS_FILE_UNSET+=KEEP_DB_OPEN
OPTIONS_FILE_UNSET+=OBSOLETE_CRAM_ATTR
OPTIONS_FILE_UNSET+=CRAM
OPTIONS_FILE_UNSET+=DIGEST
OPTIONS_FILE_SET+=LOGIN
OPTIONS_FILE_UNSET+=NTLM
OPTIONS_FILE_UNSET+=OTP
OPTIONS_FILE_SET+=PLAIN
OPTIONS_FILE_UNSET+=SCRAM
EOF

    # Perl 5.8. REQUIRED.
    cat > /var/db/ports/perl/options <<EOF
WITHOUT_DEBUGGING=true
WITH_GDBM=true
WITH_PERL_MALLOC=true
WITH_PERL_64BITINT=true
WITH_THREADS=true
WITH_PTHREAD=true
WITH_MULTIPLICITY=true
WITH_SITECUSTOMIZE=true
WITH_USE_PERL=true
EOF

    # OpenSLP. DEPENDENCE.
    cat > /var/db/ports/openslp/options <<EOF
OPTIONS_FILE_SET+=SLP_SECURITY
OPTIONS_FILE_SET+=ASYNC_API
EOF

    # OpenLDAP. REQUIRED for LDAP backend.
    cat > /var/db/ports/openldap${WANT_OPENLDAP_VER}/options <<EOF
OPTIONS_FILE_SET+=ACCESSLOG
OPTIONS_FILE_UNSET+=ACI
OPTIONS_FILE_UNSET+=AUDITLOG
OPTIONS_FILE_SET+=BDB
OPTIONS_FILE_UNSET+=COLLECT
OPTIONS_FILE_UNSET+=CONSTRAINT
OPTIONS_FILE_UNSET+=DDS
OPTIONS_FILE_UNSET+=DEREF
OPTIONS_FILE_UNSET+=DNSSRV
OPTIONS_FILE_UNSET+=DYNACL
OPTIONS_FILE_SET+=DYNAMIC_BACKENDS
OPTIONS_FILE_UNSET+=DYNGROUP
OPTIONS_FILE_UNSET+=DYNLIST
OPTIONS_FILE_UNSET+=FETCH
OPTIONS_FILE_UNSET+=MDB
OPTIONS_FILE_UNSET+=MEMBEROF
OPTIONS_FILE_UNSET+=ODBC
OPTIONS_FILE_UNSET+=PASSWD
OPTIONS_FILE_UNSET+=PERL
OPTIONS_FILE_UNSET+=PPOLICY
OPTIONS_FILE_UNSET+=PROXYCACHE
OPTIONS_FILE_UNSET+=REFINT
OPTIONS_FILE_UNSET+=RELAY
OPTIONS_FILE_UNSET+=RETCODE
OPTIONS_FILE_UNSET+=RLOOKUPS
OPTIONS_FILE_UNSET+=RWM
OPTIONS_FILE_SET+=SASL
OPTIONS_FILE_SET+=SEQMOD
OPTIONS_FILE_UNSET+=SHELL
OPTIONS_FILE_SET+=SLAPI
OPTIONS_FILE_UNSET+=SLP
OPTIONS_FILE_UNSET+=SMBPWD
OPTIONS_FILE_UNSET+=SOCK
OPTIONS_FILE_SET+=SSSVLV
OPTIONS_FILE_SET+=SYNCPROV
OPTIONS_FILE_SET+=TCP_WRAPPERS
OPTIONS_FILE_UNSET+=TRANSLUCENT
OPTIONS_FILE_UNSET+=UNIQUE
OPTIONS_FILE_UNSET+=VALSORT
EOF

    cat > /var/db/ports/openldap${WANT_OPENLDAP_VER}-client/options <<EOF
OPTIONS_FILE_UNSET+=FETCH
OPTIONS_FILE_SET+=SASL
EOF

    cat > /var/db/ports/openldap${WANT_OPENLDAP_VER}-sasl-client/options <<EOF
OPTIONS_FILE_UNSET+=FETCH
OPTIONS_FILE_SET+=SASL
EOF

    # MySQL server. Required in both backend OpenLDAP and MySQL.
    # Server
    cat > /var/db/ports/mysql/options <<EOF
OPTIONS_FILE_SET+=OPENSSL
OPTIONS_FILE_UNSET+=FASTMTX
EOF

    # mysql client
    cat > /var/db/ports/mysql${WANT_MYSQL_VER}-client/options <<EOF
OPTIONS_FILE_SET+=OPENSSL
OPTIONS_FILE_UNSET+=FASTMTX
EOF

    # PostgreSQL
    cat > /var/db/ports/postgresql${WANT_PGSQL_VER}/options <<EOF
OPTIONS_FILE_SET+=NLS
OPTIONS_FILE_UNSET+=DTRACE
OPTIONS_FILE_UNSET+=PAM
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_UNSET+=MIT_KRB5
OPTIONS_FILE_UNSET+=HEIMDAL_KRB5
OPTIONS_FILE_UNSET+=GSSAPI
OPTIONS_FILE_UNSET+=OPTIMIZED_CFLAGS
OPTIONS_FILE_SET+=XML
OPTIONS_FILE_SET+=TZDATA
OPTIONS_FILE_UNSET+=DEBUG
OPTIONS_FILE_SET+=ICU
OPTIONS_FILE_SET+=INTDATE
OPTIONS_FILE_SET+=SSL
EOF

    cat > /var/db/ports/postgresql${WANT_PGSQL_VER}-contrib/options <<EOF
OPTIONS_FILE_UNSET+=OSSP_UUID
EOF

    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        ALL_PORTS="${ALL_PORTS} net/openldap${WANT_OPENLDAP_VER}-sasl-client net/openldap${WANT_OPENLDAP_VER}-server databases/mysql${WANT_MYSQL_VER}-server"
        ENABLED_SERVICES="${ENABLED_SERVICES} ${OPENLDAP_RC_SCRIPT_NAME} ${MYSQL_RC_SCRIPT_NAME}"
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ALL_PORTS="${ALL_PORTS} databases/mysql${WANT_MYSQL_VER}-server"
        ENABLED_SERVICES="${ENABLED_SERVICES} ${MYSQL_RC_SCRIPT_NAME}"
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ALL_PORTS="${ALL_PORTS} databases/postgresql${WANT_PGSQL_VER}-server databases/postgresql${WANT_PGSQL_VER}-contrib"
        ENABLED_SERVICES="${ENABLED_SERVICES} ${PGSQL_RC_SCRIPT_NAME}"
    fi

    # Dovecot v2.0.x. REQUIRED.
    cat > /var/db/ports/dovecot2/options <<EOF
OPTIONS_FILE_SET+=DOCS
OPTIONS_FILE_SET+=EXAMPLES
OPTIONS_FILE_UNSET+=GSSAPI
OPTIONS_FILE_SET+=KQUEUE
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_SET+=LIBWRAP
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=SOLR
OPTIONS_FILE_UNSET+=SQLITE
OPTIONS_FILE_SET+=SSL
OPTIONS_FILE_UNSET+=VPOPMAIL
EOF

    # Note: dovecot-sieve will install dovecot first.
    ALL_PORTS="${ALL_PORTS} mail/dovecot2 mail/dovecot2-pigeonhole"
    ENABLED_SERVICES="${ENABLED_SERVICES} dovecot"

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP#OPTIONS_FILE_SET+=LDAP#' /var/db/ports/dovecot2/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/dovecot2/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/dovecot2/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/dovecot2/options
    fi
    rm -f /var/db/ports/dovecot2/options${SED_EXTENSION} &>/dev/null

    # ca_root_nss. DEPENDENCE.
    cat >/var/db/ports/ca_root_nss/options <<EOF
OPTIONS_FILE_SET+=ETCSYMLINK
EOF

    # libssh2. DEPENDENCE.
    cat > /var/db/ports/libssh2/options <<EOF
OPTIONS_FILE_UNSET+=GCRYPT
OPTIONS_FILE_UNSET+=TRACE
OPTIONS_FILE_SET+=ZLIB
EOF

    # Curl. DEPENDENCE.
    cat > /var/db/ports/curl/options <<EOF
OPTIONS_FILE_UNSET+=CARES
OPTIONS_FILE_UNSET+=CURL_DEBUG
OPTIONS_FILE_UNSET+=GNUTLS
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_UNSET+=KERBEROS4
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_UNSET+=LDAPS
OPTIONS_FILE_SET+=LIBIDN
OPTIONS_FILE_SET+=LIBSSH2
OPTIONS_FILE_UNSET+=NTLM
OPTIONS_FILE_SET+=OPENSSL
OPTIONS_FILE_SET+=CA_BUNDLE
OPTIONS_FILE_SET+=PROXY
OPTIONS_FILE_UNSET+=RTMP
OPTIONS_FILE_UNSET+=TRACKMEMORY
EOF

    # libusb. DEPENDENCE.
    cat > /var/db/ports/libusb/options <<EOF
OPTIONS_FILE_UNSET+=SGML
EOF

    # pth. DEPENDENCE.
    cat > /var/db/ports/pth/options <<EOF
OPTIONS_FILE_SET+=OPTIMIZED_CFLAGS
EOF

    # GnuPG. DEPENDENCE.
    cat > /var/db/ports/gnupg/options <<EOF
OPTIONS_FILE_UNSET+=PINENTRY
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_SET+=SCDAEMON
OPTIONS_FILE_SET+=CURL
OPTIONS_FILE_UNSET+=GPGSM
OPTIONS_FILE_SET+=KDNS
OPTIONS_FILE_UNSET+=STD_SOCKET
OPTIONS_FILE_SET+=NLS
EOF

    # p5-IO-Socket-SSL. DEPENDENCE.
    cat > /var/db/ports/p5-IO-Socket-SSL/options <<EOF
OPTIONS_FILE_SET+=EXAMPLES
OPTIONS_FILE_SET+=IDN
OPTIONS_FILE_SET+=IPV6
EOF

    cat > /var/db/ports/p5-Archive-Tar/options <<EOF
OPTIONS_FILE_SET+=TEXTDIFF
EOF

    cat > /var/db/ports/p5-Net-DNS/options <<EOF
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_SET+=IDN
EOF

    # SpamAssassin. REQUIRED.
    cat > /var/db/ports/p5-Mail-SpamAssassin/options <<EOF
WITH_AS_ROOT=true
WITH_SPAMC=true
WITH_SACOMPILE=true
WITH_DKIM=true
WITH_SSL=true
WITH_GNUPG=true
WITHOUT_MYSQL=true
WITHOUT_PGSQL=true
WITH_RAZOR=true
WITH_SPF_QUERY=true
WITH_RELAY_COUNTRY=true
EOF

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#WITHOUT_MYSQL=true#WITH_MYSQL=true#' /var/db/ports/p5-Mail-SpamAssassin/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#WITHOUT_PGSQL=true#WITH_PGSQL=true#' /var/db/ports/p5-Mail-SpamAssassin/options
    fi
    rm -f /var/db/ports/p5-Mail-SpamAssassin/options${SED_EXTENSION} &>/dev/null

    ALL_PORTS="${ALL_PORTS} devel/pth security/gnupg dns/p5-Net-DNS mail/p5-Mail-SpamAssassin"
    DISABLED_SERVICES="${DISABLED_SERVICES} spamd"

    cat > /var/db/ports/p5-Authen-SASL/options <<EOF
OPTIONS_FILE_SET+=KERBEROS
EOF

    # AlterMIME. REQUIRED.
    ALL_PORTS="${ALL_PORTS} security/p5-Authen-SASL mail/altermime"

    cat > /var/db/ports/p7zip/options <<EOF
OPTIONS_FILE_SET+=MINIMAL
OPTIONS_FILE_SET+=MODULES
EOF

    # Amavisd-new. REQUIRED.
    cat > /var/db/ports/amavisd-new/options <<EOF
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_SET+=BDB
OPTIONS_FILE_SET+=SNMP
OPTIONS_FILE_UNSET+=SQLITE
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_SET+=SASL
OPTIONS_FILE_SET+=SPAMASSASSIN
OPTIONS_FILE_SET+=P0F
OPTIONS_FILE_SET+=ALTERMIME
OPTIONS_FILE_SET+=FILE
OPTIONS_FILE_UNSET+=RAR
OPTIONS_FILE_SET+=UNRAR
OPTIONS_FILE_SET+=ARJ
OPTIONS_FILE_SET+=UNARJ
OPTIONS_FILE_SET+=LHA
OPTIONS_FILE_SET+=ARC
OPTIONS_FILE_SET+=NOMARCH
OPTIONS_FILE_SET+=CAB
OPTIONS_FILE_SET+=RPM
OPTIONS_FILE_SET+=ZOO
OPTIONS_FILE_SET+=UNZOO
OPTIONS_FILE_SET+=LZOP
OPTIONS_FILE_SET+=FREEZE
OPTIONS_FILE_SET+=P7ZIP
OPTIONS_FILE_SET+=MSWORD
OPTIONS_FILE_SET+=TNEF
EOF

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP#OPTIONS_FILE_SET+=LDAP#' /var/db/ports/amavisd-new/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/amavisd-new/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/amavisd-new/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/amavisd-new/options
    fi
    rm -f /var/db/ports/amavisd-new/options${SED_EXTENSION} &>/dev/null

    # Enable RAR support on i386 only since it requires 32-bit libraries
    # installed under /usr/lib32.
    if [ X"${ARCH}" == X'i386' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=RAR#OPTIONS_FILE_SET+=RAR#' /var/db/ports/amavisd-new/options
        rm -f /var/db/ports/amavisd-new/options${SED_EXTENSION} &>/dev/null
    fi

    ALL_PORTS="${ALL_PORTS} security/amavisd-new"
    ENABLED_SERVICES="${ENABLED_SERVICES} ${AMAVISD_RC_SCRIPT_NAME}"

    # Postfix. REQUIRED.
    cat > /var/db/ports/postfix/options <<EOF
OPTIONS_FILE_SET+=PCRE
OPTIONS_FILE_SET+=SASL2
OPTIONS_FILE_UNSET+=DOVECOT
OPTIONS_FILE_SET+=DOVECOT2
OPTIONS_FILE_UNSET+=SASLKRB5
OPTIONS_FILE_UNSET+=SASLKMIT
OPTIONS_FILE_SET+=TLS
OPTIONS_FILE_SET+=BDB
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=SQLITE
OPTIONS_FILE_UNSET+=OPENLDAP
OPTIONS_FILE_UNSET+=LDAP_SASL
OPTIONS_FILE_SET+=CDB
OPTIONS_FILE_UNSET+=NIS
OPTIONS_FILE_UNSET+=VDA
OPTIONS_FILE_UNSET+=TEST
OPTIONS_FILE_UNSET+=SPF
OPTIONS_FILE_UNSET+=INST_BASE
EOF

    # Enable ldap/mysql/pgsql support in Postfix
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=OPENLDAP#OPTIONS_FILE_SET+=OPENLDAP#' /var/db/ports/postfix/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP_SASL#OPTIONS_FILE_SET+=LDAP_SASL#' /var/db/ports/postfix/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/postfix/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/postfix/options
    fi
    rm -f /var/db/ports/postfix/options${SED_EXTENSION} &>/dev/null

    ALL_PORTS="${ALL_PORTS} devel/pcre mail/postfix${WANT_POSTFIX_VER}"
    ENABLED_SERVICES="${ENABLED_SERVICES} postfix"
    DISABLED_SERVICES="${DISABLED_SERVICES} sendmail sendmail_submit sendmail_outbound sendmail_msq_queue"

    # Apr. DEPENDENCE.
    cat > /var/db/ports/apr/options <<EOF
OPTIONS_FILE_SET+=SSL
OPTIONS_FILE_SET+=THREADS
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_SET+=DEVRANDOM
OPTIONS_FILE_SET+=BDB
OPTIONS_FILE_SET+=GDBM
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=NDBM
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=SQLITE
OPTIONS_FILE_UNSET+=FREETDS
EOF

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP#OPTIONS_FILE_SET+=LDAP#' /var/db/ports/apr/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/apr/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/apr/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/apr/options
    fi
    rm -f /var/db/ports/apr/options${SED_EXTENSION} &>/dev/null

    # Python v2.7
    cat > /var/db/ports/python27/options <<EOF
OPTIONS_FILE_SET+=EXAMPLES
OPTIONS_FILE_SET+=FPECTL
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_SET+=NLS
OPTIONS_FILE_UNSET+=PTH
OPTIONS_FILE_SET+=PYMALLOC
OPTIONS_FILE_UNSET+=SEM
OPTIONS_FILE_SET+=THREADS
OPTIONS_FILE_UNSET+=UCS2
OPTIONS_FILE_SET+=UCS4
EOF

    # Apache v2.2.x. REQUIRED.
    cat > /var/db/ports/apache22/options <<EOF
OPTIONS_FILE_SET+=THREADS
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=SQLITE
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_SET+=BDB
OPTIONS_FILE_SET+=AUTH_BASIC
OPTIONS_FILE_SET+=AUTH_DIGEST
OPTIONS_FILE_SET+=AUTHN_FILE
OPTIONS_FILE_SET+=AUTHN_DBD
OPTIONS_FILE_SET+=AUTHN_DBM
OPTIONS_FILE_SET+=AUTHN_ANON
OPTIONS_FILE_SET+=AUTHN_DEFAULT
OPTIONS_FILE_SET+=AUTHN_ALIAS
OPTIONS_FILE_SET+=AUTHZ_HOST
OPTIONS_FILE_SET+=AUTHZ_GROUPFILE
OPTIONS_FILE_SET+=AUTHZ_USER
OPTIONS_FILE_SET+=AUTHZ_DBM
OPTIONS_FILE_SET+=AUTHZ_OWNER
OPTIONS_FILE_SET+=AUTHZ_DEFAULT
OPTIONS_FILE_SET+=CACHE
OPTIONS_FILE_SET+=DISK_CACHE
OPTIONS_FILE_SET+=FILE_CACHE
OPTIONS_FILE_SET+=MEM_CACHE
OPTIONS_FILE_SET+=DAV
OPTIONS_FILE_SET+=DAV_FS
OPTIONS_FILE_SET+=BUCKETEER
OPTIONS_FILE_SET+=CASE_FILTER
OPTIONS_FILE_SET+=CASE_FILTER_IN
OPTIONS_FILE_SET+=EXT_FILTER
OPTIONS_FILE_SET+=LOG_FORENSIC
OPTIONS_FILE_SET+=OPTIONAL_HOOK_EXPORT
OPTIONS_FILE_SET+=OPTIONAL_HOOK_IMPORT
OPTIONS_FILE_SET+=OPTIONAL_FN_IMPORT
OPTIONS_FILE_SET+=OPTIONAL_FN_EXPORT
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_UNSET+=AUTHNZ_LDAP
OPTIONS_FILE_SET+=ACTIONS
OPTIONS_FILE_SET+=ALIAS
OPTIONS_FILE_SET+=ASIS
OPTIONS_FILE_SET+=AUTOINDEX
OPTIONS_FILE_SET+=CERN_META
OPTIONS_FILE_SET+=CGI
OPTIONS_FILE_SET+=CHARSET_LITE
OPTIONS_FILE_SET+=DBD
OPTIONS_FILE_SET+=DEFLATE
OPTIONS_FILE_SET+=DIR
OPTIONS_FILE_SET+=DUMPIO
OPTIONS_FILE_SET+=ENV
OPTIONS_FILE_SET+=EXPIRES
OPTIONS_FILE_SET+=HEADERS
OPTIONS_FILE_SET+=IMAGEMAP
OPTIONS_FILE_SET+=INCLUDE
OPTIONS_FILE_SET+=INFO
OPTIONS_FILE_SET+=LOG_CONFIG
OPTIONS_FILE_SET+=LOGIO
OPTIONS_FILE_SET+=MIME
OPTIONS_FILE_SET+=MIME_MAGIC
OPTIONS_FILE_SET+=NEGOTIATION
OPTIONS_FILE_SET+=REWRITE
OPTIONS_FILE_SET+=SETENVIF
OPTIONS_FILE_SET+=SPELING
OPTIONS_FILE_SET+=STATUS
OPTIONS_FILE_SET+=UNIQUE_ID
OPTIONS_FILE_SET+=USERDIR
OPTIONS_FILE_SET+=USERTRACK
OPTIONS_FILE_SET+=VHOST_ALIAS
OPTIONS_FILE_SET+=FILTER
OPTIONS_FILE_SET+=SUBSTITUTE
OPTIONS_FILE_SET+=VERSION
OPTIONS_FILE_SET+=PROXY
OPTIONS_FILE_SET+=PROXY_CONNECT
OPTIONS_FILE_SET+=PROXY_FTP
OPTIONS_FILE_SET+=PROXY_HTTP
OPTIONS_FILE_SET+=PROXY_AJP
OPTIONS_FILE_SET+=PROXY_BALANCER
OPTIONS_FILE_UNSET+=PROXY_SCGI
OPTIONS_FILE_SET+=SSL
OPTIONS_FILE_SET+=SUEXEC
OPTIONS_FILE_UNSET+=SUEXEC_RSRCLIMIT
OPTIONS_FILE_SET+=SUEXEC_USERDIR
OPTIONS_FILE_SET+=REQTIMEOUT
OPTIONS_FILE_SET+=CGID
EOF

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # apr bdb
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/apache22/options
        # ldap auth module
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP#OPTIONS_FILE_SET+=LDAP#' /var/db/ports/apache22/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=AUTHNZ_LDAP#OPTIONS_FILE_SET+=AUTHNZ_LDAP#' /var/db/ports/apache22/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/apache22/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/apache22/options
    fi
    rm -f /var/db/ports/apache22/options${SED_EXTENSION} &>/dev/null

    ALL_PORTS="${ALL_PORTS} www/apache22"
    ENABLED_SERVICES="${ENABLED_SERVICES} ${HTTPD_RC_SCRIPT_NAME}"

    # PHP5. REQUIRED.
    cat > /var/db/ports/php5/options <<EOF
OPTIONS_FILE_SET+=CLI
OPTIONS_FILE_SET+=CGI
OPTIONS_FILE_SET+=FPM
OPTIONS_FILE_SET+=APACHE
OPTIONS_FILE_UNSET+=AP2FILTER
OPTIONS_FILE_UNSET+=EMBED
OPTIONS_FILE_UNSET+=DEBUG
OPTIONS_FILE_UNSET+=DTRACE
OPTIONS_FILE_SET+=IPV6
OPTIONS_FILE_SET+=MAILHEAD
OPTIONS_FILE_SET+=LINKTHR
EOF

    ALL_PORTS="${ALL_PORTS} lang/php5"

    # PHP extensions. REQUIRED.
    #/usr/ports/print/freetype2 && make clean && make \
    #    WITHOUT_TTF_BYTECODE_ENABLED=yes \
    #    WITH_LCD_FILTERING=yes \
    #    install

    cat > /var/db/ports/php5-extensions/options <<EOF
OPTIONS_FILE_SET+=BCMATH
OPTIONS_FILE_SET+=BZ2
OPTIONS_FILE_SET+=CALENDAR
OPTIONS_FILE_SET+=CTYPE
OPTIONS_FILE_SET+=CURL
OPTIONS_FILE_UNSET+=DBA
OPTIONS_FILE_SET+=DOM
OPTIONS_FILE_SET+=EXIF
OPTIONS_FILE_SET+=FILEINFO
OPTIONS_FILE_SET+=FILTER
OPTIONS_FILE_SET+=FTP
OPTIONS_FILE_SET+=GD
OPTIONS_FILE_SET+=GETTEXT
OPTIONS_FILE_UNSET+=GMP
OPTIONS_FILE_SET+=HASH
OPTIONS_FILE_SET+=ICONV
OPTIONS_FILE_SET+=IMAP
OPTIONS_FILE_UNSET+=INTERBASE
OPTIONS_FILE_SET+=JSON
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_SET+=MBSTRING
OPTIONS_FILE_SET+=MCRYPT
OPTIONS_FILE_UNSET+=MSSQL
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=MYSQLI
OPTIONS_FILE_UNSET+=ODBC
OPTIONS_FILE_SET+=OPENSSL
OPTIONS_FILE_UNSET+=PCNTL
OPTIONS_FILE_UNSET+=PDF
OPTIONS_FILE_SET+=PDO
OPTIONS_FILE_SET+=PDO_SQLITE
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_SET+=PHAR
OPTIONS_FILE_SET+=POSIX
OPTIONS_FILE_SET+=PSPELL
OPTIONS_FILE_UNSET+=READLINE
OPTIONS_FILE_SET+=RECODE
OPTIONS_FILE_SET+=SESSION
OPTIONS_FILE_UNSET+=SHMOP
OPTIONS_FILE_SET+=SIMPLEXML
OPTIONS_FILE_SET+=SNMP
OPTIONS_FILE_SET+=SOAP
OPTIONS_FILE_SET+=SOCKETS
OPTIONS_FILE_SET+=SQLITE3
OPTIONS_FILE_UNSET+=SYBASE_CT
OPTIONS_FILE_UNSET+=SYSVMSG
OPTIONS_FILE_UNSET+=SYSVSEM
OPTIONS_FILE_UNSET+=SYSVSHM
OPTIONS_FILE_UNSET+=TIDY
OPTIONS_FILE_SET+=TOKENIZER
OPTIONS_FILE_UNSET+=WDDX
OPTIONS_FILE_SET+=XML
OPTIONS_FILE_SET+=XMLREADER
OPTIONS_FILE_SET+=XMLRPC
OPTIONS_FILE_SET+=XMLWRITER
OPTIONS_FILE_SET+=XSL
OPTIONS_FILE_SET+=ZIP
OPTIONS_FILE_SET+=ZLIB
EOF

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP#OPTIONS_FILE_SET+=LDAP#' /var/db/ports/php5-extensions/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/php5-extensions/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQLI#OPTIONS_FILE_SET+=MYSQLI#' /var/db/ports/php5-extensions/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/php5-extensions/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQLI#OPTIONS_FILE_SET+=MYSQLI#' /var/db/ports/php5-extensions/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/php5-extensions/options
    fi
    rm -f /var/db/ports/php5-extensions/options${SED_EXTENSION} &>/dev/null

    cat > /var/db/ports/php5-gd/options <<EOF
OPTIONS_FILE_SET+=T1LIB
OPTIONS_FILE_UNSET+=TRUETYPE
OPTIONS_FILE_UNSET+=JIS
OPTIONS_FILE_UNSET+=X11
OPTIONS_FILE_UNSET+=VPX
EOF

    # PHP extensions
    if [ X"${REQUIRE_PHP}" == X"YES" -o X"${USE_WEBMAIL}" == X"YES" ]; then
        ALL_PORTS="${ALL_PORTS} mail/php5-imap archivers/php5-zip archivers/php5-bz2 archivers/php5-zlib devel/php5-gettext converters/php5-mbstring security/php5-mcrypt security/php5-openssl www/php5-session textproc/php5-ctype security/php5-hash converters/php5-iconv textproc/php5-pspell textproc/php5-dom textproc/php5-xml"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PORTS="${ALL_PORTS} net/php5-ldap databases/php5-mysql databases/php5-mysqli"
        elif [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PORTS="${ALL_PORTS} databases/php5-mysql databases/php5-mysqli"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PORTS="${ALL_PORTS} databases/php5-pgsql"
        fi
    fi

    # Policyd v2.x
    cat > /var/db/ports/policyd2/options <<EOF
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_SET+=PostgreSQL
OPTIONS_FILE_UNSET+=SQLite
EOF

    ALL_PORTS="${ALL_PORTS} mail/policyd2"
    ENABLED_SERVICES="${ENABLED_SERVICES} policyd"

    # ClamAV. REQUIRED.
    cat > /var/db/ports/clamav/options <<EOF
OPTIONS_FILE_SET+=ARC
OPTIONS_FILE_SET+=ARJ
OPTIONS_FILE_SET+=DOCS
OPTIONS_FILE_UNSET+=EXPERIMENTAL
OPTIONS_FILE_SET+=ICONV
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_SET+=LHA
OPTIONS_FILE_UNSET+=LLVM
OPTIONS_FILE_UNSET+=MILTER
OPTIONS_FILE_UNSET+=STDERR
OPTIONS_FILE_SET+=TESTS
OPTIONS_FILE_SET+=UNRAR
OPTIONS_FILE_SET+=UNZOO
EOF

    ALL_PORTS="${ALL_PORTS} security/clamav"
    ENABLED_SERVICES="${ENABLED_SERVICES} clamav-clamd clamav-freshclam"

    # Roundcube.
    cat > /var/db/ports/roundcube/options <<EOF
OPTIONS_FILE_UNSET+=GD
OPTIONS_FILE_UNSET+=LDAP
OPTIONS_FILE_UNSET+=NSC
OPTIONS_FILE_SET+=PSPELL
OPTIONS_FILE_SET+=SSL
OPTIONS_FILE_UNSET+=MYSQL
OPTIONS_FILE_UNSET+=PGSQL
OPTIONS_FILE_UNSET+=SQLITE
EOF

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=LDAP#OPTIONS_FILE_SET+=LDAP#' /var/db/ports/roundcube/options
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/roundcube/options
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=MYSQL#OPTIONS_FILE_SET+=MYSQL#' /var/db/ports/roundcube/options
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ${CMD_SED} -e 's#OPTIONS_FILE_UNSET+=PGSQL#OPTIONS_FILE_SET+=PGSQL#' /var/db/ports/roundcube/options
    fi
    rm -f /var/db/ports/roundcube/options${SED_EXTENSION} &>/dev/null

    # Python-MySQLdb
    cat > /var/db/ports/MySQLdb/options <<EOF
OPTIONS_FILE_SET+=DOCS
OPTIONS_FILE_SET+=MYSQLCLIENT_R
EOF

    # Roundcube webmail.
    if [ X"${USE_RCM}" == X"YES" ]; then
        ALL_PORTS="${ALL_PORTS} mail/roundcube"
    fi

    # Awstats.
    if [ X"${USE_AWSTATS}" == X'YES' ]; then
        if [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PORTS="${ALL_PORTS} www/mod_auth_mysql_another"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PORTS="${ALL_PORTS} www/mod_auth_pgsql2"
        fi

        ALL_PORTS="${ALL_PORTS} www/awstats"
    fi

    # phpLDAPadmin.
    if [ X"${USE_PHPLDAPADMIN}" == X"YES" ]; then
        ALL_PORTS="${ALL_PORTS} net/phpldapadmin"
    fi

    # phpMyAdmin.
    cat > /var/db/ports/phpMyAdmin/options <<EOF
OPTIONS_FILE_UNSET+=APC
OPTIONS_FILE_SET+=BZ2
OPTIONS_FILE_UNSET+=GD
OPTIONS_FILE_SET+=MCRYPT
OPTIONS_FILE_SET+=OPENSSL
OPTIONS_FILE_UNSET+=PDF
OPTIONS_FILE_UNSET+=SUPHP
OPTIONS_FILE_SET+=ZIP
OPTIONS_FILE_SET+=ZLIB
OPTIONS_FILE_SET+=MYSQL
OPTIONS_FILE_SET+=MYSQLI
EOF

    if [ X"${USE_PHPMYADMIN}" == X"YES" ]; then
        ALL_PORTS="${ALL_PORTS} databases/phpmyadmin"
    fi

    # phpPgAdmin
    if [ X"${USE_PHPPGADMIN}" == X"YES" ]; then
        ALL_PORTS="${ALL_PORTS} databases/phppgadmin"
    fi

    # Python database interfaces
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        ALL_PORTS="${ALL_PORTS} net/py-ldap2 databases/py-MySQLdb"
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        ALL_PORTS="${ALL_PORTS} databases/py-MySQLdb"
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ALL_PORTS="${ALL_PORTS} databases/py-psycopg2"
    fi

    # iRedAPD
    ENABLED_SERVICES="${ENABLED_SERVICES} iredapd"

    # iRedAdmin
    # mod_wsgi
    ALL_PORTS="${ALL_PORTS} www/mod_wsgi www/webpy devel/py-Jinja2 net/py-netifaces"

    # Fail2ban.
    if [ X"${USE_FAIL2BAN}" == X"YES" ]; then
        # python-ldap.
        ALL_PORTS="${ALL_PORTS} security/py-fail2ban"
        ENABLED_SERVICES="${ENABLED_SERVICES} fail2ban"
    fi

    # Misc
    ALL_PORTS="${ALL_PORTS} sysutils/logwatch"

    # Fetch all source tarballs.
    ECHO_INFO "Ports tree: ${PORT_WRKDIRPREFIX}"
    ECHO_INFO "Fetching all distfiles for required ports (make fetch-recursive)"

    for i in ${ALL_PORTS}; do
        if [ X"${i}" != X'' ]; then
            portname="$( echo ${i} | tr '/' '_' | tr -d '[-\.]')"
            status="\$status_fetch_port_$portname"
            if [ X"$(eval echo ${status})" != X"DONE" ]; then
                ECHO_INFO "Fetching all distfiles for port ${i} and dependencies"
                cd ${PORT_WRKDIRPREFIX}/${i}

                # Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
                port_start_time="$(date +%s)"

                make WITH_COMPAT=yes DISABLE_LICENSES=yes fetch-recursive
                if [ X"$?" == X"0" ]; then
                    # Log used time
                    used_time="$(($(date +%s)-port_start_time))"
                    echo "export status_fetch_port_${portname}='DONE'  # ${used_time} seconds, ~$((used_time/60)) minute(s)" >> ${STATUS_FILE}
                else
                    ECHO_ERROR "Tarballs were not downloaded correctly, please fix it manually and then re-execute iRedMail.sh."
                    exit 255
                fi
            else
                ECHO_SKIP "Fetching all distfiles for port ${i} and dependencies"
            fi
        fi
    done

    # Install all packages.
    ECHO_INFO "==== Install packages ===="

    start_time="$(date +%s)"
    for i in ${ALL_PORTS}; do
        if [ X"${i}" != X'' ]; then
            # Remove special characters in port name: -, /, '.'.
            portname="$( echo ${i} | tr '/' '_' | tr -d '[-\.]')"

            status="\$status_install_port_$portname"
            if [ X"$(eval echo ${status})" != X"DONE" ]; then
                cd ${PORT_WRKDIRPREFIX}/${i} && \
                    ECHO_INFO "Installing port: ${i} ($(date '+%Y-%m-%d %H:%M:%S')) ..."
                    echo "export status_install_port_${portname}='processing'" >> ${STATUS_FILE}

                    # Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
                    port_start_time="$(date +%s)"

                    # Compiling
                    make clean && make install clean

                    if [ X"$?" == X"0" ]; then
                        # Log used time
                        used_time="$(($(date +%s)-port_start_time))"

                        echo "export status_install_port_${portname}='DONE'  # ${used_time} seconds, ~$((used_time/60)) minute(s)" >> ${STATUS_FILE}
                    else
                        ECHO_ERROR "Port was not success installed, please fix it manually and then re-execute this script."
                        exit 255
                    fi
            else
                ECHO_SKIP "Installing port: ${i}."
            fi
        fi
    done

    # Log and print used time
    all_used_time="$(($(date +%s)-start_time))"
    ECHO_INFO "Total time of ports compiling: ${all_used_time} seconds, ~$((all_used_time/60)) minute(s)"

    echo 'export status_install_all="DONE"' >> ${STATUS_FILE}
}
