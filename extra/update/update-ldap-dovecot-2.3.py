#!/usr/bin/env python
# Author:   Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose:  Add missing attribute/value pairs required by Dovecot-2.3.
# Date:     Apr 12, 2018.

import ldap

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=example,dc=com'
bind_dn = 'cn=Manager,dc=example,dc=com'
bind_pw = 'password'

# Initialize LDAP connection.
print "* Connecting to LDAP server: %s" % uri
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
print "* Get mail accounts ..."
allUsers = conn.search_s(basedn,
                         ldap.SCOPE_SUBTREE,
                         "(&(objectClass=mailUser)(|(enabledService=imapsecured)(enabledService=pop3secured)))",
                         ['mail', 'enabledService'])

total = len(allUsers)
print "* Updating %d user(s)." % (total)

# Counter.
count = 1

for (dn, entry) in allUsers:
    mail = entry['mail'][0]
    if 'enabledService' not in entry:
        continue

    enabledService = entry['enabledService']

    if 'imapsecured' in enabledService:
        enabledService += ['imaptls']

    if 'pop3secured' in enabledService:
        enabledService += ['pop3tls']

    print "* (%d of %d) Updating user: %s" % (count, total, mail)
    mod_attr = [(ldap.MOD_REPLACE, 'enabledService', enabledService)]
    try:
        conn.modify_s(dn, mod_attr)
    except Exception, e:
        print "Error while updating user:", mail, e

    count += 1

# Unbind connection.
print "* Unbind LDAP server."
conn.unbind()

print "* Update completed."
