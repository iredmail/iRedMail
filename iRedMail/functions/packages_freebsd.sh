#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb(at)iredmail.org>

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
    ALL_PKGS=''             # Binary package names. e.g. mysql-server, dovecot.
    ALL_PORTS=''            # Port name under /usr/ports/. e.g. mail/dovecot, databases/mysql50.
    ENABLED_SERVICES=''     # Scripts under /usr/local/etc/rc.d/
    DISABLED_SERVICES=''    # Scripts under /usr/local/etc/rc.d/

    # Make it don't popup dialog while building ports.
    export BATCH='yes'

    cat >> /etc/make.conf <<EOF
# Without X-Window/GUI.
WITHOUT_X11=yes
# Use MySQL-5.0.x as default.
WANT_MYSQL_VER=50
# Use python-2.6 as default.
PYTHON_DEFAULT_VERSION=python2.6
# Use apache-2.2.
APACHE_PORT=www/apache22
# Use OpenLDAP 2.4.
WANT_OPENLDAP_VER=24
WITH_SASL=yes
WANT_BDB_VER=46
EOF

    for i in m4 libiconv cyrus-sasl2 perl openslp mysql-server openldap24 dovecot \
        ca_root_nss libssh2 curl libusb pth gnupg p5-IO-Socket-SSL \
        p5-Archive-Tar p5-Net-DNS p5-Mail-SpamAssassin p5-Authen-SASL \
        amavisd-new clamav apr python26 apache22 php5 php5-extensions \
        php5-gd roundcube postfix MySQLdb p7zip; do
        mkdir -p /var/db/ports/${i} 2>/dev/null
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
WITH_BDB=true
WITHOUT_MYSQL=true
WITHOUT_PGSQL=true
WITHOUT_SQLITE=true
WITH_DEV_URANDOM=true
WITHOUT_ALWAYSTRUE=true
WITH_KEEP_DB_OPEN=true
WITHOUT_AUTHDAEMOND=true
WITHOUT_LOGIN=true
WITHOUT_PLAIN=true
WITHOUT_CRAM=true
WITHOUT_DIGEST=true
WITHOUT_OTP=true
WITHOUT_NTLM=true
EOF

    # Perl 5.8. REQUIRED.
    cat > /var/db/ports/perl/options <<EOF
WITHOUT_DEBUGGING=true
WITH_GDBM=true
WITH_PERL_MALLOC=true
WITH_PERL_64BITINT=true
WITH_THREADS=true
WITH_SUIDPERL=true
WITH_SITECUSTOMIZE=true
WITH_USE_PERL=true
EOF

    # OpenSLP. DEPENDENCE.
    cat > /var/db/ports/openslp/options <<EOF
WITH_SLP_SECURITY=true
WITH_ASYNC_API=true
EOF

    # MySQL-server. REQUIRED.
    cat > /var/db/ports/mysql-server/options <<EOF
WITH_CHARSET=utf8
WITH_XCHARSET=all
WITH_OPENSSL=yes
WITH_COLLATION=utf8_general_ci
EOF
    ALL_PKGS="${ALL_PKGS} mysql-server mysql-client"
    ALL_PORTS="${ALL_PORTS} databases/mysql50-server"

    ENABLED_SERVICES="${ENABLED_SERVICES} mysql-server"

    # OpenLDAP v2.4. REQUIRED for LDAP backend.
    if [ X"${BACKEND}" == X"OpenLDAP" ]; then
        cat > /var/db/ports/openldap24/options <<EOF
