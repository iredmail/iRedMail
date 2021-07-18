#!/usr/bin/env python3
# encoding: utf-8

# Author:   Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose:  Add enabledService=<X> for existing mail users.

import ldap

# Note: bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=example,dc=com'
bind_dn = 'cn=Manager,dc=example,dc=com'
bind_pw = 'passwd'

print("* Connecting to LDAP server:", uri)
conn = ldap.initialize(uri=uri, trace_level=0)
conn.bind_s(bind_dn, bind_pw)

print("* Get all mail accounts...")
allUsers = conn.search_s(basedn,
                         ldap.SCOPE_SUBTREE,
                         "(objectClass=mailUser)",
                         ['mail', 'enabledService'])

total = len(allUsers)
print("* Total %d user(s)." % total)

# Values of 'enabledService' which need to be added.
services = [b'sogo']

# Counter.
count = 1

for user in allUsers:
    (dn, entry) = user
    mail = entry['mail'][0]
    if 'enabledService' not in entry:
        continue

    enabledService = entry['enabledService']

    # Get missing values.
    values = [s.lower() for s in services if s not in enabledService]

    if values:
        mod_attrs = [(ldap.MOD_ADD, 'enabledService', values)]

        if len(mod_attrs) > 0:
            print("* (%d of %d) Updating user: %s" % (count, total, mail))
            conn.modify_s(dn, mod_attrs)
    else:
        print("* (%d of %d) [SKIP] No update required: %s" % (count, total, mail))

    count += 1

# Unbind connection.
print("* Unbind LDAP server.")
conn.unbind()

print("* Update completed.")
