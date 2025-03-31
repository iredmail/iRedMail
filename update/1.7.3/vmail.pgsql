ALTER TABLE mailbox ADD COLUMN IF NOT EXISTS "first_name"     VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE mailbox ADD COLUMN IF NOT EXISTS "last_name"      VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE mailbox ADD COLUMN IF NOT EXISTS "mobile"         VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE mailbox ADD COLUMN IF NOT EXISTS "telephone"      VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE mailbox ADD COLUMN IF NOT EXISTS "birthday"       DATE NOT NULL DEFAULT '0001-01-01';
ALTER TABLE mailbox ADD COLUMN IF NOT EXISTS "recovery_email" VARCHAR(255) NOT NULL DEFAULT '';

ALTER TABLE deleted_mailboxes ADD COLUMN IF NOT EXISTS "bytes"    INT8 NOT NULL DEFAULT 0;
ALTER TABLE deleted_mailboxes ADD COLUMN IF NOT EXISTS "messages" INT8 NOT NULL DEFAULT 0;
