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

# ---------------------------------------------------------------
# Optional web applications
# ---------------------------------------------------------------
if [ X"${DISABLE_WEB_SERVER}" != X'YES' ]; then
    export DIALOG_SELECTABLE_ROUNDCUBE='YES'
    export DIALOG_SELECTABLE_NETDATA='YES'
    export DIALOG_SELECTABLE_SOGO='NO'

    # SOGo team doesn't offer binary packages for arm platform.
    if [ X"${OS_ARCH}" == X'i386' -o X"${OS_ARCH}" == X'x86_64' ]; then
        export DIALOG_SELECTABLE_SOGO='YES'
    fi

    # SOGo team doesn't offer binary packages for Ubuntu 18.10 (yet).
    [ X"${DISTRO_CODENAME}" == X'cosmic' ] && export DIALOG_SELECTABLE_SOGO='NO'

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # OpenBSD doesn't have 'libuuid' which required by netdata
        export DIALOG_SELECTABLE_NETDATA='NO'
    fi
fi

# iRedAdmin
if [ X"${DIALOG_SELECTABLE_IREDADMIN}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} iRedAdmin Official_web-based_Admin_Panel on"
fi

# Roundcube
if [ X"${DIALOG_SELECTABLE_ROUNDCUBE}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} Roundcubemail Popular_webmail_built_with_PHP_and_AJAX on"
fi

# SOGo
if [ X"${DIALOG_SELECTABLE_SOGO}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} SOGo Webmail,_Calendar,_Address_book off"
fi

# netdata
if [ X"${DIALOG_SELECTABLE_NETDATA}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} netdata Awesome_system_monitor on"
fi
