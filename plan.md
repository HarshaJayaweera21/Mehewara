# Member 4 implementation plan: human approval and WorkOrders

## Scope and authority

This plan covers ordinary ASP.NET Core, React, and Flutter software for coordinator review, authorized dispatch, crew execution, monitoring, audit, and status propagation. It does **not** implement Agent 4 or AI validation. The frozen source of shared API and lifecycle rules is [`Mehewara_API_Contract (1).md`](<Mehewara_API_Contract (1).md>); the problem statement and SQL file provide additional context. React and Flutter call ASP.NET Core only. PostgreSQL is authoritative. Use UUIDs, camelCase JSON, UTC timestamps, existing `ADMIN` and `CREW_LEADER_*` roles, and existing exception/error conventions.

The WorkOrder row is created **only by successful coordinator approval** after fresh ASP.NET checks. The frozen contract has no public `POST /api/work-orders` endpoint. An AI recommendation, an edit, or a request to regenerate cannot create or dispatch one. Although the database permits `PENDING_APPROVAL`, normal new WorkOrders should enter as `ASSIGNED` in the successful approval transaction; reviewable recommendations live in workflow data before that point.

## Repository findings and decisions to settle before implementation

| Finding | Evidence | Consequence / decision gate |
| --- | --- | --- |
| Lifecycle choice is settled: follow the database and frozen contract. | `database/Initial DB Structure.sql` and contract sections 3, 17, 26, 33, 35 exclude `ACCEPTED`, `/accept`, and `acceptedAt`. | Implement `ASSIGNED -> IN_PROGRESS -> COMPLETED` using `/start` and `/complete`; do not add an accept step. The original request's `ACCEPTED` item is superseded by the user's decision. |
| "Request revision" has no dedicated endpoint. | Contract review actions are `APPROVE`, `EDIT`, `REGENERATE`, `REJECT`; `REVISION_REQUIRED` is a stored decision/validation result. | Treat `/regenerate` as the contracted revision request only if product owners confirm that meaning. A separate manual revision action needs an agreed contract change. |
| `approval_history.work_order_id` is required, including for rejection before a WorkOrder exists. | `Models/ApprovalHistory.cs`, `Data/AppDbContext.cs`, and `database/Initial DB Structure.sql`; contract section 15 says rejection is stored there. | Agreed solution: make `work_order_id` nullable and add `recommendation_id`; rejection/revision records reference the stored recommendation and have no WorkOrder ID, while approval records include both IDs. Keep recommendation content in existing workflow data. Never create a placeholder WorkOrder. Add an EF migration and update the SQL baseline/model snapshot. |
| Report–Problem schema choice is settled as one-to-many to match current EF Core. | `Models/Report.cs` has nullable `ProblemId`; `Data/AppDbContext.cs` maps it; `Migrations/20260918112155_UpdateReportProblemToOneToMany.cs` implements it. `database/Initial DB Structure.sql` has been aligned to this model. The final API contract at `F:\Downlods\Mehewara_Final_API_Contract (1).md` now matches the selected one-to-many schema. | The contract now specifies nullable `reports.problem_id`, zero or one Problem per Report, and many Reports per Problem. Align Member 2's endpoint implementation with these rules; do not promise multi-problem Report resolution. The older repo-local contract copy may need synchronization before implementation. |
| WorkOrder and crew entities exist; the service/API path does not. | `Models/WorkOrder.cs`, `Models/Crew.cs`, `AppDbContext.cs`, SQL contain tables/checks. There are no WorkOrder controllers, services, or DTOs. | Phase 1 is a schema audit and minimal correction, not a new parallel domain model. |
| Recommendation persistence and review identity are not implemented yet. | No recommendation table by contract; `WorkflowRun.StateData` and `WorkflowEvent.OutputData` exist. Current `AiWorkflowClient` persists Agent 1/2 data and marks the workflow completed after consolidation. | Agree which stable UUID identifies a recommendation (prefer its persisted workflow event ID if the producer supports it), how validation status and edits are stored, and how a WorkOrder traces back to it. Live approval must wait for an actual reviewable validated result. Test fixtures may represent one; production code may not fabricate `VALID`. |
| `workflow_events` is the contracted work-status audit mechanism, but WorkOrder has no direct workflow FK. | Contract sections 24-25; current `WorkOrder` and `WorkflowEvent` models. | Preserve the originating workflow/recommendation association through approval and put structured `workOrderId`, actor, prior/new status, and UTC time in append-only events. Agree the lookup before Phase 7. No new `WorkOrderStatusHistory` table without contract approval. |
| Completion evidence is described by the API but has no database table yet. | Contract section 17 calls for an evidence table if evidence is implemented; the current `WorkOrder` only stores notes. | Add a `work_order_evidence` table through an EF Core migration before enabling the optional `completionEvidenceUrl` field. Save the file URL and WorkOrder link; never accept and discard evidence. |
| EF startup calls `EnsureCreated()` while migrations exist. | `Program.cs` and `Migrations/`. | Agree a PostgreSQL migration/deployment path before any schema correction; `EnsureCreated()` will not evolve existing tables. Compare the actual database to model and SQL first. |
| The client/testing baseline is partial. | React has report/problem API and pages but no dispatch UI. Flutter `main.dart` is the starter app; its WorkOrder and API service files are empty. No backend test project is present. | Plan small new slices and a PostgreSQL-backed API test harness. Keep Member 1/2/3 changes behind explicit integration needs. |
| Existing controller authorization is broad. | `ProblemsController` uses `[Authorize]` without an Admin role; JWT carries `sub`/name identifier and role, not crew ID. | Every new endpoint needs server-side role and row ownership checks from its first implementation. Existing controllers are a separate integration/security issue. |

