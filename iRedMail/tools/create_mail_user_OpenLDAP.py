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
BASEDN = 'o=domains,dc=example,dc=com'

# Bind dn/password
BINDDN = 'cn=Manager,dc=example,dc=com'
BINDPW = 'password'

# Storage base directory.
STORAGE_BASE_DIRECTORY = '/var/vmail/vmail1'

# Append timestamp in maildir path.
APPEND_TIMESTAMP_IN_MAILDIR = True

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

# Default password schemes.
# Multiple passwords are supported if you separate schemes with '+'.
# For example: 'SSHA+NTLM', 'CRAM-MD5+SSHA', 'CRAM-MD5+SSHA+MD5'.
DEFAULT_PASSWORD_SCHEME = 'SSHA'

# Do not prefix password scheme name in password hash.
HASHES_WITHOUT_PREFIXED_PASSWORD_SCHEME = ['NTLM']
# ------------------------------------------------------------------

import os
import sys
import time
import datetime
from subprocess import Popen, PIPE
from base64 import b64encode
import re

try:
    #import ldap
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

    domain name, username, password, [common name], [quota_in_bytes], [groups]

Example #1:
    iredmail.org, zhang, plain_password, Zhang Huangbin, 104857600, group1:group2
Example #2:
    iredmail.org, zhang, plain_password, Zhang Huangbin, ,
Example #3:
    iredmail.org, zhang, plain_password, , 104857600, group1:group2

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

def conv_mail_to_user_dn(email):
    """Convert email address to ldap dn of normail mail user."""
    if email.count('@') != 1:
        return ''

    user, domain = email.split('@')

    # User DN format.
    # mail=user@domain.ltd,domainName=domain.ltd,[LDAP_BASEDN]
    dn = 'mail=%s,ou=Users,domainName=%s,%s' % (email, domain, BASEDN)

    return dn


def generate_password_hash(p, pwscheme=None):
    """Generate password for LDAP mail user and admin."""
    p = str(p).strip()

    if not pwscheme:
        pwscheme = DEFAULT_PASSWORD_SCHEME

    # Supports returning multiple passwords.
    pw_schemes = pwscheme.split('+')
    pws = []

    for scheme in pw_schemes:
        if scheme == 'PLAIN':
            pws.append(p)
        else:
            pw = generate_password_with_doveadmpw(scheme, p)

            if scheme in HASHES_WITHOUT_PREFIXED_PASSWORD_SCHEME:
                pw = pw.lstrip('{' + scheme + '}')

            pws.append(pw)

    return pws


def generate_ssha_password(p):
    p = str(p).strip()
    salt = os.urandom(8)
    try:
        from hashlib import sha1
        pw = sha1(p)
    except ImportError:
        import sha
        pw = sha.new(p)
    pw.update(salt)
    return "{SSHA}" + b64encode(pw.digest() + salt)


def generate_password_with_doveadmpw(scheme, plain_password):
    """Generate password hash with `doveadm pw` command.
    Return SSHA instead if no 'doveadm' command found or other error raised."""
    # scheme: CRAM-MD5, NTLM
    scheme = scheme.upper()
    p = str(plain_password).strip()

    try:
        pp = Popen(['doveadm', 'pw', '-s', scheme, '-p', p],
                   stdout=PIPE)
        pw = pp.communicate()[0]

        if scheme in HASHES_WITHOUT_PREFIXED_PASSWORD_SCHEME:
            pw.lstrip('{' + scheme + '}')

        # remove '\n'
        pw = pw.strip()

        return pw
    except:
        return generate_ssha_password(p)

def get_days_of_today():
    """Return number of days since 1970-01-01."""
    today = datetime.date.today()

    try:
        return (datetime.date(today.year, today.month, today.day) - datetime.date(1970, 1, 1)).days
    except:
        return 0

def ldif_mailuser(domain, username, passwd, cn, quota, groups=''):
    # Append timestamp in maildir path
    DATE = time.strftime('%Y.%m.%d.%H.%M.%S')
    TIMESTAMP_IN_MAILDIR = ''
    if APPEND_TIMESTAMP_IN_MAILDIR:
        TIMESTAMP_IN_MAILDIR = '-%s' % DATE

    if quota == '':
        quota = '0'

    # Remove SPACE in username.
    username = str(username).lower().strip().replace(' ', '')

    if cn == '':
        cn = username

    mail = username + '@' + domain
    dn = conv_mail_to_user_dn(mail)

    # Get group list.
    if groups.strip() != '':
        groups = groups.strip().split(':')
        for i in range(len(groups)):
            groups[i] = groups[i] + '@' + domain

    maildir_domain = str(domain).lower()
    if HASHED_MAILDIR is True:
        str1 = str2 = str3 = username[0]
        if len(username) >= 3:
            str2 = username[1]
            str3 = username[2]
        elif len(username) == 2:
            str2 = str3 = username[1]

        maildir_user = "%s/%s/%s/%s%s/" % (str1, str2, str3, username, TIMESTAMP_IN_MAILDIR, )
        mailMessageStore = maildir_domain + '/' + maildir_user
    else:
        mailMessageStore = "%s/%s%s/" % (domain, username, TIMESTAMP_IN_MAILDIR)

    homeDirectory = STORAGE_BASE_DIRECTORY + '/' + mailMessageStore
    mailMessageStore = STORAGE_NODE + '/' + mailMessageStore

    ldif = [
        ('objectClass', ['inetOrgPerson', 'mailUser', 'shadowAccount', 'amavisAccount']),
        ('mail', [mail]),
        ('userPassword', generate_password_hash(passwd)),
        ('mailQuota', [quota]),
        ('cn', [cn]),
        ('sn', [username]),
        ('uid', [username]),
        ('storageBaseDirectory', [STORAGE_BASE]),
        ('mailMessageStore', [mailMessageStore]),
        ('homeDirectory', [homeDirectory]),
        ('accountStatus', ['active']),
        ('enabledService', ['internal', 'doveadm', 'lib-storage', 'indexer-worker', 'dsync',
                            'mail',
                            'smtp', 'smtpsecured', 'smtptls'
                            'pop3', 'pop3secured', 'pop3tls',
                            'imap', 'imapsecured', 'imaptls',
                            'deliver', 'lda', 'forward', 'senderbcc', 'recipientbcc',
                            'managesieve', 'managesievesecured',
                            'sieve', 'sievesecured', 'lmtp', 'sogo',
                            'shadowaddress',
                            'displayedInGlobalAddressBook']),
        ('memberOfGroup', groups),
        # shadowAccount integration.
        ('shadowLastChange', [str(get_days_of_today())]),
        # Amavisd integration.
        ('amavisLocal', ['TRUE'])]

    return dn, ldif

if len(sys.argv) != 2 or len(sys.argv) > 2:
    print """Usage: $ python %s users.csv""" % sys.argv[0]
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


ldif_file_path = os.path.abspath(ldif_file)
print "< INFO > User data are stored in %s, you can verify it before importing it." % ldif_file_path
print "< INFO > You can import it with below command:"
print "ldapadd -x -D %s -W -f %s" % (BINDDN, ldif_file_path)

# Prompt to import user data.
'''
answer = raw_input("Would you like to import them now? [y|N]").lower().strip()

if answer == 'y':
    # Import data.
    conn = ldap.initialize(LDAP_URI)
    conn.set_option(ldap.OPT_PROTOCOL_VERSION, 3)   # Use LDAP v3
    conn.bind_s(BINDDN, BINDPW)
    conn.unbind()
else:
    pass
'''
