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

# --------------------------------------------
# Amavisd-new.
# --------------------------------------------

amavisd_dkim()
{
    pem_file="${AMAVISD_DKIM_DIR}/${FIRST_DOMAIN}.pem"

    ECHO_DEBUG "Generate DKIM pem files: ${pem_file}."
    mkdir -p ${AMAVISD_DKIM_DIR} &>/dev/null && \
    chown -R ${AMAVISD_SYS_USER}:${AMAVISD_SYS_GROUP} ${AMAVISD_DKIM_DIR}
    chmod -R 0700 ${AMAVISD_DKIM_DIR}
    ${AMAVISD_BIN} genrsa ${pem_file} 1024 &>/dev/null
    chown -R ${AMAVISD_SYS_USER}:${AMAVISD_SYS_GROUP} ${pem_file}
    chmod 0400 ${pem_file}

    cat >> ${AMAVISD_DKIM_CONF} <<EOF
# Hope to fix 'nested MAIL command' issue on high load server.
\$smtp_connection_cache_enable = 0;

# The default set of header fields to be signed can be controlled
# by setting %signed_header_fields elements to true (to sign) or
# to false (not to sign). Keys must be in lowercase, e.g.:
# 0 -> off
# 1 -> on
\$signed_header_fields{'received'} = 0;
\$signed_header_fields{'to'} = 1;

# Add dkim_key here.
dkim_key("${FIRST_DOMAIN}", "${AMAVISD_DKIM_SELECTOR}", "${pem_file}");

# Note that signing mail for subdomains with a key of a parent
# domain is treated by recipients as a third-party key, which
# may 'hold less merit' in their eyes. If one has a choice,
# it is better to publish a key for each domain (e.g. host1.a.cn)
# if mail is really coming from it. Sharing a pem file
# for multiple domains may be acceptable, so you don't need
# to generate a different key for each subdomain, but you
# do need to publish it in each subdomain. It is probably
# easier to avoid sending addresses like host1.a.cn and
# always use a parent domain (a.cn) in 'From:', thus
# avoiding the issue altogether.
#dkim_key("host1.${FIRST_DOMAIN}", "${AMAVISD_DKIM_SELECTOR}", "${pem_file}");
#dkim_key("host3.${FIRST_DOMAIN}", "${AMAVISD_DKIM_SELECTOR}", "${pem_file}");

# Add new dkim_key for other domain.
#dkim_key('Your_New_Domain_Name', 'dkim', 'Your_New_Pem_File');

@dkim_signature_options_bysender_maps = ( {
    # ------------------------------------
    # For domain: ${FIRST_DOMAIN}.
    # ------------------------------------
    # 'd' defaults to a domain of an author/sender address,
    # 's' defaults to whatever selector is offered by a matching key

    #'${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}'    => { d => "${FIRST_DOMAIN}", a => 'rsa-sha256', ttl =>  7*24*3600 },
    #"spam-reporter@${FIRST_DOMAIN}"    => { d => "${FIRST_DOMAIN}", a => 'rsa-sha256', ttl =>  7*24*3600 },

    # explicit 'd' forces a third-party signature on foreign (hosted) domains
    "${FIRST_DOMAIN}"  => { d => "${FIRST_DOMAIN}", a => 'rsa-sha256', ttl => 10*24*3600 },
    #"host1.${FIRST_DOMAIN}"  => { d => "host1.${FIRST_DOMAIN}", a => 'rsa-sha256', ttl => 10*24*3600 },
    #"host2.${FIRST_DOMAIN}"  => { d => "host2.${FIRST_DOMAIN}", a => 'rsa-sha256', ttl => 10*24*3600 },
    # ---- End domain: ${FIRST_DOMAIN} ----

    # catchall defaults
    '.' => { a => 'rsa-sha256', c => 'relaxed/simple', ttl => 30*24*3600 },
} );
EOF

    cat >> ${TIP_FILE} <<EOF
DNS record for DKIM support:

EOF
    if [ X"${DISTRO}" == X'RHEL' ]; then
        cat >> ${TIP_FILE} <<EOF
$(${AMAVISD_BIN} -c ${AMAVISD_CONF} showkeys 2>> ${INSTALL_LOG})
EOF
    else
        cat >> ${TIP_FILE} <<EOF
$(${AMAVISD_BIN} showkeys 2>> ${INSTALL_LOG})
EOF
    fi

    echo 'export status_amavisd_dkim="DONE"' >> ${STATUS_FILE}
}

