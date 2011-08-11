#!/usr/bin/env python
# encoding: utf-8

# Author:   Zhang Huangbin <zhb@iredmail.org>
# Purpose:  Dump mail accounts from OpenLDAP in XML format.
# Date:     2011-08-11

import sys
import ldap
from ldap.controls import SimplePagedResultsControl

# Note: bind_dn must have write privilege on LDAP server.
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=example,dc=com'
bind_dn = 'cn=Manager,dc=example,dc=com'
bind_pw = 'www'
xml_file = 'accounts.xml'

# ==== Do NOT modify below settings. ====
filter = '(|(objectClass=mailDomain)(objectClass=mailAdmin)(objectClass=mailUser)(objectClass=mailAlias)(objectClass=mailList)(objectClass=mailExternalUser))'
page_size = 100

# Dump object of mail domain in XML format.
def dump_ldap_entry_in_xml(entry):
    objectClasses = entry.get('objectClass')
    if 'mailDomain' in objectClasses:
        f = open('domains.temp.xml', 'a')
        f.write('\t\t<domain>\n')

        # Attributes with single value.
        for attr in ['domainName', 'accountStatus', 'cn', 'mtaTransport', \
                  'domainBackupMX', \
                  'domainMaxQuotaSize', 'domainMaxUserNumber', \
                  'domainMaxAliasNumber', 'domainMaxListNumber', \
                  'domainDefaultUserQuota', 'disclaimer', 'description', \
                  'street', 'expiredDate', \
                 ]:
            if attr in entry:
                f.write('\t\t\t<%s>%s</%s>\n' % (attr, entry.get(attr)[0], attr))

        # Attributes with multi value.
        for attr in ['domainAliasName', 'enabledService', 'accountSetting', \
                     'domainSenderBccAddress', 'domainRecipientBccAddress', \
                     'telephoneNumber', 'facsimileTelephoneNumber', \
                     'domainWhitelistIP', 'domainWhitelistSender', \
                     'domainBlacklistIP', 'domainBlacklistSender', \
                    ]:
            if attr in entry:
                f.write('\t\t\t<%s>\n' % attr)
                for i in entry.get(attr):
                    f.write('\t\t\t\t<value>%s</value>\n' % i)
                f.write('\t\t\t</%s>\n' % attr)
        
        f.write('\t\t</domain>\n')
        f.close()

        '''
        f.write('\t<name>%s</name>\n' % entry.get('domainName')[0])

        if 'accountStatus' in entry:
            f.write('\t<status>%s</status>\n' % entry.get('accountStatus')[0])

        if 'domainAliasName' in entry:
            f.write('\t<aliases>\n')
            for a in entry.get('domainAliasName'):
                f.write('\t\t<name>%s</name>\n' % a)
            f.write('\t</aliases>\n')

        if 'domainAdmin' in entry:
            f.write('\t<admins>\n')
            for a in entry.get('domainAdmin'):
                f.write('\t\t<mail>%s</mail>\n' % a)
            f.write('\t</admins>\n')

        if 'cn' in entry:
            f.write('\t<company>%s</company>\n' % entry.get('cn')[0])

        if 'mtaTransport' in entry:
            f.write('\t<transport>%s</transport>\n' % entry.get('mtaTransport')[0])

        '''

    elif 'mailAdmin' in objectClasses:
        pass
    elif 'mailUser' in objectClasses:
        f = open('users.temp.xml', 'a')
        f.write('\t\t<user>\n')

        # Attributes with single value.
        for attr in ['mail', 'uid', 'accountStatus', 'cn', 'mtaTransport', \
                     'storageBaseDirectory', 'mailMessageStore', 'homeDirectory', \
                     'mailQuota', 'mailQuotaMessageLimit', 'userPassword', \
                     'expiredDate', 'preferredLanguage', 'disclaimer', \
                    ]:
            if attr in entry:
                f.write('\t\t\t<%s>%s</%s>\n' % (attr, entry.get(attr)[0], attr))

        # Attributes with multi value.
        for attr in ['enabledService', 'accountSetting', 'telephoneNumber', \
                     'mailForwardingAddress', 'shadowAddress', 'memberOfGroup', \
                     'telephoneNumber', 'title', \
                     'userRecipientBccAddress', 'userSenderBccAddress', \
                     'mailWhitelistRecipient', 'mailBlacklistRecipient', \
                    ]:
            if attr in entry:
                f.write('\t\t\t<%s>\n' % attr)
                for i in entry.get(attr):
                    f.write('\t\t\t\t<value>%s</value>\n' % i)
                f.write('\t\t\t</%s>\n' % attr)

        f.write('\t\t</user>\n')
        f.close()
        
    elif 'mailList' in objectClasses:
        pass
    elif 'mailAlias' in objectClasses:
        pass
    elif 'mailExternalUser' in objectClasses:
        pass
    else:
        pass

# Initialize LDAP connection.
print >> sys.stderr, "* Connecting to LDAP server: %s" % uri
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.protocol_version = 3
conn.bind_s(bind_dn, bind_pw)

# Start paged control, 100 objects per page.
paged_controller = SimplePagedResultsControl(ldap.LDAP_CONTROL_PAGE_OID, True, (page_size, ''))

# Send search request
msgid = conn.search_ext(basedn, ldap.SCOPE_SUBTREE, filter, serverctrls=[paged_controller],)

pages = 0

# Create or empty existing xml file.
open(xml_file, 'w').close()
open('domains.temp.xml', 'w').close()
open('admins.temp.xml', 'w').close()
open('users.temp.xml', 'w').close()
open('maillists.temp.xml', 'w').close()
open('aliases.temp.xml', 'w').close()

while True:
    pages += 1
    print "Getting page %d" % (pages,)
    rtype, rdata, rmsgid, serverctrls = conn.result3(msgid)
    print '%d results' % len(rdata)
    for dn, entry in rdata:
        dump_ldap_entry_in_xml(entry)

    pctrls = [c for c in serverctrls if c.controlType == ldap.LDAP_CONTROL_PAGE_OID]
    if pctrls:
        est, cookie = pctrls[0].controlValue
        if cookie:
            paged_controller.controlValue = (page_size, cookie)
            msgid = conn.search_ext(basedn, ldap.SCOPE_SUBTREE, filter, serverctrls=[paged_controller],)
        else:
            break
    else:
        print "Warning:  Server ignores RFC 2696 control."
        break
