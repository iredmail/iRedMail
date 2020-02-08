-- ---------------------------------------------------------------------
-- This file is part of iRedMail, which is an open source mail server
-- solution for Red Hat(R) Enterprise Linux, CentOS, Debian and Ubuntu.
--
-- iRedMail is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- iRedMail is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with iRedMail.  If not, see <http://www.gnu.org/licenses/>.
-- ---------------------------------------------------------------------

-- Connect as vmailadmin
-- \c PH_VMAIL_DB_NAME PH_VMAIL_DB_ADMIN_USER;

-- Required by PostgreSQL 8.x (RHEL/CentOS 6)
-- CREATE LANGUAGE plpgsql;

-- Used to store domain admin accounts
CREATE TABLE admin (
    username VARCHAR(255) NOT NULL DEFAULT '',
    password VARCHAR(255) NOT NULL DEFAULT '',
    name VARCHAR(255) NOT NULL DEFAULT '',
    language VARCHAR(5) NOT NULL DEFAULT '',
    passwordlastchange TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    -- Store per-admin settings. Used in iRedAdmin-Pro.
    settings TEXT NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (username)
);
CREATE INDEX idx_admin_passwordlastchange ON admin (passwordlastchange);
CREATE INDEX idx_admin_expired ON admin (expired);
CREATE INDEX idx_admin_active ON admin (active);

-- Used to store mail alias accounts
CREATE TABLE alias (
    address VARCHAR(255) NOT NULL DEFAULT '',
    name VARCHAR(255) NOT NULL DEFAULT '',
    accesspolicy VARCHAR(30) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (address)
);
CREATE INDEX idx_alias_domain ON alias (domain);
CREATE INDEX idx_alias_expired ON alias (expired);
CREATE INDEX idx_alias_active ON alias (active);

-- Alias and mailing list moderators.
CREATE TABLE moderators (
    id SERIAL PRIMARY KEY,
    address VARCHAR(255) NOT NULL DEFAULT '',
    moderator VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    dest_domain VARCHAR(255) NOT NULL DEFAULT ''
);

CREATE INDEX idx_moderators_address ON moderators (address);
CREATE INDEX idx_moderators_moderator ON moderators (moderator);
CREATE UNIQUE INDEX idx_moderators_address_moderator ON moderators (address, moderator);
CREATE INDEX idx_moderators_domain ON moderators (domain);
CREATE INDEX idx_moderators_dest_domain ON moderators (dest_domain);

-- Forwardings. it contains
--  - members of mail alias account
--  - per-account alias addresses
--  - per-user mail forwarding addresses
CREATE TABLE forwardings (
    id SERIAL PRIMARY KEY,
    address VARCHAR(255) NOT NULL DEFAULT '',
    forwarding VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    dest_domain VARCHAR(255) NOT NULL DEFAULT '',
    -- defines whether it's a (mlmmj) mailing list account. 0=no, 1=yes.
    is_maillist INT2 NOT NULL DEFAULT 0,
    -- defines whether it's a standalone mail alias account. 0=no, 1=yes.
    is_list INT2 NOT NULL DEFAULT 0,
    -- defines whether it's a mail forwarding address of mail user. 0=no, 1=yes.
    is_forwarding INT2 NOT NULL DEFAULT 0,
    -- defines whether it's a per-account alias address. 0=no, 1=yes.
    is_alias INT2 NOT NULL DEFAULT 0,
    active INT2 NOT NULL DEFAULT 1
);
CREATE INDEX idx_forwardings_address ON forwardings (address);
CREATE INDEX idx_forwardings_forwarding ON forwardings (forwarding);
CREATE UNIQUE INDEX idx_forwardings_address_forwarding ON forwardings (address, forwarding);
CREATE INDEX idx_forwardings_domain ON forwardings (domain);
CREATE INDEX idx_forwardings_dest_domain ON forwardings (dest_domain);
CREATE INDEX idx_forwardings_is_maillist ON forwardings (is_maillist);
CREATE INDEX idx_forwardings_is_list ON forwardings (is_list);
CREATE INDEX idx_forwardings_is_forwarding ON forwardings (is_forwarding);
CREATE INDEX idx_forwardings_is_alias ON forwardings (is_alias);

