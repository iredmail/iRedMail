\c vmail;

-- cannot alter type of a column used by a view or rule
DROP VIEW IF EXISTS sogo_users;

ALTER TABLE mailbox ALTER COLUMN enablesogowebmail TYPE VARCHAR(1);
ALTER TABLE mailbox ALTER COLUMN enablesogocalendar TYPE VARCHAR(1);
ALTER TABLE mailbox ALTER COLUMN enablesogoactivesync TYPE VARCHAR(1);

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

ALTER TABLE sogo_users OWNER TO vmailadmin;

-- allow end users to change their own passwords.
GRANT SELECT,UPDATE ON mailbox TO sogo;
GRANT SELECT,UPDATE ON sogo_users TO sogo;
