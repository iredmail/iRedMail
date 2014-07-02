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
    mkdir -p ${AMAVISD_DKIM_DIR} 2>/dev/null && \
    chown ${AMAVISD_SYS_USER}:${AMAVISD_SYS_GROUP} ${AMAVISD_DKIM_DIR}
    ${AMAVISD_BIN} genrsa ${pem_file} &>/dev/null
    chmod +r ${pem_file}

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

# Make sure it sings all inbound mails, avoid error log like this:
# 'dkim: not signing inbound mail'.
\$originating = 1;

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
$(${AMAVISD_BIN} -c ${AMAVISD_CONF} showkeys 2>/dev/null)
EOF
    else
        cat >> ${TIP_FILE} <<EOF
$(${AMAVISD_BIN} showkeys 2>/dev/null)
EOF
    fi

    echo 'export status_amavisd_dkim="DONE"' >> ${STATUS_FILE}
}

amavisd_config_rhel()
{
    ECHO_INFO "Configure Amavisd-new (interface between MTA and content checkers)."

    if [ X"${DISTRO}" == X"RHEL" ]; then
        usermod -G ${AMAVISD_SYS_GROUP} ${CLAMAV_USER} >/dev/null
    fi

    # Don't check amavisd-milter status.
    perl -pi -e 's/(.*)(status.*prog2.*)/${1}#${2}/' ${DIR_RC_SCRIPTS}/${AMAVISD_RC_SCRIPT_NAME}

    backup_file ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}
    chmod 0640 ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}

    ECHO_DEBUG "Configure amavisd-new: ${AMAVISD_CONF}."

    export HOSTNAME FIRST_DOMAIN
    perl -pi -e 's/^(\$mydomain)/$1\ =\ \"$ENV{HOSTNAME}\"\;\t#/' ${AMAVISD_CONF}
    perl -pi -e 's/^(\@local_domains_maps)(.*=.*)/${1} = 1;/' ${AMAVISD_CONF}

    if [ X"${DISTRO}" == X"RHEL" -a X"${DISTRO_VERSION}" == X"6" ]; then
        perl -pi -e 's#(.*--tempdir=).*\{\}(.*)#${1}$ENV{AMAVISD_TEMPDIR}${2}#' ${AMAVISD_CONF}
        perl -pi -e 's#^(.QUARANTINEDIR =).*#${1} "$ENV{AMAVISD_QUARANTINEDIR}";#' ${AMAVISD_CONF}
    fi

    # Set default score.
    #perl -pi -e 's/(.*)(sa_tag_level_deflt)(.*)/${1}${2} = 4.0; #${3}/' ${AMAVISD_CONF}
    #perl -pi -e 's/(.*)(sa_tag2_level_deflt)(.*)/${1}${2} = 6; #${3}/' ${AMAVISD_CONF}
    #perl -pi -e 's/(.*)(sa_kill_level_deflt)(.*)/${1}${2} = 10; #${3}/' ${AMAVISD_CONF}

    # Make Amavisd listen on multiple TCP ports.
    perl -pi -e 's/(\$inet_socket_port.*=.*10024.*)/\$inet_socket_port = [10024, $ENV{'AMAVISD_QUARANTINE_PORT'}];/' ${AMAVISD_CONF}

    # Set admin address.
    perl -pi -e 's#(virus_admin.*= ")(virusalert)(.*)#${1}root${3}#' ${AMAVISD_CONF}
    perl -pi -e 's#(mailfrom_notify_admin.*= ")(virusalert)(.*)#${1}root${3}#' ${AMAVISD_CONF}
    perl -pi -e 's#(mailfrom_notify_recip.*= ")(virusalert)(.*)#${1}root${3}#' ${AMAVISD_CONF}
    perl -pi -e 's#(mailfrom_notify_spamadmin.*= ")(spam.police)(.*)#${1}root${3}#' ${AMAVISD_CONF}

    perl -pi -e 's#(virus_admin_maps.*=.*)(virusalert)(.*)#${1}root${3}#' ${AMAVISD_CONF}
    perl -pi -e 's#(spam_admin_maps.*=.*)(virusalert)(.*)#${1}root${3}#' ${AMAVISD_CONF}

    # Disable defang banned mail.
    perl -pi -e 's#(.*defang_banned = )1(;.*)#${1}0${2}#' ${AMAVISD_CONF}

    # Reset $sa_spam_subject_tag, default is '***SPAM***'.
    perl -pi -e 's#(.*sa_spam_subject_tag.*=)(.*SPAM.*)#${1} "[SPAM] ";#' ${AMAVISD_CONF}

    # TODO fixed on RHEL & Debian/Ubuntu.
    # Allow clients on my internal network to bypass scanning.
    #perl -pi -e 's#(.*policy_bank.*MYNETS.*\{)(.*)#${1} bypass_spam_checks_maps => [1], bypass_banned_checks_maps => [1], bypass_header_checks_maps => [1], ${2}#' ${AMAVISD_CONF}

    # Allow all authenticated virtual users to bypass scanning.
    #perl -pi -e 's#(.*policy_bank.*ORIGINATING.*\{)(.*)#${1} bypass_spam_checks_maps => [1], bypass_banned_checks_maps => [1], bypass_header_checks_maps => [1], ${2}#' ${AMAVISD_CONF}

    # Remove the content from '@av_scanners' to the end of file.
    new_conf="$(sed '/\@av_scanners/,$d' ${AMAVISD_CONF})"
    # Generate new configration file(Part).
    echo -e "${new_conf}" > ${AMAVISD_CONF}

    # Set pid_file.
    #echo '$pid_file = "/var/run/clamav/amavisd.pid";' >> ${AMAVISD_CONF}

    # Enable disclaimer if available.
    perl -pi -e 's%(os_fingerprint_method => undef.*)%${1}\n  allow_disclaimers => 1, # enables disclaimer insertion if available%' ${AMAVISD_CONF}

    echo '$sa_debug = 0;' >> ${AMAVISD_CONF}
    echo 'export status_amavisd_config_rhel="DONE"' >> ${STATUS_FILE}
}

