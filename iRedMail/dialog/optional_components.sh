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
# Construct dialog menu list
# Format: item_name item_descrition on/off
# Note: item_descrition must be concatenated by '_'.
export LIST_OF_OPTIONAL_COMPONENTS=''

# Fail2ban
export DIALOG_SELECTABLE_FAIL2BAN='YES'
if [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
    export DIALOG_SELECTABLE_FAIL2BAN='NO'
fi

# Web applications
if [ X"${DISABLE_WEB_SERVER}" != X'YES' ]; then
    . ${DIALOG_DIR}/web_applications.sh
fi

# iRedAdmin. Although it's a web application, but it's also able to run with
# WSGI server instead of web server.
LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} iRedAdmin Official_web-based_Admin_Panel on"

# Fail2ban.
if [ X"${DIALOG_SELECTABLE_FAIL2BAN}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} Fail2ban Ban_IP_with_too_many_password_failures on"
fi

export tmp_config_optional_components="${ROOTDIR}/.optional_components"

if echo ${LIST_OF_OPTIONAL_COMPONENTS} | grep 'o' &>/dev/null; then
    ${DIALOG} \
    --title "Optional components" \
    --checklist "\
* DKIM signing/verification and SPF validation are enabled by default.
* DNS records for SPF and DKIM are required after installation.

Refer to below file for more detail after installation:

* ${TIP_FILE}
" 20 76 6 \
${LIST_OF_OPTIONAL_COMPONENTS} \
2>${tmp_config_optional_components}

    OPTIONAL_COMPONENTS="$(cat ${tmp_config_optional_components})"
    rm -f ${tmp_config_optional_components} &>/dev/null
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'iredadmin' &>/dev/null; then
    export USE_IREDADMIN='YES'
    echo "export USE_IREDADMIN='YES'" >> ${IREDMAIL_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'roundcubemail' &>/dev/null; then
    export USE_ROUNDCUBE='YES'
    echo "export USE_ROUNDCUBE='YES'" >> ${IREDMAIL_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'sogo' &>/dev/null; then
    export USE_SOGO='YES'
    echo "export USE_SOGO='YES'" >> ${IREDMAIL_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'netdata' &>/dev/null; then
    export USE_NETDATA='YES'
    echo "export USE_NETDATA='YES'" >>${IREDMAIL_CONFIG_FILE}
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
