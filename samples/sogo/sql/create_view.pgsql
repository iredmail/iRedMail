-- create SQL view in vmail database.

CREATE VIEW sogo_users AS
     SELECT username AS c_uid,
            username AS c_name,
            password AS c_password,
            name     AS c_cn,
            username AS mail,
            domain   AS domain,
            enablesogowebmail     AS c_webmail,
            enablesogocalendar    AS c_calendar,
            enablesogoactivesync  AS c_activesync
       FROM mailbox
      WHERE enablesogo=1 AND active=1;

-- allow end users to change their own passwords.
GRANT SELECT,UPDATE ON mailbox TO sogo;

GRANT SELECT,UPDATE ON sogo_users TO sogo;
