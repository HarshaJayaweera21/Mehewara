-- For an existing EnsureCreated/manual-schema database without EF migration history.
-- Run the preflight queries in MANUAL_APPLY_DISPATCH_CONCURRENCY.txt first.
-- This script changes indexes only and does not create EF migration history.
BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM work_orders
        WHERE recommendation_id IS NOT NULL
        GROUP BY recommendation_id HAVING COUNT(*) > 1
    ) OR EXISTS (
        SELECT 1 FROM work_orders
        WHERE status IN ('ASSIGNED', 'IN_PROGRESS')
        GROUP BY crew_id HAVING COUNT(*) > 1
    ) OR EXISTS (
        SELECT 1 FROM work_orders
        WHERE status IN ('ASSIGNED', 'IN_PROGRESS')
        GROUP BY problem_id HAVING COUNT(*) > 1
    ) OR EXISTS (
        SELECT 1 FROM approval_history
        WHERE recommendation_id IS NOT NULL
          AND decision IN ('APPROVED', 'REJECTED')
        GROUP BY recommendation_id HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Existing duplicate dispatch records must be reviewed before creating unique indexes.';
    END IF;
END $$;

DROP INDEX IF EXISTS idx_work_orders_recommendation_id;

CREATE UNIQUE INDEX idx_work_orders_recommendation_id
    ON work_orders(recommendation_id)
    WHERE recommendation_id IS NOT NULL;

CREATE UNIQUE INDEX ux_work_orders_active_crew
    ON work_orders(crew_id)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

CREATE UNIQUE INDEX ux_work_orders_active_problem
    ON work_orders(problem_id)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

CREATE UNIQUE INDEX ux_approval_history_terminal_recommendation
    ON approval_history(recommendation_id)
    WHERE recommendation_id IS NOT NULL AND decision IN ('APPROVED', 'REJECTED');

COMMIT;
