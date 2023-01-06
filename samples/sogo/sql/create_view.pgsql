-- create SQL view in vmail database.

CREATE VIEW sogo_users AS
    SELECT mailbox.username AS c_uid,
           mailbox.username AS c_name,
           mailbox.password AS c_password,
           mailbox.name AS c_cn,
           mailbox.username AS mail,
           mailbox.domain,
           mailbox.enablesogowebmail AS c_webmail,
           mailbox.enablesogocalendar AS c_calendar,
           mailbox.enablesogoactivesync AS c_activesync,
           (SELECT string_agg(forwardings.address, ' ') AS string_agg FROM forwardings WHERE forwardings.forwarding = mailbox.username AND forwardings.address <> mailbox.username) AS alternate_addresses
     FROM mailbox
    WHERE mailbox.enablesogo = 1 AND mailbox.active = 1;

-- allow end users to change their own passwords.
GRANT SELECT,UPDATE ON mailbox TO sogo;

GRANT SELECT,UPDATE ON sogo_users TO sogo;
