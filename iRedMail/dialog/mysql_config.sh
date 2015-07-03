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

# MySQL root password.
while : ; do
    ${DIALOG} \
    --title "Password for MySQL administrator: ${MYSQL_ROOT_USER}" \
    ${PASSWORDBOX} "\
Please specify password for MySQL administrator ${MYSQL_ROOT_USER} on server
${MYSQL_SERVER}.

WARNING:

    * Do *NOT* use special characters in password right now. e.g. $, #, @, space.
    * EMPTY password is *NOT* permitted.
" 20 76 2>/tmp/mysql_rootpw

    MYSQL_ROOT_PASSWD="$(cat /tmp/mysql_rootpw)"

    # Check $, #, space
    echo ${MYSQL_ROOT_PASSWD} | grep '[\$\#\ ]' &>/dev/null
    [ X"$?" != X'0' -a X"${MYSQL_ROOT_PASSWD}" != X'' ] && break
done

echo "export MYSQL_ROOT_PASSWD='${MYSQL_ROOT_PASSWD}'" >>${IREDMAIL_CONFIG_FILE}
# MYSQL_ROOT_USER is defined in conf/mysql
echo "export MYSQL_ROOT_USER='${MYSQL_ROOT_USER}'" >>${IREDMAIL_CONFIG_FILE}
rm -f /tmp/mysql_rootpw
