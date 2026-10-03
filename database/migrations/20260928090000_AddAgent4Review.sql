BEGIN;
-- Forward schema change for Agent 4 and durable coordinator review.
-- Apply through EF when migration history is reconciled; this file is the schema-only alternative.
ALTER TABLE workflow_runs ADD COLUMN input_data jsonb;
ALTER TABLE workflow_runs ADD COLUMN current_recommendation_id uuid;
ALTER TABLE workflow_events ADD COLUMN revision integer NOT NULL DEFAULT 1;
ALTER TABLE workflow_events ADD COLUMN previous_recommendation_id uuid;
ALTER TABLE workflow_events ADD COLUMN original_output_data jsonb;
ALTER TABLE workflow_events ADD COLUMN validated_revision integer;
ALTER TABLE workflow_events ADD COLUMN evidence_hash text;
ALTER TABLE workflow_events ADD COLUMN evidence_request jsonb;
UPDATE workflow_events SET original_output_data = output_data,
    validation_result = '{"status":"NOT_RUN","issues":["Legacy recommendation requires Agent 4 validation."]}'::jsonb
WHERE stage = 'PRIORITIZATION';
UPDATE workflow_runs AS run SET current_recommendation_id = latest.workflow_event_id
FROM (SELECT DISTINCT ON (workflow_run_id) workflow_run_id, workflow_event_id
      FROM workflow_events WHERE stage = 'PRIORITIZATION'
      ORDER BY workflow_run_id, started_at DESC, workflow_event_id DESC) AS latest
WHERE latest.workflow_run_id = run.workflow_run_id;
CREATE TABLE ai_review_jobs (
    id uuid CONSTRAINT "PK_ai_review_jobs" PRIMARY KEY,
    workflow_run_id uuid NOT NULL CONSTRAINT "FK_ai_review_jobs_workflow_runs_workflow_run_id" REFERENCES workflow_runs(workflow_run_id) ON DELETE RESTRICT,
    recommendation_id uuid NOT NULL CONSTRAINT "FK_ai_review_jobs_workflow_events_recommendation_id" REFERENCES workflow_events(workflow_event_id) ON DELETE RESTRICT,
    expected_revision integer NOT NULL,
    request_id uuid NOT NULL,
    requested_by uuid NOT NULL CONSTRAINT "FK_ai_review_jobs_users_requested_by" REFERENCES users(user_id) ON DELETE RESTRICT,
    kind text NOT NULL,
    reason text NOT NULL,
    status text NOT NULL,
    input_data jsonb,
    error text,
    result_recommendation_id uuid,
    lease_token uuid,
    lease_until timestamptz,
    attempts integer NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT ck_ai_review_job_status CHECK (status IN ('QUEUED','RUNNING','COMPLETED','FAILED')),
    CONSTRAINT ck_ai_review_job_kind CHECK (kind IN ('REGENERATE','VALIDATE'))
);
CREATE UNIQUE INDEX "IX_ai_review_jobs_request_id" ON ai_review_jobs(request_id);
CREATE UNIQUE INDEX ux_ai_review_jobs_active_workflow ON ai_review_jobs(workflow_run_id)
    WHERE status IN ('QUEUED','RUNNING');
CREATE INDEX "IX_ai_review_jobs_recommendation_id" ON ai_review_jobs(recommendation_id);
CREATE INDEX "IX_ai_review_jobs_requested_by" ON ai_review_jobs(requested_by);
COMMIT;