-- Used to store virtual mail domains
CREATE TABLE domain (
    -- mail domain name. e.g. iredmail.org.
    domain VARCHAR(255) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    -- Disclaimer text. Used by Amavisd + AlterMIME.
    disclaimer TEXT NOT NULL DEFAULT '',
    -- Max alias accounts in this domain. e.g. 10.
    aliases INT8 NOT NULL DEFAULT 0,
    -- Max mail accounts in this domain. e.g. 100.
    mailboxes INT8 NOT NULL DEFAULT 0,
    -- Max mailing lists in this domain. e.g. 100.
    maillists INT8 NOT NULL DEFAULT 0,
    -- Max mailbox quota in this domain. e.g. 1073741824 (1GB).
    maxquota INT8 NOT NULL DEFAULT 0,
    -- Not used. Historical.
    quota INT8 NOT NULL DEFAULT 0,
    -- Per-domain transport. e.g. dovecot, smtp:[192.168.1.1]:25
    transport VARCHAR(255) NOT NULL DEFAULT 'dovecot',
    -- Store per-domain settings. Used in iRedAdmin-Pro.
    settings TEXT NOT NULL DEFAULT '',
    backupmx INT2 NOT NULL DEFAULT 0,
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (domain)
);
CREATE INDEX idx_domain_backupmx ON domain (backupmx);
CREATE INDEX idx_domain_expired ON domain (expired);
CREATE INDEX idx_domain_active ON domain (active);

-- Used to store alias domains
CREATE TABLE alias_domain (
    alias_domain VARCHAR(255) NOT NULL,
    target_domain VARCHAR(255) NOT NULL,
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (alias_domain)
);
CREATE INDEX idx_alias_domain_target_domain ON alias_domain (target_domain);
CREATE INDEX idx_alias_domain_active ON alias_domain (active);

-- Used to store domain <=> admin relationship
CREATE TABLE domain_admins (
    username VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (username,domain)
);
CREATE INDEX idx_domain_admins_username ON domain_admins (username);
CREATE INDEX idx_domain_admins_domain ON domain_admins (domain);
CREATE INDEX idx_domain_admins_active ON domain_admins (active);