WITH_SASL=true
WITH_FETCH=true
WITH_DYNACL=true
WITH_ACI=true
WITH_DNSSRV=true
WITH_PASSWD=true
WITH_PERL=true
WITH_RELAY=true
WITHOUT_SHELL=true
WITH_SOCK=true
WITHOUT_ODBC=true
WITH_RLOOKUPS=true
WITH_SLP=true
WITH_SLAPI=true
WITH_TCP_WRAPPERS=true
WITH_BDB=true
WITH_ACCESSLOG=true
WITH_AUDITLOG=true
WITH_COLLECT=true
WITH_CONSTRAINT=true
WITH_DDS=true
WITH_DEREF=true
WITH_DYNGROUP=true
WITH_DYNLIST=true
WITH_LASTMOD=true
WITH_MEMBEROF=true
WITH_PPOLICY=true
WITH_PROXYCACHE=true
WITH_REFINT=true
WITH_RETCODE=true
WITH_RWM=true
WITH_SEQMOD=true
WITH_SYNCPROV=true
WITH_TRANSLUCENT=true
WITH_UNIQUE=true
WITH_VALSORT=true
WITH_SMBPWD=true
WITH_DYNAMIC_BACKENDS=true
EOF

        ALL_PKGS="${ALL_PKGS} openldap-sasl-server openldap-sasl-client"
        ALL_PORTS="${ALL_PORTS} net/openldap24-server"
        ENABLED_SERVICES="${ENABLED_SERVICES} slapd"

    fi

    # Dovecot v1.2.x. REQUIRED.
    cat > /var/db/ports/dovecot/options <<EOF
WITH_KQUEUE=true
WITH_SSL=true
WITH_MANAGESIEVE=true
WITH_GSSAPI=true
WITHOUT_VPOPMAIL=true
WITH_BDB=true
WITH_LDAP=true
WITHOUT_PGSQL=true
WITH_MYSQL=true
WITHOUT_SQLITE=true
EOF

    # Note: dovecot-sieve will install dovecot first.
    ALL_PKGS="${ALL_PKGS} dovecot-sieve dovecot-managesieve"
    ALL_PORTS="${ALL_PORTS} mail/dovecot-sieve mail/dovecot-managesieve"
    ENABLED_SERVICES="${ENABLED_SERVICES} dovecot"

    # ca_root_nss. DEPENDENCE.
    cat >/var/db/ports/ca_root_nss/options <<EOF
WITHOUT_ETCSYMLINK=true
EOF

    # libssh2. DEPENDENCE.
    cat > /var/db/ports/libssh2/options <<EOF
WITHOUT_GCRYPT=true
EOF

    # Curl. DEPENDENCE.
    cat > /var/db/ports/curl/options <<EOF
WITHOUT_CARES=true
WITHOUT_CURL_DEBUG=true
WITHOUT_GNUTLS=true
WITH_IPV6=true
WITHOUT_KERBEROS4=true
WITHOUT_LDAP=true
WITHOUT_LDAPS=true
WITH_LIBIDN=true
WITH_LIBSSH2=true
WITH_NTLM=true
WITH_OPENSSL=true
WITH_PROXY=true
WITHOUT_TRACKMEMORY=true
EOF

    # libusb. DEPENDENCE.
    cat > /var/db/ports/libusb/options <<EOF
WITHOUT_SGML=true
EOF

    # pth. DEPENDENCE.
    cat > /var/db/ports/pth/options <<EOF
WITH_OPTIMIZED_CFLAGS=true
EOF

    # GnuPG. DEPENDENCE.
    cat > /var/db/ports/gnupg/options <<EOF
WITH_LDAP=true
WITH_SCDAEMON=true
WITH_CURL=true
WITH_GPGSM=true
WITH_CAMELLIA=true
WITH_KDNS=true
WITH_NLS=true
EOF

    # p5-IO-Socket-SSL. DEPENDENCE.
    cat > /var/db/ports/p5-IO-Socket-SSL/options <<EOF
WITH_IDN=true
EOF

    cat > /var/db/ports/p5-Archive-Tar/options <<EOF
WITH_TEXT_DIFF=true
EOF

    cat > /var/db/ports/p5-Net-DNS/options <<EOF
WITH_IPV6=true
EOF

    # SpamAssassin. REQUIRED.
    cat > /var/db/ports/p5-Mail-SpamAssassin/options <<EOF
WITH_AS_ROOT=true
WITH_SPAMC=true
WITH_SACOMPILE=true
WITH_DKIM=true
WITH_SSL=true
WITH_GNUPG=true
WITH_MYSQL=true
WITHOUT_PGSQL=true
WITH_RAZOR=true
WITH_SPF_QUERY=true
WITH_RELAY_COUNTRY=true
EOF

    ALL_PKGS="${ALL_PKGS} pth gnupg p5-Net-DNS p5-Mail-SpamAssassin"
    ALL_PORTS="${ALL_PORTS} devel/pth security/gnupg dns/p5-Net-DNS mail/p5-Mail-SpamAssassin"
    DISABLED_SERVICES="${DISABLED_SERVICES} spamd"

    cat > /var/db/ports/p5-Authen-SASL/options <<EOF
