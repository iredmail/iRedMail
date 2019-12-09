"""
This file is used to migrate SQL table `vmail.alias` for SQL backends.

Requirements:

* Make sure you have new SQL tables ready: alias_moderators, forwardings.
* For PostgreSQL, please make sure SQL user 'vmail' has 'SELECT' privilege on
  newly created sql tables.
"""

import sys
import web

web.config.debug = False

# Read iRedAdmin config file `settings.py` from one of expected paths
sys.path.insert(0, '/usr/local/www/iredadmin')      # FreeBSD
sys.path.insert(0, '/opt/www/iredadmin')            # Debian/Ubuntu
sys.path.insert(0, '/var/www/iredadmin')            # CentOS/OpenBSD
sys.path.insert(0, '/usr/share/apache2/iredadmin')  # Debian/Ubuntu (old iRedMail releases)

import settings
print "* Read SQL username/password from iRedAdmin config file:", settings.__file__
print "* Backend:", settings.backend

if settings.backend in ['ldap', 'mysql']:
    sql_dbn = 'mysql'
elif settings.backend in ['pgsql']:
    sql_dbn = 'postgres'
else:
    sys.exit('* << ERROR >>: Unsupported backend (%s).' % settings.backend)

try:
    if sql_dbn == 'postgres':
        db = web.database(dbn=sql_dbn,
                          host=settings.vmail_db_host,
                          port=int(settings.vmail_db_port),
                          db=settings.vmail_db_name,
                          user=settings.vmail_db_user,
                          pw=settings.vmail_db_password)
    else:
        db = web.database(dbn=sql_dbn,
                          host=settings.vmail_db_host,
                          port=int(settings.vmail_db_port),
                          db=settings.vmail_db_name,
                          user=settings.vmail_db_user,
                          pw=settings.vmail_db_password,
                          charset='utf8',
                          use_unicode=False)

    db.supports_multiple_insert = True
except Exception as e:
    print "<< ERROR >> Cannot connecting to SQL server:", e
    sys.exit()

# Check required tables
for tbl in ['forwardings', 'alias_moderators']:
    try:
        db.select(tbl, limit=1)
    except Exception as e:
        print "<<< ERROR >>> SQL table '%s' doesn't exist. Please create it first." % tbl
        sys.exit()

# Get all existing accounts
records = db.select('alias', what='address,goto,moderators,domain,active,islist,is_alias')

total = len(records)
counter = 1
for r in records:
    # standard mail alias account
    is_list = 0
    # per-account alias address
    is_alias = 0
    # forwarding addresses of mail user
    is_forwarding = 0

    if r.islist == 1:
        is_list = 1
        _type = 'mail alias'
    elif r.is_alias == 1:
        is_alias = 1
        _type = 'per-account alias address'
    else:
        is_forwarding = 1
        _type = 'mail user'

    account = str(r.address).lower()
    active = int(r.active)
    domain = str(r.domain).lower()

    goto = r.goto.strip(' ')
    goto = goto.replace(' ', '')
    goto = goto.replace(';', ',')
    members = list(set([i.strip().lower() for i in goto.strip(' ').split(',')]))

    # Migrating forwardings
    print "* [%d/%d] Migrating %s %s" % (counter, total, _type, account)
    for m in members:
        if m:
            try:
                dest_domain = m.split('@', 1)[-1]

                db.insert('forwardings',
                          address=account,
                          forwarding=m,
                          domain=domain,
                          dest_domain=dest_domain,
                          active=active,
                          is_list=is_list,
                          is_alias=is_alias,
                          is_forwarding=is_forwarding)

            except Exception as e:
                if e[0] == 1062 or 'duplicate' in repr(e):
                    # Duplicate record
                    pass
                else:
                    print "Error while migrating %s %s: %s" % (_type, m, repr(e))

    # Migrating moderators of mail alias account
    moderators = []
    if is_list == 1:
        if r.moderators:
            moderators = [i.lower() for i in set(r.moderators.strip(' ').split(','))]

    if moderators:
        for m in moderators:
            try:
                dest_domain = m.split('@', 1)[-1]

                db.insert('alias_moderators',
                          address=account,
                          moderator=m,
                          domain=domain,
                          dest_domain=dest_domain)
            except Exception as e:
                if e[0] == 1062 or 'duplicate' in repr(e):
                    # Duplicate record
                    pass
                else:
                    print "Error while migrating moderators of alias account %s: %s" % (m, repr(e))

    counter += 1

print "* DONE."
