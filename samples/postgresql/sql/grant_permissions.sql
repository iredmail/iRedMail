\c PH_VMAIL_DB_NAME;

-- Set correct privilege for ROLE: vmail
GRANT SELECT ON
    admin, alias, alias_domain, anyone_shares,
    deleted_mailboxes, domain, domain_admins,
    forwardings,
    mailbox, maillists, maillist_owners, moderators,
    recipient_bcc_domain, recipient_bcc_user,
    sender_bcc_domain, sender_bcc_user, sender_relayhost, share_folder
    TO PH_VMAIL_DB_BIND_USER;

-- Update per-user real-time mailbox usage
GRANT SELECT, UPDATE, INSERT, DELETE ON used_quota TO PH_VMAIL_DB_BIND_USER;
