-- ============================================================
-- MEHEWARA DATABASE SCHEMA
-- PostgreSQL
-- ============================================================
-- Purpose:
--   Municipal resident reporting, problem consolidation,
--   AI-assisted prioritization/crew recommendation,
--   human approval, and crew work execution.
--
-- Core tables:
--   1. roles
--   2. users
--   3. crews
--   4. reports
--   5. report_photos
--   6. problems
--   7. work_orders
--   8. approval_history
--   9. workflow_runs
--  10. workflow_events
--
-- Important:
--   PostgreSQL is the authoritative data store.
--   ASP.NET Core owns DB access and business-rule enforcement.
--   React/Flutter never access PostgreSQL directly.
--   FastAPI/LangGraph is an internal AI service.
-- ============================================================


-- ============================================================
-- OPTIONAL: EXTENSIONS
-- ============================================================

-- gen_random_uuid() is provided by pgcrypto.
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- 1. ROLES
-- ============================================================

CREATE TABLE roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    role_name VARCHAR(50) NOT NULL UNIQUE,

    role_code VARCHAR(50) NOT NULL UNIQUE,

    description VARCHAR(255),

    is_active BOOLEAN NOT NULL DEFAULT TRUE
);


-- ============================================================
-- 2. USERS
-- ============================================================
-- IMPORTANT:
--   There is NO crew_id in this table.
--
--   Crew relationship is maintained by:
--
--       crews.crew_leader_user_id
--              ↓
--       users.user_id
--
--   Only crew leaders are registered as users.
--   Individual crew workers do not have accounts.
-- ============================================================

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    role_id UUID NOT NULL,

    first_name VARCHAR(100) NOT NULL,

    last_name VARCHAR(100) NOT NULL,

    email VARCHAR(255) NOT NULL UNIQUE,

    password_hash VARCHAR(255) NOT NULL,

    phone_number VARCHAR(20),

    profile_image_url VARCHAR(500),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id)
        REFERENCES roles(role_id)
        ON DELETE RESTRICT
);


-- ============================================================
-- 3. CREWS
-- ============================================================
-- A crew is an actual municipal work unit.
--
-- crew_leader_user_id:
--   FK → users.user_id
--   NULLABLE
--   UNIQUE
--
-- Therefore:
--   One crew has 0..1 leader.
--   One user can lead at most one crew.
--
-- Backend must additionally verify that the linked user's role
-- is an appropriate crew-leader role for the crew type.
-- ============================================================