-- Used to store virtual mail accounts
CREATE TABLE mailbox (
    username VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL DEFAULT '',
    name VARCHAR(255) NOT NULL DEFAULT '',
    language VARCHAR(5) NOT NULL DEFAULT '',
    -- Mailbox format.
    -- All formats supported by Dovecot are ok. e.g. maildir, mdbox.
    -- FYI: https://wiki2.dovecot.org/MailboxFormat
    mailboxformat VARCHAR(50) NOT NULL DEFAULT 'maildir',
    -- mailbox folder name can be any folder name supported by Linux/BSD file
    -- system.
    mailboxfolder VARCHAR(50) NOT NULL DEFAULT 'Maildir',
    storagebasedirectory VARCHAR(255) NOT NULL DEFAULT '',
    storagenode VARCHAR(255) NOT NULL DEFAULT '',
    maildir VARCHAR(255) NOT NULL DEFAULT '',
    quota INT8 NOT NULL DEFAULT 0, -- Total mail quota size
    domain VARCHAR(255) NOT NULL DEFAULT '',
    transport VARCHAR(255) NOT NULL DEFAULT '',
    department VARCHAR(255) NOT NULL DEFAULT '',
    rank VARCHAR(255) NOT NULL DEFAULT 'normal',
    employeeid VARCHAR(255) DEFAULT '',
    isadmin INT2 NOT NULL DEFAULT 0,
    isglobaladmin INT2 NOT NULL DEFAULT 0,
    enablesmtp INT2 NOT NULL DEFAULT 1,
    enablesmtpsecured INT2 NOT NULL DEFAULT 1,
    enablepop3 INT2 NOT NULL DEFAULT 1,
    enablepop3secured INT2 NOT NULL DEFAULT 1,
    enablepop3tls INT2 NOT NULL DEFAULT 1,
    enableimap INT2 NOT NULL DEFAULT 1,
    enableimapsecured INT2 NOT NULL DEFAULT 1,
    enableimaptls INT2 NOT NULL DEFAULT 1,
    enabledeliver INT2 NOT NULL DEFAULT 1,
    enablelda INT2 NOT NULL DEFAULT 1,
    enablemanagesieve INT2 NOT NULL DEFAULT 1,
    enablemanagesievesecured INT2 NOT NULL DEFAULT 1,
    enablesieve INT2 NOT NULL DEFAULT 1,
    enablesievesecured INT2 NOT NULL DEFAULT 1,
    enablesievetls INT2 NOT NULL DEFAULT 1,
    enableinternal INT2 NOT NULL DEFAULT 1,
    enabledoveadm INT2 NOT NULL DEFAULT 1,
    "enablelib-storage" INT2 NOT NULL DEFAULT 1,
    "enablequota-status" INT2 NOT NULL DEFAULT 1,
    "enableindexer-worker" INT2 NOT NULL DEFAULT 1,
    enablelmtp INT2 NOT NULL DEFAULT 1,
    enabledsync INT2 NOT NULL DEFAULT 1,
    enablesogo INT2 NOT NULL DEFAULT 1,
    -- Must be set to NULL if it's not restricted.
    allow_nets TEXT DEFAULT NULL,
    lastlogindate TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    lastloginipv4 INET NOT NULL DEFAULT '0.0.0.0',
    lastloginprotocol CHAR(255) NOT NULL DEFAULT '',
    disclaimer TEXT NOT NULL DEFAULT '',
    -- Below 4 columns are deprecated and will be removed in future release.
    -- Don't use them.
    allowedsenders TEXT NOT NULL DEFAULT '',
    rejectedsenders TEXT NOT NULL DEFAULT '',
    allowedrecipients TEXT NOT NULL DEFAULT '',
    rejectedrecipients TEXT NOT NULL DEFAULT '',
    -- Store per-user settings. Used in iRedAdmin-Pro.
    settings TEXT NOT NULL DEFAULT '',
    passwordlastchange TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (username)
);
CREATE INDEX idx_mailbox_domain ON mailbox (domain);
CREATE INDEX idx_mailbox_department ON mailbox (department);
CREATE INDEX idx_mailbox_employeeid ON mailbox (employeeid);
CREATE INDEX idx_mailbox_isadmin ON mailbox (isadmin);
CREATE INDEX idx_mailbox_isglobaladmin ON mailbox (isglobaladmin);
CREATE INDEX idx_mailbox_enablesmtp ON mailbox (enablesmtp);
CREATE INDEX idx_mailbox_enablesmtpsecured ON mailbox (enablesmtpsecured);
CREATE INDEX idx_mailbox_enablepop3 ON mailbox (enablepop3);
CREATE INDEX idx_mailbox_enablepop3secured ON mailbox (enablepop3secured);
CREATE INDEX idx_mailbox_enableimap ON mailbox (enableimap);
CREATE INDEX idx_mailbox_enableimapsecured ON mailbox (enableimapsecured);
CREATE INDEX idx_mailbox_enableimaptls ON mailbox (enableimaptls);
CREATE INDEX idx_mailbox_enablepop3tls ON mailbox (enablepop3tls);
CREATE INDEX idx_mailbox_enablesievetls ON mailbox (enablesievetls);
CREATE INDEX idx_mailbox_enabledeliver ON mailbox (enabledeliver);
CREATE INDEX idx_mailbox_enablelda ON mailbox (enablelda);
CREATE INDEX idx_mailbox_enablemanagesieve ON mailbox (enablemanagesieve);
CREATE INDEX idx_mailbox_enablemanagesievesecured ON mailbox (enablemanagesievesecured);
CREATE INDEX idx_mailbox_enablesieve ON mailbox (enablesieve);
CREATE INDEX idx_mailbox_enablesievesecured ON mailbox (enablesievesecured);
CREATE INDEX idx_mailbox_enablelmtp ON mailbox (enablelmtp);
CREATE INDEX idx_mailbox_enabledsync ON mailbox (enabledsync);
CREATE INDEX idx_mailbox_enableinternal ON mailbox (enableinternal);
CREATE INDEX idx_mailbox_enabledoveadm ON mailbox (enabledoveadm);
CREATE INDEX idx_mailbox_enablelib_storage ON mailbox ("enablelib-storage");
CREATE INDEX idx_mailbox_enablequota_status ON mailbox ("enablequota-status");
CREATE INDEX idx_mailbox_enableindexer_worker ON mailbox ("enableindexer-worker");
CREATE INDEX idx_mailbox_enablesogo ON mailbox (enablesogo);
CREATE INDEX idx_mailbox_passwordlastchange ON mailbox (passwordlastchange);
CREATE INDEX idx_mailbox_expired ON mailbox (expired);
CREATE INDEX idx_mailbox_active ON mailbox (active);


