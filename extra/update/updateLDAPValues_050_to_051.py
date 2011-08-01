#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <michaelbibby (at) gmail.com>
# Purpose:  Add three new services name in 'enabledService' attribute.
#           Required in iRedMail-0.5.1.

import sys
import ldap

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=iredmail,dc=org'
bind_dn = 'cn=vmailadmin,dc=iredmail,dc=org'
#bind_dn = 'cn=Manager,dc=iredmail,dc=org'
bind_pw = 'passwd'

# Initialize LDAP connection.
conn = ldap.initialize(uri=uri, trace_level=0,)

# Bind.
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
allUsers = conn.search_s(
        basedn,
        ldap.SCOPE_SUBTREE,
        "(objectClass=mailUser)",
        ['dn', 'mail', 'enabledService'],
        )

# Debug.
#print >> sys.stderr, allUsers

# Values which need to be added.
services = ['pop3secured', 'imapsecured', 'managesievesecured',]

# Counter.
count = 1

for user in allUsers:
    dn = user[0]
    mail = user[1]['mail'][0]
    enabledService = user[1]['enabledService']

    # Get missing values.
    values = [ s for s in services if s not in enabledService ]

    # Update it if there are something missed..
    if len(values) != 0:
        print >> sys.stderr, """Updating user (%d): %s""" % (count, mail)

        mod_attrs = [ (ldap.MOD_ADD, 'enabledService', values) ]
        conn.modify_s(dn, mod_attrs)

        count += 1

# Unbind connection.
conn.unbind()

print >> sys.stderr, 'Updated.'