## Phase 0 — repository and contract review

- **Goal:** Freeze Member 4's implementation inputs and identify exact integration owners before changing runtime code.
- **Files/components:** Review contract sections 3-8, 14-17, 23-30, 33-35; `problem-statement_UPDATED (1).md`; `database/Initial DB Structure.sql`; backend `Models/{WorkOrder,ApprovalHistory,WorkflowRun,WorkflowEvent,Crew,Problem,Report,User}.cs`, `Data/{AppDbContext,DbSeeder}.cs`, `Migrations/*`, `Program.cs`, auth and exception classes; React/Flutter API and auth entry points. Update this plan only if decisions change.
- **Tables:** `work_orders`, `approval_history`, `workflow_runs`, `workflow_events`, `crews`, `problems`, `reports` with nullable `problem_id`.
- **Endpoints / DTOs:** Inventory contract sections 14-17 and current controllers; no new endpoint or DTO in this phase.
- **Business rules:** Record lifecycle matrix, decision meaning, recommendation ID and validation provenance, active-work conflict definition, Problem resolution condition, and failed/cancelled ownership.
- **Authorization:** Confirm `ADMIN` and the five crew leader roles; verify `JWT.sub`/name identifier and `crews.crew_leader_user_id` linkage.
- **Clients:** Check navigation, token storage, and API error display; no UI work.
- **Tests:** Baseline `dotnet build`, React build, Flutter analyze where toolchains are available; inspect actual PostgreSQL schema without altering data; capture known failures.
- **Dependencies:** Verify the Agent 3 recommendation producer, its stable recommendation identity, evidence, and migration strategy; Member 2 agreement on the updated one-to-many Report–Problem behavior; Member 3 crew API/leader linkage; and synchronization of any older repo-local contract copy. The contract does not map Agent 3 to a numbered member, so identify that owner. The lifecycle and approval-history storage approaches are agreed.
- **Done:** A short decision record names an owner and approved solution for each blocking contract mismatch, plus a baseline build/schema report. No implementation is inferred from an unresolved item.
- **Risk:** The current SQL, EF model, migrations, and deployed DB can differ. Do not design a migration from files alone.

## Phase 1 — WorkOrder domain and database alignment

- **Goal:** Make the existing model safe for post-approval creation and audit, with only approved schema corrections.
- **Files/components:** Likely `backend/Mehewara.API/Models/{WorkOrder,ApprovalHistory}.cs`, `Data/AppDbContext.cs`, one new EF migration and `Migrations/AppDbContextModelSnapshot.cs`; update `database/Initial DB Structure.sql` as the documented baseline; coordinate `Program.cs` migration startup policy. Avoid duplicating `WorkOrder`.
- **Tables:** Existing `work_orders`, `approval_history`; `workflow_runs`/`workflow_events` only for agreed references. Do not add a recommendation or status-history table by default.
- **Endpoints / DTOs:** None; preserve contracted WorkOrder field names and statuses for later `WorkOrderResponse`.
- **Business rules:** UUID FKs to one Problem and Crew; `approval_history.recommendation_id` identifies the reviewed recommendation; nullable `work_order_id` is empty for rejection/revision and populated for approval; allowed priority/status values, UTC dates, no persisted unapproved dispatch, migration that preserves existing rows. Decide whether a database uniqueness/index guard is needed for one final approval per recommendation.
- **Authorization:** No data-changing public API; database writes remain backend-owned.
- **Clients:** None.
- **Tests:** Migration up on a fresh PostgreSQL database and representative existing-schema copy; verify reject/revision rows can have no WorkOrder ID and approved rows can link both IDs; FK/check/default verification; migration rollback or restore rehearsal; model mapping test. Check `EnsureCreated()` interaction.
- **Dependencies:** Phase 0 database inspection, stable recommendation ID contract, and migration deployment strategy. The `approval_history` change is agreed. The SQL baseline and final API contract now follow the existing one-to-many EF mapping; verify that any repo-local contract copy is synchronized during Phase 0.
- **Done:** Existing WorkOrder fields and constraints match the approved contract, approval decisions can be linked without pre-approval WorkOrders, and the migration is repeatable.
- **Risk:** Changing `approval_history.work_order_id` is a shared-schema amendment. If approval-history storage remains impossible, block review writes rather than weakening the approval rule.

### Phase 1 migration workflow

