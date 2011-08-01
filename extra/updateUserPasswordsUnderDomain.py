#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <michaelbibby (at) gmail.com>
# Purpose:  Change password of ALL users under domain.

# Usage:
#   - Change LDAP related settings below:
#       + uri
#       + basedn
#       + bind_dn
#       + bind_pw
#   - Run this script with domain name and new password:
#
#       # python updateUserPasswordsUnderDomain.py DOMAIN_NAME NEW_PASSWD
#

import sys
import ldap

domain = sys.argv[1]
newpw = sys.argv[2]

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'ou=Users,domainName=%s,o=domains,dc=iredmail,dc=org' % sys.argv[1]
bind_dn = 'cn=vmailadmin,dc=iredmail,dc=org'
bind_pw = 'A807AiXxdjJ7CQWWORc49RIbub0W4d'

# Initialize LDAP connection.
conn = ldap.initialize(uri=uri, trace_level=0,)

# Bind.
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
allUsers = conn.search_s(
        basedn,
        ldap.SCOPE_SUBTREE,
        "(objectClass=mailUser)",
        ['mail', 'userPassword',],
        )

# Debug.
#print >> sys.stderr, allUsers

# Counter.
count = 1

for user in allUsers:
    dn = user[0]
    mail = user[1]['mail'][0]

    try:
        #conn.modify_s(dn, [(ldap.MOD_ADD, 'userPassword', '')])
        conn.passwd_s(dn, None, newpw)
        print >> sys.stderr, """Updated user (%d): %s""" % (count, mail)
    except ldap.TYPE_OR_VALUE_EXISTS:
        pass
    except Exception, e:
        print >> sys.stderr, """Error while updating user (%s): %s""" % (mail, str(e))

    count += 1

# Unbind connection.
conn.unbind()

print >> sys.stderr, 'Updated.'
