#!/usr/bin/env python
# encoding: utf-8

# Author: Zhang Huangbin <zhb _at_ iredmail.org>
# Purpose: Add new OpenLDAP user for postfix mail server.
# Project:  iRedMail (http://www.iredmail.org/)

# --------------------------- WARNING ------------------------------
# This script only works under iRedMail >= 0.4.0 due to ldap schema
# changes.
# ------------------------------------------------------------------

# ---------------------------- USAGE -------------------------------
# Put your user list in a csv format file, e.g. users.csv, and then
# import users listed in the file:
#
#   $ python create_mail_user_OpenLDAP.py users.csv
#
# ------------------------------------------------------------------

# ------------------------- SETTINGS -------------------------------
# LDAP server address.
LDAP_URI = 'ldap://127.0.0.1:389'

# LDAP base dn.
BASEDN = 'o=domains,dc=iredmail,dc=org'

# LDAP bind dn & password.
#BINDDN = 'cn=Manager,dc=iredmail,dc=org'
#BINDPW = 'passwd'

# Storage base directory.
STORAGE_BASE_DIRECTORY = '/var/vmail/vmail1'

# Get base directory and storage node.
std = STORAGE_BASE_DIRECTORY.rstrip('/').split('/')
STORAGE_NODE = std.pop()
STORAGE_BASE = '/'.join(std)

# Hashed maildir: True, False.
# Example:
#   domain: domain.ltd,
#   user:   zhang (zhang@domain.ltd)
#
#       - hashed: d/do/domain.ltd/z/zh/zha/zhang/
#       - normal: domain.ltd/zhang/
HASHED_MAILDIR = True
# ------------------------------------------------------------------

import os
import sys
import time
import re

try:
    import ldap
    import ldif
except ImportError:
    print '''
    Error: You don't have python-ldap installed, Please install it first.
    
    You can install it like this:

    - On RHEL/CentOS 5.x:

        $ sudo yum install python-ldap

    - On Debian & Ubuntu:

        $ sudo apt-get install python-ldap
    '''
    sys.exit()


def usage():
    print '''
CSV file format:

    domain name, username, password, [common name], [quota], [groups]

Example #1:
    iredmail.org, zhang, plain_password, Zhang Huangbin, 1024, group1:group2
Example #2:
    iredmail.org, zhang, plain_password, Zhang Huangbin, ,
Example #3:
    iredmail.org, zhang, plain_password, , 1024, group1:group2
     
Note:
    - Domain name, username and password are REQUIRED, others are optional:
        + common name.
            * It will be the same as username if it's empty.
            * Non-ascii character is allowed in this field, they will be
              encoded automaticly. Such as Chinese, Korea, Japanese, etc.
        + quota. It will be 0 (unlimited quota) if it's empty.
        + groups.
            * valid group name (hr@a.cn): hr
            * incorrect group name: hr@a.cn
            * Do *NOT* include domain name in group name, it will be
              appended automaticly.
            * Multiple groups must be seperated by colon.
    - Leading and trailing Space will be ignored.
'''

def convEmailToUserDN(email):
    """Convert email address to ldap dn of normail mail user."""
    if email.count('@') != 1: return ''

    user, domain = email.split('@')

    # User DN format.
    # mail=user@domain.ltd,domainName=domain.ltd,[LDAP_BASEDN]
    dn = 'mail=%s,ou=Users,domainName=%s,%s' % (email, domain, BASEDN)

    return dn

