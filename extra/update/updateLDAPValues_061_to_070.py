#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <zhb@iredmail.org>
# Purpose:  Add three service name in 'enabledService' attribute.
#           Required in iRedMail-0.7.0.
# Date:     2011-01-28

import sys
import ldap

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=iredmail,dc=org'
bind_dn = 'cn=vmailadmin,dc=iredmail,dc=org'
bind_pw = 'passwd'

# Initialize LDAP connection.
print >> sys.stderr, "* Connecting to LDAP server: %s" % uri
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
print >> sys.stderr, "* Get all mail accounts..."
allUsers = conn.search_s(
        basedn,
        ldap.SCOPE_SUBTREE,
        "(objectClass=mailUser)",
        ['dn', 'mail', 'enabledService', 'objectClass',],
        )

total = len(allUsers)
print >> sys.stderr, "* Total %d user(s)." % (total)

# Values of 'enabledService' which need to be added.
services = ['smtpsecured']

# Counter.
count = 1

for user in allUsers:
    (dn, entry) = user
    mail = entry['mail'][0]
    if entry.has_key('enabledService'):
        enabledService = entry['enabledService']
    else:
        continue
    objectClasses = entry['objectClass']

    # Get missing values.
    values = [str(s).lower() for s in services if s not in enabledService]

    mod_attrs = []

    # Add missing values of 'enabledService'.
    if len(values) > 0:
        mod_attrs += [(ldap.MOD_ADD, 'enabledService', values)]

    # Add missing values of 'objectClass'.
    if 'amavisAccount' not in objectClasses:
        mod_attrs += [(ldap.MOD_ADD, 'objectClass', 'amavisAccount')]

    # Update.
    if len(mod_attrs) > 0:
        print >> sys.stderr, "* Updating user (%d/%d): %s" % (count, total, mail)
        conn.modify_s(dn, mod_attrs)
    else:
        print >> sys.stderr, "* Updating user (%d/%d): %s. [SKIP. No update required.]" % (count, total, mail)

    count += 1

# Unbind connection.
print >> sys.stderr, "* Unbind LDAP server."
conn.unbind()

print >> sys.stderr, "* Update completed."