amavisd_config_rhel()
{
    if [ X"${DISTRO}" == X'RHEL' ]; then
        usermod -G ${AMAVISD_SYS_GROUP} ${CLAMAV_USER} >> ${INSTALL_LOG} 2>&1
    fi

    backup_file ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}
    chgrp ${AMAVISD_SYS_GROUP} ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}
    chmod 0640 ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}

    ECHO_DEBUG "Configure amavisd-new: ${AMAVISD_CONF}."

    export HOSTNAME FIRST_DOMAIN
    perl -pi -e 's/^(\$mydomain)/$1\ =\ \"$ENV{HOSTNAME}\"\;\t#/' ${AMAVISD_CONF}
    perl -pi -e 's/^(\@local_domains_maps)(.*=.*)/${1} = 1;/' ${AMAVISD_CONF}

    if [ X"${DISTRO}" == X'RHEL' -a X"${DISTRO_VERSION}" == X"6" ]; then
        perl -pi -e 's#(.*--tempdir=).*\{\}(.*)#${1}$ENV{AMAVISD_TEMPDIR}${2}#' ${AMAVISD_CONF}
        perl -pi -e 's#^(.QUARANTINEDIR =).*#${1} "$ENV{AMAVISD_QUARANTINEDIR}";#' ${AMAVISD_CONF}
    fi

    # Make Amavisd listen on multiple TCP ports.
    perl -pi -e 's/(\$inet_socket_port.*=.*10024.*)/\$inet_socket_port = [10024, 10026, $ENV{'AMAVISD_QUARANTINE_PORT'}];/' ${AMAVISD_CONF}

    # Disable defang banned mail.
    perl -pi -e 's#(.*defang_banned = )1(;.*)#${1}0${2}#' ${AMAVISD_CONF}

    # Remove the content from '@av_scanners' to the end of file.
    new_conf="$(sed '/\@av_scanners/,$d' ${AMAVISD_CONF})"
    # Generate new configration file(Part).
    echo -e "${new_conf}" > ${AMAVISD_CONF}

    # Set pid_file.
    #echo '$pid_file = "/var/run/clamav/amavisd.pid";' >> ${AMAVISD_CONF}

    # Enable disclaimer if available.
    perl -pi -e 's%(os_fingerprint_method => undef.*)%${1}\n  allow_disclaimers => 1, # enables disclaimer insertion if available%' ${AMAVISD_CONF}

    echo 'export status_amavisd_config_rhel="DONE"' >> ${STATUS_FILE}
}

amavisd_config_debian()
{
    backup_file ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}

    ECHO_DEBUG "Configure amavisd-new: ${AMAVISD_CONF}."

    perl -pi -e 's#^(chmop.*\$mydomain.*=).*#${1} "$ENV{HOSTNAME}";#' ${AMAVISD_CONF_DIR}/05-domain_id

    perl -pi -e 's/^(1;.*)/#{1}/' ${AMAVISD_CONF}

    cat >> ${AMAVISD_CONF} <<EOF
${CONF}

chomp(\$mydomain = "${HOSTNAME}");
@local_domains_maps = 1;
@mynetworks = qw( 127.0.0.0/8 [::1] );

# listen on multiple TCP ports. ${AMAVISD_QUARANTINE_PORT} is used for releasing quarantined mails.
\$inet_socket_port = [10024, 10026, ${AMAVISD_QUARANTINE_PORT}];

# Enable virus check.
@bypass_virus_checks_maps = (
   \%bypass_virus_checks,
   \@bypass_virus_checks_acl,
   \$bypass_virus_checks_re,
   );