1. Inspect the target database and `__EFMigrationsHistory` first. Confirm whether it was created by EF migrations or by `EnsureCreated()`/the SQL script; take a backup before changing a shared or valuable database.
2. Update `ApprovalHistory` and its `AppDbContext` mapping: make `WorkOrderId` nullable and add `RecommendationId`. Decide how existing approval rows will be handled before making `RecommendationId` required; preserve and backfill data when possible.
3. Generate a migration from the backend project after Phase 0 chooses the migration strategy. Example from the repository root:

   ```powershell
   dotnet ef migrations add AllowPreWorkOrderReview `
     --project backend/Mehewara.API `
     --startup-project backend/Mehewara.API
   ```

4. Review the generated migration's `Up` and `Down` methods and `Migrations/AppDbContextModelSnapshot.cs`. Confirm existing rows are preserved and the new decision fields match the agreed schema. Update `database/Initial DB Structure.sql` so it describes a fresh database with the same shape.
5. Apply the migration to a disposable/fresh PostgreSQL database and a representative copy of the existing schema. Use the team's chosen migration mechanism. The CLI form, when appropriate, is:

   ```powershell
   dotnet ef database update `
     --project backend/Mehewara.API `
     --startup-project backend/Mehewara.API
   ```

   Do not assume this is safe against a database created by `EnsureCreated()`; reconcile or baseline that database first. `EnsureCreated()` does not apply migrations, so choose one schema-creation/update path rather than treating it as a migration runner.
6. Commit the entity/mapping, migration, snapshot, SQL baseline, and any migration-runner configuration together. Each developer and deployment environment then applies the checked-in migration through the agreed path before running code that uses the new schema.

## Phase 1B — completion evidence storage

- **Goal:** Give optional completion evidence a durable database record before the completion API accepts it.
- **Files/components:** New `backend/Mehewara.API/Models/WorkOrderEvidence.cs`; add a DbSet and mapping in `Data/AppDbContext.cs`; new EF migration and snapshot update; update `database/Initial DB Structure.sql`. Reuse the project's approved upload/storage service; do not store image bytes in PostgreSQL.
- **Tables:** New `work_order_evidence` with UUID `evidence_id`, required `work_order_id` FK, required `evidence_url`, and UTC `uploaded_at`; index by WorkOrder. Choose FK delete behavior consistent with preserving work/audit records.
- **Endpoints / DTOs:** No new endpoint or request model in this phase. The existing completion request's optional `completionEvidenceUrl` will be wired in Phase 5B after storage exists.
- **Business rules:** Evidence belongs to one WorkOrder and is saved only for that WorkOrder's authorized completion. The URL must come from the approved upload flow. Keep the database ready for optional evidence; completion without evidence remains valid.
- **Authorization:** No direct evidence CRUD endpoint. Later writes happen only inside the authenticated crew leader's authorized completion flow.
- **Frontend/mobile changes:** None in this schema phase.
- **Tests:** Migration on fresh and representative PostgreSQL databases; verify FK/index and that evidence can be associated with its WorkOrder; test preservation of existing WorkOrders. Confirm the migration runner applies the schema.
- **Dependencies:** Phase 1 migration strategy and the contract's completion upload flow. No evidence request is accepted until this table and upload integration are ready.
- **Done:** A checked-in EF migration and SQL baseline define evidence storage linked to WorkOrders; existing jobs remain intact.
- **Risk:** File storage and PostgreSQL cannot share one transaction. If the database save fails after upload, the upload flow needs a cleanup/retry policy.

## Phase 2 — coordinator WorkOrder read API

- **Goal:** Let Admins inspect stored WorkOrders before any mutation API is added.
- **Files/components:** New `Controllers/WorkOrdersController.cs`, `Services/Interfaces/IWorkOrderService.cs`, `Services/Implementations/WorkOrderService.cs`, `DTOs/WorkOrders/{WorkOrderResponse,GetWorkOrdersQuery}.cs`; register in `Program.cs`. Reuse existing EF query style, `Common/PagedResult.cs`, and exceptions.
- **Tables:** Read `work_orders`, `problems`, `crews`; do not change data.
- **Endpoints / DTOs:** `GET /api/work-orders` with `page`, `pageSize`, `crewId`, `problemId`, `priority`, `status`, `fromDate`, `toDate`, `sortBy`, `sortDirection`; `GET /api/work-orders/{workOrderId}` initially Admin only. `WorkOrderResponse`: `id`, `problemId`, `crewId`, `priority`, `title`, `instructions`, `status`, `assignedAt`, `startedAt`, `completedAt`, `completionNotes`, `createdAt`, `updatedAt`. Add only contracted detail fields.
- **Business rules:** Whitelist filters and sort columns; defaults `page=1`, `pageSize=20`, `createdAt desc`; validate bad query values; stable ordering and UTC serialization; no generic create/update route.
- **Authorization:** `[Authorize(Roles="ADMIN")]` for list; Admin detail only until crew ownership handling is present.
- **Clients:** None yet.
- **Tests:** Admin list/detail, filters, pagination/count, invalid query, empty list, missing ID, resident/crew list denial, camelCase and UTC response shape.
- **Dependencies:** Phase 1 schema; seeded/admin test identity.
- **Done:** Admin can read WorkOrders with the documented filters and no mutation route exists.
- **Risk:** Two `PagedResult<T>` types exist in `Common` and `DTOs/Common`; choose the one consistent with existing API responses rather than introducing a third.

