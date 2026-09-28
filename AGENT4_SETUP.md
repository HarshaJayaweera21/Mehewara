# Agent 4 and coordinator review setup

Implemented in source on 2026-09-28. Builds, tests, model calls, migrations and runtime behavior were **not verified**, at the user's request. Apply the configuration and migration before starting the application. Existing Agent 1/2 modules are unchanged; Agent 3 only adds optional coordinator feedback. The initial graph now ends with Agent 4. Regeneration uses a separate Agent 3 → Agent 4 graph with the same implementations.

## 1. Fill in your Gemini key locally

Work in `ai-service/mehewara-ai`. If `.env` does not exist, copy `.env.example` to `.env`. If it already exists, edit it and preserve your existing values. The implementation has not read or changed your `.env`.

```dotenv
GEMINI_API_KEY=YOUR_GEMINI_KEY
# Preserve GEMINI_MODEL or select a Gemini model your account can use.
DOTNET_API_BASE_URL=http://localhost:5194
INTERNAL_AI_API_KEY=YOUR_RANDOM_SHARED_SERVICE_SECRET
AGENT4_EVIDENCE_TIMEOUT_SECONDS=10
AGENT4_REVIEW_TIMEOUT_SECONDS=30
```

The Gemini key is shared through the existing LLM factory. `INTERNAL_AI_API_KEY` is a separate secret for communication between ASP.NET and Python; it is not your Gemini key. Use a long random value (at least 32 random bytes), and configure the exact same value on both services. `.env` is already ignored by Git. The checked-in Gemini model default was preserved; provider availability has not been checked.

From `backend/Mehewara.API`, configure the backend locally:

```powershell
dotnet user-secrets set "AiService:InternalApiKey" "YOUR_RANDOM_SHARED_SERVICE_SECRET"
dotnet user-secrets set "AiService:BaseUrl" "http://localhost:8000"
```

Alternatively set `AiService__InternalApiKey` and `AiService__BaseUrl` in the environment of the backend process. ASP.NET does **not** automatically read the Python `.env`. Keep your existing PostgreSQL connection, JWT, Google and Cloudinary configuration.

For React, `VITE_API_BASE_URL=http://localhost:5194/api` is the existing default. Never put either service secret or your Gemini key in frontend variables.

## 2. Deploy the database change yourself

New EF migration: `20260928090000_AddAgent4Review`.

Prerequisite migrations include `20260926050014_LinkApprovalHistoryToRecommendation`, `20260926054657_LinkWorkOrderToRecommendation`, `20260926075934_ProtectDispatchConcurrency`, and `20260926084022_AddActivityHistory`, plus their preceding migration chain. Stop the application and take a database backup first.

Inspect `__EFMigrationsHistory`. Earlier project notes reported a Docker schema with tables but missing migration history. Do not run the entire migration chain against that existing schema without reconciling its history and comparing its tables/constraints first.

For a database with a correct EF migration history, run from `backend/Mehewara.API`:

```powershell
dotnet ef database update 20260928090000_AddAgent4Review
```

For a manually managed existing database whose prerequisite schema is already present, the alternative schema-only script is `database/migrations/20260928090000_AddAgent4Review.sql`. Run it once with your PostgreSQL client. It uses a transaction but does not update EF history. Do not apply both the SQL script and the EF migration to the same database. Keep manual deployment records and reconcile EF history before a later EF deployment.

This migration adds saved workflow inputs, recommendation revision/evidence fields and the durable `ai_review_jobs` table. It invalidates legacy passing validation and identifies the most recent recommendation per workflow. Legacy records without original report snapshots cannot be safely revalidated; use a new report workflow with the required evidence. Existing historical data is preserved, including any old rejection placeholders.

Startup no longer calls `EnsureCreated`; schema deployment is explicit. The background review worker requires the new table.

## 3. Start the services

Run the backend from `backend/Mehewara.API` with `dotnet run --launch-profile http` (port 5194). Run Python from `ai-service/mehewara-ai` so pydantic-settings finds its `.env`:

```powershell
uv sync --extra dev
uv run uvicorn main:app --host 127.0.0.1 --port 8000
```

Run React from `web/mehewara-web` with `npm install`, then `npm run dev`. These commands are provided for you; they were not executed during implementation.

All `/internal/ai/*` Python routes, including health and diagram, now require the `X-Internal-Api-Key` header. The backend evidence endpoint requires the same header. In a deployed environment use TLS and configure both service URLs accordingly; neither service secret belongs in browser requests.

## 4. Coordinator behavior and API

