#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <michaelbibby (at) gmail.com>
# Purpose:  Update all users' mailbox quota.

import sys
import ldap

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
bind_dn = 'cn=vmailadmin,dc=iredmail,dc=org'
bind_pw = 'passwd'

# Base dn used to update ALL mail users.
basedn = 'o=domains,dc=iredmail,dc=org'
# Base dn used to update users under domain 'example.com'.
#basedn = 'ou=Users,domainName=example.com,o=domains,dc=iredmail,dc=org'

new_quota = 2048   # quota size in MB

# Convert quota to KB.
quota = str(int(new_quota) * 1024 * 1024)

# Initialize LDAP connection.
conn = ldap.initialize(uri=uri, trace_level=0,)

# Bind.
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
allUsers = conn.search_s(
        basedn,
        ldap.SCOPE_SUBTREE,
        "(objectClass=mailUser)",
        ['mail', 'mailQuota', ],
        )

# Debug.
#print >> sys.stderr, allUsers

# Counter.
count = 1

for user in allUsers:
    dn = user[0]
    mail = user[1]['mail'][0]
    cur_quota = user[1].get('mailQuota', ['unlimited'])[0]

    print >> sys.stderr, """Updating user (%d): %s, %s""" % (count, mail, cur_quota)

    mod_attrs = [ (ldap.MOD_REPLACE, 'mailQuota', quota) ]
    try:
        conn.modify_s(dn, mod_attrs)
    except Exception, e:
        print >> sys.stderr, str(e)

    count += 1

# Unbind connection.
conn.unbind()

print >> sys.stderr, 'Updated.'
