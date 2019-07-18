ALTER TABLE mailbox ADD COLUMN "enablequota-status" INT2 NOT NULL DEFAULT 1;
CREATE INDEX idx_mailbox_enablequota_status ON mailbox ("enablequota-status");
