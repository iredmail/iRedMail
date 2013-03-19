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

# --------------------------------------------------
# -------------------- Awstats ---------------------
# --------------------------------------------------

. ${CONF_DIR}/awstats

if [ X"${BACKEND}" == X"OPENLDAP" \
    -o X"${BACKEND}" == X"MYSQL" \
    -o X"${BACKEND}" == X"PGSQL" \
    ]; then
    :
else
    # Set username for awstats access.
    while : ; do
        ${DIALOG} \
        --title "Specify usernamen for access awstats from web browser" \
        --inputbox "\
Please specify username for access awstats from web browser.

EXAMPLE:

    * admin

" 20 76 2>/tmp/awstats_username

        AWSTATS_USERNAME="$(cat /tmp/awstats_username)"
        [ X"${AWSTATS_USERNAME}" != X"" ] && break
    done

    echo "export AWSTATS_USERNAME='${AWSTATS_USERNAME}'" >>${IREDMAIL_CONFIG_FILE}
    rm -f /tmp/awstats_username

    # Set password for awstats user.
    while : ; do
        ${DIALOG} \
        --title "Password for awstats user: ${AWSTATS_USERNAME}" \
        ${PASSWORDBOX} "\
Please specify password for awstats user: ${AWSTATS_USERNAME}

WARNING:

    * EMPTY password is *NOT* permitted.

" 20 76 2>/tmp/awstats_passwd

        AWSTATS_PASSWD="$(cat /tmp/awstats_passwd)"
        [ X"${AWSTATS_PASSWD}" != X"" ] && break
    done

    echo "export AWSTATS_PASSWD='${AWSTATS_PASSWD}'" >>${IREDMAIL_CONFIG_FILE}
    rm -f /tmp/awstats_passwd
fi