amavisd_config_debian()
{
    ECHO_INFO "Configure Amavisd-new (interface between MTA and content checkers)."
    backup_file ${AMAVISD_CONF} ${AMAVISD_DKIM_CONF}

    ECHO_DEBUG "Configure amavisd-new: ${AMAVISD_CONF}."

    perl -pi -e 's#^(chmop.*\$mydomain.*=).*#${1} "$ENV{HOSTNAME}";#' ${AMAVISD_CONF_DIR}/05-domain_id

    perl -pi -e 's/^(1;.*)/#{1}/' ${AMAVISD_CONF}

    cat >> ${AMAVISD_CONF} <<EOF
${CONF}

chomp(\$mydomain = "${HOSTNAME}");
@local_domains_maps = 1;
@mynetworks = qw( 127.0.0.0/8 [::1] [FE80::]/10 [FEC0::]/10
                  10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 );

# listen on multiple TCP ports. ${AMAVISD_QUARANTINE_PORT} is used for releasing quarantined mails.
\$inet_socket_port = [10024, ${AMAVISD_QUARANTINE_PORT},];

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

\$virus_admin = "root\@\$mydomain"; # due to D_DISCARD default
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
};

\$policy_bank{'ORIGINATING'} = {  # mail supposedly originating from our users
  originating => 1,  # declare that mail was submitted by our smtp client
  allow_disclaimers => 1,  # enables disclaimer insertion if available
  # notify administrator of locally originating malware
  virus_admin_maps => ["root\@\$mydomain"],
  #spam_admin_maps  => ["root\@\$mydomain"],
  warnbadhsender   => 0,
  warnbannedsender   => 0,
  warnvirussender  => 1,
  warnspamsender   => 1,
  # forward to a smtpd service providing DKIM signing service
  #forward_method => 'smtp:[${AMAVISD_SYS_USER}]:10027',
  # force MTA conversion to 7-bit (e.g. before DKIM signing)
  smtpd_discard_ehlo_keywords => ['8BITMIME'],
  #bypass_banned_checks_maps => [1],  # allow sending any file names and types
  terminate_dsn_on_notify_success => 0,  # don't remove NOTIFY=SUCCESS option
};

