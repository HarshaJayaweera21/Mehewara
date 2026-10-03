-- Apply only to an existing EnsureCreated/manual-schema database after confirming
-- it has approval_history and workflow_events but no EF migration history.
-- The EF migration with the same name is for an EF-managed database instead.
BEGIN;

ALTER TABLE approval_history
    ALTER COLUMN work_order_id DROP NOT NULL;

ALTER TABLE approval_history
    ADD COLUMN IF NOT EXISTS recommendation_id UUID;

CREATE INDEX IF NOT EXISTS idx_approval_history_recommendation_id
    ON approval_history(recommendation_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'FK_approval_history_workflow_events_recommendation_id'
          AND conrelid = 'approval_history'::regclass
    ) THEN
        ALTER TABLE approval_history
            ADD CONSTRAINT "FK_approval_history_workflow_events_recommendation_id"
            FOREIGN KEY (recommendation_id)
            REFERENCES workflow_events(workflow_event_id)
            ON DELETE RESTRICT;
    END IF;
END $$;

COMMIT;