# Enable spam check.
@bypass_spam_checks_maps = (
    \%bypass_spam_checks,
    \@bypass_spam_checks_acl,
    \$bypass_spam_checks_re,
    );

\$mailfrom_notify_admin = "root\@\$mydomain";
\$mailfrom_notify_recip = "root\@\$mydomain";
\$mailfrom_notify_spamadmin = "root\@\$mydomain";

# Mail notify.
\$mailfrom_notify_admin     = "root\@\$mydomain";  # notifications sender
\$mailfrom_notify_recip     = "root\@\$mydomain";  # notifications sender
\$mailfrom_notify_spamadmin = "root\@\$mydomain"; # notifications sender
\$mailfrom_to_quarantine = ''; # null return path; uses original sender if undef

# Disable defang banned mail.
\$defang_banned = 0;  # MIME-wrap passed mail containing banned name

\$policy_bank{'MYNETS'} = {   # mail originating from @mynetworks
    originating => 1,  # is true in MYNETS by default, but let's make it explicit
    os_fingerprint_method => undef,  # don't query p0f for internal clients
    allow_disclaimers => 1,  # enables disclaimer insertion if available
    enable_dkim_signing => 1,
};

# it is up to MTA to re-route mail from authenticated roaming users or
# from internal hosts to a dedicated TCP port (such as 10026) for filtering
\$interface_policy{'10026'} = 'ORIGINATING';

\$policy_bank{'ORIGINATING'} = {  # mail supposedly originating from our users
    #inet_acl => [qw(${AMAVISD_INET_ACL})],   # ORIGINATING: restrict access to these IP addresses
    originating => 1,  # declare that mail was submitted by our smtp client
    allow_disclaimers => 1,  # enables disclaimer insertion if available
    enable_dkim_signing => 1,

    # notify administrator of locally originating malware
    virus_admin_maps => ["root\@\$mydomain"],
    spam_admin_maps  => [],
    bad_header_admin_maps => [],
    banned_admin_maps => ["root\@\$mydomain"],
    warnbadhsender   => 1,
    warnbannedsender => 1,

    # force MTA conversion to 7-bit (e.g. before DKIM signing)
    #smtpd_discard_ehlo_keywords => ['8BITMIME'],

    # don't remove NOTIFY=SUCCESS option
    terminate_dsn_on_notify_success => 0,

    # don't perform spam/virus/header check.
    #bypass_spam_checks_maps => [1],    # ORIGINATING spam
    #bypass_header_checks_maps => [1],  # ORIGINATING bad-header
    #bypass_virus_checks_maps => [1],   # ORIGINATING virus
    #bypass_banned_checks_maps => [1],  # ORIGINATING banned file types
};

EOF

    # Make sure that clamav is configured to init supplementary
    # groups when it drops priviledges, and that you add the
    # clamav user to the amavis group.
    adduser --quiet ${CLAMAV_USER} ${AMAVISD_SYS_GROUP} >> ${INSTALL_LOG} 2>&1

    echo 'export status_amavisd_config_debian="DONE"' >> ${STATUS_FILE}
}

