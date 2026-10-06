-- ============================================================
-- MEHEWARA DATABASE SCHEMA (FINAL)
-- PostgreSQL
-- ============================================================
-- Purpose:
--   Municipal resident reporting, problem consolidation,
--   AI-assisted prioritization and crew recommendation,
--   human approval with coordinator revisions/edits,
--   crew work execution, audit activity logging, and
--   durable background AI review job queueing (Agent 4).
--
-- Core Architecture (12 Tables):
--   1. roles             - System security and authorization roles
--   2. users             - Resident, admin, and crew leader user accounts
--   3. crews             - Work crews categorized by municipal domain
--   4. problems          - Consolidated municipal issues (with estimated duration)
--   5. reports           - 1:N resident incident intake submissions
--   6. report_photos     - Cloud-stored photographic evidence links
--   7. workflow_runs     - Orchestrated LangGraph AI multi-agent workflow instances
--   8. workflow_events   - Individual agent execution events, revisions, and evidence
--   9. work_orders       - Authorized work assigned to crews with concurrency protection
--  10. approval_history  - Human decisions on recommendations and work orders
--  11. activity_history  - Audit log for recommendation edits and dispatch actions
--  12. ai_review_jobs    - Durable queue for Agent 4 validation & regeneration
--
-- Key Schema Evolutions & Invariants:
--   1. 1:N Report-Problem Architecture:
--      - The legacy 'report_problems' N:M bridge table is removed.
--      - 'reports.problem_id' links directly to 'problems.problem_id' (ON DELETE SET NULL).
--   2. Dispatch Concurrency Protection:
--      - 'work_orders.recommendation_id' is uniquely indexed when non-null.
--      - A crew can have at most ONE work order IN_PROGRESS (idx_work_orders_single_in_progress_crew).
--      - A crew can have at most ONE work order in ASSIGNED or IN_PROGRESS (ux_work_orders_active_crew).
--      - A problem can have at most ONE work order in ASSIGNED or IN_PROGRESS (ux_work_orders_active_problem).
--      - Terminal approval decisions (APPROVED/REJECTED) are unique per recommendation (ux_approval_history_terminal_recommendation).
--   3. Coordinator Audit Trail:
--      - 'activity_history' records before/after state diffs for recommendation edits and dispatch transitions.
--   4. Agent 4 Validation & Review Jobs:
--      - 'workflow_runs' tracks 'input_data' and 'current_recommendation_id'.
--      - 'workflow_events' supports recommendation revisions ('revision', 'previous_recommendation_id',
--        'original_output_data', 'validated_revision', 'evidence_hash', 'evidence_request').
--      - 'ai_review_jobs' manages background validation/regeneration worker leases and state.
--
-- Authority:
--   PostgreSQL is the authoritative data store.
--   ASP.NET Core (Entity Framework Core) owns DB access and business rules.
--   FastAPI / LangGraph acts as the internal Agentic AI service.
-- ============================================================


-- ============================================================
-- EXTENSIONS
-- ============================================================

-- gen_random_uuid() for PostgreSQL UUID primary key generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- 1. ROLES
-- ============================================================
-- Defines system access levels. Role codes are referenced by
-- the ASP.NET Core authorization policies.
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
-- System accounts for residents, administrators, and crew leaders.
-- Note: Individual crew laborers do not have system accounts;
-- each crew is represented by its crew leader account.
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
-- Municipal field maintenance crews categorized by operational type.
-- Each crew is led by exactly one user account (crew_leader_user_id).
-- ============================================================

