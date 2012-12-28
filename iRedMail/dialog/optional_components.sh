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

# ----------------------------------------
# Optional components for special backend.
# ----------------------------------------
# Detect selectable menu items
if [ X"${DISTRO}" == X'SUSE' ]; then
    # Apache module mod_auth_pgsql is not available
    [ X"${BACKEND}" == X'PGSQL' ] && export DIALOG_SELECTABLE_AWSTATS='NO'
elif [ X"${DISTRO}" == X'OPENBSD' ]; then
    # Binary/port Awstats is not available in 5.2 and earlier releases
    export DIALOG_SELECTABLE_AWSTATS='NO'
fi

# Construct dialog menu list
# Format: item_name item_descrition on/off
# Note: item_descrition must be concatenated by '_'.
export LIST_OF_OPTIONAL_COMPONENTS=''

if [ X"${BACKEND}" == X'OPENLDAP' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} phpLDAPadmin Web-based_LDAP_management_tool on"
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} phpMyAdmin Web-based_MySQL_management_tool on"
elif [ X"${BACKEND}" == X'MYSQL' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} phpMyAdmin Web-based_MySQL_management_tool on"
elif [ X"${BACKEND}" == X'PGSQL' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} phpMyAdmin Web-based_MySQL_management_tool on"
fi

if [ X"${DIALOG_SELECTABLE_AWSTATS}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} phpPgAdmin Web-based_PostgreSQL_management_tool on"
fi

# Fail2ban
LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} Fail2ban Ban_IP_with_too_many_password_failures on"

export tmp_config_optional_components="${ROOTDIR}/.optional_components"

${DIALOG} \
--title "Optional components" \
--checklist "\
Note:
    * DKIM is recommended.
    * SPF validation (Sender Policy Framework) is enabled by default.
    * DNS records (TXT type) are required for both SPF and DKIM.
    * Refer to file for more detail after installation:
      ${TIP_FILE}
" 20 76 8 \
"DKIM signing/verification" "DomainKeys Identified Mail" "on" \
"iRedAdmin" "Official web-based Admin Panel" "on" \
"Roundcubemail" "WebMail program (PHP, AJAX)" "on" \
${LIST_OF_OPTIONAL_COMPONENTS} \
2>${tmp_config_optional_components}

OPTIONAL_COMPONENTS="$(cat ${tmp_config_optional_components})"
rm -f ${tmp_config_optional_components} &>/dev/null

echo ${OPTIONAL_COMPONENTS} | grep -i '\<SPF\>' >/dev/null 2>&1
[ X"$?" == X"0" ] && export ENABLE_SPF='YES' && echo "export ENABLE_SPF='YES'" >>${CONFIG_FILE}

echo ${OPTIONAL_COMPONENTS} | grep -i '\<DKIM\>' >/dev/null 2>&1
[ X"$?" == X"0" ] && export ENABLE_DKIM='YES' && echo "export ENABLE_DKIM='YES'" >>${CONFIG_FILE}

echo ${OPTIONAL_COMPONENTS} | grep -i 'iredadmin' >/dev/null 2>&1
[ X"$?" == X"0" ] && export USE_IREDADMIN='YES' && export USE_IREDADMIN='YES' && echo "export USE_IREDADMIN='YES'" >> ${CONFIG_FILE}

if echo ${OPTIONAL_COMPONENTS} | grep -i 'roundcubemail' &>/dev/null; then
    export USE_WEBMAIL='YES'
    export USE_RCM='YES'
    export REQUIRE_PHP='YES'
    echo "export USE_WEBMAIL='YES'" >> ${CONFIG_FILE}
    echo "export USE_RCM='YES'" >> ${CONFIG_FILE}
    echo "export REQUIRE_PHP='YES'" >> ${CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'phpldapadmin' &>/dev/null; then
    export USE_PHPLDAPADMIN='YES'
    export REQUIRE_PHP='YES'
    echo "export USE_PHPLDAPADMIN='YES'" >>${CONFIG_FILE}
    echo "export REQUIRE_PHP='YES'" >> ${CONFIG_FILE}
fi

echo ${OPTIONAL_COMPONENTS} | grep -i 'phpmyadmin' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
    export USE_PHPMYADMIN='YES'
    echo "export USE_PHPMYADMIN='YES'" >>${CONFIG_FILE}
    echo "export REQUIRE_PHP='YES'" >> ${CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'phppgadmin' &>/dev/null; then
    export USE_PHPPGADMIN='YES'
    echo "export USE_PHPPGADMIN='YES'" >>${CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'awstats' &>/dev/null; then
    export USE_AWSTATS='YES'
    echo "export USE_AWSTATS='YES'" >>${CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'fail2ban' &>/dev/null; then
    export USE_FAIL2BAN='YES'
    echo "export USE_FAIL2BAN='YES'" >>${CONFIG_FILE}
fi

# Used when you use awstats.
[ X"${USE_AWSTATS}" == X"YES" ] && . ${DIALOG_DIR}/awstats_config.sh