## Phase 3A — recommendation read adapter

- **Goal:** Expose persisted, reviewable recommendation data without creating a new shared table or generating AI output in Member 4 code.
- **Files/components:** New `Controllers/DispatchRecommendationsController.cs`, `Services/Interfaces/IRecommendationReviewService.cs`, `Services/Implementations/RecommendationReviewService.cs`, `DTOs/Dispatch/{RecommendationResponse,GetRecommendationsQuery}.cs`; register service in `Program.cs`.
- **Tables:** Read `workflow_runs`, `workflow_events`, `problems`, `crews`, `reports.problem_id`, and approval decisions.
- **Endpoints / DTOs:** `GET /api/dispatch/recommendations`; `GET /api/dispatch/recommendations/{recommendationId}`. Contract fields: recommendation/workflow/Problem references, priority/score/reasons, required crew type, recommended crew, reason, validation status/issues, nullable `reviewDecision`, UTC `createdAt`; contracted pagination/filter fields.
- **Business rules:** Only persisted recommendation events with an agreed stable ID are returned. Treat absent/malformed/old workflow data as non-reviewable, never as `VALID`. No hidden chain-of-thought in responses.
- **Authorization:** Admin only; unauthorized users cannot enumerate recommendations.
- **Clients:** None.
- **Tests:** Fixture with valid/revision/safe-failure/absent validation; stable ID, sorting, filtering, serialization, denial for non-Admin.
- **Dependencies:** Agreed recommendation event payload and identity from Agent 3/workflow owner. Agent 4 is out of scope; fixture validation tests the adapter only.
- **Done:** A real persisted recommendation can be read in the frozen shape. No synthetic production recommendation is emitted.
- **Risk:** The current AI client completes at Problem consolidation. This phase can be tested against fixtures but cannot expose a live review queue until the producer integration exists.

## Phase 3B — non-dispatch human review actions

- **Goal:** Record coordinator edit, reject, and revision/regeneration decisions without dispatch.
- **Files/components:** Extend `DispatchRecommendationsController`, `IRecommendationReviewService`, and its implementation; likely new `Controllers/ReviewsController.cs`; new `DTOs/Dispatch/{RecommendationEditRequest,ReviewReasonRequest,ReviewDecisionResponse,RejectedReportResponse,GetRejectedReportsQuery}.cs`; approved `ApprovalHistory`/workflow-event mapping only.
- **Tables:** `workflow_events`, `workflow_runs`, `approval_history`; no `work_orders` insert.
- **Endpoints / DTOs:** `PATCH /api/dispatch/recommendations/{recommendationId}` with `priority`, `priorityScore`, `recommendedCrewId`, required `editReason`; `POST .../reject` with required `reason`; `POST .../regenerate` with `reason` and contracted `202` response **only when** real workflow enqueue exists; `GET /api/reviews/rejected-reports` with the frozen paged report/problem/rejected-recommendation shape. If regeneration integration is absent, return a defined unavailable response rather than falsely reporting queued work. No new `/request-revision` endpoint.
- **Business rules:** Validate edits server-side; append edit/decision audit; preserve old recommendation; block re-review after a final decision; reject/revision never create WorkOrders or set Report status to `REJECTED`. Confirm whether `/regenerate` maps to `REVISION_REQUIRED` and how new recommendation IDs are linked.
- **Authorization:** Admin only; actor ID from JWT, not request body.
- **Clients:** None yet.
- **Tests:** Required reason/editReason, invalid priority/score/crew, repeat reject, edit after final review, rejected-reports paging and access, no WorkOrder on reject/regenerate, actor/audit accuracy, actual enqueue versus unavailable response.
- **Dependencies:** Phases 1 and 3A; workflow owner for regeneration; approved pre-order approval-history linkage.
- **Done:** Edit and reject persist correctly; regenerate works end to end when the workflow producer is ready, or is explicitly unavailable with no false success.
- **Risk:** `REVISION_REQUIRED` is a decision value, but the contract does not specify a separate human revision route or exact state transition.

## Phase 3C — atomic approval and authorized dispatch

