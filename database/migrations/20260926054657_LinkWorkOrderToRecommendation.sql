-- Apply to an existing EnsureCreated/manual-schema database without EF migration history.
-- Existing WorkOrders keep recommendation_id NULL; new approvals populate it.
-- This script does not create EF migration history.
BEGIN;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS recommendation_id UUID;

CREATE INDEX IF NOT EXISTS idx_work_orders_recommendation_id
    ON work_orders(recommendation_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'FK_work_orders_workflow_events_recommendation_id'
          AND conrelid = 'work_orders'::regclass
    ) THEN
        ALTER TABLE work_orders
            ADD CONSTRAINT "FK_work_orders_workflow_events_recommendation_id"
            FOREIGN KEY (recommendation_id)
            REFERENCES workflow_events(workflow_event_id)
            ON DELETE RESTRICT;
    END IF;
END $$;

COMMIT;
