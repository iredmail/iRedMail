-- \c vmail;

-- DROP column
ALTER TABLE mailbox DROP COLUMN local_part;

-- New SQL column
ALTER TABLE mailbox ADD COLUMN enableimaptls INT2 NOT NULL DEFAULT 1;
CREATE INDEX idx_mailbox_enableimaptls ON mailbox (enableimaptls);
ALTER TABLE mailbox ADD COLUMN enablepop3tls INT2 NOT NULL DEFAULT 1;
CREATE INDEX idx_mailbox_enablepop3tls ON mailbox (enablepop3tls);
ALTER TABLE mailbox ADD COLUMN enablesievetls INT2 NOT NULL DEFAULT 1;
CREATE INDEX idx_mailbox_enablesievetls ON mailbox (enablesievetls);

-- Rename table
ALTER TABLE alias_moderators RENAME TO moderators;

-- Column used to limit number of mailing lists a domain admin can create
ALTER TABLE domain ADD COLUMN maillists INT8 NOT NULL DEFAULT 0;

-- Column used to mark sql record is a mailing list
ALTER TABLE forwardings ADD COLUMN is_maillist INT2 NOT NULL DEFAULT 0;
CREATE INDEX idx_forwardings_is_maillist ON forwardings (is_maillist);

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
    created TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '1970-01-01 00:00:00',
    modified TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '1970-01-01 00:00:00',
    expired TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '9999-12-31 00:00:00',
    active INT2 NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX idx_maillists_address ON maillists (address);
CREATE INDEX idx_maillists_domain ON maillists (domain);
CREATE UNIQUE INDEX idx_maillists_mlid ON maillists (mlid);
CREATE INDEX idx_maillists_is_newsletter ON maillists (is_newsletter);
CREATE INDEX idx_maillists_active ON maillists (active);

GRANT SELECT ON maillists TO vmail;
GRANT SELECT ON maillists_id_seq TO vmail;
GRANT SELECT ON alias_moderators_id_seq TO vmail;
GRANT SELECT ON forwardings_id_seq TO vmail;

GRANT ALL ON maillists TO vmailadmin;
GRANT ALL ON maillists_id_seq TO vmailadmin;
GRANT ALL ON alias_moderators_id_seq TO vmailadmin;
GRANT ALL ON forwardings_id_seq TO vmailadmin;
