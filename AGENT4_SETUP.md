# Agent 4: setup, deployment and verification

Updated for Steps 2–8 on 2026-09-28. Builds, tests, migrations, service startup, model calls and browser/runtime checks were **not run**, as requested. Source is authoritative; this guide is not a runtime guarantee.

## 1. Database status

You report applying migration 9, `20260928090000_AddAgent4Review`. No additional migration is required for Steps 2–8. Do not reapply its SQL script. Your database and migration history were not inspected here.

For another environment, check its actual EF history and matching source. The preceding migration is `20260928023710_AddProblemEstimatedDurationMinutes`; earlier concurrency and activity-history migrations also belong to the EF chain. From `backend/Mehewara.API`, user-run commands are:

```powershell
dotnet ef migrations list
# Only for another environment which has not applied this migration:
dotnet ef database update 20260928090000_AddAgent4Review
```

The alternate SQL script changes schema but does not update EF history. Do not apply SQL and EF versions to the same database. Reconcile an existing schema with missing/inconsistent history before running the EF chain. Incomplete legacy snapshots may require a new report workflow; missing evidence/provenance is not invented.

## 2. Python configuration

Use Python 3.12 or later and the project's uv dependency files. Work from `ai-service/mehewara-ai` so settings find `.env`. Copy `.env.example` only if `.env` does not exist; otherwise add missing settings while preserving existing values:

```dotenv
GEMINI_API_KEY=YOUR_GEMINI_KEY
# Preserve GEMINI_MODEL or choose a model available to your Gemini account.
DOTNET_API_BASE_URL=http://localhost:5194
INTERNAL_AI_API_KEY=YOUR_RANDOM_SHARED_SERVICE_SECRET
AGENT4_EVIDENCE_TIMEOUT_SECONDS=10
AGENT4_REVIEW_TIMEOUT_SECONDS=30
```

All agents reuse the shared Gemini factory/key/model. Agent 4 needs no separate Gemini key. The configured example model's provider availability has not been checked. Timeout values must be positive and finite.

Generate a random service secret locally and configure exactly the same value in Python and ASP.NET. It is separate from your Gemini key. Keep secrets out of source control and logs. Actual `.env` values were not read or changed during Step 8.

## 3. Backend configuration

Use the .NET 8 SDK. Preserve existing PostgreSQL, JWT and other integration configuration. From `backend/Mehewara.API`, run locally:

```powershell
dotnet user-secrets set "AiService:InternalApiKey" "YOUR_RANDOM_SHARED_SERVICE_SECRET"
dotnet user-secrets set "AiService:BaseUrl" "http://localhost:8000"
```

Alternatively set `AiService__InternalApiKey` and `AiService__BaseUrl` in the backend process environment. ASP.NET does not load Python's `.env`. User secrets are for development; deployed services need secrets in their deployment configuration.

The backend's `http` launch profile uses `http://localhost:5194`; its configured Python URL is `http://localhost:8000`. If ports/hosts change, update both service URLs. Development CORS includes `http://localhost:5173`, `http://localhost:5174` and `http://localhost:3000`. Configure additional browser origins through `Cors:AllowedOrigins`.

## 4. Frontend configuration

Use Node/npm compatible with the project's package files. Create or update `web/mehewara-web/.env.local`:

```dotenv
VITE_API_BASE_URL=http://localhost:5194/api
```

The actual fallback is relative `/api`; current Vite configuration has no backend proxy. Direct Vite development therefore needs this URL. Restart Vite after changing environment settings. Never put Gemini or service secrets in `VITE_*` variables; these are exposed to browsers.

For deployment, configure the API URL at frontend build time or serve `/api` through the deployment reverse proxy. Browser requests use existing user authentication, not internal service keys.

## 5. Deployment and startup

Deploy matching Python/backend/frontend versions. Stop backend workers and report submissions while replacing services. Confirm existing schema/configuration, start Python, then backend, then frontend. The backend starts its hosted review worker automatically and may immediately claim saved jobs; no separate worker command exists.

Each terminal below starts from the repository root. These commands were not executed here:

```powershell
# Terminal 1
Set-Location ai-service/mehewara-ai
uv sync --extra dev
uv run uvicorn main:app --host 127.0.0.1 --port 8000
```

```powershell
# Terminal 2
Set-Location backend/Mehewara.API
dotnet run --launch-profile http
```

```powershell
# Terminal 3
Set-Location web/mehewara-web
npm ci
npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

Open `http://localhost:5173` using an Admin account. Explicit Uvicorn `--port` controls its listener; setting `PORT` alone does not change this command. In deployment configure reachable hosts and appropriate HTTPS URLs; localhost refers to each process's own machine/container.

