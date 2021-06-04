#!/usr/bin/env python3
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
print("* Connecting to LDAP server: {}".format(uri))
conn = ldap.initialize(uri=uri, trace_level=0,)
conn.bind_s(bind_dn, bind_pw)

# Get all mail users.
print("* Get mail accounts ...")
allUsers = conn.search_s(
    basedn,
    ldap.SCOPE_SUBTREE,
    "(&(objectClass=mailUser)(|(enabledService=imapsecured)(enabledService=pop3secured)(enabledService=smtpsecured)(enabledService=sievesecured)(enabledService=managesievesecured)))",
    ['mail', 'enabledService'],
)

total = len(allUsers)
print("* Updating {} user(s).".format(total))

# Counter.
count = 1

for (dn, entry) in allUsers:
    mail = entry['mail'][0]
    if 'enabledService' not in entry:
        continue

    enabledService = entry['enabledService']

    _update = False

    # If old service is disabled for the user, then no need to add the new one.
    for old, new in [(b'imapsecured', b'imaptls'),
                     (b'pop3secured', b'pop3tls'),
                     (b'smtpsecured', b'smtptls'),
                     (b'sievesecured', b'sievetls')]:
        if (old in enabledService) and (new not in enabledService):
            enabledService.append(new)
            _update = True

    if _update:
        print("* ({} of {}) Updating user: {}".format(count, total, mail))
        mod_attr = [(ldap.MOD_REPLACE, 'enabledService', enabledService)]
        try:
            conn.modify_s(dn, mod_attr)
        except Exception as e:
            print("Error while updating user {}: {}".format(mail, repr(e)))
    else:
        print("* [SKIP] No update required for user: {}".format(mail))

    count += 1

# Unbind connection.
print("* Unbind LDAP server.")
conn.unbind()

print("* Update completed.")
