#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <zhb@iredmail.org>
# Purpose:  Delete specified mail accounts.
# Date:     2011-03-01

import sys
import shlex
import subprocess
import ldap

# Note:
#   * bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=iredmail,dc=org'
bind_dn = 'cn=Manager,dc=iredmail,dc=org'
bind_pw = 'passwd'

allAccounts = sys.argv[1:]
total = len(allAccounts)

if not total > 0:
    print >> sys.stderr, '* Exit. No users specified.'
    sys.exit(0)
else:
    print >> sys.stderr, "* Total %d user(s)." % (total)

# Initialize LDAP connection.
print >> sys.stderr, "* Connecting to LDAP server: %s" % uri
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.bind_s(bind_dn, bind_pw)

# Generate LDAP search filter.
filter_objcls = '(|(objectClass=mailUser)(objectClass=mailList)(objectClass=mailAlias))'
filter_mails = '(|'
for mail in allAccounts:
    filter_mails += '(mail=%s)(shadowAddress=%s)' % (str(mail), str(mail))
filter_mails += ')'

filter = '(&%s%s)' % (filter_objcls, filter_mails,)

# Query LDAP to get maildir related info.
print >> sys.stderr, "* Get LDAP info of specified mail accounts..."
qr = conn.search_s(
    basedn,
    ldap.SCOPE_SUBTREE,
    filter,
    ['dn', 'objectClass', 'mail', 'storageBaseDirectory', 'mailMessageStore',],
)

print >> sys.stderr, '* Total %d account(s) found in LDAP server.' % (len(qr))
for account in qr:
    (dn, entry) = account
    mail = entry.get('mail', [''])[0]
    objectClasses = entry.get('objectClass', [])

    if 'mailUser' in objectClasses:
        storageBaseDirectory = entry.get('storageBaseDirectory', [''])[0]
        mailMessageStore = entry.get('mailMessageStore', [''])[0]
        mailbox = storageBaseDirectory + '/' + mailMessageStore

        answer = raw_input('? Delete mailbox of %s (%s)? [y|N]' % (mail, mailbox))
        if answer.lower() == 'y':
            try:
                p = subprocess.Popen(shlex.split('rm -rf %s' % mailbox))
            except Exception, e:
                print >> sys.stderr, '<< ERROR >> %s' % str(e)

    # Delete account from LDAP server.
    answer = raw_input('? Delete account from LDAP server (%s)? [y|N]' % (dn))
    if answer.lower() == 'y':
        try:
            conn.delete_s(dn)
        except Exception, e:
            print >> sys.stderr, e

# Unbind connection.
print >> sys.stderr, "* Unbind LDAP server."
conn.unbind()
