-- Dovecot 2.4 uses plugin `quota_clone` to store quota usage info in SQL db,
-- Dovecot 2.3 uses quota dict for that, triggers used by 2.3 does not work
-- in 2.4 anymore, and we just need trigger to set `used_quota.domain` in 2.4.

-- Remove trigger created for Dovecot 2.3.
DROP TRIGGER IF EXISTS mergequota ON used_quota;

CREATE OR REPLACE FUNCTION set_used_quota_domain() RETURNS TRIGGER AS $$
BEGIN
    NEW.domain := split_part(LOWER(NEW.username), '@', 2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER used_quota_before_insert
    BEFORE INSERT ON used_quota
    FOR EACH ROW
    EXECUTE PROCEDURE set_used_quota_domain();
