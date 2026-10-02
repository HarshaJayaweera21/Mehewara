BEGIN;
SET LOCAL search_path = public;
SET LOCAL standard_conforming_strings = on;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';
DO $deployment$
DECLARE current_ids text[] := ARRAY[]::text[];
BEGIN
    IF NOT pg_try_advisory_xact_lock(61743, 2) THEN
        RAISE EXCEPTION 'Another Mehewara database deployment is running';
    END IF;
    IF current_database() <> 'mehewara_deploy_test_ebd84cee11344fd89f0018c46688a6cd' THEN
        RAISE EXCEPTION 'Database target changed';
    END IF;
    IF (
SELECT COALESCE(json_agg(c.relname ORDER BY c.relname), '[]'::json)::text
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
)::jsonb <> '["__EFMigrationsHistory", "approval_history", "crews", "problems", "report_photos", "reports", "roles", "users", "work_orders", "workflow_events", "workflow_runs"]'::jsonb THEN
        RAISE EXCEPTION 'Schema relations changed since preflight; inspect again';
    END IF;
    IF to_regclass('public."__EFMigrationsHistory"') IS NOT NULL THEN
        SELECT COALESCE(array_agg("MigrationId"::text ORDER BY "MigrationId"), ARRAY[]::text[])
        INTO current_ids FROM public."__EFMigrationsHistory";
    END IF;
    IF current_ids <> ARRAY['20260916150458_InitialCreate','20260918043408_UpdateAppDbContext','20260918112155_UpdateReportProblemToOneToMany','20260926050014_LinkApprovalHistoryToRecommendation','20260926054657_LinkWorkOrderToRecommendation','20260926075934_ProtectDispatchConcurrency']::text[] THEN
        RAISE EXCEPTION 'Migration history changed since preflight; inspect again';
    END IF;

END $deployment$;

CREATE TABLE activity_history (
    activity_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    actor_user_id uuid NOT NULL,
    action character varying(40) NOT NULL,
    recommendation_id uuid,
    work_order_id uuid,
    before_data jsonb NOT NULL,
    after_data jsonb NOT NULL,
    note text,
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_activity_history" PRIMARY KEY (activity_id),
    CONSTRAINT chk_activity_history_action CHECK (action IN ('RECOMMENDATION_EDITED', 'WORK_ORDER_STARTED', 'WORK_ORDER_COMPLETED')),
    CONSTRAINT chk_activity_history_edit_reason CHECK (action <> 'RECOMMENDATION_EDITED' OR NULLIF(BTRIM(note), '') IS NOT NULL),
    CONSTRAINT chk_activity_history_target CHECK ((action = 'RECOMMENDATION_EDITED' AND recommendation_id IS NOT NULL AND work_order_id IS NULL) OR (action IN ('WORK_ORDER_STARTED', 'WORK_ORDER_COMPLETED') AND work_order_id IS NOT NULL AND recommendation_id IS NULL)),
    CONSTRAINT "FK_activity_history_users_actor_user_id" FOREIGN KEY (actor_user_id) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT "FK_activity_history_work_orders_work_order_id" FOREIGN KEY (work_order_id) REFERENCES work_orders (work_order_id) ON DELETE RESTRICT,
    CONSTRAINT "FK_activity_history_workflow_events_recommendation_id" FOREIGN KEY (recommendation_id) REFERENCES workflow_events (workflow_event_id) ON DELETE RESTRICT
);

CREATE INDEX idx_activity_history_actor_time ON activity_history (actor_user_id, created_at);

CREATE INDEX idx_activity_history_recommendation_time ON activity_history (recommendation_id, created_at);

CREATE INDEX idx_activity_history_work_order_time ON activity_history (work_order_id, created_at);

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260926084022_AddActivityHistory', '8.0.31');



COMMIT;