WITH_KERBEROS=true
EOF

    # AlterMIME. REQUIRED.
    ALL_PKGS="${ALL_PKGS} p5-Authen-SASL altermime"
    ALL_PORTS="${ALL_PORTS} security/p5-Authen-SASL mail/altermime"

    cat > /var/db/ports/p7zip/options <<EOF
WITH_MINIMAL=true
EOF

    # Amavisd-new. REQUIRED.
    cat > /var/db/ports/amavisd-new/options <<EOF
WITH_IPV6=true
WITH_BDB=true
WITH_SNMP=true
WITHOUT_SQLITE=true
WITH_MYSQL=true
WITHOUT_PGSQL=true
WITH_LDAP=true
WITH_SASL=true
WITHOUT_MILTER=true
WITH_SPAMASSASSIN=true
WITH_P0F=true
WITH_ALTERMIME=true
WITH_FILE=true
WITHOUT_RAR=true
WITH_UNRAR=true
WITH_ARJ=true
WITH_UNARJ=true
WITH_LHA=true
WITH_ARC=true
WITH_NOMARCH=true
WITH_CAB=true
WITH_RPM=true
WITH_ZOO=true
WITH_UNZOO=true
WITH_LZOP=true
WITH_FREEZE=true
WITH_P7ZIP=true
WITH_MSWORD=true
WITH_TNEF=true
EOF

    # Disable RAR support on amd64 since it requires 32-bit libraries
    # installed under /usr/lib32.
    if [ X"${ARCH}" == X"${i386}" ]; then
        cat >> /var/db/ports/amavisd-new/options <<EOF
WITH_RAR=true
EOF
    else
        cat >> /var/db/ports/amavisd-new/options <<EOF
WITHOUT_RAR=true
EOF
    fi

    ALL_PKGS="${ALL_PKGS} amavisd-new"
    ALL_PORTS="${ALL_PORTS} security/amavisd-new"
    ENABLED_SERVICES="${ENABLED_SERVICES} amavisd"

    # Postfix. REQUIRED.
    cat > /var/db/ports/postfix/options <<EOF
WITH_PCRE=true
WITHOUT_SASL2=true
WITH_DOVECOT=true
WITHOUT_DOVECOT2=true
WITHOUT_SASLKRB5=true
WITHOUT_SASLKMIT=true
WITH_TLS=true
WITH_BDB=true
WITH_MYSQL=true
WITHOUT_PGSQL=true
WITH_OPENLDAP=true
WITH_CDB=true
WITHOUT_NIS=true
WITHOUT_VDA=true
WITHOUT_TEST=true
WITHOUT_SPF=true
WITHOUT_INST_BASE=true
EOF

    ALL_PKGS="${ALL_PKGS} pcre postfix"
    ALL_PORTS="${ALL_PORTS} devel/pcre mail/postfix27"
    ENABLED_SERVICES="${ENABLED_SERVICES} postfix"
    DISABLED_SERVICES="${DISABLED_SERVICES} sendmail sendmail_submit sendmail_outbound sendmail_msq_queue"

    # Policyd v1.8x. REQUIRED.
    ALL_PKGS="${ALL_PKGS} postfix-policyd-sf"
    ALL_PORTS="${ALL_PORTS} mail/postfix-policyd-sf"
    ENABLED_SERVICES="${ENABLED_SERVICES} policyd"

    # ClamAV. REQUIRED.
    cat > /var/db/ports/clamav/options <<EOF
WITH_ARC=true
WITH_ARJ=true
WITH_LHA=true
WITH_UNZOO=true
WITH_UNRAR=true
WITH_ICONV=true
WITHOUT_MILTER=true
WITHOUT_LDAP=true
WITHOUT_STDERR=true
WITHOUT_EXPERIMENTAL=true
EOF

    ALL_PKGS="${ALL_PKGS} clamav"
    ALL_PORTS="${ALL_PORTS} security/clamav"
    ENABLED_SERVICES="${ENABLED_SERVICES} clamav-clamd clamav-freshclam"

    # Apr. DEPENDENCE.
    cat > /var/db/ports/apr/options <<EOF