amavisd_config_general()
{
    # Comment out existing $final_xxx_destiny to avoid duplicate
    perl -pi -e 's/^(.final_virus_destiny.*)/#${1}/' ${AMAVISD_CONF}
    perl -pi -e 's/^(.final_banned_destiny.*)/#${1}/' ${AMAVISD_CONF}
    perl -pi -e 's/^(.final_spam_destiny.*)/#${1}/' ${AMAVISD_CONF}
    perl -pi -e 's/^(.final_bad_header_destiny.*)/#${1}/' ${AMAVISD_CONF}

    cat >> ${AMAVISD_CONF} <<EOF

$(cat ${SAMPLE_DIR}/amavisd/log_templ)

# Set hostname.
\$myhostname = "${HOSTNAME}";
\$localhost_name = \$myhostname;

# Set listen IP/PORT.
\$notify_method  = 'smtp:[${SMTP_SERVER}]:10025';
\$forward_method = 'smtp:[${SMTP_SERVER}]:10025';

@av_scanners = (
    #### http://www.clamav.net/
    ['ClamAV-clamd',
    \&ask_daemon, ["CONTSCAN {}\n", "${CLAMD_LOCAL_SOCKET}"],
    qr/\bOK$/, qr/\bFOUND$/,
    qr/^.*?: (?!Infected Archive)(.*) FOUND$/ ],
);

@av_scanners_backup = (
    ### http://www.clamav.net/   - backs up clamd or Mail::ClamAV
    ['ClamAV-clamscan', 'clamscan',
    "--stdout --disable-summary -r --tempdir=\$TEMPBASE {}", [0], [1],
    qr/^.*?: (?!Infected Archive)(.*) FOUND$/ ],
);

#
# Port used to release quarantined mails.
#
\$interface_policy{'${AMAVISD_QUARANTINE_PORT}'} = 'AM.PDP-INET';
\$policy_bank{'AM.PDP-INET'} = {
    protocol => 'AM.PDP',       # select Amavis policy delegation protocol
    #inet_acl => [qw(${AMAVISD_INET_ACL})],   # QUARANTINE: restrict access to these IP addresses
    auth_required_release => 1,    # 0 - don't require secret_id for amavisd-release
    #log_level => 4,
    #always_bcc_by_ccat => {CC_CLEAN, 'admin@example.com'},
};

#########################
# Default action applied to detected spam/virus/banned/bad-header, and how to
# quarantine them
#
# Available actions:
#   - D_PASS: Mail will pass to recipients, regardless of bad contents.
#             If a quarantine is configured, a copy of the mail will go there.
#             Note that including a recipient in a @*_lovers_maps is
#             functionally equivalent to setting '$final_*_destiny = D_PASS;'
#             for that recipient.
#
#   - D_BOUNCE: Mail will not be delivered to its recipients. A non-delivery
#               notification (bounce) will be created and sent to the sender.
#
#   - D_REJECT: Mail will not be delivered to its recipients. Amavisd will
#               send the typical 55x reject response to the upstream MTA and
#               that MTA may create a reject notice (bounce) and return it to
#               the sender.
#               This notice is not as informative as the one created using
#               D_BOUNCE, so usually D_BOUNCE is preferred over D_REJECT.
#               If a quarantine is configured, a copy of the mail will go
#               there, if not mail message will be lost, but the sender should
#               be notified their message was rejected.
#
#   - D_DISCARD: Mail will not be delivered to its recipients and the sender
#                normally will NOT be notified.
#                If a quarantine is configured, a copy of the mail will go
#                there, if not mail message will be lost. Note that there are
#                additional settings available that can send notifications to
#                persons that normally may not be notified when an undesirable
#                message is found, so it is possible to notify the sender even
#                when using D_DISCARD.
#
# Where to store quarantined mail message:
#
#   - 'local:spam-%i-%m', quarantine mail on local file system.
#   - 'sql:', quarantine mail in SQL server specified in @storage_sql_dsn.
#   - undef, do not quarantine mail.

# SPAM.
\$final_spam_destiny = D_PASS;
\$spam_quarantine_method = undef;
#\$spam_quarantine_method = 'sql:';
#\$spam_quarantine_to = 'spam-quarantine';

# Virus
\$final_virus_destiny = D_DISCARD;
\$virus_quarantine_method = 'sql:';
\$virus_quarantine_to     = 'virus-quarantine';

# Banned
\$final_banned_destiny = D_DISCARD;
\$banned_files_quarantine_method = undef;
#\$banned_files_quarantine_method = 'sql:';
#\$banned_quarantine_to = 'banned-quarantine';

# Bad header.
\$final_bad_header_destiny = D_PASS;
\$bad_header_quarantine_method = undef;
#\$bad_header_quarantine_method = 'sql:';
#\$bad_header_quarantine_to = 'bad-header-quarantine';

#########################
# Quarantine CLEAN mails.
# Don't forget to enable clean quarantine in policy bank 'MYUSERS'.
#
#\$clean_quarantine_method = 'sql:';
#\$clean_quarantine_to = 'clean-quarantine';

\$sql_allow_8bit_address = 1;
\$timestamp_fmt_mysql = 1;

# a string to prepend to Subject (for local recipients only) if mail could
# not be decoded or checked entirely, e.g. due to password-protected archives
#\$undecipherable_subject_tag = '***UNCHECKED*** ';  # undef disables it
\$undecipherable_subject_tag = undef;
EOF

    # Write dkim settings.
    check_status_before_run amavisd_dkim

    # Enable disclaimer if available.
    cat >> ${AMAVISD_CONF} <<EOF
# ------------ Disclaimer Setting ---------------
# Uncomment this line to enable singing disclaimer in outgoing mails.
#\$defang_maps_by_ccat{+CC_CATCHALL} = [ 'disclaimer' ];

# Program used to signing disclaimer in outgoing mails.
\$altermime = '${ALTERMIME_BIN}';

# Disclaimer in plain text formart.
@altermime_args_disclaimer = qw(--disclaimer=${DISCLAIMER_DIR}/_OPTION_.txt --disclaimer-html=${DISCLAIMER_DIR}/_OPTION_.txt --force-for-bad-html);

@disclaimer_options_bysender_maps = ({
    # Per-domain disclaimer setting: ${DISCLAIMER_DIR}/host1.iredmail.org.txt
    #'host1.iredmail.org' => 'host1.iredmail.org',

    # Sub-domain disclaimer setting: ${DISCLAIMER_DIR}/iredmail.org.txt
    #'.iredmail.org'      => 'iredmail.org',

    # Per-user disclaimer setting: ${DISCLAIMER_DIR}/boss.iredmail.org.txt
    #'boss@iredmail.org'  => 'boss.iredmail.org',

    # Catch-all disclaimer setting: ${DISCLAIMER_DIR}/default.txt
    '.' => 'default',
},);
# ------------ End Disclaimer Setting ---------------
EOF

    # Create directory to store disclaimer files if not exist.
    [ -d ${DISCLAIMER_DIR} ] || mkdir -p ${DISCLAIMER_DIR} >> ${INSTALL_LOG} 2>&1
    # Create a empty disclaimer.
    echo -e '\n----' > ${DISCLAIMER_DIR}/default.txt

    # Integrate SQL. Used to store incoming & outgoing related mail information.
    if [ X"${BACKEND}" == X'PGSQL' ]; then
        perl_dbi_type='Pg'
    else
        perl_dbi_type='mysql'
    fi

    cat >> ${AMAVISD_CONF} <<EOF
# Reporting and quarantining.
@storage_sql_dsn = (['DBI:${perl_dbi_type}:database=${AMAVISD_DB_NAME};host=${SQL_SERVER_ADDRESS};port=${SQL_SERVER_PORT}', '${AMAVISD_DB_USER}', '${AMAVISD_DB_PASSWD}']);

# Lookup for per-recipient, per-domain and global policy.
@lookup_sql_dsn = @storage_sql_dsn;
EOF

    # Use 'utf8' character set.
    if [ X"${BACKEND}" != X'PGSQL' ]; then
        grep -i 'set names' ${AMAVISD_BIN} &>/dev/null
        if [ X"$?" != X"0" ]; then
            perl -pi -e 's#(.*)(section_time.*sql-connect.*)#${1}\$dbh->do("SET NAMES utf8"); ${2}#' ${AMAVISD_BIN}
        fi
    fi

    # Comment out existing `$max_servers` setting
    perl -pi -e 's/^(\$max_servers.*)/#${1}/g' ${AMAVISD_CONF}

    cat >> ${AMAVISD_CONF} <<EOF
# Don't send email with subject "UNCHECKED contents in mail FROM xxx".
delete \$admin_maps_by_ccat{&CC_UNCHECKED};

# Do not notify administrator about SPAM/VIRUS from remote servers.
\$virus_admin = undef;
\$spam_admin = undef;
\$banned_admin = undef;
\$bad_header_admin = undef;

# Num of pre-forked children.
# WARNING: it must match (equal to or larger than) the number set in
# /etc/postfix/master.cf "maxproc" column for the 'smtp-amavis' service.
\$max_servers = ${AMAVISD_MAX_SERVERS};

EOF

    # Enable DKIM signing and verification.
    cat >> ${AMAVISD_CONF} <<EOF
# Enable DKIM signing/verification
\$enable_dkim_verification = 1;
#\$enable_dkim_signing = 1;     # we have dkim signing enabled in policy banks.

EOF

    # Logging.
    perl -pi -e 's/^(\$log_level.*)/#${1}/g' ${AMAVISD_CONF}
    perl -pi -e 's/^(\$sa_debug.*)/#${1}/g' ${AMAVISD_CONF}

    cat >> ${AMAVISD_CONF} <<EOF
# Amavisd log level. Verbosity: 0, 1, 2, 3, 4, 5, -d.
\$log_level = 0;
# SpamAssassin debugging (require \$log_level). Default if off (0).
\$sa_debug = 0;

EOF

    cat >> ${AMAVISD_CONF} <<EOF
# Amavisd on some Linux/BSD distribution use \$banned_namepath_re instead of
# \$banned_filename_re, so we define some blocked file types here.
#
# Sample input for \$banned_namepath_re:
#
#   P=p003\tL=1\tM=multipart/mixed\nP=p002\tL=1/2\tM=application/octet-stream\tT=dat\tN=my_docum.zip
#   P=p003,L=1,M=multipart/mixed | P=p002,L=1/2,M=application/zip,T=zip,N=FedEx_00628727.zip | P=p005,L=1/2/2,T=asc,N=FedEx_00628727.doc.wsf
#
# What it means:
#   - T: type. e.g. zip archive.
#   - M: MIME type. e.g. application/octet-stream.
#   - N: suggested (MIME) name. e.g. my_docum.zip.

\$banned_namepath_re = new_RE(
    #[qr'T=(rar|arc|arj|zoo|gz|bz2)(,|\t)'xmi => 'DISCARD'],     # Compressed file types
    [qr'T=x-(msdownload|msdos-program|msmetafile)(,|\t)'xmi => 'DISCARD'],
    [qr'T=(hta)(,|\t)'xmi => 'DISCARD'],

    # Dangerous mime types
    [qr'T=(9|386|LeChiffre|aaa|abc|aepl|ani|aru|atm|aut|b64|bat|bhx|bin|bkd|blf|bll|bmw|boo|bps|bqf|breaking_bad|buk|bup|bxz|cc|ccc|ce0|ceo|cfxxe|chm|cih|cla|class|cmd|com|cpl|crinf|crjoker|crypt|cryptolocker|cryptowall|ctbl|cxq|cyw|dbd|delf|dev|dlb|dli|dll|dllx|dom|drv|dx|dxz|dyv|dyz|ecc|exe|exe-ms|exe1|exe_renamed|exx|ezt|ezz|fag|fjl|fnr|fuj|good|gzquar|hlp|hlw|hqx|hsq|hts|iva|iws|jar|js|kcd|keybtc@inbox_com|let|lik|lkh|lnk|locky|lok|lol!|lpaq5|magic|mfu|micro|mim|mjg|mjz|mp3|nls|oar|ocx|osa|ozd|pcx|pgm|php2|php3|pid|pif|plc|pr|pzdc|qit|qrn|r5a|rhk|rna|rsc_tmp|s7p|scr|shs|ska|smm|smtmp|sop|spam|ssy|swf|sys|tko|tps|tsa|tti|ttt|txs|upa|uu|uue|uzy|vb|vba|vbe|vbs|vbx|vexe|vxd|vzr|wlpginstall|ws|wsc|wsf|wsh|wss|xdu|xir|xlm|xlv|xnt|xnxx|xtbl|xxe|xxx|xyz|zix|zvz|zzz)(,|\t)'xmi => 'DISCARD'],

    # Dangerous file name extensions
    [qr'N=.*\.(9|386|LeChiffre|aaa|abc|aepl|ani|aru|atm|aut|b64|bat|bhx|bin|bkd|blf|bll|bmw|boo|bps|bqf|breaking_bad|buk|bup|bxz|cc|ccc|ce0|ceo|cfxxe|chm|cih|cla|class|cmd|com|cpl|crinf|crjoker|crypt|cryptolocker|cryptowall|ctbl|cxq|cyw|dbd|delf|dev|dlb|dli|dll|dllx|dom|drv|dx|dxz|dyv|dyz|ecc|exe|exe-ms|exe1|exe_renamed|exx|ezt|ezz|fag|fjl|fnr|fuj|good|gzquar|hlp|hlw|hqx|hsq|hts|iva|iws|jar|js|kcd|keybtc@inbox_com|let|lik|lkh|lnk|locky|lok|lol!|lpaq5|magic|mfu|micro|mim|mjg|mjz|mp3|nls|oar|ocx|osa|ozd|pcx|pgm|php2|php3|pid|pif|plc|pr|pzdc|qit|qrn|r5a|rhk|rna|rsc_tmp|s7p|scr|shs|ska|smm|smtmp|sop|spam|ssy|swf|sys|tko|tps|tsa|tti|ttt|txs|upa|uu|uue|uzy|vb|vba|vbe|vbs|vbx|vexe|vxd|vzr|wlpginstall|ws|wsc|wsf|wsh|wss|xdu|xir|xlm|xlv|xnt|xnxx|xtbl|xxe|xxx|xyz|zix|zvz|zzz)$'xmi => 'DISCARD'],
);
EOF

    cat >> ${AMAVISD_CONF} <<EOF
# Selectively disable some of the header checks
#
# Duplicate or multiple occurrence of a header field
\$allowed_header_tests{'multiple'} = 0;

# Missing some headers. e.g. 'Date:'
\$allowed_header_tests{'missing'} = 0;

# Listen on specified addresses.
\$inet_socket_bind = ['${LOCAL_ADDRESS}'];

# Set ACL
@inet_acl = qw(${AMAVISD_INET_ACL});

1;  # insure a defined return
EOF
    # End amavisd.conf

    cat ${SAMPLE_DIR}/postfix/main.cf.amavisd >> ${POSTFIX_FILE_MAIN_CF}
    perl -pi -e 's#PH_SMTP_SERVER#$ENV{SMTP_SERVER}#g' ${POSTFIX_FILE_MAIN_CF}

    # Add postfix alias for user: amavis.
    add_postfix_alias 'virusalert' ${SYS_ROOT_USER}
    add_postfix_alias ${AMAVISD_SYS_USER} ${SYS_ROOT_USER}

    # Add crontab job to delete virus mail.
    ECHO_DEBUG "Setting cron job for vmail user to delete virus mail per month."
    cat >> ${CRON_FILE_AMAVISD} <<EOF
${CONF_MSG}
# Delete virus mails which created 15 days ago.
1   5   *   *   *   touch ${AMAVISD_VIRUSMAILS_DIR}; find ${AMAVISD_VIRUSMAILS_DIR}/ -mtime +15 | xargs rm -rf {}

EOF

    cat >> ${TIP_FILE} <<EOF
Amavisd-new:
    * Configuration files:
        - ${AMAVISD_CONF}
        - ${POSTFIX_FILE_MASTER_CF}
        - ${POSTFIX_FILE_MAIN_CF}
    * RC script:
        - ${DIR_RC_SCRIPTS}/${AMAVISD_RC_SCRIPT_NAME}
    * MySQL Database:
        - Database name: ${AMAVISD_DB_NAME}
        - Database user: ${AMAVISD_DB_USER}
        - Database password: ${AMAVISD_DB_PASSWD}
        - SQL template: ${AMAVISD_DB_MYSQL_TMPL}

EOF

    echo 'export status_amavisd_config_general="DONE"' >> ${STATUS_FILE}
}

