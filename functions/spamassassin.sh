#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# ---------------------------------------------------------
# SpamAssassin.
# ---------------------------------------------------------
sa_config()
{
    ECHO_INFO "Configure SpamAssassin (content-based spam filter)."

    backup_file ${SA_LOCAL_CF}

    ECHO_DEBUG "Copy sample SpamAssassin config file: ${SAMPLE_DIR}/spamassassin/local.cf -> ${SA_LOCAL_CF}."
    cp -f ${SAMPLE_DIR}/spamassassin/local.cf ${SA_LOCAL_CF}
    cp -f ${SAMPLE_DIR}/spamassassin/razor.conf ${SA_PLUGIN_RAZOR_CONF}

    perl -pi -e 's#PH_SA_PLUGIN_RAZOR_CONF#$ENV{SA_PLUGIN_RAZOR_CONF}#g' ${SA_LOCAL_CF}

    ECHO_DEBUG "Enable crontabs for SpamAssassin update."
    if [ X"${DISTRO}" == X'RHEL' ]; then
        [ -f ${ETC_SYSCONFIG_DIR}/sa-update ] && \
            perl -pi -e 's/^#(SAUPDATE=yes)/${1}/' ${ETC_SYSCONFIG_DIR}/sa-update

        chmod 0644 /etc/cron.d/sa-update
        perl -pi -e 's/#(10.*)/${1}/' /etc/cron.d/sa-update
    elif [ X"${DISTRO}" == X'UBUNTU' -o X"${DISTRO}" == X'DEBIAN' ]; then
        perl -pi -e 's#^(CRON=)0#${1}1#' /etc/default/spamassassin
    fi

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        ECHO_DEBUG "Compile SpamAssassin ruleset into native code."
        sa-compile >> ${INSTALL_LOG} 2>&1
    fi

    cat >> ${TIP_FILE} <<EOF
SpamAssassin:
    * Configuration files and rules:
        - ${SA_CONF_DIR}
        - ${SA_CONF_DIR}/local.cf

EOF

    echo 'export status_sa_config="DONE"' >> ${STATUS_FILE}
}