WITH_THREADS=true
WITH_IPV6=true
WITH_GDBM=true
WITH_BDB=true
WITHOUT_NDBM=true
WITH_LDAP=true
WITH_MYSQL=true
WITHOUT_PGSQL=true
EOF

    # Python v2.6. REQUIRED.
    cat > /var/db/ports/python26/options <<EOF
WITH_THREADS=true
WITH_HUGE_STACK_SIZE=true
WITH_UCS4=true
WITH_PYMALLOC=true
WITH_IPV6=true
WITH_FPECTL=true
EOF

    # Apache v2.2.x. REQUIRED.
    cat > /var/db/ports/apache22/options <<EOF
WITH_APR_FROM_PORTS=true
WITH_THREADS=true
WITH_MYSQL=true
WITHOUT_PGSQL=true
WITHOUT_SQLITE=true
WITH_IPV6=true
WITH_BDB=true
WITH_AUTH_BASIC=true
WITH_AUTH_DIGEST=true
WITH_AUTHN_FILE=true
WITH_AUTHN_DBD=true
WITH_AUTHN_DBM=true
WITH_AUTHN_ANON=true
WITH_AUTHN_DEFAULT=true
WITH_AUTHN_ALIAS=true
WITH_AUTHZ_HOST=true
WITH_AUTHZ_GROUPFILE=true
WITH_AUTHZ_USER=true
WITH_AUTHZ_DBM=true
WITH_AUTHZ_OWNER=true
WITH_AUTHZ_DEFAULT=true
WITH_CACHE=true
WITH_DISK_CACHE=true
WITH_FILE_CACHE=true
WITH_MEM_CACHE=true
WITH_DAV=true
WITH_DAV_FS=true
WITH_BUCKETEER=true
WITH_CASE_FILTER=true
WITH_CASE_FILTER_IN=true
WITH_EXT_FILTER=true
WITH_LOG_FORENSIC=true
WITH_OPTIONAL_HOOK_EXPORT=true
WITH_OPTIONAL_HOOK_IMPORT=true
WITH_OPTIONAL_FN_IMPORT=true
WITH_OPTIONAL_FN_EXPORT=true
WITH_LDAP=true
WITH_AUTHNZ_LDAP=true
WITH_ACTIONS=true
WITH_ALIAS=true
WITH_ASIS=true
WITH_AUTOINDEX=true
WITH_CERN_META=true
WITH_CGI=true
WITH_CHARSET_LITE=true
WITH_DBD=true
WITH_DEFLATE=true
WITH_DIR=true
WITH_DUMPIO=true
WITH_ENV=true
WITH_EXPIRES=true
WITH_HEADERS=true
WITH_IMAGEMAP=true
WITH_INCLUDE=true
WITH_INFO=true
WITH_LOG_CONFIG=true
WITH_LOGIO=true
WITH_MIME=true
WITH_MIME_MAGIC=true
WITH_NEGOTIATION=true
WITH_REWRITE=true
WITH_SETENVIF=true
WITH_SPELING=true
WITH_STATUS=true
WITH_UNIQUE_ID=true
WITH_USERDIR=true
WITH_USERTRACK=true
WITH_VHOST_ALIAS=true
WITH_FILTER=true
WITH_VERSION=true
WITH_PROXY=true
WITH_PROXY_CONNECT=true
WITH_PATCH_PROXY_CONNECT=true
WITH_PROXY_FTP=true
WITH_PROXY_HTTP=true
WITH_PROXY_AJP=true
WITH_PROXY_BALANCER=true
WITH_SSL=true
WITH_SUEXEC=true
WITH_CGID=true
EOF

    ALL_PKGS="${ALL_PKGS} apache"
    ALL_PORTS="${ALL_PORTS} www/apache22"
    ENABLED_SERVICES="${ENABLED_SERVICES} apache22"

    # PHP5. REQUIRED.
    cat > /var/db/ports/php5/options <<EOF
