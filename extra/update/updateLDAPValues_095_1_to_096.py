#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose:  Add `domainStatus=disabled` to all mail users/aliases/lists if
#           domain is disabled.
# Date:     Oct 21, 2016.

import sys
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

print "* Authenticate as dn: %s" % bind_dn
conn.bind_s(bind_dn, bind_pw)

# Get all disabled domains.
print "* Get all disabled mail domains ..."

qf = "(&(objectClass=mailDomain)(accountStatus=disabled))"
qr_domains = conn.search_s(basedn,
                           ldap.SCOPE_ONELEVEL,
                           qf,
                           ['dn', 'domainName'])

if not qr_domains:
    print "* No disabled domain. Exit."
    sys.exit()

print "* Found %d disabled domains." % len(qr_domains)

qf = "(&"
qf += "(!(domainStatus=disabled))"
qf += "(|(objectClass=mailUser)(objectClass=mailAlias)(objectClass=mailList)(objectClass=mailExternalUser))"
qf += ")"

mod_attr = [(ldap.MOD_ADD, 'domainStatus', ['disabled'])]

for (dn, _ldif) in qr_domains:
    domain = _ldif['domainName'][0]

    # Get all mail accounts which don't have required mod_attr.
    qr_accounts = conn.search_s(basedn,
                                ldap.SCOPE_SUBTREE,
                                qf,
                                ['mail', 'domainStatus'])

    total = len(qr_accounts)
    if total:
        print "* Updating %d accounts(s) under domain %s." % (total, domain)
    else:
        print "* No update required for domain %s." % domain

    # Counter.
    count = 1

    for (dn, _ldif2) in qr_accounts:
        mail = _ldif2['mail'][0]

        try:
            print "* (%d of %d) Updating user: %s" % (count, total, mail)
            conn.modify_s(dn, mod_attr)
        except Exception, e:
            print "* (%d of %d) <<< ERROR >>> %s: %s" % (count, total, mail, repr(e))

        count += 1

conn.unbind()

print "* Update completed."
