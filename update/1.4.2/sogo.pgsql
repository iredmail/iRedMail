DROP VIEW users;

CREATE VIEW users AS
     SELECT * FROM dblink('host=127.0.0.1
                           port=5432
                           dbname=vmail
                           user=vmail
                           password=VMAIL_DB_BIND_PASSWD',
                          'SELECT username AS c_uid,
                                  username AS c_name,
                                  password AS c_password,
                                  name     AS c_cn,
                                  username AS mail,
                                  domain   AS domain,
                                  enablesogowebmail     AS c_webmail,
                                  enablesogocalendar    AS c_calendar,
                                  enablesogoactivesync  AS c_activesync
                             FROM mailbox
                            WHERE enablesogo=1 AND active=1')
         AS users (c_uid         VARCHAR(255),
                                  c_name        VARCHAR(255),
                                  c_password    VARCHAR(255),
                                  c_cn          VARCHAR(255),
                                  mail          VARCHAR(255),
                                  domain        VARCHAR(255),
                                  c_webmail     VARCHAR(1),
                                  c_calendar    VARCHAR(1),
                                  c_activesync  VARCHAR(1));

ALTER TABLE users OWNER TO sogo;
