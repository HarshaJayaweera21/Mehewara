START TRANSACTION;


DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926075934_ProtectDispatchConcurrency') THEN
    DROP INDEX idx_work_orders_recommendation_id;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926075934_ProtectDispatchConcurrency') THEN
    CREATE UNIQUE INDEX idx_work_orders_recommendation_id ON work_orders (recommendation_id) WHERE recommendation_id IS NOT NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926075934_ProtectDispatchConcurrency') THEN
    CREATE UNIQUE INDEX ux_work_orders_active_crew ON work_orders (crew_id) WHERE status IN ('ASSIGNED', 'IN_PROGRESS');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926075934_ProtectDispatchConcurrency') THEN
    CREATE UNIQUE INDEX ux_work_orders_active_problem ON work_orders (problem_id) WHERE status IN ('ASSIGNED', 'IN_PROGRESS');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926075934_ProtectDispatchConcurrency') THEN
    CREATE UNIQUE INDEX ux_approval_history_terminal_recommendation ON approval_history (recommendation_id) WHERE recommendation_id IS NOT NULL AND decision IN ('APPROVED', 'REJECTED');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926075934_ProtectDispatchConcurrency') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260926075934_ProtectDispatchConcurrency', '8.0.31');
    END IF;
END $EF$;
COMMIT;

