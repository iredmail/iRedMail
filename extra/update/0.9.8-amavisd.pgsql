-- Change `maddr.email` type to VARCHAR, because split_part() doesn't support
-- `bytea`
ALTER TABLE maddr ALTER COLUMN email TYPE VARCHAR(255);

-- mail address without address extension: user+abc@domain.com -> user@domain.com
ALTER TABLE maddr ADD COLUMN email_raw VARCHAR(255) NOT NULL DEFAULT '';

-- index
CREATE INDEX maddr_idx_email ON maddr (email);
CREATE INDEX maddr_idx_email_raw ON maddr (email_raw);
CREATE INDEX maddr_idx_domain ON maddr (domain);

-- Create trigger to save email address withou address extension
-- user+abc@domain.com -> user@domain.com
-- CREATE OR REPLACE FUNCTION strip_addr_extension(bytea, varchar, integer) RETURNS TRIGGER AS $$
CREATE OR REPLACE FUNCTION strip_addr_extension()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.email LIKE '%+%') THEN
        NEW.email_raw := split_part(NEW.email, '+', 1) || '@' || split_part(NEW.email, '@', 2);
    ELSE
        NEW.email_raw := NEW.email;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER maddr_email_raw
    BEFORE INSERT ON maddr
    FOR EACH ROW
    EXECUTE PROCEDURE strip_addr_extension();
