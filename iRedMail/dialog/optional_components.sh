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
# Enabled components.
export DIALOG_SELECTABLE_AWSTATS='YES'
export DIALOG_SELECTABLE_FAIL2BAN='YES'
export DIALOG_SELECTABLE_SOGO='NO'

if [ X"${DISTRO}" == X'RHEL' ]; then
    [ X"${DISTRO_VERSION}" == X'6' ] && export DIALOG_SELECTABLE_SOGO='YES'
elif [ X"${DISTRO}" == X'DEBIAN' ]; then
    export DIALOG_SELECTABLE_SOGO='YES'
elif [ X"${DISTRO}" == X'UBUNTU' ]; then
    export DIALOG_SELECTABLE_SOGO='YES'
elif [ X"${DISTRO}" == X'FREEBSD' ]; then
    export DIALOG_SELECTABLE_FAIL2BAN='NO'
fi

# Construct dialog menu list
# Format: item_name item_descrition on/off
# Note: item_descrition must be concatenated by '_'.
export LIST_OF_OPTIONAL_COMPONENTS=''

if [ X"${DIALOG_SELECTABLE_SOGO}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} SOGo Webmail,_Calendar,_Address_book off"
fi

if [ X"${DIALOG_SELECTABLE_AWSTATS}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} Awstats Advanced_web_and_mail_log_analyzer on"
fi

# Fail2ban
if [ X"${DIALOG_SELECTABLE_FAIL2BAN}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} Fail2ban Ban_IP_with_too_many_password_failures on"
fi

export tmp_config_optional_components="${ROOTDIR}/.optional_components"

${DIALOG} \
--title "Optional components" \
--checklist "\
Note:
    * DKIM is recommended.
    * SPF validation (Sender Policy Framework) is enabled by default.
    * DNS records (TXT type) are required for both SPF and DKIM.

Refer to below file for more detail after installation:
    * ${TIP_FILE}
" 20 76 8 \
"DKIM signing/verification" "DomainKeys Identified Mail" "on" \
"iRedAdmin" "Official web-based Admin Panel" "on" \
"Roundcubemail" "WebMail program (PHP, AJAX)" "on" \
${LIST_OF_OPTIONAL_COMPONENTS} \
2>${tmp_config_optional_components}

OPTIONAL_COMPONENTS="$(cat ${tmp_config_optional_components})"
rm -f ${tmp_config_optional_components} &>/dev/null

echo ${OPTIONAL_COMPONENTS} | grep -i '\<SPF\>' >/dev/null 2>&1
[ X"$?" == X"0" ] && export ENABLE_SPF='YES' && echo "export ENABLE_SPF='YES'" >>${IREDMAIL_CONFIG_FILE}

echo ${OPTIONAL_COMPONENTS} | grep -i '\<DKIM\>' >/dev/null 2>&1
[ X"$?" == X"0" ] && export ENABLE_DKIM='YES' && echo "export ENABLE_DKIM='YES'" >>${IREDMAIL_CONFIG_FILE}

echo ${OPTIONAL_COMPONENTS} | grep -i 'iredadmin' >/dev/null 2>&1
[ X"$?" == X"0" ] && export USE_IREDADMIN='YES' && echo "export USE_IREDADMIN='YES'" >> ${IREDMAIL_CONFIG_FILE}

if echo ${OPTIONAL_COMPONENTS} | grep -i 'roundcubemail' &>/dev/null; then
    export USE_RCM='YES'
    echo "export USE_RCM='YES'" >> ${IREDMAIL_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'sogo' &>/dev/null; then
    export USE_SOGO='YES'
    echo "export USE_SOGO='YES'" >> ${IREDMAIL_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'awstats' &>/dev/null; then
    export USE_AWSTATS='YES'
    echo "export USE_AWSTATS='YES'" >>${IREDMAIL_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'fail2ban' &>/dev/null; then
    export USE_FAIL2BAN='YES'
    echo "export USE_FAIL2BAN='YES'" >>${IREDMAIL_CONFIG_FILE}
fi

export AMAVISD_DB_PASSWD="$(${RANDOM_STRING})"
echo "export AMAVISD_DB_PASSWD='${AMAVISD_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export CLUEBRINGER_DB_PASSWD="$(${RANDOM_STRING})"
echo "export CLUEBRINGER_DB_PASSWD='${CLUEBRINGER_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export IREDADMIN_DB_PASSWD="$(${RANDOM_STRING})"
echo "export IREDADMIN_DB_PASSWD='${IREDADMIN_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export RCM_DB_PASSWD="$(${RANDOM_STRING})"
echo "export RCM_DB_PASSWD='${RCM_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export SOGO_DB_PASSWD="$(${RANDOM_STRING})"
echo "export SOGO_DB_PASSWD='${SOGO_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}