CREATE TABLE crews (
    crew_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    crew_name VARCHAR(100) NOT NULL UNIQUE,

    crew_type VARCHAR(50) NOT NULL,

    crew_leader_user_id UUID UNIQUE,

    description TEXT,

    contact_number VARCHAR(20),

    status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE',

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_crews_crew_leader
        FOREIGN KEY (crew_leader_user_id)
        REFERENCES users(user_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_crews_status
        CHECK (
            status IN (
                'AVAILABLE',
                'BUSY',
                'UNAVAILABLE'
            )
        ),

    CONSTRAINT chk_crews_type
        CHECK (
            crew_type IN (
                'DRAINAGE',
                'ROAD',
                'WASTE',
                'ELECTRICAL',
                'ENVIRONMENT'
            )
        )
);


-- ============================================================
-- 4. REPORTS
-- ============================================================
-- Original resident-submitted report.
--
-- Resident-facing status values:
--
--   PENDING
--   PROCESSING
--   ASSIGNED
--   RESOLVED
--   CANCELLED
--
-- Internal AI workflow states are NOT stored here.
-- They belong in workflow_runs/workflow_events.
-- ============================================================

CREATE TABLE reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    resident_id UUID NOT NULL,

    -- Current EF Core relationship: each Report links to zero or one Problem.
    problem_id UUID,

    description TEXT NOT NULL,

    category VARCHAR(50) NOT NULL,

    latitude DECIMAL(9,6) NOT NULL,

    longitude DECIMAL(9,6) NOT NULL,

    address TEXT,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reports_resident
        FOREIGN KEY (resident_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_reports_status
        CHECK (
            status IN (
                'PENDING',
                'PROCESSING',
                'ASSIGNED',
                'RESOLVED',
                'CANCELLED'
            )
        ),

    CONSTRAINT chk_reports_category
        CHECK (
            category IN (
                'DRAINAGE',
                'ROAD',
                'WASTE',
                'ELECTRICAL',
                'ENVIRONMENT'
            )
        ),

    CONSTRAINT chk_reports_latitude
        CHECK (
            latitude >= -90
            AND latitude <= 90
        ),

    CONSTRAINT chk_reports_longitude
        CHECK (
            longitude >= -180
            AND longitude <= 180
        )
);


-- ============================================================
-- 5. REPORT_PHOTOS
-- ============================================================
-- One report can have multiple photos.
--
-- Actual files can be stored in Cloudinary/object storage.
-- PostgreSQL stores the URL/reference.
-- ============================================================

CREATE TABLE report_photos (
    photo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_id UUID NOT NULL,

    photo_url TEXT NOT NULL,

    file_name VARCHAR(255),

    mime_type VARCHAR(100),

    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_report_photos_report
        FOREIGN KEY (report_id)
        REFERENCES reports(report_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 6. PROBLEMS
-- ============================================================
-- Represents the real-world municipal issue.
--
-- One problem can be associated with many reports.
--
-- priority:
--   LOW
--   MEDIUM
--   HIGH
--   CRITICAL
--
-- priority_score:
--   Numeric score, e.g. 0-100.
--
-- Exact mapping between priority_score and priority is
-- determined by application/business rules.
-- ============================================================

CREATE TABLE problems (
    problem_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title VARCHAR(200) NOT NULL,

    description TEXT,

    category VARCHAR(50) NOT NULL,

    latitude DECIMAL(9,6) NOT NULL,

    longitude DECIMAL(9,6) NOT NULL,

    address TEXT,

    priority VARCHAR(20),

    priority_score INTEGER,

    status VARCHAR(30) NOT NULL DEFAULT 'IDENTIFIED',

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_problems_category
        CHECK (
            category IN (
                'DRAINAGE',
                'ROAD',
                'WASTE',
                'ELECTRICAL',
                'ENVIRONMENT'
            )
        ),

    CONSTRAINT chk_problems_priority
        CHECK (
            priority IS NULL
            OR priority IN (
                'LOW',
                'MEDIUM',
                'HIGH',
                'CRITICAL'
            )
        ),

    CONSTRAINT chk_problems_priority_score
        CHECK (
            priority_score IS NULL
            OR (
                priority_score >= 0
                AND priority_score <= 100
            )
        ),

    CONSTRAINT chk_problems_status
        CHECK (
            status IN (
                'IDENTIFIED',
                'AWAITING_ASSIGNMENT',
                'ASSIGNED',
                'IN_PROGRESS',
                'RESOLVED',
                'CLOSED'
            )
        ),

    CONSTRAINT chk_problems_latitude
        CHECK (
            latitude >= -90
            AND latitude <= 90
        ),

    CONSTRAINT chk_problems_longitude
        CHECK (
            longitude >= -180
            AND longitude <= 180
        )
);


-- ============================================================
-- Report -> Problem relationship (one-to-many)
-- ============================================================
-- One report can link to zero or one problem. A problem can link to many
-- reports. This matches the current EF Core Report.ProblemId mapping.
--
-- The Problem table is declared after Reports, so add the foreign key here.
-- ============================================================

ALTER TABLE reports
    ADD CONSTRAINT fk_reports_problem
    FOREIGN KEY (problem_id)
    REFERENCES problems(problem_id)
    ON DELETE SET NULL;


-- ============================================================
-- 7. WORK_ORDERS
-- ============================================================
-- Represents actual authorized work.
--
-- IMPORTANT:
--   There is NO accepted_at column.
--   There is NO ACCEPTED status.
--
-- Lifecycle:
--
--   PENDING_APPROVAL
--          ↓
--      ASSIGNED
--          ↓
--     IN_PROGRESS
--          ↓
--      COMPLETED
--
-- Alternative terminal states:
--   FAILED
--   CANCELLED
--
-- AI recommendations do NOT directly create authorized work.
-- Human approval is required.
-- ============================================================

CREATE TABLE work_orders (
    work_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    problem_id UUID NOT NULL,

    crew_id UUID NOT NULL,

    recommendation_id UUID,

    priority VARCHAR(20) NOT NULL,

    title VARCHAR(200) NOT NULL,

    instructions TEXT,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING_APPROVAL',

    assigned_at TIMESTAMP WITH TIME ZONE,

    started_at TIMESTAMP WITH TIME ZONE,

    completed_at TIMESTAMP WITH TIME ZONE,

    completion_notes TEXT,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_work_orders_problem
        FOREIGN KEY (problem_id)
        REFERENCES problems(problem_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_work_orders_crew
        FOREIGN KEY (crew_id)
        REFERENCES crews(crew_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_work_orders_priority
        CHECK (
            priority IN (
                'LOW',
                'MEDIUM',
                'HIGH',
                'CRITICAL'
            )
        ),

    CONSTRAINT chk_work_orders_status
        CHECK (
            status IN (
                'PENDING_APPROVAL',
                'ASSIGNED',
                'IN_PROGRESS',
                'COMPLETED',
                'FAILED',
                'CANCELLED'
            )
        )
);


-- ============================================================
-- 8. APPROVAL_HISTORY
-- ============================================================
-- Records human approval/rejection/revision decisions.
--
-- The coordinator/admin must be authorized by ASP.NET Core.
-- AI cannot approve its own recommendation.
-- ============================================================

CREATE TABLE approval_history (
    approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    work_order_id UUID,
    recommendation_id UUID,

    decided_by UUID NOT NULL,

    decision VARCHAR(30) NOT NULL,

    reason TEXT,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_approval_history_work_order
        FOREIGN KEY (work_order_id)
        REFERENCES work_orders(work_order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_approval_history_decided_by
        FOREIGN KEY (decided_by)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_approval_history_decision
        CHECK (
            decision IN (
                'APPROVED',
                'REJECTED',
                'REVISION_REQUIRED'
            )
        )
);


-- ============================================================
-- 9. WORKFLOW_RUNS
-- ============================================================
-- Represents one complete execution of the Agentic AI workflow.
--
-- LangGraph is the orchestrator/state machine.
-- It is NOT counted as one of the four domain agents.
--
-- Internal workflow state stays separate from resident-facing
-- report.status.
-- ============================================================

CREATE TABLE workflow_runs (
    workflow_run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_id UUID NOT NULL,

    problem_id UUID,

    current_stage VARCHAR(50) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'RUNNING',

    state_data JSONB,

    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    completed_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_workflow_runs_report
        FOREIGN KEY (report_id)
        REFERENCES reports(report_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_workflow_runs_problem
        FOREIGN KEY (problem_id)
        REFERENCES problems(problem_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_workflow_runs_stage
        CHECK (
            current_stage IN (
                'REPORT_ANALYSIS',
                'PROBLEM_CONSOLIDATION',
                'PRIORITIZATION',
                'VALIDATION',
                'WAITING_FOR_APPROVAL',
                'WORK_EXECUTION',
                'COMPLETED'
            )
        ),

    CONSTRAINT chk_workflow_runs_status
        CHECK (
            status IN (
                'RUNNING',
                'WAITING',
                'COMPLETED',
                'FAILED',
                'CANCELLED'
            )
        )
);


-- ============================================================
-- 10. WORKFLOW_EVENTS
-- ============================================================
-- Stores individual agent/stage execution records.
--
-- Store:
--   structured inputs
--   structured outputs
--   validation results
--   tool results
--   concise evidence/decision summaries
--   errors
--   execution status
--
-- DO NOT store hidden chain-of-thought/private model reasoning.
-- ============================================================

CREATE TABLE workflow_events (
    workflow_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    workflow_run_id UUID NOT NULL,

    agent_name VARCHAR(50) NOT NULL,

    stage VARCHAR(50) NOT NULL,

    status VARCHAR(30) NOT NULL,

    input_data JSONB,

    output_data JSONB,

    validation_result JSONB,

    tool_results JSONB,

    error_message TEXT,

    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    completed_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT fk_workflow_events_workflow_run
        FOREIGN KEY (workflow_run_id)
        REFERENCES workflow_runs(workflow_run_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_workflow_events_stage
        CHECK (
            stage IN (
                'REPORT_ANALYSIS',
                'PROBLEM_CONSOLIDATION',
                'PRIORITIZATION',
                'VALIDATION',
                'WAITING_FOR_APPROVAL',
                'WORK_EXECUTION',
                'COMPLETED'
            )
        ),

    CONSTRAINT chk_workflow_events_status
        CHECK (
            status IN (
                'RUNNING',
                'COMPLETED',
                'FAILED',
                'CANCELLED',
                'WAITING'
            )
        )
);

ALTER TABLE approval_history
    ADD CONSTRAINT fk_approval_history_recommendation
    FOREIGN KEY (recommendation_id)
    REFERENCES workflow_events(workflow_event_id)
    ON DELETE RESTRICT;

ALTER TABLE work_orders
    ADD CONSTRAINT "FK_work_orders_workflow_events_recommendation_id"
    FOREIGN KEY (recommendation_id)
    REFERENCES workflow_events(workflow_event_id)
    ON DELETE RESTRICT;


-- ============================================================
-- INDEXES
-- ============================================================
-- Primary keys and UNIQUE constraints already create indexes.
-- These additional indexes support common application queries.
-- ============================================================


-- Users

CREATE INDEX idx_users_role_id
    ON users(role_id);


CREATE INDEX idx_users_active
    ON users(is_active);


-- Crews

CREATE INDEX idx_crews_type
    ON crews(crew_type);


CREATE INDEX idx_crews_status
    ON crews(status);


CREATE INDEX idx_crews_leader
    ON crews(crew_leader_user_id);


-- Reports

CREATE INDEX idx_reports_resident_id
    ON reports(resident_id);


CREATE INDEX idx_reports_status
    ON reports(status);


CREATE INDEX idx_reports_problem_id
    ON reports(problem_id);


CREATE INDEX idx_reports_category
    ON reports(category);


CREATE INDEX idx_reports_created_at
    ON reports(created_at);


CREATE INDEX idx_reports_location
    ON reports(latitude, longitude);


-- Report photos

CREATE INDEX idx_report_photos_report_id
    ON report_photos(report_id);


-- Problems

CREATE INDEX idx_problems_status
    ON problems(status);


CREATE INDEX idx_problems_category
    ON problems(category);


CREATE INDEX idx_problems_priority
    ON problems(priority);


CREATE INDEX idx_problems_priority_score
    ON problems(priority_score);


CREATE INDEX idx_problems_location
    ON problems(latitude, longitude);


-- Work orders

CREATE INDEX idx_work_orders_problem_id
    ON work_orders(problem_id);


CREATE INDEX idx_work_orders_crew_id
    ON work_orders(crew_id);

CREATE UNIQUE INDEX idx_work_orders_recommendation_id
    ON work_orders(recommendation_id)
    WHERE recommendation_id IS NOT NULL;

CREATE UNIQUE INDEX ux_work_orders_active_crew
    ON work_orders(crew_id)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

CREATE UNIQUE INDEX ux_work_orders_active_problem
    ON work_orders(problem_id)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS');


CREATE INDEX idx_work_orders_status
    ON work_orders(status);


CREATE INDEX idx_work_orders_priority
    ON work_orders(priority);


CREATE INDEX idx_work_orders_created_at
    ON work_orders(created_at);


-- Approval history

CREATE INDEX idx_approval_history_work_order_id
    ON approval_history(work_order_id);

CREATE INDEX idx_approval_history_recommendation_id
    ON approval_history(recommendation_id);

CREATE UNIQUE INDEX ux_approval_history_terminal_recommendation
    ON approval_history(recommendation_id)
    WHERE recommendation_id IS NOT NULL AND decision IN ('APPROVED', 'REJECTED');


CREATE INDEX idx_approval_history_decided_by
    ON approval_history(decided_by);


CREATE INDEX idx_approval_history_created_at
    ON approval_history(created_at);


-- Workflow runs

CREATE INDEX idx_workflow_runs_report_id
    ON workflow_runs(report_id);


CREATE INDEX idx_workflow_runs_problem_id
    ON workflow_runs(problem_id);


CREATE INDEX idx_workflow_runs_status
    ON workflow_runs(status);


CREATE INDEX idx_workflow_runs_current_stage
    ON workflow_runs(current_stage);


CREATE INDEX idx_workflow_runs_created_at
    ON workflow_runs(created_at);


-- Workflow events

CREATE INDEX idx_workflow_events_workflow_run_id
    ON workflow_events(workflow_run_id);


CREATE INDEX idx_workflow_events_agent_name
    ON workflow_events(agent_name);


CREATE INDEX idx_workflow_events_stage
    ON workflow_events(stage);


CREATE INDEX idx_workflow_events_status
    ON workflow_events(status);


CREATE INDEX idx_workflow_events_started_at
    ON workflow_events(started_at);


-- ============================================================
-- OPTIONAL JSONB INDEXES
-- ============================================================
-- Useful if you frequently query workflow JSON fields.
-- Can be added now or later if needed.
--
-- CREATE INDEX idx_workflow_runs_state_data
--     ON workflow_runs USING GIN(state_data);
--
-- CREATE INDEX idx_workflow_events_output_data
--     ON workflow_events USING GIN(output_data);
-- ============================================================


-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
-- Automatically updates updated_at whenever a row is modified.
-- ============================================================

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


-- ============================================================
-- SEED ROLES
-- ============================================================

INSERT INTO roles (
    role_name,
    role_code,
    description
)
VALUES
(
    'Resident',
    'RESIDENT',
    'Municipal resident who submits and tracks reports'
),
(
    'Administrator',
    'ADMIN',
    'Coordinator/administrator who reviews AI recommendations and manages workflows'
),
(
    'Drainage Crew Leader',
    'CREW_LEADER_DRAINAGE',
    'Leader of a drainage work crew'
),
(
    'Waste Crew Leader',
    'CREW_LEADER_WASTE',
    'Leader of a waste management work crew'
),
(
    'Road Crew Leader',
    'CREW_LEADER_ROAD',
    'Leader of a road maintenance work crew'
),
(
    'Electrical Crew Leader',
    'CREW_LEADER_ELECTRICAL',
    'Leader of an electrical work crew'
)

ON CONFLICT (role_code) DO NOTHING;


-- ============================================================
-- END OF MEHEWARA DATABASE SCHEMA
-- ============================================================
