#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -------------------------------------------
# Install all optional components.
# -------------------------------------------
optional_components()
{
    # iRedAPD.
    check_status_before_run iredapd_setup

    # iRedAdmin.
    [ X"${USE_IREDADMIN}" == X'YES' ] && check_status_before_run iredadmin_setup

    # Fail2ban.
    [ X"${USE_FAIL2BAN}" == X'YES' \
        -a X"${DISTRO}" != X'OPENBSD' \
        -a X"${DISTRO}" != X'FREEBSD' \
        ] && \
        check_status_before_run fail2ban_config

    # Roundcubemail.
    [ X"${USE_ROUNDCUBE}" == X'YES' ] && check_status_before_run rcm_setup

    # SOGo
    [ X"${USE_SOGO}" == X'YES' ] && check_status_before_run sogo_setup

    # netdata.
    [ X"${USE_NETDATA}" == X'YES' ] && check_status_before_run netdata_setup
}
