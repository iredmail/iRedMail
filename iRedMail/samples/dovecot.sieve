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

require ["fileinto", "vacation"];

# -------------------------------------------------
# --------------- Global sieve rules --------------
# -------------------------------------------------

# rule:[Move Spam to Junk Folder]
if false # header :is "X-Spam-Flag" "YES"
{
    fileinto "Junk";
    stop;
}

# Sample rule of vacation message, disabled by default.
# rule:[Vacation]
if false # true
{
    vacation :days 1 "I'm on vacation.";
}