Both internal directions require `X-Internal-Api-Key`: backend calls to Python `/internal/ai/*` (including health/diagram), and Python calls to backend `POST /internal/ai/validation-context`. Missing/wrong secrets are rejected. Health/startup output does not prove Gemini review works.

## 6. Implemented workflow

1. Initial Python generation runs Agents 1 → 2 → 3 and returns; Agent 4 is not inline.
2. Backend persistence saves authorized inputs, original outputs, resolved Problem mapping, recommendation and its initial `VALIDATE` job atomically.
3. The durable worker runs Agent 4 alone for `VALIDATE`, or Agent 3 → Agent 4 for `REGENERATE`, once per job.
4. Agent 4 checks schema/references, retrieves authorized authoritative evidence within 10 seconds, applies consistency checks and performs structured Gemini review within 30 seconds by default. At most one model retry fits inside that overall deadline.
5. Backend records a separate validation event bound to the exact revision and reviewed evidence. Fresh locked evidence comparison prevents changed evidence from passing.
6. Bounded successors may follow. Admin approval performs fresh transactional business checks before creating a WorkOrder.

Original output, validations, predecessor recommendations, jobs and human edits remain for audit. Original Agent 2 `CREATE_NEW` is preserved; resolved Problem ID is separate. Agent 4 never dispatches, silently rewrites output or fixes report associations.

| Result/action | Backend action |
| --- | --- |
| `VALID` | Finish; approval still depends on current backend eligibility. |
| `REVISION_REQUIRED` / `REGENERATE` | Queue Agent 3 → Agent 4; at most two automatic corrections per chain. |
| `REVISION_REQUIRED` / `RETRY_VALIDATION` | Queue Agent 4 after five seconds; at most two evidence revalidations per chain. |
| `REVISION_REQUIRED` / `WAIT_FOR_CREW` | Stop for attention; restored availability does not automatically restart work. |
| `REVISION_REQUIRED` / `REVIEW_INPUT` | Stop for source/Problem review; regeneration cannot repair report links. |
| `INVALID` or `NOT_RUN` | Stop for attention; no approval. |
| Returned `ERROR` during `VALIDATE` | Bounded Agent 4-only retries. |
| Returned `ERROR` during `REGENERATE` | Preserve predecessor and stop; do not rerun Agent 3 solely for failed review. |

Transient transport/timeouts/408/429/5xx retry the same job after 10 and 30 seconds, with at most three executions. Regeneration transport retries may rerun Agent 3 because no complete durable response was received. Permanent authentication/request errors stop. Technical failure never implies `VALID`.

Claims use `FOR UPDATE SKIP LOCKED`, four-minute leases and a 120-second AI HTTP deadline. Restart recovers expired claims; late results cannot commit. Parent completion/successor creation are atomic with one active job per workflow. Worker attempts, correction and evidence retry budgets are separate. Unsupported legacy metadata gains no invented automatic chain.

### Human edits and dashboard

Views: Ready for Approval, Processing, Needs Attention, Decided, All / History. These are display groups, not extra validation statuses. Even `VALID` can need attention after availability/business conditions change.

A genuine Admin edit requires reason/expected revision and creates an audited `HUMAN_OVERRIDE`, incrementing revision while preserving original AI output. No Agent 4 rerun is queued. A meaningful no-op creates no override, audit or revision. Previous validation remains historical; the override's current display is `NOT_RUN` with the human approval policy.

Audited overrides need explicit responsibility acknowledgement, a nonblank approval reason and all mandatory backend checks. Unedited AI requires passing Agent 4 validation. Both paths check authorized source links, eligible Problem, correct available crew, active work, recommendation fields, current revision and previous decisions under transactional locks/concurrency constraints. Editor and approver may differ and both are recorded. Rejection records a decision without a WorkOrder.

Failed regeneration blocks predecessor approval. AI predecessors need retry or revalidation; audited human predecessors need successful regeneration or a genuine new audited edit/revision. Responsibility acknowledgement alone cannot remove that block.

### Existing APIs

