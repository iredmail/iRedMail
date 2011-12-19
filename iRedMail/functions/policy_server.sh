#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb@iredmail.org)

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

policy_server_config()
{
    if [ X"${DISTRO_CODENAME}" != X"oneiric" ]; then
        . ${FUNCTIONS_DIR}/policyd.sh

        ECHO_INFO "Configure Policyd (postfix policy server, version 1.8)."
        check_status_before_run policyd_user
        check_status_before_run policyd_config
    else
        . ${FUNCTIONS_DIR}/cluebringer.sh

        ECHO_INFO "Configure Policyd (postfix policy server, code name cluebringer)."
        check_status_before_run cluebringer_user
        check_status_before_run cluebringer_config
        check_status_before_run cluebringer_webui_config
    fi

    # FreeBSD: Start policyd when system start up.
    [ X"${DISTRO}" == X"FREEBSD" ] && cat >> /etc/rc.conf <<EOF
# Start policyd.
postfix_policyd_sf_enable="YES"
EOF

    echo 'export status_policy_server_config="DONE"' >> ${STATUS_FILE}
}