- **Goal:** Make the one and only normal WorkOrder creation path a successful Admin approval.
- **Files/components:** Extend dispatch controller/service; new `DTOs/Dispatch/ApproveRecommendationRequest.cs` and approval response DTO; reuse `WorkOrderResponse`, `ConflictException`, EF context/transaction, and `Program.cs` registration.
- **Tables:** `workflow_events`, `workflow_runs`, `approval_history`, `work_orders`, `crews`, `problems`, `reports.problem_id`.
- **Endpoints / DTOs:** `POST /api/dispatch/recommendations/{recommendationId}/approve` with optional `reason`; `201 Created` including recommendation ID, `APPROVED`, actor/time, and assigned WorkOrder summary. No standalone create endpoint.
- **Business rules:** In one PostgreSQL transaction, lock/recheck review state and crew availability; verify persisted recommendation and its validation provenance, Problem, and any `reports.problem_id` link, allowed priority, crew existence/type/status, and no conflicting active work; insert `ASSIGNED` WorkOrder and approval record; set relevant assignment statuses according to the approved contract; mark crew `BUSY` only under an agreed crew-availability rule. Any failure rolls back all changes. Use a DB/transaction guard so two coordinators cannot both dispatch; map repeats to `409 RECOMMENDATION_ALREADY_REVIEWED`, unavailable crew to `409 CREW_UNAVAILABLE`.
- **Authorization:** Admin only; no client-supplied actor or arbitrary crew override on approve. A prior edit must have passed server validation.
- **Clients:** None yet.
- **Tests:** Successful transaction; duplicate/concurrent approval (exactly one WorkOrder); crew becomes busy; mismatched type; invalid/missing Problem or link; non-valid/missing validation; duplicate active work; rollback on audit failure; non-Admin denial. PostgreSQL integration tests are essential.
- **Dependencies:** Phases 0-3B; approved one-to-many contract behavior; persisted recommendation producer and authoritative validation status. Agent 4 implementation is **not** part of this phase. Until its validated output exists, production approval must remain gated.
- **Done:** The only successful approval creates exactly one assigned WorkOrder with linked approval/audit data; every failed check creates none.
- **Risk:** The frozen contract requires both AI validation and fresh ASP.NET validation. A test fixture can prove the software path; it is not permission to accept unvalidated live recommendations.

## Phase 4 — crew assigned-jobs API

- **Goal:** Return only jobs owned by the authenticated crew leader's crew.
- **Files/components:** New `Controllers/CrewWorkOrdersController.cs` or an explicit `api/crew/work-orders` route; extend WorkOrder service and DTO query; extend WorkOrder detail route with row-level ownership guard.
- **Tables:** `crews`, `users`, `work_orders`, limited linked Problem data.
- **Endpoints / DTOs:** `GET /api/crew/work-orders`; `GET /api/work-orders/{workOrderId}` for own crew. Reuse `WorkOrderResponse`; query fields only where specified/agreed.
- **Business rules:** Resolve crew by `crews.crew_leader_user_id = JWT.sub`; never accept a crew ID from the client as the authorization source; return permitted assigned/execution/history jobs with deterministic order.
- **Authorization:** Crew leader roles only, with database ownership check on every row; no linked crew yields denial/empty list according to agreed error semantics. Admin retains detail access; residents see none.
- **Clients:** None yet.
- **Tests:** Two leaders from different crews; list and detail isolation, guessed foreign UUID, missing crew link, Admin/resident behavior, inactive user if existing auth policy covers it.
- **Dependencies:** Phases 1-2; Member 3's crew assignments/leader link and seeded test users.
- **Done:** Cross-crew reads fail and list results contain no foreign-crew row.
- **Risk:** Role name alone does not prove crew membership; JWT intentionally has no `crewId`.

## Phase 5A — server-side start transition

- **Goal:** Implement the frozen `ASSIGNED -> IN_PROGRESS` execution step.
- **Files/components:** Extend `WorkOrdersController`, `IWorkOrderService`, `WorkOrderService`; transition response DTO if the full `WorkOrderResponse` cannot be reused cleanly.
- **Tables:** Update `work_orders`; agreed `problems` status and `workflow_events` audit association.
- **Endpoints / DTOs:** `POST /api/work-orders/{workOrderId}/start`; response `id`, `status`, `startedAt`, `updatedAt`. No request body is required by the contract.
- **Business rules:** Only current `ASSIGNED` may start; set UTC times; one atomic update; invalid/repeated transitions return `409 INVALID_WORK_ORDER_STATE`; missing ID is 404. Do not add `ACCEPTED`.
- **Authorization:** Own crew leader only, checked in the transition query/service as well as route role metadata.
- **Clients:** None yet.
- **Tests:** Valid start, repeat start, start from every other status, concurrent starts, foreign crew, resident/Admin denial, timestamp and audit behavior.
- **Dependencies:** Phases 3C/4 or seeded approved WorkOrder fixtures; agreed workflow-event association.
- **Done:** A valid own-crew start changes exactly one row once; all invalid calls leave it unchanged.
- **Risk:** Audit event writing must share the state-change transaction; otherwise a transition can appear without history.

## Phase 5B — server-side completion transition

