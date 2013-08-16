-- References: http://wiki.policyd.org/

-- Priorities (Lower integer has higher priority):
--  6 Whitelist 
--  7 No greylisting
--  8 Blacklist

-- Cluebringer default priorities:
--  0 Default
--  10 Default Inbound
--  10 Default Outbound

-- ------------------------------
-- Whitelists (priority=6)
-- ------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('whitelisted_senders', 6, 0, 'Whitelisted senders');
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('whitelisted_domains', 6, 0, 'Whitelisted domains');
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('whitelisted_ips', 6, 0, 'Whitelisted IP addresses');

INSERT INTO policy_groups (Name, Disabled) VALUES ('whitelisted_senders', 0);
INSERT INTO policy_groups (Name, Disabled) VALUES ('whitelisted_domains', 0);
INSERT INTO policy_groups (Name, Disabled) VALUES ('whitelisted_ips', 0);

INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%internal_domains', 0
    FROM policies WHERE name='whitelisted_senders' LIMIT 1;
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%internal_domains', 0
    FROM policies WHERE name='whitelisted_domains' LIMIT 1;
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%internal_domains', 0
    FROM policies WHERE name='whitelisted_ips' LIMIT 1;

-- Add access_control record to bypass whitelisted senders
INSERT INTO access_control (PolicyID, Name, Verdict)
    SELECT id, 'bypass_whitelisted_senders', 'OK'
    FROM policies WHERE name='whitelisted_senders' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict)
    SELECT id, 'bypass_whitelisted_domains', 'OK'
    FROM policies WHERE name='whitelisted_domains' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict)
    SELECT id, 'bypass_whitelisted_ips', 'OK'
    FROM policies WHERE name='whitelisted_ips' LIMIT 1;

-- Sample: Add whitelisted sender, domain, IP
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, 'user@domain.com', 0 FROM policy_groups WHERE name='whitelisted_senders' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '@domain.com', 0 FROM policy_groups WHERE name='whitelisted_domains' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '123.123.123.123', 0 FROM policy_groups WHERE name='whitelisted_ips' LIMIT 1;

-- ------------------------------
-- Blacklist (priority=8)
-- ------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description) 
    VALUES ('blacklisted_senders', 8, 0, 'Blacklisted senders');
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('blacklisted_domains', 8, 0, 'Blacklisted domains');
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('blacklisted_ips', 8, 0, 'Blacklisted IP addresses');

INSERT INTO policy_groups (Name, Disabled) VALUES ('blacklisted_senders', 0);
INSERT INTO policy_groups (Name, Disabled) VALUES ('blacklisted_domains', 0);
INSERT INTO policy_groups (Name, Disabled) VALUES ('blacklisted_ips', 0);

INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%internal_domains', 0
    FROM policies WHERE name='blacklisted_senders' LIMIT 1;
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%internal_domains', 0
    FROM policies WHERE name='blacklisted_domains' LIMIT 1;
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%internal_domains', 0
    FROM policies WHERE name='blacklisted_ips' LIMIT 1;

-- Add access control to reject whitelisted senders.
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted_senders', 'REJECT', 'Blacklisted sender'
    FROM policies WHERE name='blacklisted_senders' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted_domains', 'REJECT', 'Blacklisted domain'
    FROM policies WHERE name='blacklisted_domains' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted_ips', 'REJECT', 'Blacklisted IP'
    FROM policies WHERE name='blacklisted_ips' LIMIT 1;

-- Sample: Add blacklisted sender, domain, IP
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, 'user@domain.com', 0 FROM policy_groups WHERE name='blacklisted_senders' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '@domain.com', 0 FROM policy_groups WHERE name='blacklisted_domains' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '123.123.123.123', 0 FROM policy_groups WHERE name='blacklisted_ips' LIMIT 1;

-- ------------------------------------
-- Per-domain and per-user greylisting
-- ------------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('no_greylisting', 7, 0, 'Disable grelisting for certain domain or users');
INSERT INTO policy_groups (Name, Disabled) VALUES ('no_greylisting', 0);
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%no_greylisting', 0
    FROM policies WHERE name='no_greylisting' LIMIT 1;
-- Disable greylisting for %no_greylisting
INSERT INTO greylisting (PolicyID, Name, UseGreylisting, Track, UseAutoWhitelist, UseAutoBlacklist, Disabled)
    SELECT id, 'no_greylisting', 0, 'SenderIP:/32', 0, 0, 0
    FROM policies WHERE name='no_greylisting' LIMIT 1;

-- Disable greylisting for certain domain/users:
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '@domain.com', 0 FROM policy_groups WHERE name='no_greylisting' LIMIT 1;

-- TODO add indexes for columns used in Cluebringer core
-- Add necessary indexes with index name
CREATE INDEX policies_disabled on policies (disabled);
CREATE INDEX policies_name ON policies (name);
CREATE INDEX policy_groups_name ON policy_groups (name);
CREATE INDEX policy_group_members_member ON policy_group_members (member);
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