amavisd_initialize_db()
{
    ECHO_DEBUG "Import Amavisd database and privileges."

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create database
CREATE DATABASE ${AMAVISD_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Grant privileges
GRANT SELECT,INSERT,UPDATE,DELETE ON ${AMAVISD_DB_NAME}.* TO '${AMAVISD_DB_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${AMAVISD_DB_PASSWD}';
-- GRANT SELECT,INSERT,UPDATE,DELETE ON ${AMAVISD_DB_NAME}.* TO '${AMAVISD_DB_USER}'@'${HOSTNAME}' IDENTIFIED BY '${AMAVISD_DB_PASSWD}';

-- Import Amavisd SQL template
USE ${AMAVISD_DB_NAME};
SOURCE ${AMAVISD_DB_MYSQL_TMPL};

FLUSH PRIVILEGES;
EOF
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        cp -f ${AMAVISD_DB_PGSQL_TMPL} ${PGSQL_SYS_USER_HOME}/amavisd.sql >> ${INSTALL_LOG} 2>&1
        chmod 0777 ${PGSQL_SYS_USER_HOME}/amavisd.sql >/dev/null

        su - ${PGSQL_SYS_USER} -c "psql -d template1" >> ${INSTALL_LOG}  <<EOF
-- Create database
CREATE DATABASE ${AMAVISD_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

-- Create user
CREATE USER ${AMAVISD_DB_USER} WITH ENCRYPTED PASSWORD '${AMAVISD_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

ALTER DATABASE ${AMAVISD_DB_NAME} OWNER TO ${AMAVISD_DB_USER};
EOF

        # Import Amavisd SQL template
        su - ${PGSQL_SYS_USER} -c "psql -U ${AMAVISD_DB_USER} -d ${AMAVISD_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
\i ${PGSQL_SYS_USER_HOME}/amavisd.sql;
EOF
        rm -f ${PGSQL_SYS_USER_HOME}/amavisd.sql >> ${INSTALL_LOG}

        if [ X"${DISTRO}" == X'RHEL' -a X"${DISTRO_VERSION}" == X'6' ]; then
            :
        else
            su - ${PGSQL_SYS_USER} -c "psql -U ${AMAVISD_DB_USER} -d ${AMAVISD_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
ALTER DATABASE ${AMAVISD_DB_NAME} SET bytea_output TO 'escape';
EOF
        fi
    fi

    echo 'export status_amavisd_initialize_db="DONE"' >> ${STATUS_FILE}
}

amavisd_config()
{
    ECHO_INFO "Configure Amavisd-new (interface between MTA and content checkers)."

    if [ X"${DISTRO}" == X'RHEL' \
        -o X"${DISTRO}" == X'FREEBSD' \
        -o X"${DISTRO}" == X'OPENBSD' ]; then
        check_status_before_run amavisd_config_rhel
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        check_status_before_run amavisd_config_debian
    fi

    check_status_before_run amavisd_config_general

    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run amavisd_initialize_db
    fi

    # Comment out port 10027, we don't have Amavisd listening on this port.
    perl -pi -e 's/(.*forward_method.*10027.*)/#${1}/g' ${AMAVISD_CONF}

    # Do NOT disable banned checking
    perl -pi -e 's/(.*bypass_banned_checks_maps.*=>.*allow sending any file names and types)/#${1}/g' ${AMAVISD_CONF}

    if [ X"${DISTRO}" == X'FREEBSD' ]; then
        # Start service when system start up.
        service_control enable 'amavisd_enable' 'YES'
        service_control enable 'amavisd_pidfile' '/var/amavis/amavisd.pid'
        service_control enable 'amavis_milter_enable' 'NO'
        service_control enable 'amavis_p0fanalyzer_enable' 'NO'
    fi

    echo 'export status_amavisd_config="DONE"' >> ${STATUS_FILE}
}
