#!/usr/bin/env python3
# encoding: utf-8

# Author: Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose: Assign one user to specified groups.

# USAGE
#
#   * Set correct LDAP server address (LDAP_URI), LDAP suffix (LDAP_SUFFIX),
#     bind dn (BINDDN) and password (BINDPW).
#
#   * Run this script:
#
#       $ python3 ldap_assign_user_to_groups.py [options] user@domain.com group@domain.com [group2@domain.com ...]

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
    print("""Usage:

$ python3 ldap_assign_user_to_groups.py [options] user@domain.com new_group@domain.com [new_group_2@domain.com ...]

Note: Non-existing group will be ignored.

Optional arguments:

    --remove Remove memberships. If no mailing list specified, it will remove
             ALL assigned mailing lists.

Samples:

*) Remove all memberships:
    python3 ldap_assign_user_to_groups.py --remove user@domain.com

*) Remove memberships of specified mailing lists:
    python3 ldap_assign_user_to_groups.py --remove user@domain.com group1@domain.com group2@domain.com

*) Assign user to new mailing lists:
    python3 ldap_assign_user_to_groups.py user@domain.com group1@domain.com group2@domain.com
""")


if len(sys.argv) < 3:
    usage()
    sys.exit()

args = sys.argv
args.pop(0)

is_remove = False
if '--remove' in args:
    args.remove('--remove')
    is_remove = True

user = args.pop(0)
groups = args

if not groups and not is_remove:
    print("<<< ERROR >>> No group specified.")
    usage()
    sys.exit()

print("* Connecting to LDAP server: %s" % LDAP_URI)
conn = ldap.initialize(uri=LDAP_URI, trace_level=0)
conn.bind_s(BINDDN, BINDPW)

if not is_remove:
    print("* Querying existing mailing lists.")

    qr_filter = '(&(objectClass=mailList)(|'
    for g in groups:
        qr_filter += '(mail=%s)(shadowAddress=%s)' % (g, g)
    qr_filter += '))'

    print("* Query filter:", qr_filter)

    qr = conn.search_s(BASEDN,
                       ldap.SCOPE_SUBTREE,
                       qr_filter,
                       ['mail'])

    if qr:
        groups = []
        for (dn, entry) in qr:
            groups += entry['mail']

        print("* Found %d mailing list(s)." % len(groups))
    else:
        sys.exit("* No specified groups found in LDAP.")

print("* Get user's dn and membership of mailing list(s).")
(user_name, domain) = user.split('@', 1)
user_dn = 'mail=%s,ou=Users,domainName=%s,%s' % (user, domain, BASEDN)
try:
    qr = conn.search_s(user_dn,
                       ldap.SCOPE_BASE,
                       '(mail=%s)' % user,
                       ['mail', 'memberOfGroup'])
except ldap.NO_SUCH_OBJECT:
    print("* <<< ERROR >>> User doesn't exist: %s" % user)
    sys.exit()

(dn, entry) = qr[0]

# Get existing, assigned mailing lists.
existing_groups = entry.get('memberOfGroup', [])
if existing_groups:
    print("* Existing membership: %s" % ', '.join(existing_groups))
else:
    print("* User is not member of any mailing list.")

# New groups
if is_remove:
    if groups:
        print("* Remove membership: %s" % ', '.join(groups))
        new_groups = list(set(existing_groups) - set(groups))
    else:
        print("* Remove ALL memberships.")
        new_groups = []

    # Set to None to remove attribute `memberOfGroup`
    if not new_groups:
        print("* No membership left, remove attribute `memberOfGroup`.")
        new_groups = None
else:
    new_groups = list(set(existing_groups + groups))
    print("* New membership: %s" % ', '.join(new_groups))

mod_attrs = [(ldap.MOD_REPLACE, 'memberOfGroup', new_groups)]

try:
    print("* Updating membership.")
    conn.modify_s(dn, mod_attrs)
    print("* Updated.")

    # Unbind connection.
    print("* Unbind LDAP server.")
    conn.unbind()
except Exception as e:
    print("<<< ERROR >>> %s" % repr(e))
