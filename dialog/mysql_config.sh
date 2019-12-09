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
# --------------------- MySQL ----------------------
# --------------------------------------------------

. ${CONF_DIR}/mysql

if [ -z "${MYSQL_ROOT_PASSWD}" ]; then
    # set a new MySQL root password.
    while : ; do
        ${DIALOG} \
        --title "Password for MySQL administrator: ${MYSQL_ROOT_USER}" \
        --passwordbox "\
Please specify password for MySQL administrator ${MYSQL_ROOT_USER} on server
${MYSQL_SERVER_ADDRESS}.

WARNING:

* Do *NOT* use double quote (\") in password.
* EMPTY password is *NOT* permitted.
* Sample password: $(${RANDOM_STRING})
" 20 76 2>${RUNTIME_DIR}/.mysql_rootpw

        MYSQL_ROOT_PASSWD="$(cat ${RUNTIME_DIR}/.mysql_rootpw)"

        [ X"${MYSQL_ROOT_PASSWD}" != X'' ] && break
    done

    export MYSQL_ROOT_PASSWD="${MYSQL_ROOT_PASSWD}"
fi

echo "export MYSQL_ROOT_PASSWD='${MYSQL_ROOT_PASSWD}'" >>${IREDMAIL_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.mysql_rootpw &>/dev/null
