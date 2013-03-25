#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose:  Use shadowAddress instead of memberOfGroup for alias domains
#           in objects objectClass=mailExternaluser.
# Date:     2013-03-25

import sys
import ldap

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=example,dc=com'
bind_dn = 'cn=Manager,dc=example,dc=com'
bind_pw = 'passwd'

# Initialize LDAP connection.
print >> sys.stderr, "* Connecting to LDAP server: %s" % uri
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
print >> sys.stderr, "* Get all accounts with objectClass=mailExternalUser..."
allUsers = conn.search_s(
    basedn,
    ldap.SCOPE_SUBTREE,
    "(objectClass=mailExternalUser)",
    ['memberOfGroup'],
)

total = len(allUsers)
print >> sys.stderr, "* Total %d user(s)." % (total)

# Counter.
count = 1

for user in allUsers:
    (dn, entry) = user

    # Get all values in attribute memberOfGroup, they're value of shadowAddress
    # we will set later.
    shadow_addresses = entry['memberOfGroup']
    if len(shadow_addresses) > 1:
        # Get memberOfGroup in dn
        value_of_rdn = dn.split(',', 1)[0].split('=')[-1]

        # Use only value of rdn.
        mod_attrs = [(ldap.MOD_REPLACE, 'memberOfGroup', [value_of_rdn])]

        # Add shadowAddress
        shadow_addresses.remove(value_of_rdn)
        mod_attrs += [(ldap.MOD_REPLACE, 'shadowAddress', shadow_addresses)]

        # Update.
        print >> sys.stderr, "* (%d of %d) Updating object: %s" % (count, total, dn)
        conn.modify_s(dn, mod_attrs)
    else:
        print >> sys.stderr, "* (%d of %d) [SKIP] No update required: %s" % (count, total, dn)

    count += 1

# Unbind connection.
print >> sys.stderr, "* Unbind LDAP server."
conn.unbind()

print >> sys.stderr, "* Update completed."
