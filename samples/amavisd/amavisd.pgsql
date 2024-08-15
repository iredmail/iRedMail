-- MySQL template for Amavisd-new-2.7.0 and later releases.
-- Read-only part of the dataset (@lookup_sql_dsn)

-- used in @lookup_sql_dsn
-- local users
CREATE TABLE users (
  id         serial  PRIMARY KEY,  -- unique id
  priority   integer NOT NULL DEFAULT '7',  -- sort field, 0 is low prior.
  policy_id  integer NOT NULL DEFAULT '1' CHECK (policy_id >= 0),
                                         -- JOINs with policy.id
  email      bytea   NOT NULL UNIQUE,    -- email address, non-rfc2822-quoted
  fullname   varchar(255) DEFAULT NULL  -- not used by amavisd-new
  -- local   char(1)      -- Y/N  (optional field, see note further down)
);

-- used in @lookup_sql_dsn
-- any e-mail address (non- rfc2822-quoted), external or local,
-- used as senders in wblist
CREATE TABLE mailaddr (
  id         serial  PRIMARY KEY,
  priority   integer NOT NULL DEFAULT '7',  -- 0 is low priority
  email      bytea   NOT NULL UNIQUE
);

-- used in @lookup_sql_dsn
-- per-recipient whitelist and/or blacklist,
-- puts sender and recipient in relation wb  (white or blacklisted sender)
-- White/blacklist for inbound message
CREATE TABLE wblist (
  rid        integer NOT NULL CHECK (rid >= 0),  -- recipient: users.id
  sid        integer NOT NULL CHECK (sid >= 0),  -- sender: mailaddr.id
  wb         varchar(10) NOT NULL,  -- W or Y / B or N / space=neutral / score
  PRIMARY KEY (rid,sid)
);

-- White/blacklist for outbound message
-- Note: it's used by iRedAPD plugin `amavisd_wblist`, not by Amavisd.
CREATE TABLE outbound_wblist (
  rid        integer NOT NULL CHECK (rid >= 0),  -- recipient: mailaddr.id
  sid        integer NOT NULL CHECK (sid >= 0),  -- sender: users.id
  wb         varchar(10) NOT NULL,  -- W or Y / B or N / space=neutral / score
  PRIMARY KEY (rid,sid)
);

-- used in @lookup_sql_dsn
CREATE TABLE policy (
  id  serial PRIMARY KEY,           -- 'id' this is the _only_ required field
  policy_name      varchar(32),     -- not used by amavisd-new, a comment

  virus_lover           char(1) default NULL,     -- Y/N
  spam_lover            char(1) default NULL,     -- Y/N
  unchecked_lover       char(1) default NULL,     -- Y/N
  banned_files_lover    char(1) default NULL,     -- Y/N
  bad_header_lover      char(1) default NULL,     -- Y/N

  bypass_virus_checks   char(1) default NULL,     -- Y/N
  bypass_spam_checks    char(1) default NULL,     -- Y/N
  bypass_banned_checks  char(1) default NULL,     -- Y/N
  bypass_header_checks  char(1) default NULL,     -- Y/N

  virus_quarantine_to      varchar(64) default NULL,
  spam_quarantine_to       varchar(64) default NULL,
  banned_quarantine_to     varchar(64) default NULL,
  unchecked_quarantine_to  varchar(64) default NULL,
  bad_header_quarantine_to varchar(64) default NULL,
  clean_quarantine_to      varchar(64) default NULL,
  archive_quarantine_to    varchar(64) default NULL,

  spam_tag_level  real default NULL, -- higher score inserts spam info headers
  spam_tag2_level real default NULL, -- inserts 'declared spam' header fields
  spam_tag3_level real default NULL, -- inserts 'blatant spam' header fields
  spam_kill_level real default NULL, -- higher score triggers evasive actions
                                     -- e.g. reject/drop, quarantine, ...
                                     -- (subject to final_spam_destiny setting)
  spam_dsn_cutoff_level        real default NULL,
  spam_quarantine_cutoff_level real default NULL,

  addr_extension_virus      varchar(64) default NULL,
  addr_extension_spam       varchar(64) default NULL,
  addr_extension_banned     varchar(64) default NULL,
  addr_extension_bad_header varchar(64) default NULL,

  warnvirusrecip      char(1)     default NULL, -- Y/N
  warnbannedrecip     char(1)     default NULL, -- Y/N
  warnbadhrecip       char(1)     default NULL, -- Y/N
  newvirus_admin      varchar(64) default NULL,
  virus_admin         varchar(64) default NULL,
  banned_admin        varchar(64) default NULL,
  bad_header_admin    varchar(64) default NULL,
  spam_admin          varchar(64) default NULL,
  spam_subject_tag    varchar(64) default NULL,
  spam_subject_tag2   varchar(64) default NULL,
  spam_subject_tag3   varchar(64) default NULL,
  message_size_limit  integer     default NULL, -- max size in bytes, 0 disable
  banned_rulenames    varchar(64) default NULL, -- comma-separated list of ...
        -- names mapped through %banned_rules to actual banned_filename tables
  disclaimer_options  varchar(64) default NULL,
  forward_method      varchar(64) default NULL,
  sa_userconf         varchar(64) default NULL,
  sa_username         varchar(64) default NULL
);

