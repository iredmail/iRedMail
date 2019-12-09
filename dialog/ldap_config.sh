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
" 20 76 "dc=example,dc=com" 2>${RUNTIME_DIR}/.ldap_suffix

    LDAP_SUFFIX="$(cat ${RUNTIME_DIR}/.ldap_suffix)"
    [ X"${LDAP_SUFFIX}" != X"" ] && break
done

rm -f ${RUNTIME_DIR}/.ldap_suffix

export LDAP_SUFFIX="${LDAP_SUFFIX}"
echo "export LDAP_SUFFIX='${LDAP_SUFFIX}'" >> ${IREDMAIL_CONFIG_FILE}

# LDAP bind dn, passwords.
export LDAP_BINDPW="$(${RANDOM_STRING})"
export LDAP_ADMIN_PW="$(${RANDOM_STRING})"
export LDAP_ROOTPW="$(${RANDOM_STRING})"
echo "export LDAP_BINDPW='${LDAP_BINDPW}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export LDAP_ADMIN_PW='${LDAP_ADMIN_PW}'" >> ${IREDMAIL_CONFIG_FILE}
echo "export LDAP_ROOTPW='${LDAP_ROOTPW}'" >> ${IREDMAIL_CONFIG_FILE}
