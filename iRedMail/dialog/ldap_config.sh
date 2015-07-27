#!/usr/bin/env bash

# Author:   Zhang Huangbin <zhb _at_ iredmail.org>

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

# --------------------------------------------------
# --------------------- LDAP -----------------------
# --------------------------------------------------

# LDAP suffix.
while : ; do
    ${DIALOG} \
        --title "LDAP suffix (root dn)" \
        --inputbox "\
Please specify your LDAP suffix (root dn):

EXAMPLE:

* Domain 'example.com': dc=example,dc=com
* Domain 'test.com.cn': dc=test,dc=com,dc=cn

Note: Password for LDAP rootdn (cn=Manager,dc=xx,dc=xx) will be
generated randomly.
" 20 76 "dc=example,dc=com" 2>/tmp/ldap_suffix

    LDAP_SUFFIX="$(cat /tmp/ldap_suffix)"
    [ X"${LDAP_SUFFIX}" != X"" ] && break
done

# Get DNS name derived from ldap suffix.
export dn2dnsname="$(echo ${LDAP_SUFFIX} | sed -e 's/dc=//g' -e 's/,/./g')"

export LDAP_SUFFIX_MAJOR="$( echo ${dn2dnsname} | awk -F'.' '{print $1}')"
export LDAP_BINDDN="cn=${VMAIL_USER_NAME},${LDAP_SUFFIX}"
export LDAP_ADMIN_DN="cn=${VMAIL_DB_ADMIN_USER},${LDAP_SUFFIX}"
export LDAP_ROOTDN="cn=Manager,${LDAP_SUFFIX}"
export LDAP_BASEDN_NAME='domains'
export LDAP_BASEDN="o=${LDAP_BASEDN_NAME},${LDAP_SUFFIX}"
export LDAP_ADMIN_BASEDN="o=${LDAP_ATTR_DOMAINADMIN_DN_NAME},${LDAP_SUFFIX}"
rm -f /tmp/ldap_suffix

cat >> ${IREDMAIL_CONFIG_FILE} <<EOF
export dn2dnsname="${dn2dnsname}"
export LDAP_SUFFIX="${LDAP_SUFFIX}"
export LDAP_SUFFIX_MAJOR="${LDAP_SUFFIX_MAJOR}"
export LDAP_BINDDN="cn=${VMAIL_USER_NAME},${LDAP_SUFFIX}"
export LDAP_ADMIN_DN="${LDAP_ADMIN_DN}"
export LDAP_ROOTDN="cn=Manager,${LDAP_SUFFIX}"
export LDAP_BASEDN_NAME="domains"
export LDAP_BASEDN="o=${LDAP_BASEDN_NAME},${LDAP_SUFFIX}"
export LDAP_ADMIN_BASEDN="o=${LDAP_ATTR_DOMAINADMIN_DN_NAME},${LDAP_SUFFIX}"
EOF
