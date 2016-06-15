USE PH_VMAIL_DB_NAME;

-- Add your first domain
INSERT INTO domain (domain, transport, settings, created)
            VALUES ('PH_FIRST_DOMAIN', 'PH_TRANSPORT', 'default_user_quota:1024;', NOW());

-- Add your first normal user
INSERT INTO mailbox (username,
                     password,
                     name,
                     maildir,
                     quota,
                     domain,
                     isadmin,
                     isglobaladmin,
                     created)
             VALUES ('PH_FIRST_USER@PH_FIRST_DOMAIN',
                     'PH_FIRST_USER_PASSWD',
                     'PH_FIRST_USER',
                     'PH_FIRST_USER_MAILDIR_HASH_PART',
                     1024,
                     'PH_FIRST_DOMAIN',
                     1,
                     1,
                     NOW());

INSERT INTO alias (address, goto, domain, created)
           VALUES ('PH_FIRST_USER@PH_FIRST_DOMAIN', 'PH_FIRST_USER@PH_FIRST_DOMAIN', 'PH_FIRST_DOMAIN', NOW());

-- Mark first mail user as global admin
INSERT INTO domain_admins (username, domain, created)
                   VALUES ('PH_DOMAIN_ADMIN_NAME@PH_FIRST_DOMAIN', 'ALL', NOW());
