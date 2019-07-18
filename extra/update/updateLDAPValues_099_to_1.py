#!/usr/bin/env python2
# Author:   Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose:  Add enabledService=quota-status for existing mail users.
#           Used by Dovecot quota-status service.
# Date:     Jul 17, 2019.

import ldap

# Note: bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=example,dc=com'
bind_dn = 'cn=Manager,dc=example,dc=com'
bind_pw = 'passwd'

# Initialize LDAP connection.
print "* Connecting to LDAP server: %s" % uri
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
print "* Get all mail accounts..."
all_users = conn.search_s(basedn,
                          ldap.SCOPE_SUBTREE,
                          "(objectClass=mailUser)",
                          ['mail', 'enabledService'])

total = len(all_users)
print "* Total %d user(s)." % (total)

# New values of the 'enabledService' attribute.
new_services = ['quota-status']

# Counter.
count = 1

for user in all_users:
    (dn, ldif) = user
    mail = ldif['mail'][0]
    if 'enabledService' not in ldif:
        continue

    existing_services = ldif['enabledService']
    missed_services = [str(s).lower() for s in new_services if s not in existing_services]

    mod_attrs = []

    if missed_services:
        mod_attrs += [(ldap.MOD_ADD, 'enabledService', missed_services)]

        # Update.
        print "* (%d of %d) Updating user: %s" % (count, total, mail)
        conn.modify_s(dn, mod_attrs)
    else:
        print "* (%d of %d) [SKIP] No update required: %s" % (count, total, mail)

    count += 1

# Unbind connection.
print "* Unbind LDAP server."
conn.unbind()

print "* Update completed."