WITH_CLI=true
WITH_CGI=true
WITH_APACHE=true
WITHOUT_DEBUG=true
WITH_SUHOSIN=true
WITH_MULTIBYTE=true
WITH_IPV6=true
WITH_MAILHEAD=true
WITH_REDIRECT=true
WITH_DISCARD=true
WITH_FASTCGI=true
WITH_PATHINFO=true
EOF

    ALL_PKGS="${ALL_PKGS} php5"
    ALL_PORTS="${ALL_PORTS} lang/php5"

    # PHP extensions. REQUIRED.
    #/usr/ports/print/freetype2 && make clean && make \
    #    WITHOUT_TTF_BYTECODE_ENABLED=yes \
    #    WITH_LCD_FILTERING=yes \
    #    install

    cat > /var/db/ports/php5-extensions/options <<EOF
WITH_BCMATH=true
WITH_BZ2=true
WITHOUT_CALENDAR=true
WITH_CTYPE=true
WITH_CURL=true
WITHOUT_DBA=true
WITHOUT_DBASE=true
WITH_DOM=true
WITHOUT_EXIF=true
WITH_FILEINFO=true
WITH_FILTER=true
WITHOUT_FRIBIDI=true
WITH_FTP=true
WITH_GD=true
WITH_GETTEXT=true
WITHOUT_GMP=true
WITH_HASH=true
WITH_ICONV=true
WITH_IMAP=true
WITHOUT_INTERBASE=true
WITH_JSON=true
WITH_LDAP=true
WITH_MBSTRING=true
WITH_MCRYPT=true
WITH_MHASH=true
WITH_MING=true
WITHOUT_MSSQL=true
WITH_MYSQL=true
WITH_MYSQLI=true
WITHOUT_NCURSES=true
WITHOUT_ODBC=true
WITH_OPENSSL=true
WITHOUT_PCNTL=true
WITH_PCRE=true
WITHOUT_PDF=true
WITH_PDO=true
WITH_PDO_SQLITE=true
WITHOUT_PGSQL=true
WITH_POSIX=true
WITH_PSPELL=true
WITHOUT_READLINE=true
WITH_RECODE=true
WITH_SESSION=true
WITHOUT_SHMOP=true
WITH_SIMPLEXML=true
WITH_SNMP=true
WITHOUT_SOAP=true
WITH_SOCKETS=true
WITH_SPL=true
WITH_SQLITE=true
WITHOUT_SYBASE_CT=true
WITHOUT_SYSVMSG=true
WITHOUT_SYSVSEM=true
WITHOUT_SYSVSHM=true
WITHOUT_TIDY=true
WITH_TOKENIZER=true
WITHOUT_WDDX=true
WITH_XML=true
WITH_XMLREADER=true
WITH_XMLRPC=true
WITH_XMLWRITER=true
WITH_XSL=true
WITHOUT_YAZ=true
WITH_ZIP=true
WITH_ZLIB=true
EOF

    cat > /var/db/ports/php5-gd/options <<EOF
WITH_T1LIB=true
WITHOUT_TRUETYPE=true
WITHOUT_JIS=true
EOF

    # Roundcube.
    cat > /var/db/ports/roundcube/options <<EOF
WITH_MYSQL=true
WITHOUT_PGSQL=true
WITH_SQLITE=true
WITH_SSL=true
WITH_LDAP=true
WITH_PSPELL=true
WITHOUT_NSC=true
WITH_AUTOCOMP=true
EOF

    # Python-MySQLdb
    cat > /var/db/ports/MySQLdb/options <<EOF
