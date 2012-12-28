#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)

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

# ------------------------------
# Define some global variables.
# ------------------------------
tmprootdir="$(dirname $0)"
echo ${tmprootdir} | grep '^/' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
    export ROOTDIR="${tmprootdir}"
else
    export ROOTDIR="$(pwd)"
fi

cd ${ROOTDIR}

export CONF_DIR="${ROOTDIR}/conf"
export FUNCTIONS_DIR="${ROOTDIR}/functions"
export DIALOG_DIR="${ROOTDIR}/dialog"
export PKG_DIR="${ROOTDIR}/pkgs/pkgs"
export MISC_DIR="${ROOTDIR}/pkgs/misc"
export SAMPLE_DIR="${ROOTDIR}/samples"
export PATCH_DIR="${ROOTDIR}/patches"
export TOOLS_DIR="${ROOTDIR}/tools"

. ${CONF_DIR}/global
. ${CONF_DIR}/core

# Check downloaded packages, pkg repository.
[ -f ${STATUS_FILE} ] && . ${STATUS_FILE}
if [ X"${status_get_all}" != X"DONE" ]; then
    cd ${ROOTDIR}/pkgs/ && bash get_all.sh
    if [ X"$?" == X'0' ]; then
        cd ${ROOTDIR}
    else
        exit 255
    fi
fi

# --------------------------------------
# Check target platform and environment.
# --------------------------------------
# Required by OpenVZ:
# Make sure others can read-write /dev/null and /dev/*random, so that it won't
# interrupt iRedMail installation.
chmod go+rx /dev/null /dev/*random &>/dev/null

check_env

# ------------------------------
# Import variables.
# ------------------------------
# Source 'conf/apache_php' first, other components need some variables
# defined in it.
. ${CONF_DIR}/apache_php
. ${CONF_DIR}/openldap
. ${CONF_DIR}/ldapd
. ${CONF_DIR}/phpldapadmin
. ${CONF_DIR}/mysql
. ${CONF_DIR}/postgresql
. ${CONF_DIR}/postfix
. ${CONF_DIR}/policy_server
. ${CONF_DIR}/iredapd
. ${CONF_DIR}/dovecot
. ${CONF_DIR}/managesieve
. ${CONF_DIR}/amavisd
. ${CONF_DIR}/clamav
. ${CONF_DIR}/spamassassin
. ${CONF_DIR}/roundcube
. ${CONF_DIR}/phpmyadmin
. ${CONF_DIR}/phppgadmin
. ${CONF_DIR}/awstats
. ${CONF_DIR}/fail2ban
. ${CONF_DIR}/iredadmin

# ------------------------------
# Import functions.
# ------------------------------
# All packages.
if [ X"${DISTRO}" == X"FREEBSD" ]; then
    # Install packages from freebsd ports tree.
    . ${FUNCTIONS_DIR}/packages_freebsd.sh
else
    . ${FUNCTIONS_DIR}/packages.sh
fi

# User/Group: vmail. We will export vmail uid/gid here.
. ${FUNCTIONS_DIR}/system_accounts.sh

. ${FUNCTIONS_DIR}/apache_php.sh
. ${FUNCTIONS_DIR}/ldap_server.sh
. ${FUNCTIONS_DIR}/mysql.sh
. ${FUNCTIONS_DIR}/postgresql.sh

# Switch backend
. ${FUNCTIONS_DIR}/backend.sh

. ${FUNCTIONS_DIR}/postfix.sh
. ${FUNCTIONS_DIR}/policy_server.sh
. ${FUNCTIONS_DIR}/iredapd.sh
. ${FUNCTIONS_DIR}/dovecot.sh
. ${FUNCTIONS_DIR}/managesieve.sh
. ${FUNCTIONS_DIR}/clamav.sh
. ${FUNCTIONS_DIR}/amavisd.sh
. ${FUNCTIONS_DIR}/spamassassin.sh
. ${FUNCTIONS_DIR}/roundcubemail.sh
. ${FUNCTIONS_DIR}/phpldapadmin.sh
. ${FUNCTIONS_DIR}/phpmyadmin.sh
. ${FUNCTIONS_DIR}/phppgadmin.sh
. ${FUNCTIONS_DIR}/awstats.sh
. ${FUNCTIONS_DIR}/fail2ban.sh
. ${FUNCTIONS_DIR}/iredadmin.sh
. ${FUNCTIONS_DIR}/optional_components.sh
. ${FUNCTIONS_DIR}/cleanup.sh

# ************************************************************************
# *************************** Script Main ********************************
# ************************************************************************

# Install all packages.
check_status_before_run install_all || (ECHO_ERROR "Package installation error, please check the output log." && exit 255)

echo -e '\n\n'
cat <<EOF

********************************************************************
* Start iRedMail Configurations
********************************************************************
EOF


# Create SSL/TLS cert file.
check_status_before_run generate_ssl_keys

# User/Group: vmail
check_status_before_run add_required_users

# Apache & PHP.
check_status_before_run apache_php_config

# Install & Config Backend: OpenLDAP or MySQL.
check_status_before_run backend_install

# Postfix.
check_status_before_run postfix_config_basic && \
check_status_before_run postfix_config_virtual_host && \
check_status_before_run postfix_config_sasl && \
check_status_before_run postfix_config_tls

# Policy service for Postfix: Policyd.
check_status_before_run policy_server_config

# Dovecot.
check_status_before_run enable_dovecot

# Managesieve.
check_status_before_run managesieve_config

# ClamAV.
check_status_before_run clamav_config

# Amavisd-new.
check_status_before_run amavisd_config

# SpamAssassin.
check_status_before_run sa_config

# Optional components.
optional_components

# Cleanup.
check_status_before_run cleanup
