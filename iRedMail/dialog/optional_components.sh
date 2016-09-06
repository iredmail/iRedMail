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
export DIALOG_SELECTABLE_SOGO='YES'

# SOGo team doesn't offer binary packages for arm platform.
if [ X"${OS_ARCH}" == X'armhf' ]; then
    export DIALOG_SELECTABLE_SOGO='NO'
fi

if [ X"${APACHE_VERSION}" == X'2.4' -o X"${WEB_SERVER_IS_NGINX}" == X'YES' ] ;then
    # Apache 2.4 and Nginx don't have SQL/LDAP AUTH module
    export DIALOG_SELECTABLE_AWSTATS='NO'
fi

if [ X"${DISTRO}" == X'FREEBSD' ]; then
    export DIALOG_SELECTABLE_FAIL2BAN='NO'
fi

if [ X"${WEB_SERVER_IS_NGINX}" == X'YES' ]; then
    export DIALOG_SELECTABLE_AWSTATS='NO'
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
* DKIM signing/verification and SPF validation are enabled by default.
* DNS records for SPF and DKIM are required after installation.

Refer to below file for more detail after installation:

* ${TIP_FILE}
" 20 76 6 \
"iRedAdmin" "Official web-based Admin Panel" "on" \
"Roundcubemail" "WebMail program (PHP, AJAX)" "on" \
${LIST_OF_OPTIONAL_COMPONENTS} \
2>${tmp_config_optional_components}

OPTIONAL_COMPONENTS="$(cat ${tmp_config_optional_components})"
rm -f ${tmp_config_optional_components} &>/dev/null

echo ${OPTIONAL_COMPONENTS} | grep -i 'iredadmin' &>/dev/null
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

export random_pw="$(${RANDOM_STRING})"
export AMAVISD_DB_PASSWD="${AMAVISD_DB_PASSWD:=${random_pw}}"
echo "export AMAVISD_DB_PASSWD='${AMAVISD_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export IREDADMIN_DB_PASSWD="${IREDADMIN_DB_PASSWD:=${random_pw}}"
echo "export IREDADMIN_DB_PASSWD='${IREDADMIN_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export RCM_DB_PASSWD="${RCM_DB_PASSWD:=${random_pw}}"
echo "export RCM_DB_PASSWD='${RCM_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export SOGO_DB_PASSWD="${SOGO_DB_PASSWD:=${random_pw}}"
echo "export SOGO_DB_PASSWD='${SOGO_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export SOGO_SIEVE_MASTER_PASSWD="${SOGO_SIEVE_MASTER_PASSWD:=${random_pw}}"
echo "export SOGO_SIEVE_MASTER_PASSWD='${SOGO_SIEVE_MASTER_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export IREDAPD_DB_PASSWD="${IREDAPD_DB_PASSWD:=${random_pw}}"
echo "export IREDAPD_DB_PASSWD='${IREDAPD_DB_PASSWD}'" >> ${IREDMAIL_CONFIG_FILE}
