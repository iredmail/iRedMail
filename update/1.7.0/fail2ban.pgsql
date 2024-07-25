--
-- Used to store both enabled and disabled jails.
--
CREATE TABLE jails (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL DEFAULT '',
    enabled INT2 DEFAULT 1
);
CREATE UNIQUE INDEX idx_jails_name      ON jails (name);
CREATE        INDEX idx_jails_enabled   ON jails (enabled);

ALTER TABLE jails OWNER TO fail2ban;
