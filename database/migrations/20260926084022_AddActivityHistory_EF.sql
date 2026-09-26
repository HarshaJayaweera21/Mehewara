START TRANSACTION;


DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926084022_AddActivityHistory') THEN
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
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926084022_AddActivityHistory') THEN
    CREATE INDEX idx_activity_history_actor_time ON activity_history (actor_user_id, created_at);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926084022_AddActivityHistory') THEN
    CREATE INDEX idx_activity_history_recommendation_time ON activity_history (recommendation_id, created_at);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926084022_AddActivityHistory') THEN
    CREATE INDEX idx_activity_history_work_order_time ON activity_history (work_order_id, created_at);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926084022_AddActivityHistory') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260926084022_AddActivityHistory', '8.0.31');
    END IF;
END $EF$;
COMMIT;