# SpamAssassin debugging. Default if off(0).
# Note: '\$log_level' variable above is required for SA debug.
\$log_level = 0;              # verbosity 0..5, -d
\$sa_debug = 0;

EOF

    # Add postfix alias for user: amavis.
    add_postfix_alias ${AMAVISD_SYS_USER} ${SYS_ROOT_USER}
    add_postfix_alias 'virusalert' ${SYS_ROOT_USER}

    # Make sure that clamav is configured to init supplementary
    # groups when it drops priviledges, and that you add the
    # clamav user to the amavis group.
    adduser --quiet ${CLAMAV_USER} ${AMAVISD_SYS_GROUP} >/dev/null

    echo 'export status_amavisd_config_debian="DONE"' >> ${STATUS_FILE}
}

amavisd_config_general()
{
    # Disable $final_xxx_destiny to avoid duplicate
    perl -pi -e 's/^(\$final_virus_destiny.*)/#${1}/' ${AMAVISD_CONF}
    perl -pi -e 's/^(\$final_banned_destiny.*)/#${1}/' ${AMAVISD_CONF}
    perl -pi -e 's/^(\$final_spam_destiny.*)/#${1}/' ${AMAVISD_CONF}
    perl -pi -e 's/^(\$final_bad_header_destiny.*)/#${1}/' ${AMAVISD_CONF}

    cat >> ${AMAVISD_CONF} <<EOF
# Set hostname.
\$myhostname = "${HOSTNAME}";

# Set listen IP/PORT.
\$notify_method  = 'smtp:[${SMTP_SERVER}]:10025';
\$forward_method = 'smtp:[${SMTP_SERVER}]:10025';

# Set default action.
# Available actions: D_PASS, D_BOUNCE, D_REJECT, D_DISCARD.
\$final_virus_destiny      = D_DISCARD;
\$final_banned_destiny     = D_PASS;
\$final_spam_destiny       = D_PASS;
\$final_bad_header_destiny = D_PASS;

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

# This policy will perform virus checks only.
#\$interface_policy{'10026'} = 'VIRUSONLY';
#\$policy_bank{'VIRUSONLY'} = { # mail from the pickup daemon
#    bypass_spam_checks_maps   => [1],  # don't spam-check this mail
#    bypass_banned_checks_maps => [1],  # don't banned-check this mail
#    bypass_header_checks_maps => [1],  # don't header-check this mail
#};

# Allow SASL authenticated users to bypass scanning. Typically SASL
# users already submit messages to the submission port (587) or the
# smtps port (465):
#\$interface_policy{'10026'} = 'SASLBYPASS';
#\$policy_bank{'SASLBYPASS'} = {  # mail from submission and smtps ports
#    bypass_spam_checks_maps   => [1],  # don't spam-check this mail
#    bypass_banned_checks_maps => [1],  # don't banned-check this mail
#    bypass_header_checks_maps => [1],  # don't header-check this mail
#};

# Apply to mails which coming from internal networks or authenticated
# roaming users.
# mail supposedly originating from our users
\$policy_bank{'MYUSERS'} = {
    # declare that mail was submitted by our smtp client
    originating => 1,

    # enables disclaimer insertion if available
    allow_disclaimers => 1,

    # notify administrator of locally originating malware
    virus_admin_maps => ["root\@\$mydomain"],
    #spam_admin_maps  => ["root\@\$mydomain"],

    # forward to a smtpd service providing DKIM signing service
    #forward_method => 'smtp:[${AMAVISD_SERVER}]:10027',

    # force MTA conversion to 7-bit (e.g. before DKIM signing)
    smtpd_discard_ehlo_keywords => ['8BITMIME'],

    # don't remove NOTIFY=SUCCESS option
    terminate_dsn_on_notify_success => 0,

    # don't perform spam/virus/header check.
    #bypass_spam_checks_maps => [1],
    #bypass_virus_checks_maps => [1],
    #bypass_header_checks_maps => [1],

    # allow sending any file names and types
    #bypass_banned_checks_maps => [1],

    # Quarantine clean messages
    #clean_quarantine_method => 'sql:',
    #final_destiny_by_ccat => {CC_CLEAN, D_DISCARD},
};

# regular incoming mail, originating from anywhere (usually from outside)
#\$policy_bank{'EXT'} = {
#  # just use global settings, no special overrides
#};

#
# Port used to release quarantined mails.
#
\$interface_policy{'${AMAVISD_QUARANTINE_PORT}'} = 'AM.PDP-INET';
\$policy_bank{'AM.PDP-INET'} = {
    protocol => 'AM.PDP',       # select Amavis policy delegation protocol
    inet_acl => [qw( ${AMAVISD_SERVER} [::1] )],    # restrict access to these IP addresses
    auth_required_release => 1,    # 0 - don't require secret_id for amavisd-release
    #log_level => 4,
    #always_bcc_by_ccat => {CC_CLEAN, 'admin@example.com'},
};

#########################
# Quarantine mails.
#

# Where to store quarantined mail message:
#   - 'local:spam-%i-%m', quarantine mail on local file system.
#   - 'sql:', quarantine mail in SQL server specified in @storage_sql_dsn. 
#   - undef, do not quarantine mail.

# Bad header.
\$bad_header_quarantine_method = undef;
#\$bad_header_quarantine_method = 'sql:';
#\$bad_header_quarantine_to = 'bad-header-quarantine';

# SPAM.
\$spam_quarantine_method = undef;
#\$spam_quarantine_method = 'sql:';
#\$spam_quarantine_to = 'spam-quarantine';

# Virus
#\$virus_quarantine_to     = 'virus-quarantine';
#\$virus_quarantine_method = 'sql:';

# Banned
\$banned_files_quarantine_method = undef;
#\$banned_files_quarantine_method = 'sql:';
#\$banned_quarantine_to = 'banned-quarantine';

#########################
# Quarantine CLEAN mails.
# Don't forget to enable clean quarantine in policy bank 'MYUSERS'.
#
#\$clean_quarantine_method = 'sql:';
#\$clean_quarantine_to = 'clean-quarantine';

# Modify email subject, add '\$sa_spam_subject_tag'.
#   0:  disable
#   1:  enable
\$sa_spam_modifies_subj = 1;

# remove existing headers
#\$remove_existing_x_scanned_headers= 0;
#\$remove_existing_spam_headers = 0;

# Leave empty (undef) to add no header.
# Modify /usr/sbin/amavisd or /usr/sbin/amavisd-new file to add customize header in:
#
#   sub add_forwarding_header_edits_per_recip
#
#\$X_HEADER_TAG = 'X-Virus-Scanned';
#\$X_HEADER_LINE = "by amavisd at \$myhostname";

# Notify virus sender?
#\$warnvirussender = 0;

# Notify spam sender?
#\$warnspamsender = 0;

# Notify sender of banned files?
\$warnbannedsender = 0;

# Notify sender of syntactically invalid header containing non-ASCII characters?
\$warnbadhsender = 0;

# Notify virus (or banned files) RECIPIENT?
#  (not very useful, but some policies demand it)
\$warnvirusrecip = 0;
\$warnbannedrecip = 0;

# Notify also non-local virus/banned recipients if \$warn*recip is true?
#  (including those not matching local_domains*)
\$warn_offsite = 0;

#\$notify_sender_templ      = read_text('/var/amavis/notify_sender.txt');
#\$notify_virus_sender_templ= read_text('/var/amavis/notify_virus_sender.txt');
#\$notify_virus_admin_templ = read_text('/var/amavis/notify_virus_admin.txt');
#\$notify_virus_recips_templ= read_text('/var/amavis/notify_virus_recips.txt');
#\$notify_spam_sender_templ = read_text('/var/amavis/notify_spam_sender.txt');
#\$notify_spam_admin_templ  = read_text('/var/amavis/notify_spam_admin.txt');

\$sql_allow_8bit_address = 1;
\$timestamp_fmt_mysql = 1;

# a string to prepend to Subject (for local recipients only) if mail could
# not be decoded or checked entirely, e.g. due to password-protected archives
#\$undecipherable_subject_tag = '***UNCHECKED*** ';  # undef disables it
\$undecipherable_subject_tag = undef;
EOF

    # Write dkim settings.
    check_status_before_run amavisd_dkim

    # Enable/Disable DKIM feature.
    if [ X"${ENABLE_DKIM}" == X"YES" ]; then
        if [ X"${DISTRO}" == X"RHEL" ]; then
            perl -pi -e 's/^(\$enable_dkim_verification = )\d(;.*)/${1}1${2}/' ${AMAVISD_CONF}
            perl -pi -e 's/^(\$enable_dkim_signing = )\d(;.*)/${1}1${2}/' ${AMAVISD_CONF}
        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            cat >> ${AMAVISD_CONF} <<EOF
\$enable_dkim_verification = 1;  # enable DKIM signatures verification
\$enable_dkim_signing = 1;    # load DKIM signing code, keys defined by dkim_key
EOF
        else
            :
        fi

    else
        if [ X"${DISTRO}" == X"RHEL" ]; then
            perl -pi -e 's/^(\$enable_dkim_verification = )\d(;.*)/${1}0${2}/' ${AMAVISD_CONF}
            perl -pi -e 's/^(\$enable_dkim_signing = )\d(;.*)/${1}0${2}/' ${AMAVISD_CONF}
        elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
            cat >> ${AMAVISD_CONF} <<EOF
\$enable_dkim_verification = 0;  # enable DKIM signatures verification
\$enable_dkim_signing = 0;    # load DKIM signing code, keys defined by dkim_key
EOF
        else
            :
        fi
    fi

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
    [ -d ${DISCLAIMER_DIR} ] || mkdir -p ${DISCLAIMER_DIR} 2>/dev/null
    # Create a empty disclaimer.
    echo -e '\n----' > ${DISCLAIMER_DIR}/default.txt

    # Integrate LDAP.
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        cat >> ${AMAVISD_CONF} <<EOF
# Integrate Amavisd-new with OpenLDAP.
\$enable_ldap    = 1;    # 1 -> enable, 0 -> disable.
\$default_ldap   = {
    hostname        => "${LDAP_SERVER_HOST}",
    port            => ${LDAP_SERVER_PORT},
    version         => ${LDAP_BIND_VERSION},
    tls             => 0,
    inet6           => 0,
    timeout         => 120,
    base            => "${LDAP_BASEDN}",
    scope           => "sub",
    query_filter    => "(&(objectClass=mailUser)(objectClass=amavisAccount)(accountStatus=active)(|(mail=%m)(shadowAddress=%m)))",
    bind_dn         => "${LDAP_BINDDN}",
    bind_password   => "${LDAP_BINDPW}",
};
EOF
    else
        :
    fi

    # Integrate SQL. Used to store incoming & outgoing related mail information.
    if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
        cat >> ${AMAVISD_CONF} <<EOF
@storage_sql_dsn = (
    ['DBI:mysql:database=${AMAVISD_DB_NAME};host=${SQL_SERVER};port=${SQL_SERVER_PORT}', '${AMAVISD_DB_USER}', '${AMAVISD_DB_PASSWD}'],
);
EOF
    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        cat >> ${AMAVISD_CONF} <<EOF
@storage_sql_dsn = (
    ['DBI:Pg:database=${AMAVISD_DB_NAME};host=${SQL_SERVER};port=${SQL_SERVER_PORT}', '${AMAVISD_DB_USER}', '${AMAVISD_DB_PASSWD}'],
);
#@lookup_sql_dsn = @storage_sql_dsn;
EOF
    fi

    # SQL lookup.
    if [ X"${BACKEND}" == X"OPENLDAP" ]; then
        cat >> ${AMAVISD_CONF} <<EOF
#@lookup_sql_dsn = @storage_sql_dsn;
EOF
    elif [ X"${BACKEND}" == X"MYSQL" ]; then
        # MySQL backend
        cat >> ${AMAVISD_CONF} <<EOF
# Uncomment below two lines to lookup virtual mail domains from MySQL database.
#@lookup_sql_dsn =  (
#    ['DBI:mysql:database=${VMAIL_DB};host=${SQL_SERVER};port=${SQL_SERVER_PORT}', '${VMAIL_DB_BIND_USER}', '${VMAIL_DB_BIND_PASSWD}'],
#);
# For Amavisd-new-2.7.0 and later versions. Placeholder '%d' is available in Amavisd-2.7.0+.
#\$sql_select_policy = "SELECT domain FROM domain WHERE domain='%d'";

# For Amavisd-new-2.6.x.
# WARNING: IN() may cause MySQL lookup performance issue.
#\$sql_select_policy = "SELECT domain FROM domain WHERE CONCAT('@', domain) IN (%k)";
EOF
    fi

    # Use 'utf8' character set.
    if [ X"${BACKEND}" != X'PGSQL' ]; then
        grep -i 'set names' ${AMAVISD_BIN} >/dev/null 2>&1
        if [ X"$?" != X"0" ]; then
            perl -pi -e 's#(.*)(section_time.*sql-connect.*)#${1}\$dbh->do("SET NAMES utf8"); ${2}#' ${AMAVISD_BIN}
        fi
    fi

    if [ X"${LOCAL_ADDRESS}" != X'127.0.0.1' ]; then
        # ACL
        cat >> ${AMAVISD_CONF} <<EOF
@inet_acl = qw(${LOCAL_ADDRESS});
EOF
    fi

    # Don't send email with subject "UNCHECKED contents in mail FROM xxx".
    if [ X"${AMAVISD_VERSION}" == X'2.7' ]; then
        cat >> ${AMAVISD_CONF} <<EOF
delete \$admin_maps_by_ccat{&CC_UNCHECKED};
EOF
    fi

    cat >> ${AMAVISD_CONF} <<EOF

# Num of pre-forked children.
# WARNING: it must match (equal to or larger than) the number set in
# /etc/postfix/master.cf "maxproc" column for the 'smtp-amavis' service.
\$max_servers = ${AMAVISD_MAX_SERVERS};

1;  # insure a defined return
EOF
    # ------------- END configure /etc/amavisd.conf ------------

    # Configure postfix: master.cf.
    cat >> ${POSTFIX_FILE_MASTER_CF} <<EOF
smtp-amavis unix -  -   -   -   ${AMAVISD_MAX_SERVERS}  smtp
    -o smtp_data_done_timeout=1200
    -o smtp_send_xforward_command=yes
    -o disable_dns_lookups=yes
    -o max_use=20

${AMAVISD_SERVER}:10025 inet n  -   -   -   -  smtpd
    -o content_filter=
    -o mynetworks_style=host
    -o mynetworks=${AMAVISD_MYNETWORKS}
    -o local_recipient_maps=
    -o relay_recipient_maps=
    -o strict_rfc821_envelopes=yes
    -o smtp_tls_security_level=none
    -o smtpd_tls_security_level=none
    -o smtpd_restriction_classes=
    -o smtpd_delay_reject=no
    -o smtpd_client_restrictions=permit_mynetworks,reject
    -o smtpd_helo_restrictions=
    -o smtpd_sender_restrictions=
    -o smtpd_recipient_restrictions=permit_mynetworks,reject
    -o smtpd_end_of_data_restrictions=
    -o smtpd_error_sleep_time=0
    -o smtpd_soft_error_limit=1001
    -o smtpd_hard_error_limit=1000
    -o smtpd_client_connection_count_limit=0
    -o smtpd_client_connection_rate_limit=0
    -o receive_override_options=no_header_body_checks,no_unknown_recipient_checks,no_address_mappings
EOF

    postconf -e content_filter="smtp-amavis:[${AMAVISD_SERVER}]:10024"
    # Concurrency per recipient limit.
    postconf -e smtp-amavis_destination_recipient_limit='1'

    # ---- Make amavisd log to standalone file: ${AMAVISD_LOGROTATE_FILE} ----
    if [ X"${AMAVISD_SEPERATE_LOG}" == X"YES" ]; then
        ECHO_DEBUG "Make Amavisd log to file: ${AMAVISD_LOGFILE}."
        perl -pi -e 's#(.*syslog_facility.*)(mail)(.*)#${1}local0${3}#' ${AMAVISD_CONF}
        echo -e "local0.*\t\t\t\t\t\t-${AMAVISD_LOGFILE}" >> ${SYSLOG_CONF}

        ECHO_DEBUG "Setting logrotate for amavisd log file: ${AMAVISD_LOGFILE}."
        cat > ${AMAVISD_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${AMAVISD_LOGFILE} {
    compress
    weekly
    rotate 10
    create 0600 amavis amavis
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2 

    postrotate
        ${SYSLOG_POSTROTATE_CMD}
    endscript
}
EOF
    else
        :
    fi

    # Add crontab job to delete virus mail.
    ECHO_DEBUG "Setting cron job for vmail user to delete virus mail per month."
    cat > ${CRON_SPOOL_DIR}/${AMAVISD_SYS_USER} <<EOF
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

amavisd_import_sql()
{
    ECHO_DEBUG "Import Amavisd database and privileges."

    if [ X"${BACKEND}" == X"OPENLDAP" -o X"${BACKEND}" == X"MYSQL" ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create database
CREATE DATABASE ${AMAVISD_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Grant privileges
GRANT SELECT,INSERT,UPDATE,DELETE ON ${AMAVISD_DB_NAME}.* TO "${AMAVISD_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY '${AMAVISD_DB_PASSWD}';

-- Import Amavisd SQL template
USE ${AMAVISD_DB_NAME};
SOURCE ${AMAVISD_DB_MYSQL_TMPL};

FLUSH PRIVILEGES;
EOF
    elif [ X"${BACKEND}" == X"PGSQL" ]; then
        cp -f ${AMAVISD_DB_PGSQL_TMPL} ${PGSQL_SYS_USER_HOME}/amavisd.sql >/dev/null
        chmod 0777 ${PGSQL_SYS_USER_HOME}/amavisd.sql >/dev/null

        su - ${PGSQL_SYS_USER} -c "psql -d template1" >/dev/null  <<EOF
-- Create database
CREATE DATABASE ${AMAVISD_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

-- Create user
CREATE USER ${AMAVISD_DB_USER} WITH ENCRYPTED PASSWORD '${AMAVISD_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Import Amavisd SQL template
\c ${AMAVISD_DB_NAME};
\i ${PGSQL_SYS_USER_HOME}/amavisd.sql;

-- Grant privileges
GRANT SELECT,INSERT,UPDATE,DELETE ON maddr,mailaddr,msgrcpt,msgs,policy,quarantine,users,wblist TO ${AMAVISD_DB_USER};
GRANT SELECT,UPDATE,USAGE ON maddr_id_seq,mailaddr_id_seq,policy_id_seq,users_id_seq TO ${AMAVISD_DB_USER};
EOF
        rm -f ${PGSQL_SYS_USER_HOME}/amavisd.sql >/dev/null
    fi

    echo 'export status_amavisd_import_sql="DONE"' >> ${STATUS_FILE}
}

amavisd_config()
{
    if [ X"${DISTRO}" == X"RHEL" \
        -o X"${DISTRO}" == X'FREEBSD' \
        -o X"${DISTRO}" == X'OPENBSD' \
        ]; then
        check_status_before_run amavisd_config_rhel
    elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
        check_status_before_run amavisd_config_debian
    else
        :
    fi

    # FreeBSD: Start amavisd when system start up.
    freebsd_enable_service_in_rc_conf 'amavisd_enable' 'YES'
    freebsd_enable_service_in_rc_conf 'amavisd_pidfile' '/var/amavis/amavisd.pid'
    freebsd_enable_service_in_rc_conf 'amavis_milter_enable' 'NO'
    freebsd_enable_service_in_rc_conf 'amavis_p0fanalyzer_enable' 'NO'

    check_status_before_run amavisd_config_general
    check_status_before_run amavisd_import_sql
}
