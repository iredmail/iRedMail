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

#
# Sample dovecot sieve global rules. It should be localted at:
#   /var/vmail/sieve/dovecot.sieve
#
# Refer to 'sieve_global_path' parameter for the file localtion
# in dovecot.conf on your server.
#

# For more information, please refer to official documentation:
# http://wiki.dovecot.org/LDA/Sieve

require "fileinto";

# -------------------------------------------------
# --------------- Global sieve rules --------------
# -------------------------------------------------

# rule:[Move Spam to Junk Folder]
if header :matches ["X-Spam-Flag"] ["YES"] {
    #
    # If you want to copy this spam mail to other people, uncomment
    # below line and set correct email address. One email one line.
    #
    #redirect "user1@domain.ltd";
    #redirect "user2@domain.ltd";

    # Keep this mail in INBOX.
    #keep;

    # If you ensure it is really a spam, drop it to 'Junk', and stop
    # here so that we do not reply to spammers.
    fileinto "Junk";

    # Do not waste resource on spam mail.
    stop;

    # If you ensure they are spam, you can discard it.
    #discard;
}
