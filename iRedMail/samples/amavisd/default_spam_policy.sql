-- Default server-wide spam policy
--
-- *) with 'spam_lover=Y' and:
--
--      - with 'spam_quarantine_to=spam-quarantine', spam will be delivered
--        to mailbox and a copy will be quarantined
--      - with 'spam_quarantine_to=' (empty value), spam will be delivered to
--        mailbox, no copy will be quarantined
--
-- *) with 'spam_lover=N' and
--
--      - with 'spam_quarantine_to=spam-quarantine', spam will be quarantined,
--        no copy will be delivered to mailbox.
--      - with 'spam_quarantine_to=' (empty value), spam won't be quarantined,
--        a copy will be delivered to mailbox.
--

INSERT INTO policy (policy_name,
                    spam_lover,
                    virus_lover,
                    banned_files_lover,
                    bad_header_lover,
                    bypass_spam_checks,
                    bypass_virus_checks,
                    bypass_banned_checks,
                    bypass_header_checks,
                    spam_quarantine_to,
                    virus_quarantine_to,
                    banned_quarantine_to,
                    bad_header_quarantine_to)
            VALUES ('@.',
                    'Y',
                    'N',
                    'Y',
                    'Y',
                    'N',
                    'N',
                    'N',
                    'N',
                    '',
                    'virus-quarantine',
                    '',
                    '');

INSERT INTO users (priority, email) VALUES (0, '@.');
UPDATE users SET policy_id = (SELECT id FROM policy WHERE policy.policy_name='@.' LIMIT 1);
