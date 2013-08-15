-- References: http://wiki.policyd.org/

-- Priorities (Lower integer has higher priority):
--  4 No greylisting
--  6 Whitelist 
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
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'whitelisted_senders', 'OK', 'Whitelisted sender'
    FROM policies WHERE name='whitelisted_senders' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'whitelisted_domains', 'OK', 'Whitelisted domain'
    FROM policies WHERE name='whitelisted_domains' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'whitelisted_ips', 'OK', 'Whitelisted IP'
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

-- Add access_control record to bypass whitelisted senders
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'blacklisted_senders', 'OK', 'Blacklisted'
    FROM policies WHERE name='blacklisted_senders' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'blacklisted_domains', 'OK', 'Blacklisted'
    FROM policies WHERE name='blacklisted_domains' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'blacklisted_ips', 'OK', 'Blacklisted'
    FROM policies WHERE name='blacklisted_ips' LIMIT 1;

-- Add access control to reject whitelisted senders.
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted_senders', 'REJECT', 'Blacklisted'
    FROM policies WHERE name='blacklisted_senders' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted_domains', 'REJECT', 'Blacklisted'
    FROM policies WHERE name='blacklisted_domains' LIMIT 1;
INSERT INTO access_control (PolicyID, Name, Verdict, Data)
    SELECT id, 'reject_blacklisted_ips', 'REJECT', 'Blacklisted'
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
    VALUES ('no_greylisting', 4, 0, 'Disable grelisting for certain domain or users');
INSERT INTO policy_groups (Name, Disabled) VALUES ('no_greylisting', 0);
INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
    SELECT id, '!%internal_ips,!%internal_domains', '%no_greylisting', 0
    FROM policies WHERE name='no_greylisting' LIMIT 1;
-- Disable greylisting for %no_greylisting
INSERT INTO greylisting (PolicyID, Name, UseGreylisting, UseAutoWhitelist, UseAutoBlacklist, Disabled)
    SELECT id, 'no_greylisting', 0, 0, 0, 0
    FROM policies WHERE name='no_greylisting' LIMIT 1;

-- Disable greylisting for certain domain/users:
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '@domain.com', 0 FROM policy_groups WHERE name='no_greylisting' LIMIT 1;

-- TODO Add necessary indexes with index name
-- policies.name
-- policy_group_members.member
-- policy_members.source, policy_members.destination

-- -------------------------------
-- TODO Per-domain white/blacklist
-- -------------------------------
-- Add policy: domain_blacklist_domain.com (prefix 'domain_blacklist_')
-- Add policy_group: domain_domain.com (prefix 'domain_' + domain name)
-- Add policy_members: !internal_ips,!internal_domains -> domain_domain.com
-- Add policy_members: !internal_ips,!internal_domains -> domain_[alias_domain]
-- Add policy_group_members: domain_domain.com -> primary domain and all alias domains

