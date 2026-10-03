START TRANSACTION;


DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926050014_LinkApprovalHistoryToRecommendation') THEN
    ALTER TABLE approval_history ALTER COLUMN work_order_id DROP NOT NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926050014_LinkApprovalHistoryToRecommendation') THEN
    ALTER TABLE approval_history ADD recommendation_id uuid;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926050014_LinkApprovalHistoryToRecommendation') THEN
    CREATE INDEX idx_approval_history_recommendation_id ON approval_history (recommendation_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926050014_LinkApprovalHistoryToRecommendation') THEN
    ALTER TABLE approval_history ADD CONSTRAINT "FK_approval_history_workflow_events_recommendation_id" FOREIGN KEY (recommendation_id) REFERENCES workflow_events (workflow_event_id) ON DELETE RESTRICT;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260926050014_LinkApprovalHistoryToRecommendation') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260926050014_LinkApprovalHistoryToRecommendation', '8.0.31');
    END IF;
END $EF$;
COMMIT;