def ldif_mailuser(domain, username, passwd, cn, quota, groups=''):
    DATE = time.strftime('%Y.%m.%d.%H.%M.%S')
    if quota == '':
        quota = '0'

    # Remove SPACE in username.
    username = str(username).strip().replace(' ', '')

    if cn == '': cn = username
    mail = username.lower() + '@' + domain
    dn = convEmailToUserDN(mail)

    # Get group list.
    if groups.strip() != '':
        groups = groups.strip().split(':')
        for i in range(len(groups)):
            groups[i] = groups[i] + '@' + domain

    maildir_domain = str(domain).lower()
    if HASHED_MAILDIR is True:
        # Hashed. Length of domain name are always >= 2.
        #maildir_domain = "%s/%s/%s/" % (domain[:1], domain[:2], domain)
        if len(username) >= 3:
            maildir_user = "%s/%s/%s/%s-%s/" % (username[0], username[1], username[2], username, DATE,)
        elif len(username) == 2:
            maildir_user = "%s/%s/%s/%s-%s/" % (
                    username[0],
                    username[1],
                    username[1],
                    username,
                    DATE,
                    )
        else:
            maildir_user = "%s/%s/%s/%s-%s/" % (
                    username[0],
                    username[0],
                    username[0],
                    username,
                    DATE,
                    )
        mailMessageStore = maildir_domain + '/' + maildir_user
    else:
        mailMessageStore = "%s/%s-%s/" % (domain, username, DATE)

    homeDirectory = STORAGE_BASE_DIRECTORY + '/' + mailMessageStore
    mailMessageStore = STORAGE_NODE + '/' + mailMessageStore

    ldif = [
        ('objectClass',         ['inetOrgPerson', 'mailUser', 'shadowAccount', 'amavisAccount',]),
        ('mail',                [mail]),
        ('userPassword',        [passwd]),
        ('mailQuota',           [quota]),
        ('cn',                  [cn]),
        ('sn',                  [username]),
        ('uid',                 [username]),
        ('storageBaseDirectory', [STORAGE_BASE]),
        ('mailMessageStore',    [mailMessageStore]),
        ('homeDirectory',       [homeDirectory]),
        ('accountStatus',       ['active']),
        ('mtaTransport',        ['dovecot']),
        ('enabledService',      ['internal', 'doveadm',
                                 'mail', 'smtp', 'smtpsecured',
                                 'pop3', 'pop3secured', 'imap', 'imapsecured',
                                'deliver', 'lda', 'forward', 'senderbcc', 'recipientbcc',
                                 'managesieve', 'managesievesecured',
                                 'sieve', 'sievesecured', 'shadowaddress',
                                'displayedInGlobalAddressBook', ]),
        ('memberOfGroup',       groups),
        ]

    return dn, ldif

if len(sys.argv) != 2 or len(sys.argv) > 2:
    print """Usage: $ python %s users.csv""" % ( sys.argv[0] )
    usage()
    sys.exit()
else:
    CSV = sys.argv[1]
    if not os.path.exists(CSV):
        print '''Erorr: file not exist:''', CSV
        sys.exit()

ldif_file = CSV + '.ldif'

# Remove exist LDIF file.
if os.path.exists(ldif_file):
    print '''< INFO > Remove exist file:''', ldif_file
    os.remove(ldif_file)

# Read user list.
userList = open(CSV, 'rb')

# Convert to LDIF format.
for entry in userList.readlines():
    entry = entry.rstrip()
    domain, username, passwd, cn, quota, groups = re.split('\s?,\s?', entry)
    dn, data = ldif_mailuser(domain, username, passwd, cn, quota, groups)

    # Write LDIF data.
    result = open(ldif_file, 'a')
    ldif_writer = ldif.LDIFWriter(result)
    ldif_writer.unparse(dn, data)

# Notify info.
print "< INFO > User data are stored in %s, you can verify it before import it." % os.path.abspath(ldif_file)

# Prompt to import user data.
'''
Would you like to import them now?""" % (ldif_file)

answer = raw_input('[Y|n] ').lower().strip()

if answer == '' or answer == 'y':
    # Import data.
    conn = ldap.initialize(LDAP_URI)
    conn.set_option(ldap.OPT_PROTOCOL_VERSION, 3)   # Use LDAP v3
    conn.bind_s(BINDDN, BINDPW)
    conn.unbind()
else:
    pass
'''