CREATE TABLE maillists (
    id SERIAL PRIMARY KEY,
    address VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    -- Per mailing list transport. for example: 'mlmmj:example.com/listname'.
    transport VARCHAR(255) NOT NULL DEFAULT '',
    accesspolicy VARCHAR(30) NOT NULL DEFAULT '',
    maxmsgsize INT8 NOT NULL DEFAULT 0,
    -- name of the mailing list
    name VARCHAR(255) NOT NULL DEFAULT '',
    -- short introduction of the mailing list on subscription page
    description TEXT,
    -- a server-wide unique id (a 36-characters string) for each mailing list
    mlid VARCHAR(36) NOT NULL DEFAULT '',
    -- control whether newsletter-style subscription from website is enabled
    -- 1 -> enabled, 0 -> disabled
    is_newsletter INT2 NOT NULL DEFAULT 0,
    settings TEXT,
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX idx_maillists_address ON maillists (address);
CREATE INDEX idx_maillists_domain ON maillists (domain);
CREATE UNIQUE INDEX idx_maillists_mlid ON maillists (mlid);
CREATE INDEX idx_maillists_is_newsletter ON maillists (is_newsletter);
CREATE INDEX idx_maillists_active ON maillists (active);

CREATE TABLE sender_bcc_domain (
    domain VARCHAR(255) NOT NULL DEFAULT '',
    bcc_address VARCHAR(255) NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (domain)
);
CREATE INDEX idx_sender_bcc_domain_bcc_address ON sender_bcc_domain (bcc_address);
CREATE INDEX idx_sender_bcc_domain_expired ON sender_bcc_domain (expired);
CREATE INDEX idx_sender_bcc_domain_active ON sender_bcc_domain (active);

CREATE TABLE sender_bcc_user (
    username VARCHAR(255) NOT NULL DEFAULT '',
    bcc_address VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (username)
);
CREATE INDEX idx_sender_bcc_user_bcc_address ON sender_bcc_user (bcc_address);
CREATE INDEX idx_sender_bcc_user_domain ON sender_bcc_user (domain);
CREATE INDEX idx_sender_bcc_user_expired ON sender_bcc_user (expired);
CREATE INDEX idx_sender_bcc_user_active ON sender_bcc_user (active);

--
-- Table structure for table recipient_bcc_domain
--
CREATE TABLE recipient_bcc_domain (
    domain VARCHAR(255) NOT NULL DEFAULT '',
    bcc_address VARCHAR(255) NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (domain)
);
CREATE INDEX idx_recipient_bcc_domain_bcc_address ON recipient_bcc_domain (bcc_address);
CREATE INDEX idx_recipient_bcc_domain_expired ON recipient_bcc_domain (expired);
CREATE INDEX idx_recipient_bcc_domain_active ON recipient_bcc_domain (active);

--
-- Table structure for table recipient_bcc_user
--
CREATE TABLE recipient_bcc_user (
    username VARCHAR(255) NOT NULL DEFAULT '',
    bcc_address VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()::TIMESTAMP WITHOUT TIME ZONE,
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 01:01:01',
    active INT2 NOT NULL DEFAULT 1,
    PRIMARY KEY (username)
);
CREATE INDEX idx_recipient_bcc_user_bcc_address ON recipient_bcc_user (bcc_address);
CREATE INDEX idx_recipient_bcc_user_expired ON recipient_bcc_user (expired);
CREATE INDEX idx_recipient_bcc_user_active ON recipient_bcc_user (active);

-- Sender dependent relayhost.
--  - per-user: account='user@domain.com'
--  - per-domain: account='@domain.com'
-- References:
--  - http://www.postfix.org/postconf.5.html#sender_dependent_relayhost_maps
--  - http://www.postfix.org/transport.5.html
CREATE TABLE sender_relayhost (
    id SERIAL PRIMARY KEY,
    account VARCHAR(255) NOT NULL DEFAULT '',
    relayhost VARCHAR(255) NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX idx_sender_relayhost_account ON sender_relayhost (account);

-- Used to store basic info of deleted mailboxes.
CREATE TABLE deleted_mailboxes (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Email address of deleted user
    username VARCHAR(255) NOT NULL DEFAULT '',

    -- Domain part of username
    domain VARCHAR(255) NOT NULL DEFAULT '',

    -- Absolute path of user's mailbox
    maildir VARCHAR(255) NOT NULL DEFAULT '',

    -- Deleted by which domain admin
    admin VARCHAR(255) NOT NULL DEFAULT '',

    -- The time scheduled to delete this mailbox.
    -- NOTE: it requires cron job + script to actually delete the mailbox.
    delete_date DATE DEFAULT NULL
);

CREATE INDEX idx_deleted_mailboxes_timestamp ON deleted_mailboxes (timestamp);
CREATE INDEX idx_deleted_mailboxes_username ON deleted_mailboxes (username);
CREATE INDEX idx_deleted_mailboxes_domain ON deleted_mailboxes (domain);
CREATE INDEX idx_deleted_mailboxes_admin ON deleted_mailboxes (admin);
CREATE INDEX idx_delete_date ON deleted_mailboxes (delete_date);

--
-- IMAP shared folders. User 'from_user' shares folders to user 'to_user'.
-- WARNING: Works only with Dovecot 1.2+.
--
CREATE TABLE share_folder (
    from_user VARCHAR(255) NOT NULL,
    to_user VARCHAR(255) NOT NULL,
    dummy CHAR(1),
    PRIMARY KEY (from_user, to_user)
);
CREATE INDEX idx_share_folder_from_user ON share_folder (from_user);
CREATE INDEX idx_share_folder_to_user ON share_folder (to_user);

CREATE TABLE anyone_shares (
    from_user VARCHAR(255) NOT NULL,
    dummy CHAR(1),
    PRIMARY KEY (from_user)
);

-- used_quota
-- Used to store realtime mailbox quota in Dovecot.
-- WARNING: Works only with Dovecot 1.2+.
--
-- Note: Don't touch this table, it will be updated by Dovecot automatically.
CREATE TABLE used_quota (
    username VARCHAR(255) NOT NULL,
    bytes INT8 NOT NULL DEFAULT 0,
    messages INT8 NOT NULL DEFAULT 0,
    domain VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (username)
);
CREATE INDEX idx_used_quota_domain ON used_quota (domain);

-- Trigger required by quota dict
CREATE OR REPLACE FUNCTION merge_quota() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.messages < 0 OR NEW.messages IS NULL THEN
        -- ugly kludge: we came here from this function, really do try to insert
        IF NEW.messages IS NULL THEN
            NEW.messages = 0;
        ELSE
            NEW.messages = -NEW.messages;
        END IF;
        return NEW;
    END IF;

    LOOP
        UPDATE used_quota
        SET bytes = bytes + NEW.bytes, messages = messages + NEW.messages, domain=split_part(NEW.username, '@', 2)
        WHERE username = NEW.username;
        IF found THEN
            RETURN NULL;
        END IF;

        BEGIN
            IF NEW.messages = 0 THEN
                INSERT INTO used_quota (bytes, messages, username, domain)
                VALUES (NEW.bytes, NULL, NEW.username, split_part(NEW.username, '@', 2));
            ELSE
                INSERT INTO used_quota (bytes, messages, username, domain)
                VALUES (NEW.bytes, -NEW.messages, NEW.username, split_part(NEW.username, '@', 2));
            END IF;
            return NULL;
            EXCEPTION WHEN unique_violation THEN
            -- someone just inserted the record, update it
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mergequota
    BEFORE INSERT ON used_quota FOR EACH ROW
    EXECUTE PROCEDURE merge_quota();
