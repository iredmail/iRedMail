#!/usr/bin/env python
# encoding: utf-8

# Author: Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose: Move or copy ALL members of specified mailing list to another
#          mailing list.

# USAGE
#
#   * Set correct LDAP server address (LDAP_URI), LDAP suffix (LDAP_SUFFIX),
#     bind dn (BINDDN) and password (BINDPW).
#
#   * Run this script:
#
#       $ python ldap_move_members_to_another_group.py [options] old_group@domain.com new_group@domain.com [new_group2@domain.com ...]

# LDAP server address.
LDAP_URI = 'ldap://127.0.0.1:389'
LDAP_SUFFIX = 'dc=example,dc=com'

# LDAP base dn, bind dn/password.
BASEDN = 'o=domains,%s' % LDAP_SUFFIX
BINDDN = 'cn=Manager,%s' % LDAP_SUFFIX
BINDPW = 'www'


import sys
import ldap

def usage():
    print """Usage:

$ python ldap_move_members_to_another_group.py [options] old_group@domain.com [new_group@domain.com new_group_2@domain.com ...]

Available optional options:

    --copy Assign members of old group to new groups without removing
           membership of old group. That means user will be member of both
           old and new groups.

           If no --copy specified, this script will remove membership of old
           group.

Samples:

*) Copy all members of old_group@domain.com to new_group@domain.com
    python ldap_move_members_to_another_group --copy old_group@domain.com new_group@domain.com

*) Copy all members of old_group@domain.com to new_group@domain.com, and remove
   ALL members of old_group@domain.com.
    python ldap_move_members_to_another_group old_group@domain.com new_group@domain.com

*) Remove all members (just remove membership, not remove mail accounts) of
   old_group@domain.com.
    python ldap_move_members_to_another_group old_group@domain.com
"""

if len(sys.argv) < 3:
    usage()
    sys.exit()

args = sys.argv
args.pop(0)

is_copy = False
if '--copy' in args:
    is_copy = True
    args.remove('--copy')

old_group = args.pop(0)
new_groups = args

# Initialize LDAP connection.
print "* Connecting to LDAP server: %s" % LDAP_URI
conn = ldap.initialize(uri=LDAP_URI, trace_level=0)
conn.bind_s(BINDDN, BINDPW)

# Get all members of old mailing list.
print "* Get all members of old mailing list: %s" % old_group

qr_filter = '(&(objectClass=mailUser)(memberOfGroup=%s))' % old_group
print "* Query filter:", qr_filter

qr = conn.search_s(BASEDN,
                   ldap.SCOPE_SUBTREE,
                   qr_filter,
                   ['memberOfGroup'])

total = len(qr)

if total:
    print "* Old mailing list has %d member(s)." % (total)
else:
    sys.exit("* Old mailing list doesn't have any member. Exit.")

# accumulate counter
count = 1

for user in qr:
    (dn, entry) = user

    # Get all assigned mailing lists.
    groups = entry['memberOfGroup']

    if not is_copy:
        # Remove old mailing list
        groups.remove(old_group)

    # Assign to new mailing list
    if new_groups:
        groups = list(set(groups + new_groups))

    # Use only value of rdn.
    mod_attrs = [(ldap.MOD_REPLACE, 'memberOfGroup', groups)]

    try:
        print "* (%d of %d) Updating object: %s" % (count, total, dn)
        conn.modify_s(dn, mod_attrs)
    except Exception, e:
        print '<<< ERROR >>> %s' % str(e)

    count += 1

# Unbind connection.
print "* Unbind LDAP server."
conn.unbind()

print "* Done."