- **Goal:** Implement `IN_PROGRESS -> COMPLETED` with notes, while preserving a clean hook for Phase 8 propagation.
- **Files/components:** Extend WorkOrder controller/service; new `DTOs/WorkOrders/CompleteWorkOrderRequest.cs` and completion response; reuse exception/error middleware and `WorkOrderEvidence` persistence.
- **Tables:** Update `work_orders`; insert optional evidence metadata in `work_order_evidence`; append `workflow_events`; Problem/Report updates are added atomically in Phase 8.
- **Endpoints / DTOs:** `POST /api/work-orders/{workOrderId}/complete` with optional `completionNotes` and optional `completionEvidenceUrl` from the approved upload flow. Response includes `id`, `status`, notes, `completedAt`, `updatedAt`.
- **Business rules:** Current state must be `IN_PROGRESS`; optional notes are validated for length/content if provided; validate evidence URL against the approved upload flow; store evidence and completion state together in a database transaction; store UTC completion time; repeated/invalid completion returns `409 INVALID_WORK_ORDER_STATE`. Keep the operation transactional so Phase 8 can extend it.
- **Authorization:** Own crew leader only.
- **Clients:** None yet.
- **Tests:** Valid completion with/without notes or evidence, invalid/repeated/concurrent completion, foreign crew, malformed/untrusted evidence URL, and rollback if evidence metadata cannot be saved.
- **Dependencies:** Phase 5A, Phase 1B evidence table, approved upload flow, and audit link.
- **Done:** Completion is accepted exactly once from `IN_PROGRESS`; supplied evidence is stored against that WorkOrder and completion can be verified through API/audit data.
- **Risk:** Blob upload can succeed while the PostgreSQL transaction fails; use the upload service's retry or orphan-cleanup behavior.

## Phase 6 — authorization and security regression

- **Goal:** Verify all new routes and service paths enforce role plus row ownership, independent of UI checks.
- **Files/components:** Review new controllers/services, `Services/Implementations/TokenService.cs`, `Program.cs` JWT setup, exception middleware, and relevant tests; change existing auth code only if integration proves necessary.
- **Tables:** Read `users`, `roles`, `crews`, `work_orders`; no schema change.
- **Endpoints / DTOs:** All Phase 2-5 endpoints; no new public contract.
- **Business rules:** Never trust URL IDs, body actor IDs, or a client-selected crew as proof of ownership; avoid leaking foreign job details through errors or nested DTOs; consistent 401/403/404/409 semantics.
- **Authorization:** Test unauthenticated, resident, Admin, each crew leader, unlinked leader, and two-crew cross-access matrix; verify both read and mutation paths.
- **Clients:** None; client hiding is supplementary only.
- **Tests:** API integration suite for every role/endpoint combination, changed crew-leader mapping after JWT issue, direct service invocation where relevant, negative ID enumeration tests.
- **Dependencies:** Phases 2-5 and stable auth seed data.
- **Done:** No unauthorized caller can read or alter another crew's WorkOrder or approve dispatch.
- **Risk:** Existing non-Member-4 controllers may have broad `[Authorize]`; record and coordinate any separate fix rather than expanding this phase silently.

## Phase 7 — append-only history and coordinator monitoring

- **Goal:** Show current and historical WorkOrder state with a trustworthy audit trail.
- **Files/components:** Extend WorkOrder service/read DTOs/controller, review service, `Models/WorkflowEvent.cs` mapping if needed; optional new `DTOs/WorkOrders/WorkOrderHistoryEntryResponse.cs` only if an approved API shape is agreed. Reuse existing `approval_history` and `workflow_events`.
- **Tables:** `work_orders`, `approval_history`, `workflow_runs`, `workflow_events`, `crews`, `problems`.
- **Endpoints / DTOs:** Existing `GET /api/work-orders` filters include `ASSIGNED`, `IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED`, and legacy `PENDING_APPROVAL`; existing detail may include approved history fields if contract is extended. No new history endpoint without shared agreement.
- **Business rules:** Append creation, start, completion, edit/reject/revision/approval events with actor, UTC time, prior/new state and IDs; never overwrite audit rows. Read stored `FAILED`/`CANCELLED` states even though no transition endpoint is contracted. Define who may mark failure/cancellation before adding any action.
- **Authorization:** Monitoring/history for Admin; crew detail may expose only own execution history after DTO privacy review.
- **Clients:** None yet.
- **Tests:** Chronological history, event attribution, transaction rollback if event insert fails, status/date filters, cancelled/failed seeded rows, no unrelated workflow data leak.
- **Dependencies:** Approval and execution phases; approved WorkOrder-to-workflow association.
- **Done:** Admin can filter all contracted states and explain each implemented state change from append-only records.
- **Risk:** `workflow_events` has a required `agent_name`; agree a clear human/system event convention. Failure/cancellation *visibility* must not be mistaken for an authorized failure/cancel API.

## Phase 8 — completion propagation to Problem and Report

