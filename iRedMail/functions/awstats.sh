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

awstats_config_basic()
{
    ECHO_INFO "Configure Awstats (logfile analyzer for mail and web server)."
    [ -f ${AWSTATS_CONF_SAMPLE} ] && dos2unix ${AWSTATS_CONF_SAMPLE} &>/dev/null

    ECHO_DEBUG "Generate apache config file for awstats: ${AWSTATS_HTTPD_CONF}."
    backup_file ${AWSTATS_HTTPD_CONF}

    # Assign Apache daemon user to group 'adm', so that Awstats cron job can read log files.
    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        usermod -G adm ${HTTPD_USER} >> ${INSTALL_LOG} 2>&1
    fi

    if [ X"${WEB_SERVER}" == X'APACHE' ]; then
        cp -f ${SAMPLE_DIR}/awstats/apache.conf ${AWSTATS_HTTPD_CONF}

        perl -pi -e 's#PH_AWSTATS_ICON_DIR#$ENV{AWSTATS_ICON_DIR}#g' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_AWSTATS_CSS_DIR#$ENV{AWSTATS_CSS_DIR}#g' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_AWSTATS_JS_DIR#$ENV{AWSTATS_JS_DIR}#g' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_AWSTATS_CGI_DIR#$ENV{AWSTATS_CGI_DIR}#g' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_AWSTATS_HTTPD_AUTH_FILE#$ENV{AWSTATS_HTTPD_AUTH_FILE}#g' ${AWSTATS_HTTPD_CONF}

        # Make Awstats accessible via HTTPS.
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /awstats/icon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /awstatsicon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(\s*</VirtualHost>)#ScriptAlias /awstats "$ENV{AWSTATS_CGI_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}

        if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
            a2enmod cgi >> ${INSTALL_LOG} 2>&1

            # serve-cgi-bin.conf contains duplicate and conflict setting for cgi-bin
            a2disconf serve-cgi-bin >> ${INSTALL_LOG} 2>&1
            a2enconf awstats >> ${INSTALL_LOG} 2>&1
        fi
    fi

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        ECHO_DEBUG "Create directory used to store static pages: ${AWSTATS_STATIC_PAGES_DIR}"
        [ -d ${AWSTATS_STATIC_PAGES_DIR} ] || mkdir -p ${AWSTATS_STATIC_PAGES_DIR} >> ${INSTALL_LOG} 2>&1
    fi


    ECHO_DEBUG "Generate htpasswd file: ${AWSTATS_HTTPD_AUTH_FILE}."
    touch ${AWSTATS_HTTPD_AUTH_FILE}
    chown ${HTTPD_USER}:${HTTPD_GROUP} ${AWSTATS_HTTPD_AUTH_FILE}
    chmod 0400 ${AWSTATS_HTTPD_AUTH_FILE}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # htpasswd in OpenBSD base system is not same as Apache htpasswd
        echo "${FIRST_USER}@${FIRST_DOMAIN}:${FIRST_USER_PASSWD}" | htpasswd -I ${AWSTATS_HTTPD_AUTH_FILE}
    else
        if [ X"${APACHE_VERSION}" == X'2.4' -o X"${DISTRO}" == X'FREEBSD' ]; then
            # Use BCRYPT (the '-B' flag)
            htpasswd -b -B -c ${AWSTATS_HTTPD_AUTH_FILE} ${FIRST_USER}@${FIRST_DOMAIN} ${FIRST_USER_PASSWD} >> ${INSTALL_LOG} 2>&1
        else
            # Use MD5
            htpasswd -b -c ${AWSTATS_HTTPD_AUTH_FILE} ${FIRST_USER}@${FIRST_DOMAIN} ${FIRST_USER_PASSWD} >> ${INSTALL_LOG} 2>&1
        fi
    fi

    cat >> ${TIP_FILE} <<EOF
Awstats:
    * Configuration files:
        - ${AWSTATS_CONF_DIR}
        - ${AWSTATS_CONF_WEB}
        - ${AWSTATS_CONF_MAIL}
        - ${AWSTATS_HTTPD_AUTH_FILE}
        - ${AWSTATS_HTTPD_CONF} - Available if you're running Apache
    * Login account:
        - Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}, password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * URL:
        - https://${HOSTNAME}/awstats/awstats.pl?config=web
        - https://${HOSTNAME}/awstats/awstats.pl?config=smtp
    * Crontab job:
        shell> crontab -l root
    * Command used to add a new user, or reset password for an existing user:
        htpasswd PH_AWSTATS_HTTPD_AUTH_FILE username

EOF

    echo 'export status_awstats_config_basic="DONE"' >> ${STATUS_FILE}
}

