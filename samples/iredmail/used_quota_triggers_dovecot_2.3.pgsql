-- Trigger required by Dovecot 2.3 quota dict.
CREATE OR REPLACE FUNCTION merge_quota() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.messages < 0 OR NEW.messages IS NULL THEN
        -- ugly kludge: we came here from this function, really do try to insert
        IF NEW.messages IS NULL THEN
            NEW.messages = 0;
        ELSE
            NEW.messages = -NEW.messages;
        END IF;
        return NEW;
    END IF;

    LOOP
        UPDATE used_quota
        SET bytes = bytes + NEW.bytes, messages = messages + NEW.messages, domain=split_part(NEW.username, '@', 2)
        WHERE username = NEW.username;
        IF found THEN
            RETURN NULL;
        END IF;

        BEGIN
            IF NEW.messages = 0 THEN
                INSERT INTO used_quota (bytes, messages, username, domain)
                VALUES (NEW.bytes, NULL, NEW.username, split_part(NEW.username, '@', 2));
            ELSE
                INSERT INTO used_quota (bytes, messages, username, domain)
                VALUES (NEW.bytes, -NEW.messages, NEW.username, split_part(NEW.username, '@', 2));
            END IF;
            return NULL;
            EXCEPTION WHEN unique_violation THEN
            -- someone just inserted the record, update it
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER mergequota
    BEFORE INSERT ON used_quota FOR EACH ROW
    EXECUTE PROCEDURE merge_quota();