WITH_MYSQLCLIENT_R=true
EOF

    # PHP extensions
    if [ X"${REQUIRE_PHP}" == X"YES" -o X"${USE_WEBMAIL}" == X"YES" ]; then
        ALL_PKGS="${ALL_PKGS} php5-gd php5-imap php5-zip php5-bz2 php5-zlib php5-gettext php5-mbstring php5-mcrypt php5-mysql php5-mysqli php5-openssl php5-session php5-ldap php5-ctype php5-hash php5-iconv php5-pspell php5-dom php5-xml php5-sqlite"
        ALL_PORTS="${ALL_PORTS} mail/php5-imap graphics/php5-gd archivers/php5-zip archivers/php5-bz2 archivers/php5-zlib devel/php5-gettext converters/php5-mbstring security/php5-mcrypt databases/php5-mysql security/php5-openssl www/php5-session net/php5-ldap textproc/php5-ctype security/php5-hash converters/php5-iconv textproc/php5-pspell textproc/php5-dom textproc/php5-xml databases/php5-sqlite databases/php5-mysqli"
    fi

    # Roundcube webmail.
    if [ X"${USE_RCM}" == X"YES" ]; then
        ALL_PKGS="${ALL_PKGS} roundcube"
        ALL_PORTS="${ALL_PORTS} mail/roundcube"
    fi

    # Awstats.
    if [ X"${USE_AWSTATS}" == X"YES" ]; then
        if [ X"${BACKEND}" == X"MySQL" ]; then
            ALL_PORTS="${ALL_PORTS} www/mod_auth_mysql_another"
        fi

        ALL_PKGS="${ALL_PKGS} awstats"
        ALL_PORTS="${ALL_PORTS} www/awstats"
    fi

    # phpLDAPadmin.
    if [ X"${USE_PHPLDAPADMIN}" == X"YES" ]; then
        ALL_PKGS="${ALL_PKGS} phpldapadmin"
        ALL_PORTS="${ALL_PORTS} net/phpldapadmin"
    fi

    # phpMyAdmin.
    if [ X"${USE_PHPMYADMIN}" == X"YES" ]; then
        ALL_PKGS="${ALL_PKGS} phpMyAdmin"
        ALL_PORTS="${ALL_PORTS} databases/phpmyadmin"
    fi

    # iRedAPD.
    if [ X"${USE_IREDAPD}" == X"YES" ]; then
        # python-ldap.
        ALL_PORTS="${ALL_PORTS} net/py-ldap2"
        ENABLED_SERVICES="${ENABLED_SERVICES} iredapd"
    fi

    # iRedAdmin.
    if [ X"${USE_IREDADMIN}" == X"YES" ]; then
        # mod_wsgi.
        ALL_PORTS="${ALL_PORTS} www/mod_wsgi www/webpy devel/py-Jinja2 databases/py-MySQLdb net/py-netifaces"
        [ X"${USE_IREDAPD}" != X"YES" ] && ALL_PORTS="${ALL_PORTS} net/py-ldap2"
    fi

    # Fail2ban.
    #if [ X"${USE_FAIL2BAN}" == X"YES" ]; then
    #    # python-ldap.
    #    ALL_PORTS="${ALL_PORTS} security/py-fail2ban"
    #    ENABLED_SERVICES="${ENABLED_SERVICES} fail2ban"
    #fi

    # Fetch all source tarballs.
    ECHO_INFO "==== Fetch all source tarballs of required components (make fetch-recursive) ===="
    for i in ${ALL_PORTS}; do
        if [ X"${i}" != X'' ]; then
            portname="$( echo ${i} | tr -d '-' | tr -d '/' | tr -d '\.' )"
            status="\$status_fetch_port_$portname"
            if [ X"$(eval echo ${status})" != X"DONE" ]; then
                cd /usr/ports/${i} && make fetch-recursive
                if [ X"$?" == X"0" ]; then
                    echo "export status_fetch_port_${portname}='DONE'" >> ${STATUS_FILE}
                else
                    ECHO_ERROR "Tarballs were not downloaded correctly, please fix it manually and then re-execute iRedMail.sh."
                    exit 255
                fi
            else
                ECHO_INFO "Skip fetching tarballs of port: ${i}."
            fi
        fi
    done

    # Install all packages.
    ECHO_INFO "==== Install packages ===="
    for i in ${ALL_PORTS}; do
        if [ X"${i}" != X'' ]; then
            portname="$( echo ${i} | tr -d '-' | tr -d '/' | tr -d '\.' )"
            status="\$status_install_port_$portname"
            if [ X"$(eval echo ${status})" != X"DONE" ]; then
                cd /usr/ports/${i} && \
                    make clean && \
                    ECHO_INFO "Installing port: ${i} ..." && \
                    make BATCH=yes install clean

                    if [ X"$?" == X"0" ]; then
                        echo "export status_install_port_${portname}='DONE'" >> ${STATUS_FILE}
                    else
                        ECHO_ERROR "Port was not success installed, please fix it manually and then re-execute this script."
                        exit 255
                    fi
            else
                ECHO_INFO "Skip installing port: ${i}."
            fi
        fi
    done
}
