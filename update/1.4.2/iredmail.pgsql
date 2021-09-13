-- Fix incorrect column types.
ALTER TABLE mailbox ALTER COLUMN "enablesogowebmail" TYPE VARCHAR(1);
ALTER TABLE mailbox ALTER COLUMN "enablesogocalendar" TYPE VARCHAR(1);
ALTER TABLE mailbox ALTER COLUMN "enablesogoactivesync" TYPE VARCHAR(1);

-- Drop unused columns.
ALTER TABLE mailbox DROP COLUMN "lastlogindate";
ALTER TABLE mailbox DROP COLUMN "lastloginipv4";
ALTER TABLE mailbox DROP COLUMN "lastloginprotocol";