Initial flow: report → Agents 1/2/3 → Agent 4 rule checks → authenticated backend evidence fetch → Gemini evidence review → persistence → coordinator review. Agent 4 cannot dispatch work.

| Route | Behavior |
| --- | --- |
| `POST /api/dispatch/recommendations/{id}/regenerate` | Admin submits `reason`, `expectedRevision`, `requestId` (UUID). Returns `202` with `jobId`, `status`, `statusUrl`; queues Agents 3 + 4. |
| `POST /api/dispatch/recommendations/{id}/validate` | Same request fields. Queues only Agent 4 against the current revision. |
| `GET /api/dispatch/review-jobs/{id}` | Admin reads `QUEUED`, `RUNNING`, `COMPLETED` or `FAILED`, error and result recommendation ID. |
| Existing recommendation list/detail | Adds revision, current/superseded flag, approval eligibility and latest job. Detail includes recommendation, edit and validation history. |
| Existing PATCH | Requires `expectedRevision` and `editReason`; supports priority, score, crew, specialty, priority reasons and recommendation reason. Saving invalidates validation; select **Validate current revision** afterward. |
| Existing approve | Requires `expectedRevision`; checks valid Agent 4 result, current evidence and live availability under database locks. |
| Existing reject | Requires `expectedRevision` and a reason; records a final decision without a WorkOrder. |
| `POST /internal/ai/validation-context` | Backend read-only evidence API. Request: `workflowId`, optional `jobId`, optional `problemId`/`crewId`, `reportIds`. References must be within the saved authorized context. |
| `POST /internal/ai/recommendation-review` | Python job executor; called by the backend with saved original analysis and fresh context. |

Use a new request UUID for each deliberate new review request. Reuse the same UUID only when retrying the same HTTP submission after an uncertain network result. Different content with the same ID is rejected. One active review job is allowed per workflow. Edit/approve/reject are blocked while it runs.

Jobs have four-minute leases, a 120-second AI HTTP deadline, and at most three claims after expired leases. Normal service/model failures are recorded for explicit coordinator retry; restarting the backend recovers abandoned jobs. Old or late results cannot replace a newer revision. Regeneration preserves previous recommendations and never dispatches automatically. The UI polls every 2.5 seconds and resumes polling from server state after refresh.

Agent 4 statuses: `VALID`, `REVISION_REQUIRED`, `INVALID`, `ERROR`, `NOT_RUN`. Only `VALID` for the exact current revision and unchanged evidence can become eligible for approval. Availability and conflicts are always checked again at dispatch. Initial input context is limited to the existing ten nearby candidates/reports; the evidence endpoint retrieves exact referenced records. Regeneration uses linked reports with a 100-report safety limit; exceeding it produces an explicit failure rather than silently truncating evidence.

## 5. Verification to perform on your side

1. Build backend and frontend; run the existing Python checks with the new authenticated service contract. Test against a disposable migrated database before your main database.
2. Submit a new report. Inspect four workflow events and a saved initial input snapshot. A successful review must wait for approval, not mark the municipal work complete.
3. Exercise invalid score bands, specialty mismatch, missing/no crew, contradictory evidence and unavailable crews. Approval must stay blocked.
4. Remove service credentials or make Gemini unavailable. Confirm `ERROR`, preserved earlier outputs, no WorkOrder and an explicit retry path.
5. Edit a recommendation. Confirm its revision increments, prior validation stops applying, and the reason/before/after values appear in history. Validate again before approving.
6. Regenerate with feedback. Confirm Agents 1/2 are not rerun, fresh crew context is used, a new recommendation replaces the current one, and both outputs remain in history.
7. Submit the same request ID twice. Confirm one job. Submit competing new IDs, stale revisions and unauthorized calls; confirm rejection.
8. Restart the backend during a job. Confirm lease recovery, bounded attempts and one resulting current recommendation. Check that failures preserve the previous recommendation but do not silently restore approval eligibility.
9. Change a crew's availability or evidence before approval; confirm dispatch is blocked. Send concurrent approvals; confirm one WorkOrder and one decision.
10. Reject a recommendation; confirm no cancelled placeholder WorkOrder is created. Verify existing Agent 1/2 behavior and ordinary Agent 3 output remain intact.

## Remaining operational limits

The initial resident-report trigger remains the existing in-process background task; only coordinator review/regeneration jobs have durable restart recovery. Agent 1 still does not inspect photo contents. Agent 2's existing tools and global context behavior are unchanged. No claim is made that runtime concurrency or model accuracy has been verified.

Graphify refresh was attempted, but the CLI was not available in this shell. Refresh graph metadata with `graphify update .` in an environment where graphify is installed.
