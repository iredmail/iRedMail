CREATE TABLE maillist_owners (
    id SERIAL PRIMARY KEY,
    address VARCHAR(255) NOT NULL DEFAULT '',
    owner VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    dest_domain VARCHAR(255) NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX idx_maillist_owners_address_owner ON maillist_owners (address, owner);
CREATE INDEX idx_maillist_owners_address ON maillist_owners (address);
CREATE INDEX idx_maillist_owners_owner ON maillist_owners (owner);
CREATE INDEX idx_maillist_owners_domain ON maillist_owners (domain);
CREATE INDEX idx_maillist_owners_dest_domain ON maillist_owners (dest_domain);
