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
    IF current_database() <> 'mehewara_deploy_test_694fd67504394bfdae9564c9cac7336b' THEN
        RAISE EXCEPTION 'Database target changed';
    END IF;
    IF (
SELECT COALESCE(json_agg(c.relname ORDER BY c.relname), '[]'::json)::text
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
)::jsonb <> '[]'::jsonb THEN
        RAISE EXCEPTION 'Schema relations changed since preflight; inspect again';
    END IF;
    IF to_regclass('public."__EFMigrationsHistory"') IS NOT NULL THEN
        SELECT COALESCE(array_agg("MigrationId"::text ORDER BY "MigrationId"), ARRAY[]::text[])
        INTO current_ids FROM public."__EFMigrationsHistory";
    END IF;
    IF current_ids <> ARRAY[]::text[] THEN
        RAISE EXCEPTION 'Migration history changed since preflight; inspect again';
    END IF;

    IF to_regclass('public.report_problems') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.report_problems) THEN
            RAISE EXCEPTION 'report_problems contains links; deployment would lose data';
        END IF;
    END IF;

END $deployment$;

CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

CREATE TABLE problems (
    problem_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    title character varying(200) NOT NULL,
    description text,
    category character varying(50) NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    address text,
    priority character varying(20),
    priority_score integer,
    status character varying(30) NOT NULL DEFAULT 'IDENTIFIED',
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_problems" PRIMARY KEY (problem_id),
    CONSTRAINT chk_problems_category CHECK ("category" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')),
    CONSTRAINT chk_problems_latitude CHECK ("latitude" >= -90 AND "latitude" <= 90),
    CONSTRAINT chk_problems_longitude CHECK ("longitude" >= -180 AND "longitude" <= 180),
    CONSTRAINT chk_problems_priority CHECK ("priority" IS NULL OR "priority" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_problems_priority_score CHECK ("priority_score" IS NULL OR ("priority_score" >= 0 AND "priority_score" <= 100)),
    CONSTRAINT chk_problems_status CHECK ("status" IN ('IDENTIFIED', 'AWAITING_ASSIGNMENT', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'))
);

CREATE TABLE roles (
    role_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    role_name character varying(50) NOT NULL,
    role_code character varying(50) NOT NULL,
    description character varying(255),
    is_active boolean NOT NULL DEFAULT TRUE,
    CONSTRAINT "PK_roles" PRIMARY KEY (role_id)
);

CREATE TABLE users (
    user_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    role_id uuid NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    phone_number character varying(20),
    is_active boolean NOT NULL DEFAULT TRUE,
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_users" PRIMARY KEY (user_id),
    CONSTRAINT "FK_users_roles_role_id" FOREIGN KEY (role_id) REFERENCES roles (role_id) ON DELETE RESTRICT
);

CREATE TABLE crews (
    crew_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    crew_name character varying(100) NOT NULL,
    crew_type character varying(50) NOT NULL,
    crew_leader_user_id uuid,
    description text,
    contact_number character varying(20),
    status character varying(30) NOT NULL DEFAULT 'AVAILABLE',
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_crews" PRIMARY KEY (crew_id),
    CONSTRAINT chk_crews_status CHECK ("status" IN ('AVAILABLE', 'BUSY', 'UNAVAILABLE')),
    CONSTRAINT chk_crews_type CHECK ("crew_type" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')),
    CONSTRAINT "FK_crews_users_crew_leader_user_id" FOREIGN KEY (crew_leader_user_id) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE TABLE reports (
    report_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    resident_id uuid NOT NULL,
    description text NOT NULL,
    category character varying(50) NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    address text,
    status character varying(30) NOT NULL DEFAULT 'PENDING',
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_reports" PRIMARY KEY (report_id),
    CONSTRAINT chk_reports_category CHECK ("category" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')),
    CONSTRAINT chk_reports_latitude CHECK ("latitude" >= -90 AND "latitude" <= 90),
    CONSTRAINT chk_reports_longitude CHECK ("longitude" >= -180 AND "longitude" <= 180),
    CONSTRAINT chk_reports_status CHECK ("status" IN ('PENDING', 'PROCESSING', 'ASSIGNED', 'RESOLVED', 'CANCELLED')),
    CONSTRAINT "FK_reports_users_resident_id" FOREIGN KEY (resident_id) REFERENCES users (user_id) ON DELETE RESTRICT
);

CREATE TABLE work_orders (
    work_order_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    problem_id uuid NOT NULL,
    crew_id uuid NOT NULL,
    priority character varying(20) NOT NULL,
    title character varying(200) NOT NULL,
    instructions text,
    status character varying(30) NOT NULL DEFAULT 'PENDING_APPROVAL',
    assigned_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    completion_notes text,
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_work_orders" PRIMARY KEY (work_order_id),
    CONSTRAINT chk_work_orders_priority CHECK ("priority" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_work_orders_status CHECK ("status" IN ('PENDING_APPROVAL', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED')),
    CONSTRAINT "FK_work_orders_crews_crew_id" FOREIGN KEY (crew_id) REFERENCES crews (crew_id) ON DELETE RESTRICT,
    CONSTRAINT "FK_work_orders_problems_problem_id" FOREIGN KEY (problem_id) REFERENCES problems (problem_id) ON DELETE RESTRICT
);

CREATE TABLE report_photos (
    photo_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    report_id uuid NOT NULL,
    photo_url text NOT NULL,
    file_name character varying(255),
    mime_type character varying(100),
    uploaded_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_report_photos" PRIMARY KEY (photo_id),
    CONSTRAINT "FK_report_photos_reports_report_id" FOREIGN KEY (report_id) REFERENCES reports (report_id) ON DELETE CASCADE
);

CREATE TABLE report_problems (
    report_problem_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    report_id uuid NOT NULL,
    problem_id uuid NOT NULL,
    link_type character varying(30) NOT NULL,
    linked_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_report_problems" PRIMARY KEY (report_problem_id),
    CONSTRAINT chk_report_problems_link_type CHECK ("link_type" IN ('DUPLICATE', 'RELATED', 'PRIMARY')),
    CONSTRAINT "FK_report_problems_problems_problem_id" FOREIGN KEY (problem_id) REFERENCES problems (problem_id) ON DELETE CASCADE,
    CONSTRAINT "FK_report_problems_reports_report_id" FOREIGN KEY (report_id) REFERENCES reports (report_id) ON DELETE CASCADE
);

CREATE TABLE workflow_runs (
    workflow_run_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    report_id uuid NOT NULL,
    problem_id uuid,
    current_stage character varying(50) NOT NULL,
    status character varying(30) NOT NULL DEFAULT 'RUNNING',
    state_data jsonb,
    started_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_workflow_runs" PRIMARY KEY (workflow_run_id),
    CONSTRAINT chk_workflow_runs_stage CHECK ("current_stage" IN ('REPORT_ANALYSIS', 'PROBLEM_CONSOLIDATION', 'PRIORITIZATION', 'VALIDATION', 'WAITING_FOR_APPROVAL', 'WORK_EXECUTION', 'COMPLETED')),
    CONSTRAINT chk_workflow_runs_status CHECK ("status" IN ('RUNNING', 'WAITING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    CONSTRAINT "FK_workflow_runs_problems_problem_id" FOREIGN KEY (problem_id) REFERENCES problems (problem_id) ON DELETE SET NULL,
    CONSTRAINT "FK_workflow_runs_reports_report_id" FOREIGN KEY (report_id) REFERENCES reports (report_id) ON DELETE CASCADE
);

CREATE TABLE approval_history (
    approval_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    work_order_id uuid NOT NULL,
    decided_by uuid NOT NULL,
    decision character varying(30) NOT NULL,
    reason text,
    created_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT "PK_approval_history" PRIMARY KEY (approval_id),
    CONSTRAINT chk_approval_history_decision CHECK ("decision" IN ('APPROVED', 'REJECTED', 'REVISION_REQUIRED')),
    CONSTRAINT "FK_approval_history_users_decided_by" FOREIGN KEY (decided_by) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT "FK_approval_history_work_orders_work_order_id" FOREIGN KEY (work_order_id) REFERENCES work_orders (work_order_id) ON DELETE CASCADE
);

CREATE TABLE workflow_events (
    workflow_event_id uuid NOT NULL DEFAULT (gen_random_uuid()),
    workflow_run_id uuid NOT NULL,
    agent_name character varying(50) NOT NULL,
    stage character varying(50) NOT NULL,
    status character varying(30) NOT NULL,
    input_data jsonb,
    output_data jsonb,
    validation_result jsonb,
    tool_results jsonb,
    error_message text,
    started_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    completed_at timestamp with time zone,
    CONSTRAINT "PK_workflow_events" PRIMARY KEY (workflow_event_id),
    CONSTRAINT chk_workflow_events_stage CHECK ("stage" IN ('REPORT_ANALYSIS', 'PROBLEM_CONSOLIDATION', 'PRIORITIZATION', 'VALIDATION', 'WAITING_FOR_APPROVAL', 'WORK_EXECUTION', 'COMPLETED')),
    CONSTRAINT chk_workflow_events_status CHECK ("status" IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED', 'WAITING')),
    CONSTRAINT "FK_workflow_events_workflow_runs_workflow_run_id" FOREIGN KEY (workflow_run_id) REFERENCES workflow_runs (workflow_run_id) ON DELETE CASCADE
);

CREATE INDEX idx_approval_history_created_at ON approval_history (created_at);

CREATE INDEX idx_approval_history_decided_by ON approval_history (decided_by);

CREATE INDEX idx_approval_history_work_order_id ON approval_history (work_order_id);

CREATE UNIQUE INDEX idx_crews_leader ON crews (crew_leader_user_id);

CREATE INDEX idx_crews_status ON crews (status);

CREATE INDEX idx_crews_type ON crews (crew_type);

CREATE UNIQUE INDEX "IX_crews_crew_name" ON crews (crew_name);

CREATE INDEX idx_problems_category ON problems (category);

CREATE INDEX idx_problems_location ON problems (latitude, longitude);

CREATE INDEX idx_problems_priority ON problems (priority);

CREATE INDEX idx_problems_priority_score ON problems (priority_score);

CREATE INDEX idx_problems_status ON problems (status);

CREATE INDEX idx_report_photos_report_id ON report_photos (report_id);

CREATE INDEX idx_report_problems_problem_id ON report_problems (problem_id);

CREATE INDEX idx_report_problems_report_id ON report_problems (report_id);

CREATE UNIQUE INDEX uq_report_problem ON report_problems (report_id, problem_id);

CREATE INDEX idx_reports_category ON reports (category);

CREATE INDEX idx_reports_created_at ON reports (created_at);

CREATE INDEX idx_reports_location ON reports (latitude, longitude);

CREATE INDEX idx_reports_resident_id ON reports (resident_id);

CREATE INDEX idx_reports_status ON reports (status);

CREATE UNIQUE INDEX "IX_roles_role_code" ON roles (role_code);

CREATE UNIQUE INDEX "IX_roles_role_name" ON roles (role_name);

CREATE INDEX idx_users_active ON users (is_active);

CREATE INDEX idx_users_role_id ON users (role_id);

CREATE UNIQUE INDEX "IX_users_email" ON users (email);

CREATE INDEX idx_work_orders_created_at ON work_orders (created_at);

CREATE INDEX idx_work_orders_crew_id ON work_orders (crew_id);

CREATE INDEX idx_work_orders_priority ON work_orders (priority);

CREATE INDEX idx_work_orders_problem_id ON work_orders (problem_id);

CREATE INDEX idx_work_orders_status ON work_orders (status);

CREATE INDEX idx_workflow_events_agent_name ON workflow_events (agent_name);

CREATE INDEX idx_workflow_events_stage ON workflow_events (stage);

CREATE INDEX idx_workflow_events_started_at ON workflow_events (started_at);

CREATE INDEX idx_workflow_events_status ON workflow_events (status);

CREATE INDEX idx_workflow_events_workflow_run_id ON workflow_events (workflow_run_id);

CREATE INDEX idx_workflow_runs_created_at ON workflow_runs (created_at);

CREATE INDEX idx_workflow_runs_current_stage ON workflow_runs (current_stage);

CREATE INDEX idx_workflow_runs_problem_id ON workflow_runs (problem_id);

CREATE INDEX idx_workflow_runs_report_id ON workflow_runs (report_id);

CREATE INDEX idx_workflow_runs_status ON workflow_runs (status);


                CREATE OR REPLACE FUNCTION update_updated_at_column()
                RETURNS TRIGGER AS $$
                BEGIN
                    NEW.updated_at = CURRENT_TIMESTAMP;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;
            


                CREATE TRIGGER trg_roles_updated_at
                BEFORE UPDATE ON roles
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                CREATE TRIGGER trg_users_updated_at
                BEFORE UPDATE ON users
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                CREATE TRIGGER trg_crews_updated_at
                BEFORE UPDATE ON crews
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                CREATE TRIGGER trg_reports_updated_at
                BEFORE UPDATE ON reports
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                CREATE TRIGGER trg_problems_updated_at
                BEFORE UPDATE ON problems
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                CREATE TRIGGER trg_work_orders_updated_at
                BEFORE UPDATE ON work_orders
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                CREATE TRIGGER trg_workflow_runs_updated_at
                BEFORE UPDATE ON workflow_runs
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            


                INSERT INTO roles (role_name, role_code, description, is_active)
                VALUES
                    ('Resident', 'RESIDENT', 'Municipal resident who submits and tracks reports', TRUE),
                    ('Administrator', 'ADMIN', 'Coordinator/administrator who reviews AI recommendations and manages workflows', TRUE),
                    ('Drainage Crew Leader', 'CREW_LEADER_DRAINAGE', NULL, TRUE),
                    ('Waste Crew Leader', 'CREW_LEADER_WASTE', NULL, TRUE),
                    ('Road Crew Leader', 'CREW_LEADER_ROAD', NULL, TRUE),
                    ('Electrical Crew Leader', 'CREW_LEADER_ELECTRICAL', NULL, TRUE)
                ON CONFLICT (role_code) DO NOTHING;
            

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260916150458_InitialCreate', '8.0.31');

ALTER TABLE users ADD profile_image_url character varying(500);

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260918043408_UpdateAppDbContext', '8.0.31');

DROP TABLE report_problems;

ALTER TABLE reports ADD problem_id uuid;

CREATE INDEX idx_reports_problem_id ON reports (problem_id);

ALTER TABLE reports ADD CONSTRAINT "FK_reports_problems_problem_id" FOREIGN KEY (problem_id) REFERENCES problems (problem_id) ON DELETE SET NULL;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260918112155_UpdateReportProblemToOneToMany', '8.0.31');

ALTER TABLE approval_history ALTER COLUMN work_order_id DROP NOT NULL;

ALTER TABLE approval_history ADD recommendation_id uuid;

CREATE INDEX idx_approval_history_recommendation_id ON approval_history (recommendation_id);

ALTER TABLE approval_history ADD CONSTRAINT "FK_approval_history_workflow_events_recommendation_id" FOREIGN KEY (recommendation_id) REFERENCES workflow_events (workflow_event_id) ON DELETE RESTRICT;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260926050014_LinkApprovalHistoryToRecommendation', '8.0.31');

ALTER TABLE work_orders ADD recommendation_id uuid;

CREATE INDEX idx_work_orders_recommendation_id ON work_orders (recommendation_id);

ALTER TABLE work_orders ADD CONSTRAINT "FK_work_orders_workflow_events_recommendation_id" FOREIGN KEY (recommendation_id) REFERENCES workflow_events (workflow_event_id) ON DELETE RESTRICT;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260926054657_LinkWorkOrderToRecommendation', '8.0.31');

DROP INDEX idx_work_orders_recommendation_id;

CREATE UNIQUE INDEX idx_work_orders_recommendation_id ON work_orders (recommendation_id) WHERE recommendation_id IS NOT NULL;

CREATE UNIQUE INDEX ux_work_orders_active_crew ON work_orders (crew_id) WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

CREATE UNIQUE INDEX ux_work_orders_active_problem ON work_orders (problem_id) WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

CREATE UNIQUE INDEX ux_approval_history_terminal_recommendation ON approval_history (recommendation_id) WHERE recommendation_id IS NOT NULL AND decision IN ('APPROVED', 'REJECTED');

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260926075934_ProtectDispatchConcurrency', '8.0.31');

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
