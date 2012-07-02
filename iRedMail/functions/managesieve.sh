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

managesieve_config()
{
    if [ X"${USE_MANAGESIEVE}" == X"YES" ]; then
        if [ X"${DOVECOT_VERSION}" == X"1.1" ]; then
            # Dovecot is patched on Debian/Ubuntu, ships managesieve protocal.
            cat >> ${DOVECOT_CONF} <<EOF
protocol managesieve {
    # IP or host address where to listen in for connections.
    listen = ${MANAGESIEVE_BIND_HOST}:${MANAGESIEVE_PORT}

    # Specifies the location of the symbolic link pointing to the
    # active script in the sieve storage directory.
    sieve = ${SIEVE_DIR}/%Ld/%Ln/${SIEVE_RULE_FILENAME}

    # This specifies the path to the directory where the uploaded scripts are stored.
    sieve_storage = ${SIEVE_DIR}/%Ld/%Ln/

    # Login executable location.
    login_executable = /usr/lib/dovecot/managesieve-login

    # managesieve executable location. See mail_executable for IMAP for
    # examples how this could be changed.
    mail_executable = /usr/lib/dovecot/managesieve

    # Maximum managesieve command line length in bytes.
    managesieve_max_line_length = 65536

    # To fool ManageSieve clients that are focused on CMU's timesieved
    # you can specify the IMPLEMENTATION capability that the dovecot
    # reports to clients (e.g. 'Cyrus timsieved v2.2.13').
    managesieve_implementation_string = dovecot
}
EOF
        elif [ X"${DOVECOT_VERSION}" == X"1.2" ]; then
            cat >> ${DOVECOT_CONF} <<EOF
# ManageSieve service. http://wiki.dovecot.org/ManageSieve
protocol managesieve {
    # IP or host address where to listen in for connections.
    listen = ${MANAGESIEVE_BIND_HOST}:${MANAGESIEVE_PORT}

    # Login executable location.
    #login_executable = /usr/local/libexec/dovecot/managesieve-login

    # ManageSieve executable location. See IMAP's mail_executable above for
    # examples how this could be changed.
    #mail_executable = /usr/local/libexec/dovecot/managesieve

    # Maximum ManageSieve command line length in bytes. This setting is
    # directly borrowed from IMAP. But, since long command lines are very
    # unlikely with ManageSieve, changing this will not be very useful.
    #managesieve_max_line_length = 65536

    # ManageSieve logout format string:
    #  %i - total number of bytes read from client
    #  %o - total number of bytes sent to client
    #managesieve_logout_format = bytes=%i/%o

    # If, for some inobvious reason, the sieve_storage remains unset, the
    # ManageSieve daemon uses the specification of the mail_location to find out
    # where to store the sieve files (see explaination in README.managesieve).
    # The example below, when uncommented, overrides any global mail_location
    # specification and stores all the scripts in '~/mail/sieve' if sieve_storage
    # is unset. However, you should always use the sieve_storage setting.
    # mail_location = mbox:~/mail

    # To fool ManageSieve clients that are focused on timesieved you can
    # specify the IMPLEMENTATION capability that the dovecot reports to clients
    # (default: "dovecot").
    #managesieve_implementation_string = dovecot
}

# sieve plugin. http://wiki.dovecot.org/LDA/Sieve
plugin {
    # If the user has no personal active script (i.e. if the file 
    # indicated in sieve= does not exist), use this one:
    #sieve_global_path = ${DOVECOT_GLOBAL_SIEVE_FILE}

    # The include extension fetches the :global scripts from this 
    # directory.
    #sieve_global_dir = 

    # Path to a script file or a directory containing script files
    # that need to be executed before the user's script. If the path
    # points to a directory, all the Sieve scripts contained therein
    # (with the proper .sieve extension) are executed. The order of
    # execution is determined by the file names, using a normal 8bit
    # per-character comparison.
    #sieve_before = ${DOVECOT_GLOBAL_SIEVE_FILE}

    # Identical to sieve_before, only the specified scripts are
    # executed after the user's script (only when keep is still in
    # effect!).
    #sieve_after = ${DOVECOT_GLOBAL_SIEVE_FILE}

    # Location of the active script. When ManageSieve is used this is actually
    # a symlink pointing to the active script in the sieve storage directory.
    sieve = ${SIEVE_DIR}/%Ld/%Ln/${SIEVE_RULE_FILENAME}

    # The path to the directory where the personal Sieve scripts are stored. For
    # ManageSieve this is where the uploaded scripts are stored.
    sieve_dir = ${SIEVE_DIR}/%Ld/%Ln
}
EOF

        fi
    fi
}
