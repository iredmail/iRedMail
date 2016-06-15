\c PH_VMAIL_DB_NAME;

-- Set correct privilege for ROLE: vmail
GRANT SELECT ON admin, alias, alias_domain, domain, domain_admins, mailbox, recipient_bcc_domain, recipient_bcc_user, sender_bcc_domain, sender_bcc_user, anyone_shares, share_folder, deleted_mailboxes, sender_relayhost TO PH_VMAIL_DB_BIND_USER;

-- Update per-user real-time mailbox usage
GRANT SELECT, UPDATE, INSERT, DELETE ON used_quota TO PH_VMAIL_DB_BIND_USER;