awstats_config_weblog()
{
    ECHO_DEBUG "Config awstats to analyze apache web access log: ${AWSTATS_CONF_WEB}."
    cd ${AWSTATS_CONF_DIR}
    cp -f ${AWSTATS_CONF_SAMPLE} ${AWSTATS_CONF_WEB}

    perl -pi -e 's#^(SiteDomain=)(.*)#${1}"$ENV{HOSTNAME}"#' ${AWSTATS_CONF_WEB}
    perl -pi -e 's#^(LogFile=)(.*)#${1}"$ENV{HTTPD_LOG_ACCESSLOG}"#' ${AWSTATS_CONF_WEB}
    perl -pi -e 's#^(Lang=)(.*)#${1}$ENV{AWSTATS_LANGUAGE}#' ${AWSTATS_CONF_WEB}

    perl -pi -e 's#^(DirIcons=)(.*)#${1}"/awstats/icon#' ${AWSTATS_CONF_WEB}

    # LogFormat
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        perl -pi -e 's#^(LogFormat).*#${1}="%host %other %logname %time1 %methodurl %code %bytesd"#' ${AWSTATS_CONF_WEB}
        perl -pi -e 's#^(LogFile=)(.*)#${1}"$ENV{HTTPD_SERVERROOT}/$ENV{HTTPD_LOG_ACCESSLOG}"#' ${AWSTATS_CONF_WEB}
    fi
    # On RHEL/CentOS/Debian, ${AWSTATS_CONF_SAMPLE} is default config file. Overrided here.
    backup_file ${AWSTATS_CONF_SAMPLE}
    cp -f ${AWSTATS_CONF_WEB} ${AWSTATS_CONF_SAMPLE}

    echo 'export status_awstats_config_weblog="DONE"' >> ${STATUS_FILE}
}

awstats_config_maillog()
{
    ECHO_DEBUG "Config awstats to analyze postfix mail log: ${AWSTATS_CONF_MAIL}."

    cd ${AWSTATS_CONF_DIR}

    # Create a default config file.
    cp -f ${AWSTATS_CONF_SAMPLE} ${AWSTATS_CONF_MAIL}
    cp -f ${AWSTATS_CONF_MAIL} ${AWSTATS_CONF_DIR}/awstats.conf

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        if [ X"${DISTRO_VERSION}" == X'9' ]; then
            export maillogconvert_pl="$( eval ${LIST_FILES_IN_PKG} "/var/db/pkg/awstats-*" | grep 'maillogconvert.pl')"
        else
            export maillogconvert_pl="$( eval ${LIST_FILES_IN_PKG} awstats | grep 'maillogconvert.pl')"
        fi
    else
        export maillogconvert_pl="$( eval ${LIST_FILES_IN_PKG} awstats | grep 'maillogconvert.pl')"
    fi

    perl -pi -e 's#^(SiteDomain=)(.*)#${1}"mail"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogFile=)(.*)#${1}"perl $ENV{maillogconvert_pl} standard < $ENV{MAILLOG} |"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogType=)(.*)#${1}M#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogFormat=)(.*)#${1}"%time2 %email %email_r %host %host_r %method %url %code %bytesd"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForBrowsersDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForOSDetection=)(.*)#${1}0##' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForRefererAnalyze=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForRobotsDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForWormsDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForSearchEnginesDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForFileTypesDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDomainsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowAuthenticatedUsers=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowRobotsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSessionsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowPagesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowFileTypesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowFileSizesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowBrowsersStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowOSStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowOriginStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowKeyphrasesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowKeywordsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowMiscStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHTTPErrorsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDownloadsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowLinksOnUrl=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(ShowMenu=)(.*)#${1}1#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSummary=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowMonthStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDaysOfMonthStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDaysOfWeekStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHoursStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSMTPErrorsStats=)(.*)#${1}1#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHostsStats=)(.*)#${1}HBL#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowEMailSenders=)(.*)#${1}HBML#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowEMailReceivers=)(.*)#${1}HBML#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(Lang=)(.*)#${1}$ENV{AWSTATS_LANGUAGE}#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(DirIcons=)(.*)#${1}"/awstats/icon#' ${AWSTATS_CONF_MAIL}

    echo 'export status_awstats_config_maillog="DONE"' >> ${STATUS_FILE}
}

awstats_config_crontab()
{
    ECHO_DEBUG "Setting cronjob for awstats."

    if [ X"${WEB_SERVER}" == X'APACHE' ]; then
        cat >> ${CRON_FILE_ROOT} <<EOF
# ${PROG_NAME}: update Awstats statistics for web
1   */1   *   *   *   ${PERL_BIN} ${AWSTATS_CGI_DIR}/awstats.pl -update -config=web >/dev/null

# ${PROG_NAME}: update Awstats statistics for smtp
1   */1   *   *   *   ${PERL_BIN} ${AWSTATS_CGI_DIR}/awstats.pl -update -config=smtp >/dev/null

EOF
    elif [ X"${WEB_SERVER}" == X'NGINX' ]; then
        cat >> ${CRON_FILE_ROOT} <<EOF
# ${PROG_NAME}: update Awstats statistics for web
1   */1   *   *   *   ${PERL_BIN} ${AWSTATS_CMD_BUILDSTATICPAGE} -update -config=web -dir=${AWSTATS_STATIC_PAGES_DIR} -configdir=${AWSTATS_CONF_DIR} >/dev/null

# ${PROG_NAME}: update Awstats statistics for smtp
1   */1   *   *   *   ${PERL_BIN} ${AWSTATS_CMD_BUILDSTATICPAGE} -update -config=smtp -dir=${AWSTATS_STATIC_PAGES_DIR} -configdir=${AWSTATS_CONF_DIR} >/dev/null

EOF
    fi

    echo 'export status_awstats_config_crontab="DONE"' >> ${STATUS_FILE}
}

awstats_setup() {
    check_status_before_run awstats_config_basic
    check_status_before_run awstats_config_weblog
    check_status_before_run awstats_config_maillog
    check_status_before_run awstats_config_crontab

    echo 'export status_awstats_setup="DONE"' >> ${STATUS_FILE}
}