CREATE TABLE crews (
    crew_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    crew_leader_user_id UUID UNIQUE,

    crew_name VARCHAR(100) NOT NULL UNIQUE,

    crew_type VARCHAR(50) NOT NULL,

    description TEXT,

    contact_number VARCHAR(20),

    status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE',

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_crews_leader
        FOREIGN KEY (crew_leader_user_id)
        REFERENCES users(user_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_crews_type
        CHECK (
            crew_type IN (
                'DRAINAGE',
                'ROAD',
                'WASTE',
                'ELECTRICAL',
                'ENVIRONMENT'
            )
        ),

    CONSTRAINT chk_crews_status
        CHECK (
            status IN (
                'AVAILABLE',
                'BUSY',
                'UNAVAILABLE'
            )
        )
);


-- ============================================================
-- 4. PROBLEMS
-- ============================================================
-- Real-world consolidated municipal issues identified by residents
-- and grouped by AI / municipal coordinators.
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

    estimated_duration_minutes INTEGER,

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
-- 5. REPORTS
-- ============================================================
-- Citizen reports submitted from mobile or web clients.
-- In 1:N consolidation, each report optionally links to one problem.
-- ============================================================

CREATE TABLE reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    resident_id UUID NOT NULL,

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

    CONSTRAINT fk_reports_problem
        FOREIGN KEY (problem_id)
        REFERENCES problems(problem_id)
        ON DELETE SET NULL,

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
-- 6. REPORT_PHOTOS
-- ============================================================
-- Image attachments uploaded as evidence for resident reports.
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
-- 7. WORKFLOW_RUNS
-- ============================================================
-- Tracks an execution instance of the Agentic AI workflow for a report.
-- ============================================================

CREATE TABLE workflow_runs (
    workflow_run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_id UUID NOT NULL,

    problem_id UUID,

    current_stage VARCHAR(50) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'RUNNING',

    input_data JSONB,

    current_recommendation_id UUID,

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
-- 8. WORKFLOW_EVENTS
-- ============================================================
-- Execution log of individual agent nodes within a workflow run.
-- Also persists Agent 3/4 recommendation outputs, revisions,
-- evidence hashes, and validation outputs.
-- ============================================================

CREATE TABLE workflow_events (
    workflow_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    workflow_run_id UUID NOT NULL,

    agent_name VARCHAR(50) NOT NULL,

    stage VARCHAR(50) NOT NULL,

    status VARCHAR(30) NOT NULL,

    input_data JSONB,

    revision INTEGER NOT NULL DEFAULT 1,

    previous_recommendation_id UUID,

    original_output_data JSONB,

    validated_revision INTEGER,

    evidence_hash TEXT,

    evidence_request JSONB,

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


-- ============================================================
-- 9. WORK_ORDERS
-- ============================================================
-- Authorized municipal work assignments dispatched to crews.
-- Can be linked to the approved workflow recommendation event.
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

    CONSTRAINT fk_work_orders_recommendation
        FOREIGN KEY (recommendation_id)
        REFERENCES workflow_events(workflow_event_id)
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
-- 10. APPROVAL_HISTORY
-- ============================================================
-- Records human municipal coordinator decisions (Approved,
-- Rejected, Revision Required) for recommendations or work orders.
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

    CONSTRAINT fk_approval_history_recommendation
        FOREIGN KEY (recommendation_id)
        REFERENCES workflow_events(workflow_event_id)
        ON DELETE RESTRICT,

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
-- 11. ACTIVITY_HISTORY
-- ============================================================
-- Audit trail tracking human coordinator modifications to AI
-- recommendations (with mandatory reason notes) and crew dispatch
-- lifecycle actions.
-- ============================================================

CREATE TABLE activity_history (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID NOT NULL,

    action VARCHAR(40) NOT NULL,

    recommendation_id UUID,

    work_order_id UUID,

    before_data JSONB NOT NULL,

    after_data JSONB NOT NULL,

    note TEXT,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_activity_history_actor
        FOREIGN KEY (actor_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_activity_history_recommendation
        FOREIGN KEY (recommendation_id)
        REFERENCES workflow_events(workflow_event_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_activity_history_work_order
        FOREIGN KEY (work_order_id)
        REFERENCES work_orders(work_order_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_activity_history_action
        CHECK (
            action IN (
                'RECOMMENDATION_EDITED',
                'WORK_ORDER_STARTED',
                'WORK_ORDER_COMPLETED'
            )
        ),

    CONSTRAINT chk_activity_history_target
        CHECK (
            (action = 'RECOMMENDATION_EDITED' AND recommendation_id IS NOT NULL AND work_order_id IS NULL)
            OR (action IN ('WORK_ORDER_STARTED', 'WORK_ORDER_COMPLETED') AND work_order_id IS NOT NULL AND recommendation_id IS NULL)
        ),

    CONSTRAINT chk_activity_history_edit_reason
        CHECK (
            action <> 'RECOMMENDATION_EDITED'
            OR NULLIF(BTRIM(note), '') IS NOT NULL
        )
);


-- ============================================================
-- 12. AI_REVIEW_JOBS
-- ============================================================
-- Durable background queue for Agent 4 review operations
-- (REGENERATE and VALIDATE) with worker lease management.
-- ============================================================

CREATE TABLE ai_review_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    workflow_run_id UUID NOT NULL,

    recommendation_id UUID NOT NULL,

    expected_revision INTEGER NOT NULL,

    request_id UUID NOT NULL UNIQUE,

    requested_by UUID NOT NULL,

    kind TEXT NOT NULL,

    reason TEXT NOT NULL,

    status TEXT NOT NULL,

    input_data JSONB,

    error TEXT,

    result_recommendation_id UUID,

    lease_token UUID,

    lease_until TIMESTAMP WITH TIME ZONE,

    attempts INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ai_review_jobs_workflow_run
        FOREIGN KEY (workflow_run_id)
        REFERENCES workflow_runs(workflow_run_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_review_jobs_recommendation
        FOREIGN KEY (recommendation_id)
        REFERENCES workflow_events(workflow_event_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_review_jobs_requested_by
        FOREIGN KEY (requested_by)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_ai_review_job_status
        CHECK (
            status IN (
                'QUEUED',
                'RUNNING',
                'COMPLETED',
                'FAILED'
            )
        ),

    CONSTRAINT ck_ai_review_job_kind
        CHECK (
            kind IN (
                'REGENERATE',
                'VALIDATE'
            )
        )
);


-- ============================================================
-- INDEXES
-- ============================================================
-- Performance and operational query indexes.
-- Unique constraints define database-level business invariants.
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


-- Reports
CREATE INDEX idx_reports_resident_id
    ON reports(resident_id);

CREATE INDEX idx_reports_problem_id
    ON reports(problem_id);

CREATE INDEX idx_reports_status
    ON reports(status);

CREATE INDEX idx_reports_category
    ON reports(category);

CREATE INDEX idx_reports_created_at
    ON reports(created_at);

CREATE INDEX idx_reports_location
    ON reports(latitude, longitude);


-- Report Photos
CREATE INDEX idx_report_photos_report_id
    ON report_photos(report_id);


-- Workflow Runs
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


-- Workflow Events
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


-- Work Orders
CREATE INDEX idx_work_orders_problem_id
    ON work_orders(problem_id);

CREATE INDEX idx_work_orders_crew_id
    ON work_orders(crew_id);

CREATE INDEX idx_work_orders_status
    ON work_orders(status);

CREATE INDEX idx_work_orders_priority
    ON work_orders(priority);

CREATE INDEX idx_work_orders_created_at
    ON work_orders(created_at);

-- Dispatch concurrency invariant: Exactly one work order per recommendation
CREATE UNIQUE INDEX idx_work_orders_recommendation_id
    ON work_orders(recommendation_id)
    WHERE recommendation_id IS NOT NULL;

-- Invariant: A crew can have at most one active (ASSIGNED or IN_PROGRESS) work order
CREATE UNIQUE INDEX ux_work_orders_active_crew
    ON work_orders(crew_id)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

-- Invariant: A problem can have at most one active (ASSIGNED or IN_PROGRESS) work order
CREATE UNIQUE INDEX ux_work_orders_active_problem
    ON work_orders(problem_id)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS');

-- Storage-level invariant: A crew can never have more than one work order in IN_PROGRESS status
CREATE UNIQUE INDEX idx_work_orders_single_in_progress_crew
    ON work_orders(crew_id)
    WHERE status = 'IN_PROGRESS';


-- Approval History
CREATE INDEX idx_approval_history_work_order_id
    ON approval_history(work_order_id);

CREATE INDEX idx_approval_history_recommendation_id
    ON approval_history(recommendation_id);

CREATE INDEX idx_approval_history_decided_by
    ON approval_history(decided_by);

CREATE INDEX idx_approval_history_created_at
    ON approval_history(created_at);

-- Invariant: Only one terminal decision (APPROVED or REJECTED) can exist for a given recommendation
CREATE UNIQUE INDEX ux_approval_history_terminal_recommendation
    ON approval_history(recommendation_id)
    WHERE recommendation_id IS NOT NULL AND decision IN ('APPROVED', 'REJECTED');


-- Activity History
CREATE INDEX idx_activity_history_actor_time
    ON activity_history(actor_user_id, created_at);

CREATE INDEX idx_activity_history_recommendation_time
    ON activity_history(recommendation_id, created_at);

CREATE INDEX idx_activity_history_work_order_time
    ON activity_history(work_order_id, created_at);


-- AI Review Jobs
CREATE UNIQUE INDEX idx_ai_review_jobs_request_id
    ON ai_review_jobs(request_id);

CREATE UNIQUE INDEX ux_ai_review_jobs_active_workflow
    ON ai_review_jobs(workflow_run_id)
    WHERE status IN ('QUEUED', 'RUNNING');

CREATE INDEX idx_ai_review_jobs_recommendation_id
    ON ai_review_jobs(recommendation_id);

CREATE INDEX idx_ai_review_jobs_requested_by
    ON ai_review_jobs(requested_by);


-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================
-- Automatically updates updated_at whenever a row is modified.
-- Applied only to tables containing the updated_at column.
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


CREATE TRIGGER trg_crews_updated_at
BEFORE UPDATE ON crews
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


CREATE TRIGGER trg_problems_updated_at
BEFORE UPDATE ON problems
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


CREATE TRIGGER trg_reports_updated_at
BEFORE UPDATE ON reports
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


CREATE TRIGGER trg_ai_review_jobs_updated_at
BEFORE UPDATE ON ai_review_jobs
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
),
(
    'Environment Crew Leader',
    'CREW_LEADER_ENVIRONMENT',
    'Leader of an environmental and public spaces crew'
)
ON CONFLICT (role_code) DO NOTHING;


-- ============================================================
-- END OF MEHEWARA DATABASE SCHEMA (FINAL)
-- ============================================================
