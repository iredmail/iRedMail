#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -------------------------------------------
# Install all optional components.
# -------------------------------------------
optional_components()
{
    # iRedAPD.
    [ X"${USE_IREDAPD}" == X'YES' ] && \
        check_status_before_run iredapd_config

    # iRedAdmin.
    [ X"${USE_IREDADMIN}" == X"YES" ] && \
        check_status_before_run iredadmin_config

    # Fail2ban.
    [ X"${USE_FAIL2BAN}" == X'YES' \
        -a X"${DISTRO}" != X'OPENBSD' \
        -a X"${DISTRO}" != X'FREEBSD' \
        ] && \
        check_status_before_run fail2ban_config

    # Roundcubemail.
    [ X"${USE_RCM}" == X"YES" ] && \
        check_status_before_run rcm_install && \
        check_status_before_run rcm_config_httpd && \
        check_status_before_run rcm_import_sql && \
        check_status_before_run rcm_config && \
        check_status_before_run rcm_plugin_managesieve && \
        check_status_before_run rcm_plugin_password

    # SOGo
    [ X"${USE_SOGO}" == X"YES" ] && \
        check_status_before_run sogo_config

    # Awstats.
    [ X"${USE_AWSTATS}" == X"YES" ] && \
        check_status_before_run awstats_config_basic && \
        check_status_before_run awstats_config_weblog && \
        check_status_before_run awstats_config_maillog && \
        check_status_before_run awstats_config_crontab
}
