#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)

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


ldapd_config()
{
    ECHO_INFO "Configure LDAP server shipped in OpenBSD base system: ldapd(8)."

    # Enable ldapd in rc.conf.local
    cat >> ${RC_CONF_LOCAL} <<EOF
ldapd_flags=''
EOF

    ECHO_DEBUG "Copy schema files"
    cp -f ${SAMPLE_DIR}/iredmail.schema ${LDAPD_SCHEMA_DIR}
    cp -f /usr/local/share/doc/amavisd-new/LDAP.schema ${LDAPD_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}

    ECHO_DEBUG "Copy sample config file: ${SAMPLE_DIR}/openbsd/ldapd.conf -> ${LDAPD_CONF}"
    backup_file ${LDAPD_CONF}
    cp -f ${SAMPLE_DIR}/openbsd/ldapd.conf ${LDAPD_CONF}
    chmod 0600 ${LDAPD_CONF}

    ECHO_DEBUG "Update config file: ${LDAPD_CONF}"
    export LDAP_SUFFIX LDAP_BASEDN LDAP_ADMIN_BASEDN
    export LDAP_ROOTDN LDAP_ROOTPW
    export LDAP_BINDDN LDAP_ADMIN_DN
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_BASEDN#$ENV{LDAP_ADMIN_BASEDN}#g' ${LDAPD_CONF}

    perl -pi -e 's#PH_LDAP_ROOTDN#$ENV{LDAP_ROOTDN}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_ROOTPW#$ENV{LDAP_ROOTPW_SSHA}#g' ${LDAPD_CONF}

    perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_DN#$ENV{LDAP_ADMIN_DN}#g' ${LDAPD_CONF}

    ECHO_DEBUG "Start ldapd"
    ${DIR_RC_SCRIPTS}/${LDAPD_RC_SCRIPT_NAME} restart >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Sleep 5 seconds for LDAP daemon initialize ..."
    sleep 5

    ECHO_DEBUG "Populate LDAP tree"
    ldapadd -x \
        -h ${LDAP_SERVER_HOST} -p ${LDAP_SERVER_PORT} \
        -D "${LDAP_ROOTDN}" -w "${LDAP_ROOTPW}" \
        -f ${LDAP_INIT_LDIF} >> ${INSTALL_LOG} 2>&1

    echo 'export status_ldapd_config="DONE"' >> ${STATUS_FILE}
}
