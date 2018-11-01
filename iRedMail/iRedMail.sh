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
export PKG_MISC_DIR="${ROOTDIR}/pkgs/misc"
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

# Define paths of some directories
# Directory used to store mailboxes
export STORAGE_MAILBOX_DIR="${STORAGE_MAILBOX_DIR:=${STORAGE_BASE_DIR}/${STORAGE_NODE}}"
# Directory used to store sieve filters
export SIEVE_DIR="${SIEVE_DIR:=${STORAGE_BASE_DIR}/sieve}"
# Directory used to store daily SQL/LDAP backup files
export BACKUP_DIR="${BACKUP_DIR:=${STORAGE_BASE_DIR}/backup}"
# Directory used to store public IMAP folders
export PUBLIC_MAILBOX_DIR="${PUBLIC_MAILBOX_DIR:=${STORAGE_BASE_DIR}/public}"

# Domain admin email address
export DOMAIN_ADMIN_EMAIL="${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}"

# Import global variables in specified order.
. ${CONF_DIR}/web_server
. ${CONF_DIR}/openldap
. ${CONF_DIR}/ldapd
. ${CONF_DIR}/mysql
. ${CONF_DIR}/postgresql
. ${CONF_DIR}/dovecot
. ${CONF_DIR}/postfix
. ${CONF_DIR}/mlmmj
. ${CONF_DIR}/amavisd
. ${CONF_DIR}/iredapd
. ${CONF_DIR}/memcached
. ${CONF_DIR}/sogo
. ${CONF_DIR}/clamav
. ${CONF_DIR}/spamassassin
. ${CONF_DIR}/roundcube
. ${CONF_DIR}/netdata
. ${CONF_DIR}/fail2ban
. ${CONF_DIR}/iredadmin

# Import functions in specified order.
if [ X"${DISTRO}" == X'FREEBSD' ]; then
    # Install packages from freebsd ports tree.
    . ${FUNCTIONS_DIR}/packages_freebsd.sh
else
    . ${FUNCTIONS_DIR}/packages.sh
fi

. ${FUNCTIONS_DIR}/system_accounts.sh
. ${FUNCTIONS_DIR}/web_server.sh
. ${FUNCTIONS_DIR}/ldap_server.sh
. ${FUNCTIONS_DIR}/mysql.sh
. ${FUNCTIONS_DIR}/postgresql.sh

# Switch backend
. ${FUNCTIONS_DIR}/backend.sh

. ${FUNCTIONS_DIR}/postfix.sh
. ${FUNCTIONS_DIR}/dovecot.sh
. ${FUNCTIONS_DIR}/mlmmj.sh
. ${FUNCTIONS_DIR}/amavisd.sh
. ${FUNCTIONS_DIR}/iredapd.sh
. ${FUNCTIONS_DIR}/clamav.sh
. ${FUNCTIONS_DIR}/spamassassin.sh
. ${FUNCTIONS_DIR}/roundcubemail.sh
. ${FUNCTIONS_DIR}/sogo.sh
. ${FUNCTIONS_DIR}/fail2ban.sh
. ${FUNCTIONS_DIR}/iredadmin.sh
. ${FUNCTIONS_DIR}/netdata.sh
. ${FUNCTIONS_DIR}/optional_components.sh
. ${FUNCTIONS_DIR}/cleanup.sh

# ************************************************************************
# *************************** Script Main ********************************
# ************************************************************************

# Install all required packages.
check_status_before_run install_all || (ECHO_ERROR "Package installation error, please check the output log.\n\n" && exit 255)

cat <<EOF

********************************************************************
* Start iRedMail Configurations
********************************************************************
EOF


check_status_before_run generate_ssl_keys
check_status_before_run add_required_users
check_status_before_run web_server_config
check_status_before_run backend_install
check_status_before_run postfix_setup
check_status_before_run dovecot_setup
check_status_before_run mlmmj_config
check_status_before_run mlmmjadmin_config
check_status_before_run clamav_config
check_status_before_run amavisd_config
check_status_before_run sa_config
optional_components
check_status_before_run cleanup