-- Required by iRedMail
ALTER TABLE policy ALTER COLUMN policy_name TYPE varchar(255);
CREATE UNIQUE INDEX policy_idx_policy_name ON policy (policy_name);

-- Read-write part of the dataset (optional) - @storage_sql_dsn.
--   May reside in the same or in a separate database as lookups database;
--   REQUIRES SUPPORT FOR TRANSACTIONS; specified in @storage_sql_dsn
--
--  Please create additional indexes on keys when needed, or drop suggested
--  ones as appropriate to optimize queries needed by a management application.
--  See your database documentation for further optimization hints.

-- used in @storage_sql_dsn
-- provide unique id for each e-mail address, avoids storing copies
CREATE TABLE maddr (
    partition_tag integer   DEFAULT 0,   -- see $partition_tag
    id serial       PRIMARY KEY,
    -- full e-mail address
    email bytea         NOT NULL,   -- long-term unique mail id, dflt 12 ch
    -- mail address without address extension: user+abc@domain.com -> user@domain.com
    email_raw  VARCHAR(255) NOT NULL DEFAULT '',
    domain bytea        NOT NULL,   -- only domain part of the email address
                                        -- with subdomain fields in reverse
    CONSTRAINT part_email UNIQUE (partition_tag,email)
);

CREATE INDEX maddr_idx_email ON maddr (email);
CREATE INDEX maddr_idx_email_raw ON maddr (email_raw);
CREATE INDEX maddr_idx_domain ON maddr (domain);

-- Create trigger to save email address withou address extension
-- user+abc@domain.com -> user@domain.com
-- CREATE OR REPLACE FUNCTION strip_addr_extension(bytea, varchar, integer) RETURNS TRIGGER AS $$
CREATE OR REPLACE FUNCTION strip_addr_extension()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.email LIKE '%+%') THEN
        NEW.email_raw := split_part(convert_from(NEW.email, 'UTF8'), '+', 1) || '@' || split_part(convert_from(NEW.email, 'UTF8'), '@', 2);
    ELSE
        NEW.email_raw := convert_from(NEW.email, 'UTF8');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER maddr_email_raw
    BEFORE INSERT ON maddr
    FOR EACH ROW
    EXECUTE PROCEDURE strip_addr_extension();

-- used in @storage_sql_dsn
-- information pertaining to each processed message as a whole;
-- NOTE: records with NULL msgs.content should be ignored by utilities,
--   as such records correspond to messages just being processes, or were lost
CREATE TABLE msgs (
  partition_tag integer     DEFAULT 0,  -- see $partition_tag
  mail_id     bytea         NOT NULL,   -- long-term unique mail id, dflt 12 ch
  secret_id   bytea         DEFAULT '', -- authorizes release of mail_id, 12 ch
  am_id       varchar(20)   NOT NULL,   -- id used in the log
  time_num    integer NOT NULL CHECK (time_num >= 0),
                                        -- rx_time: seconds since Unix epoch
  time_iso    timestamp WITH TIME ZONE NOT NULL,-- rx_time: ISO8601 UTC ascii time
  sid         integer NOT NULL CHECK (sid >= 0), -- sender: maddr.id
  policy      varchar(255)  DEFAULT '', -- policy bank path (like macro %p)
  client_addr varchar(255)  DEFAULT '', -- SMTP client IP address (IPv4 or v6)
  size        integer NOT NULL CHECK (size >= 0), -- message size in bytes
  originating char(1) DEFAULT ' ' NOT NULL,  -- sender from inside or auth'd
  content     char(1),
    -- V: virus
    -- B: banned
    -- U: unchecked
    -- S: spam(kill)
    -- Y: spammy(tag2)
    -- M: bad-mime
    -- H: bad-header
    -- O: oversized
    -- O: mta-err
    -- C: clean
    -- is NULL on partially processed mail
    -- (prior to 2.7.0 the CC_SPAMMY was logged as 's', now 'Y' is used;
    -- to avoid a need for case-insenstivity in queries)
  quar_type  char(1),                   -- quarantined as: ' '/F/Z/B/Q/M/L
                                        --  none/file/zipfile/bsmtp/sql/
                                        --  /mailbox(smtp)/mailbox(lmtp)
  quar_loc   varchar(255)  DEFAULT '',  -- quarantine location (e.g. file)
  dsn_sent   char(1),                   -- was DSN sent? Y/N/q (q=quenched)
  spam_level real,                      -- SA spam level (no boosts)
  message_id varchar(255)  DEFAULT '',  -- mail Message-ID header field
  from_addr  bytea         DEFAULT '',  -- mail From header field, UTF8
  subject    bytea         DEFAULT '',  -- mail Subject header field, UTF8
  host       varchar(255)  NOT NULL,    -- hostname where amavisd is running
  PRIMARY KEY (partition_tag,mail_id)
--FOREIGN KEY (sid) REFERENCES maddr(id) ON DELETE RESTRICT
);
CREATE INDEX msgs_idx_sid      ON msgs (sid);
CREATE INDEX msgs_idx_mess_id  ON msgs (message_id); -- useful with pen pals
CREATE INDEX msgs_idx_time_iso ON msgs (time_iso);
CREATE INDEX msgs_idx_time_num ON msgs (time_num);   -- optional