- **Goal:** Make completed required work update linked lifecycle state in the same authoritative transaction.
- **Files/components:** Extend `WorkOrderService`; coordinate only necessary integration edits in `Models/{Problem,Report}.cs`, `Data/AppDbContext.cs`, Member 2 link/query service, and existing response projections. No FastAPI write.
- **Tables:** `work_orders`, `problems`, `reports.problem_id`, `workflow_events`, `crews`.
- **Endpoints / DTOs:** Existing approve/start/complete endpoints perform status changes; existing Problem/Report read DTOs show updated statuses. No new public route.
- **Business rules:** Verify Phase 3C assignment and Phase 5A start status effects remain correct. On completion, resolve Problem only when its required WorkOrders are complete under an agreed rule; a Report linked through `reports.problem_id` becomes `RESOLVED` when that Problem is resolved. A Report has at most one linked Problem under the chosen relationship. Keep `CANCELLED` reports cancelled. Set crew availability consistently with remaining active jobs. All completion/status/audit changes commit or roll back together.
- **Authorization:** Only the authorized approval/own-crew transition paths may cause propagation; never expose a direct Report status mutation for clients.
- **Clients:** Existing Resident/Coordinator reads should reflect new state; UI changes remain later phases.
- **Tests:** One Problem linked to multiple Reports; Report with no Problem link; verify a Report cannot reference more than one Problem; multiple required WorkOrders; concurrent completions; cancelled report; rollback; read-after-write across endpoints.
- **Dependencies:** Phase 5B; Member 2 integration against the selected one-to-many link; team decision on required WorkOrders, `FAILED`/`CANCELLED`, and crew availability.
- **Done:** Completion and derived statuses remain consistent in PostgreSQL under the approved one-to-many relationship, and resident read APIs show the result.
- **Risk:** The final API contract now defines one linked Problem per Report. Confirm Member 2's status propagation follows that rule and keeps Reports without a Problem link unresolved until the lifecycle permits resolution.

## Phase 9A — React recommendation review UI

- **Goal:** Give Admins a typed, reviewable recommendation queue and decision controls.
- **Files/components:** New `web/mehewara-web/src/types/dispatch.ts`, `services/dispatchApi.ts`, `pages/dispatch/RecommendationsPage.tsx` and styling; minimal navigation integration in `src/App.tsx` and existing header/page navigation.
- **Tables:** None directly; ASP.NET owns PostgreSQL access.
- **Endpoints / DTOs:** Call Phase 3 recommendation list/detail, edit, approve, reject, regenerate routes and exact camelCase DTOs. Surface server error codes/messages.
- **Business rules:** Show validation/reasoning summary, linked Problem/Crew, review state, and explicit decision confirmation; refresh after mutation; do not invent `VALID` or create WorkOrders client-side. Disable actions after a final decision while trusting server as authority.
- **Authorization:** Show to `ADMIN`; send JWT; server enforcement remains decisive.
- **Clients:** React only; keep existing reports/problems pages intact except navigation links.
- **Tests:** TypeScript build, component/API mock tests for each decision and 409/403 handling, manual keyboard/readability check.
- **Dependencies:** Phase 3 read/review APIs and live producer for an actual queue; existing React auth state.
- **Done:** Admin can review, edit, reject, and approve against ASP.NET and see the created WorkOrder; regenerate is shown only when its backend action works.
- **Risk:** Current React navigation is a local `viewMode` union, so add a small route/view change without replacing app navigation architecture.

## Phase 9B — React WorkOrder monitoring UI

- **Goal:** Let coordinators filter and inspect work progress and available history.
- **Files/components:** New `web/mehewara-web/src/types/workOrders.ts`, `services/workOrderApi.ts`, `pages/work-orders/WorkOrdersPage.tsx` and styles; `src/App.tsx`/header navigation.
- **Tables:** None directly.
- **Endpoints / DTOs:** `GET /api/work-orders`, `GET /api/work-orders/{id}`; approved history fields if exposed. Reuse pagination/query names exactly.
- **Business rules:** Display current status, crew, Problem, timestamps, notes, and filters for assigned/in-progress/completed/failed/cancelled; legacy pending if present. Do not add unsupported cancel/fail buttons.
- **Authorization:** Admin UI only; backend role check required.
- **Clients:** React coordinator pages.
- **Tests:** Build, filter/pagination mapping, empty/loading/error states, UTC display handling, role-based navigation.
- **Dependencies:** Phases 2 and 7; Phase 8 for final propagated status display.
- **Done:** Coordinator can find and monitor each contracted WorkOrder status from backend data.
- **Risk:** Status labels in UI must follow frozen values; `ACCEPTED` is not available under this contract.

## Phase 10A — Flutter assigned-jobs read flow

- **Goal:** Replace the starter screen for a crew leader with an own-crew jobs list and detail view.
- **Files/components:** Fill `mobile/mehewara_mobile/lib/services/work_orders/work_order_service.dart`; add a WorkOrder model and `lib/screens/work_orders/` list/detail widgets; integrate minimally with `lib/main.dart`, existing auth/API/storage files once Member 1 mobile integration is available.
- **Tables:** None directly.
- **Endpoints / DTOs:** `GET /api/crew/work-orders`, `GET /api/work-orders/{id}`; parse frozen `WorkOrderResponse` and API errors.
- **Business rules:** Display only server-returned jobs; refresh after navigation; handle empty/expired session; no direct FastAPI call or client crew-ID selector.
- **Authorization:** Crew leader login/token; backend resolves crew.
- **Clients:** Flutter only.
- **Tests:** Model JSON parsing, service mocked HTTP, list/detail widget states, foreign-job 403/404 handling; `flutter analyze` and targeted widget tests.
- **Dependencies:** Phase 4 API and Member 1/mobile auth/API client foundation (currently empty/starter files).
- **Done:** A logged-in crew leader sees only their assigned crew's backend WorkOrders.
- **Risk:** Flutter network/auth services are currently empty, so coordinate ownership rather than building a second competing authentication stack.

