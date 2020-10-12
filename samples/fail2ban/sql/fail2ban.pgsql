--
-- Used to store banned/unbanned clients
--
CREATE TABLE banned (
    id SERIAL PRIMARY KEY,
    -- Banned client IP address
    ip VARCHAR(46) NOT NULL DEFAULT '',
    -- A list of banned network ports, separated by comma
    ports VARCHAR(100) NOT NULL DEFAULT '',
    -- protocol: tcp, udp, ...
    protocol VARCHAR(10) NOT NULL DEFAULT 'tcp',
    -- Fail2ban jail name
    jail VARCHAR(50) NOT NULL DEFAULT '',
    -- The server hostname which the ban/unban happens
    hostname VARCHAR(255) NOT NULL DEFAULT '',
    country VARCHAR(255) NOT NULL DEFAULT '',
    -- reverse DNS name of banned IP address.
    rdns VARCHAR(255) NOT NULL DEFAULT '',
    -- number of times the failure occurred in the log file.
    -- we use Fail2ban action tag `ipjailfailures` here.
    failures SMALLINT NOT NULL DEFAULT 0,
    -- matched log lines.
    -- we use Fail2ban action tag `ipjailmatches` here.
    loglines TEXT,
    -- When the ban happens
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
    -- if `remove=1`, `ip` will be removed by cron job.
    remove INT2 DEFAULT 0
);

CREATE UNIQUE INDEX idx_banned_ip_ports_protocol ON banned (ip, ports, protocol);
CREATE INDEX idx_banned_jail ON banned (jail);
CREATE INDEX idx_banned_hostname ON banned (hostname);
CREATE INDEX idx_banned_country ON banned (country);
CREATE INDEX idx_banned_timestamp ON banned (timestamp);
CREATE INDEX idx_banned_remove ON banned (remove);
CREATE INDEX idx_banned_rdns ON banned (rdns);