| Route | Usage |
| --- | --- |
| `GET /api/dispatch/recommendations` | Admin list with `reviewBucket=ALL`, `READY`, `PROCESSING`, `NEEDS_ATTENTION`, `DECIDED`; search/filter/paging. |
| `GET /api/dispatch/recommendations/{id}` | Findings, revision, original output, histories, allowed actions. |
| `POST /api/dispatch/recommendations/{id}/validate` | Queue Agent 4; `reason`, `expectedRevision`, `requestId`; excludes audited overrides. |
| `POST /api/dispatch/recommendations/{id}/regenerate` | Queue Agent 3 → Agent 4; same request fields. |
| `GET /api/dispatch/review-jobs/{id}` | Safe job status, chain links, attempts and retry time; no raw context or lease credentials. |
| `POST /internal/ai/validation-context` | Authenticated read-only backend evidence retrieval authorized against saved context. |
| `POST /internal/ai/recommendation-review` | Authenticated Python executor used by the worker. |

Queue requests return 202 with a job reference. New deliberate requests use new UUIDs; resubmission after uncertain HTTP outcomes reuses the same ID/content. Conflicting content is rejected. Active review blocks edit/approve/reject. UI `allowedActions` are advisory; endpoints enforce rules again.

## 7. Consolidated user verification

Run against suitable local test data. These checks have not been executed:

| Check | Expected result |
| --- | --- |
| Normal report and valid AI output | Original Agents 1–3 output/snapshot persist, initial job runs, separate validation binds revision/evidence; no automatic WorkOrder. |
| Existing Agents 1/2 and ordinary Agent 3 | Normal generation remains; review retries do not rerun Agents 1/2. |
| CREATE_NEW and existing Problem | Original decision and separate real UUID; wrong/out-of-context IDs or unlinked reports cannot pass. |
| Wrong types, priority/score bands, specialty, duration/travel bounds | Failed checks, issues/corrections, blocked approval. Travel shape checks do not prove a road route. |
| Busy crew, active work, cancelled Problem/report | Approval blocked even after earlier `VALID`. |
| No selected crew | `REVISION_REQUIRED`; regenerate if matching available alternatives, otherwise `WAIT_FOR_CREW`; never passing. |
| Missing/incomplete/unauthorized evidence | Safe failure without invented evidence or passing fallback. |
| Bad internal secret, backend outage, model timeout or malformed citations | Visible technical failure, bounded retry and no WorkOrder. |
| Evidence changes during review | Snapshot mismatch prevents passing; five-second Agent 4-only child, separate two-revalidation limit. |
| Repeated correction failures | Persisted children, accumulated rejected crews, last automatic correction count 2, then Needs Attention. |
| Transport timeout or 429/503 | Persisted 10/30-second delays, at most three executions, visible failure history. |
| Returned ERROR after regeneration | Previous recommendation stays current/blocked; failed candidate remains audit-only where retained. |
| Worker restart during claim/delay; multiple workers | Delays survive, leases recover, exclusive claims/one successor, late results discarded. |
| Duplicate ID, conflicting payload, stale revision | Deduplication or rejection; no duplicate active job or overwritten revision. |
| Genuine edit and no-op | Audit actor/reason/before/after and revision for genuine edit, no Agent 4 job; no-op preserves existing state. |
| Override approval | Missing acknowledgement/reason fails; eligible acknowledged approval records one decision/WorkOrder and atomic acknowledgement. |
| Override regeneration fails | Acknowledgement cannot restore eligibility; new genuine edit or successful regeneration required. |
| Rejection | Decision retained, no WorkOrder, no further decision/edit actions. |
| Concurrent approvals or changing availability | Fresh checks/constraints prevent conflicting assignments and duplicate decisions. |
| Dashboard tabs, filters, search and more than 20 records | Correct groups/totals, filter-before-pagination, stale response protection and historical action restrictions. |
| Dashboard progress/history | Retry times, counts, child jobs, original AI output and human audit visible; failed candidate not silently selected as current. |
| Non-Admin calls | Admin routes/actions denied. |

Optional user-run compilation: `dotnet build` from the backend directory and `npm run build` from the frontend directory. Run existing tests using their project tooling. Compilation alone does not establish model accuracy, recovery or approval concurrency.

## 8. Remaining operational limits

- Initial report generation remains an in-process task; only review/correction jobs have durable recovery.
- Workers are sequential per backend process, exclusive across processes. No global Gemini quota manager, queue capacity limit or initial-generation throttle was added.
- Validation does not reserve crews. Availability changes require a deliberate later action; report association defects require source review.
- Listing performs per-recommendation eligibility checks; large-scale performance is unverified. Workflows without persisted recommendations stay in earlier report/Problem handling.
- Legacy missing evidence/provenance stays unknown. Generated graphs are navigation aids, not runtime verification.

All planned steps have source/documentation delivery reports. Builds, tests, migrations, model calls and runtime behavior remain unverified. Next: configure locally, start matching services and perform this checklist; fix observed failures before relying on deployment.