## Phase 10B — Flutter start and complete flow

- **Goal:** Let a crew leader start and complete an own-crew job from the mobile app.
- **Files/components:** Extend WorkOrder service and `lib/screens/work_orders/` detail/action widgets; completion form; reuse shared error/token handling.
- **Tables:** None directly.
- **Endpoints / DTOs:** `POST /api/work-orders/{id}/start`; `POST /api/work-orders/{id}/complete` with optional `completionNotes`; add evidence UI only after the approved evidence backend exists.
- **Business rules:** Show Start only for `ASSIGNED`, Complete only for `IN_PROGRESS`, submit once, refresh from server after success, surface 409 conflicts, avoid optimistic status authority. No Accept action under frozen contract.
- **Authorization:** Crew leader JWT; server checks own crew for every action.
- **Clients:** Flutter crew workflow.
- **Tests:** Widget/service tests for valid transitions, duplicate tap/loading, 401/403/409/error recovery, notes serialization; device/simulator smoke test.
- **Dependencies:** Phase 10A, Phases 5A/5B/8, Phase 1B evidence storage, and approved upload flow.
- **Done:** Crew leader can start and complete an own-crew job and sees server-confirmed status and notes.
- **Risk:** Optional evidence is a contract field without current storage; do not present a control that loses uploaded evidence.

## Phase 11 — integration and end-to-end verification

- **Goal:** Prove the resident-to-coordinator-to-crew flow and the negative security/transaction cases across platforms.
- **Files/components:** New backend API/integration test project under `backend/` (name agreed with team); targeted React/Flutter tests; test fixtures and CI/test instructions. Avoid altering unrelated feature code except verified integration fixes.
- **Tables:** All authoritative tables: `reports.problem_id`, `problems`, `crews`, `workflow_runs`, `workflow_events`, `approval_history`, `work_orders`, `work_order_evidence`.
- **Endpoints / DTOs:** Contracted report, problem, recommendation, WorkOrder, crew, and resident read APIs; exact status/error response shapes.
- **Business rules:** Validated recommendation -> Admin approval -> one assigned WorkOrder -> own crew start/complete -> Problem resolution -> linked Report resolution; reject/revision makes no WorkOrder; concurrency and rollback are repeatable.
- **Authorization:** Resident/Admin/two crew identities; verify denied direct access, guessed IDs, and cross-crew mutations.
- **Clients:** React coordinator review/monitoring, Flutter crew execution, resident status refresh through ASP.NET. FastAPI is internal only.
- **Tests:** PostgreSQL-backed API tests for constraints and concurrent approval; backend unit tests for transition rules; React build/tests; Flutter analyze/widget tests; manual cross-platform golden-flow demo; serialized UUID/camelCase/UTC/error checks.
- **Dependencies:** Prior phases plus Member 1 reports/mobile auth, Member 2 consolidation aligned to the approved one-to-many contract, Member 3 crew API, the confirmed owner of Agent 3 priority/crew recommendation output, and eventual Agent 4 validated result. Agent 4 code remains outside this plan.
- **Done:** The documented golden flow passes using real persisted data; role and race tests pass; known contract gaps are resolved by approved changes or explicitly remain blocked with no unsafe fallback.
- **Risk:** A fixture-only recommendation proves Member 4 behavior but is not a complete live AI-to-approval demonstration.

## Recommended sequence and first coding checkpoint

Proceed **0 -> 1 -> 1B -> 2 -> 3A -> 3B -> 3C -> 4 -> 5A -> 5B -> 6 -> 7 -> 8 -> 9A -> 9B -> 10A -> 10B -> 11**. A phase can be tested with explicit persisted fixtures while its upstream producer is being built, but a live dispatch path stays closed until all required gates are satisfied. After each code phase, run the focused tests, inspect the API contract, and run `graphify update .` as required by `AGENTS.md`.

Start **Phase 0 first**. Before writing Phase 1 code, inspect the actual PostgreSQL schema and migration history, the complete frozen contract sections listed above, `AppDbContext`/WorkOrder/ApprovalHistory/workflow models, `Program.cs` startup behavior, the producer's proposed recommendation event JSON/ID and validation status, Member 2's Report–Problem endpoint behavior, and Member 3's crew leader linkage. The lifecycle, approval-history storage approach, and one-to-many database choice are settled; confirm the stable recommendation ID and migration deployment path, and verify the final API contract and any repo-local contract copy match the chosen one-to-many relationship before implementing dependent endpoints.
