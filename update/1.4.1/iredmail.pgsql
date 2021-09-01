ALTER TABLE mailbox ADD COLUMN "enablesogowebmail" INT2 NOT NULL DEFAULT 1;
ALTER TABLE mailbox ADD COLUMN "enablesogocalendar" INT2 NOT NULL DEFAULT 1;
ALTER TABLE mailbox ADD COLUMN "enablesogoactivesync" INT2 NOT NULL DEFAULT 1;
