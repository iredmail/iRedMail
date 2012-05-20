#
# IMAP shared folders. User 'from_user' shares folders to user 'to_user'.
# WARNING: Works only with Dovecot 1.2+.
#
CREATE TABLE IF NOT EXISTS share_folder (
  from_user VARCHAR(150) NOT NULL,
  to_user VARCHAR(150) NOT NULL,
  dummy CHAR(1),
  PRIMARY KEY (from_user, to_user)
);

CREATE TABLE IF NOT EXISTS anyone_shares (
    from_user VARCHAR(255) NOT NULL,
    dummy CHAR(1) DEFAULT '1',
    PRIMARY KEY (from_user)
);