CREATE INDEX msgs_idx_mail_id   ON msgs (mail_id);
CREATE INDEX msgs_idx_content   ON msgs (content);
CREATE INDEX msgs_idx_quar_type ON msgs (quar_type);
-- CREATE INDEX msgs_idx_content_time_num ON msgs (content, time_num);
CREATE INDEX msgs_idx_spam_level ON msgs (spam_level);

-- used in @storage_sql_dsn
-- per-recipient information related to each processed message;
-- NOTE: records in msgrcpt without corresponding msgs.mail_id record are
--  orphaned and should be ignored and eventually deleted by external utilities
CREATE TABLE msgrcpt (
  partition_tag integer DEFAULT 0,  -- see $partition_tag
  mail_id    bytea    NOT NULL,     -- (must allow duplicates)
  rseqnum    integer  DEFAULT 0   NOT NULL, -- recip's enumeration within msg
  rid        integer  NOT NULL,     -- recipient: maddr.id (duplicates allowed)
  is_local   char(1)  DEFAULT ' ' NOT NULL, -- recip is: Y=local, N=foreign
  content    char(1)  DEFAULT ' ' NOT NULL, -- content type V/B/U/S/Y/M/H/O/T/C
  ds         char(1)  NOT NULL,     -- delivery status: P/R/B/D/T
                                    -- pass/reject/bounce/discard/tempfail
  rs         char(1)  NOT NULL,     -- release status: initialized to ' '
  bl         char(1)  DEFAULT ' ',  -- sender blacklisted by this recip
  wl         char(1)  DEFAULT ' ',  -- sender whitelisted by this recip
  bspam_level real,                 -- per-recipient (total) spam level
  smtp_resp  varchar(255) DEFAULT '', -- SMTP response given to MTA
  PRIMARY KEY (partition_tag,mail_id,rseqnum)
--FOREIGN KEY (rid)     REFERENCES maddr(id)     ON DELETE RESTRICT,
--FOREIGN KEY (mail_id) REFERENCES msgs(mail_id) ON DELETE CASCADE
);
CREATE INDEX msgrcpt_idx_mail_id  ON msgrcpt (mail_id);
CREATE INDEX msgrcpt_idx_rid      ON msgrcpt (rid);

-- used in @storage_sql_dsn
-- mail quarantine in SQL, enabled by $*_quarantine_method='sql:'
-- NOTE: records in quarantine without corresponding msgs.mail_id record are
--  orphaned and should be ignored and eventually deleted by external utilities
CREATE TABLE quarantine (
  partition_tag integer  DEFAULT 0,      -- see $partition_tag
  mail_id    bytea   NOT NULL,           -- long-term unique mail id
  chunk_ind  integer NOT NULL CHECK (chunk_ind >= 0), -- chunk number, 1..
  mail_text  bytea   NOT NULL,           -- store mail as chunks of octects
  PRIMARY KEY (partition_tag,mail_id,chunk_ind)
--FOREIGN KEY (mail_id) REFERENCES msgs(mail_id) ON DELETE CASCADE
);

-- field msgrcpt.rs is primarily intended for use by quarantine management
-- software; the value assigned by amavisd is a space;
-- a short _preliminary_ list of possible values:
--   'V' => viewed (marked as read)
--   'R' => released (delivered) to this recipient
--   'p' => pending (a status given to messages when the admin received the
--                   request but not yet released; targeted to banned parts)
--   'D' => marked for deletion; a cleanup script may delete it
