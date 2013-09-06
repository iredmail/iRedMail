-- Reference: http://wiki.policyd.org/

-- Priorities (Lower integer has higher priority):
--  priority=6  server-wide Whitelist
--  priority=7  server-wide Blacklist
--  priority=20 No greylisting. Works for both per-domain and per-user account.

-- Cluebringer default priorities:
--  priority=0  Default
--  priority=10 Default Inbound
--  priority=10 Default Outbound

-- Alter tables to store UTF-8 characters as comment
ALTER TABLE access_control MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE amavis_rules MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE checkhelo MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE checkhelo_blacklist MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE checkhelo_whitelist MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE checkspf MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE greylisting MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE greylisting_autoblacklist MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE greylisting_autowhitelist MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE greylisting_whitelist MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE policies MODIFY COLUMN Description VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE policy_group_members MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE policy_groups MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE policy_members MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE quotas MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;
ALTER TABLE quotas_limits MODIFY COLUMN Comment VARCHAR(1024) CHARACTER SET utf8;

-- Add new column: policy_group_members.Type.
-- It's used to identify record type/kind in iRedAdmin-Pro, for easier
-- management of white/blacklists.
--
-- Samples:
--   - Type=ip: value of `Member` is an IP address or CIDR range
--   - Type=email: a valid full email address
--   - Type=domain: a valid domain name
--
-- We can use multiple policies for different types, but it bringer more SQL
-- queries for each policy request, this is not a good idea for performance
-- since Cluebringer is used to process every in/out SMTP session.
ALTER TABLE policy_group_members ADD COLUMN Type VARCHAR(10) NOT NULL DEFAULT '';
CREATE INDEX policy_group_members_type ON policy_group_members (Type);
CREATE INDEX policy_group_members_policygroupid_type ON policy_group_members (PolicyGroupID, Type);

-- ------------------------------
-- Whitelists (priority=6)
-- ------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('whitelists', 6, 0, 'Whitelisted sender, domain, IP');

INSERT INTO policy_groups (Name, Disabled) VALUES ('whitelists', 0);

INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '%whitelists', '%internal_domains', 0
    FROM policies WHERE name='whitelists' LIMIT 1;

-- Add access_control record to bypass whitelisted senders
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'bypass_whitelisted', 'OK', 'Whitelisted'
    FROM policies WHERE name='whitelists' LIMIT 1;

-- Samples: Add whitelisted sender, domain, IP
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, 'user@domain.com', 0, 'email' FROM policy_groups
--    WHERE name='whitelisted_senders' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '@domain.com', 0, 'domain' FROM policy_groups
--    WHERE name='whitelisted_domains' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '123.123.123.123', 0, 'ip' FROM policy_groups
--    WHERE name='whitelisted_ips' LIMIT 1;

-- ------------------------------
-- Blacklist (priority=8)
-- ------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description) 
    VALUES ('blacklists', 8, 0, 'Blacklisted sender, domain, IP');

INSERT INTO policy_groups (Name, Disabled) VALUES ('blacklists', 0);

INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '%blacklists', '%internal_domains', 0
    FROM policies WHERE name='blacklists' LIMIT 1;

-- Add access control to reject whitelisted senders.
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted', 'REJECT', 'Blacklisted'
    FROM policies WHERE name='blacklists' LIMIT 1;

-- Samples: Add blacklisted sender, domain, IP
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, 'user@domain.com', 0, 'email' FROM policy_groups
--    WHERE name='blacklists' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '@domain.com', 0, 'domain' FROM policy_groups
--    WHERE name='blacklists' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '123.123.123.123', 0, 'ip' FROM policy_groups
--    WHERE name='blacklists' LIMIT 1;

-- ------------------------------------
-- Per-domain and per-user greylisting
-- ------------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('no_greylisting', 20, 0, 'Disable grelisting for certain domain and users');
INSERT INTO policy_groups (Name, Disabled) VALUES ('no_greylisting', 0);
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%no_greylisting', 0
    FROM policies WHERE name='no_greylisting' LIMIT 1;
-- Disable greylisting for %no_greylisting
INSERT INTO greylisting (PolicyID, Name, UseGreylisting, Track, UseAutoWhitelist, AutoWhitelistCount, AutoWhitelistPercentage, UseAutoBlacklist, AutoBlacklistCount, AutoBlacklistPercentage, Disabled)
    SELECT id, 'no_greylisting', 0, 'SenderIP:/32', 0, 0, 0, 0, 0, 0, 0
    FROM policies WHERE name='no_greylisting' LIMIT 1;

-- Sample: Disable greylisting for certain domain/users:
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '@domain.com', 0 FROM policy_groups WHERE name='no_greylisting' LIMIT 1;

-- ---------------
-- INDEXES
-- ---------------
-- Add indexes for columns used in Cluebringer modules
--
CREATE INDEX policies_disabled ON policies (disabled);
-- Used in module: access_control
CREATE INDEX access_control_policyid_disabled ON access_control (policyid, disabled);
-- Used in module: checkhelo
CREATE INDEX checkhelo_policyid_disabled ON checkhelo (policyid, disabled);
CREATE INDEX checkhelo_whitelist_disabled ON checkhelo_whitelist (disabled);
-- Used in module: greylisting
CREATE INDEX greylisting_policyid_disabled ON greylisting (policyid, disabled);
CREATE INDEX greylisting_whitelist_disabled ON greylisting_whitelist (disabled);
CREATE INDEX greylisting_tracking_trackkey_firstseen ON greylisting_tracking (trackkey, firstseen);
CREATE INDEX greylisting_tracking_trackkey_firstseen_count ON greylisting_tracking (trackkey, firstseen, count);
-- Used in module: quotas
CREATE INDEX quotas_policyid_disabled ON quotas (policyid, disabled);
-- Used in module: accounting_tracking. Available in cluebringer-2.1.x.
-- CREATE INDEX accounting_policyid_disabled ON accounting (policyid, disabled);
-- CREATE INDEX accounting_tracking_accountingid_trackkey_periodkey ON accounting_tracking (accountingid, trackkey, periodkey);

--
-- Add indexes for columns required by web interface
--
CREATE UNIQUE INDEX policies_name ON policies (name);
CREATE UNIQUE INDEX policy_groups_name ON policy_groups (name);
CREATE INDEX policy_group_members_member ON policy_group_members (member);
-- Unique index to avoid duplicate records
CREATE UNIQUE INDEX policy_group_members_policygroupid_member ON policy_group_members (policygroupid, member);

-- CREATE INDEX policy_members_source ON policy_members (source);
-- CREATE INDEX policy_members_destination ON policy_members (destination);

-- -------------------------------
-- TODO Per-domain white/blacklist
-- -------------------------------
-- Add policy: domain_blacklist_domain.com (prefix 'domain_blacklist_')
-- Add policy_group: domain_domain.com (prefix 'domain_' + domain name)
-- Add policy_members: !internal_ips,!internal_domains -> domain_domain.com
-- Add policy_members: !internal_ips,!internal_domains -> domain_[alias_domain]
-- Add policy_group_members: domain_domain.com -> primary domain and all alias domains

