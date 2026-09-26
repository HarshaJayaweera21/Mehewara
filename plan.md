# Member 4: review, dispatch, and WorkOrder execution

## 1. Findings and agreed scope

**The current Member 4 slice needs five new public endpoints, corrections to the existing review and approval endpoints, and React/Flutter integration. Regeneration is deferred until Member 3's recommendation implementation and interface are ready.**

The existing [DispatchController](E:/sliit/3YS1/SE/Assignment/CivicWorks/Mehewara/backend/Mehewara.API/Controllers/DispatchController.cs:10) already provides recommendation review APIs. Extend this implementation.

Source inspection confirmed these gaps:

| Area                  | Current implementation                                       | Required work                                                      |
| --------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------ |
| Recommendation review | List, detail, edit, approve, reject, regenerate routes exist | Correct validation, decision tracking, and client contracts        |
| Approval              | Creates an assigned WorkOrder                                | Protect against simultaneous approvals and stale crew availability |
| Rejection             | Source records a decision without a WorkOrder; inspected Docker schema has the needed columns, FK, and index but no EF history | Verify live behavior and resolve migration-history ambiguity before future EF deployment |
| Regeneration          | Records a request without executing Agent 3                   | Defer the execution design until Member 3's recommendation interface is settled |
| Work execution        | WorkOrder model exists                                       | Build read, start, and completion operations                       |
| React                 | Dispatch screens exist; crew leader job dashboard is absent  | Fix integration, add WorkOrder monitoring, and build crew job execution |
| Flutter               | Counter starter; service placeholders                        | Build crew login, job list/detail, start, and completion           |
| History               | Workflow and approval tables exist; `activity_history` is present in the inspected Docker database, and recommendation edits write audit rows | Add crew start/completion events with the new APIs |

Agreed current scope: review and authorized dispatch, WorkOrder execution and monitoring, role-based web and Flutter crew dashboards, and notes-only completion. Agent 4 and functional regeneration remain later features. For this release, approval uses genuine backend business validation; the UI must identify Agent 4 validation as unavailable.

Crew leaders will manage their jobs through both React web and Flutter mobile. Each client provides one dynamic crew dashboard shared by all five existing `CREW_LEADER_*` roles; its data comes from the authenticated leader's crew association. This is planned functionality, not an existing implementation. Separate accounts or permissions for individual crew members are outside this scope.

### Development demo accounts and role access

Reuse the accounts already defined in `backend/Mehewara.API/Data/DbSeeder.cs`: one Admin (`admin@mehewara.gov.lk`), one resident (`resident@example.com`), and five crew leaders (`crew.drainage@mehewara.gov.lk`, `crew.road@mehewara.gov.lk`, `crew.waste@mehewara.gov.lk`, `crew.electrical@mehewara.gov.lk`, and `crew.environment@mehewara.gov.lk`). The seeder also links each crew leader to the matching Crew through `CrewLeaderUserId`. These are development and demonstration accounts; use the existing login API and JWT role claim for both clients, rather than introducing a separate demo authentication path. Existing accounts are skipped by the seeder, so startup does not reset their credentials.

All five existing `CREW_LEADER_*` role codes share the same crew-job permissions; the linked Crew determines which jobs each leader can access. Keep these role codes for this implementation and group them under one crew-leader authorization policy. Public signup, including new Google accounts, continues to create residents only. Admin and crew leader accounts come from the existing seed data during development; no public staff-role selection or new account-provisioning endpoint is part of this release. Do not embed demo credentials in React or Flutter.

## 2. API endpoints

### New public endpoints

| Method | Endpoint                                  | Access                      | Purpose                                                                                                     |
| ------ | ----------------------------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| GET    | `/api/work-orders`                        | ADMIN                       | Paginated monitoring with status, priority, crew, Problem, and date filters                                 |
| GET    | `/api/work-orders/{workOrderId}`          | ADMIN or owning crew leader | Job details, location, instructions, timestamps, completion notes, and permitted history                    |
| GET    | `/api/crew/work-orders`                   | Crew leader                 | Jobs belonging to the authenticated leader’s crew                                                           |
| POST   | `/api/work-orders/{workOrderId}/start`    | Owning crew leader          | Transition `ASSIGNED → IN_PROGRESS`; no request body                                                        |
| POST   | `/api/work-orders/{workOrderId}/complete` | Owning crew leader          | Transition `IN_PROGRESS → COMPLETED`; optional `completionNotes`                                            |

Use existing camelCase JSON, UUIDs, UTC timestamps, pagination envelopes, and error conventions. New lists default to page 1 and 20 items, capped at 100. Start and complete return the updated WorkOrder.

React and Flutter crew dashboards consume the same crew list, WorkOrder detail, start, and complete endpoints above. Adding web access requires no additional public endpoints or platform-specific permissions. The backend resolves crew ownership from the authenticated user on both clients.

### Existing endpoints to correct

All remain ADMIN-only.

| Endpoint                                                           | Required correction                                                            |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| GET `/api/dispatch/recommendations`                                | Read normalized recommendations and decisions belonging to each recommendation |
| GET `/api/dispatch/recommendations/{recommendationId}`             | Include real backend validation and review history                             |
| PATCH `/api/dispatch/recommendations/{recommendationId}`           | Require `editReason`, preserve original AI output, audit edits, and revalidate |
| POST `/api/dispatch/recommendations/{recommendationId}/approve`    | Perform fresh transactional checks and create exactly one WorkOrder            |
| POST `/api/dispatch/recommendations/{recommendationId}/reject`     | Require a reason; save rejection without creating a WorkOrder                  |

The existing `POST /api/dispatch/recommendations/{recommendationId}/regenerate` currently records request metadata and returns `202`; it does not run Agent 3 or produce a new recommendation. Leave functional regeneration, any new workflow-status API, and any backend-to-AI integration endpoint out of this slice. Define those interfaces with Member 3 after their recommendation output and rerun behavior are agreed. Do not advertise the current `202` response as completed regeneration.

WorkOrders are created through approval. The lifecycle is `ASSIGNED → IN_PROGRESS → COMPLETED`; there is no separate accept action. Cancellation, failure actions, and photo evidence are deferred.

## 3. Backend implementation

**Recommendation integrity and review**

- Correct [AiWorkflowClient](E:/sliit/3YS1/SE/Assignment/CivicWorks/Mehewara/backend/Mehewara.API/Integrations/AiService/AiWorkflowClient.cs:176) to persist the actual Problem association, replace `NEW_PROBLEM` with the created UUID, and normalize `NONE` to a null crew. Malformed results must be recorded as unusable.
- Remove automatic `VALID` results. Validate Problem/report links, allowed priority and score, crew specialty, current availability, active work conflicts, and review eligibility.
- Keep recommendation identity as its workflow-event UUID. Preserve original output; append coordinator overrides and before/after history. Reads and approval use the latest validated override.
- Make approval history’s WorkOrder link nullable and add recommendation linkage. Add WorkOrder-to-recommendation linkage for reliable execution history.
- Approved and rejected recommendations cannot be approved again. Decide how a future regenerated recommendation supersedes an earlier one when Member 3's interface is agreed.

**Atomic dispatch and execution**

- Extend [DispatchService](E:/sliit/3YS1/SE/Assignment/CivicWorks/Mehewara/backend/Mehewara.API/Services/Implementations/DispatchService.cs:363); add a shared WorkOrder service.
- Lock and recheck recommendation, Problem, and crew state inside the approval transaction. Add database uniqueness protection for approved recommendations and active orders per crew and Problem.
- Resolve crew ownership through `CrewLeaderUserId` and the authenticated user ID on every read/write.
- Approval creates `ASSIGNED` work, marks the crew `BUSY`, and updates the Problem and non-cancelled reports.
- Start updates the WorkOrder and Problem to `IN_PROGRESS`; reports remain `ASSIGNED`.
- Completion records notes/timestamps, resolves the Problem and non-cancelled linked reports when no active work remains, completes the originating workflow, and releases the crew when appropriate. Preserve `UNAVAILABLE` crew status.
- Commit status changes and audit events together. Repeated/invalid transitions return `409`; validation failures use existing `400` conventions.

**Deferred regeneration dependency**

- Wait for Member 3 to finalize the recommendation input/output contract and supported rerun behavior before deciding how to invoke Agent 3 again, store requests and results, or expose progress and failure.
- Revisit queue/storage needs, workflow linkage, supersession rules, API responses, and tests with Member 3. No regeneration job table, worker, or new AI endpoint is committed to the current database and backend slice.

**Database rollout**

Use forward EF migrations and an explicit migration deployment step, replacing reliance on `EnsureCreated`. Check schema/migration history and conflicting active orders before upgrading. Preserve legacy records; do not guess ambiguous recommendation links or delete rejection placeholders.

The review-history slice is implemented in source: new decisions link to the recommendation, and rejection no longer creates a WorkOrder. The inspected Docker database already has the review-history columns, foreign key, and index, but its EF migration-history table was absent in later checks; how it reached that state remains unverified. Do not rerun the first migration on that schema. WorkOrder-to-recommendation linkage is implemented in source with EF migration `20260926054657_LinkWorkOrderToRecommendation` and has been verified in the user's Docker database. Approval and rejection now lock and recheck rows within a transaction; EF migration `20260926075934_ProtectDispatchConcurrency` records the uniqueness rules for developers. The user applied the manual SQL and supplied query output confirming all four unique indexes and their predicates in Docker. Runtime concurrency behavior is not yet tested. Regeneration remains later work.

The human `activity_history` table is implemented in the EF model and migration `20260926084022_AddActivityHistory`; its schema-only SQL and checks are in `database/migrations/MANUAL_APPLY_ACTIVITY_HISTORY.txt`. Read-only inspection confirmed the table, columns, constraints, and indexes in the Docker database. Recommendation edits now capture the before/after recommendation JSON, actor, reason, and time in the same transaction as the edit. Crew start/completion audit writes follow when those APIs are implemented. Approval/rejection decisions remain only in `approval_history`.

## 4. Client implementation and delivery order

**React coordinator dashboard:** retain the existing dispatch screens and correct their review DTOs: edits send `editReason`, approval sends `reason`, and approval reads `response.workOrder.id`. Display server validation instead of hard-coded passing checks. Add WorkOrder list/detail/history and keep the existing Admin crew directory available for coordinator use. Do not present the existing regenerate action as a completed AI rerun; defer its functional UI integration with Member 3.

**React crew dashboard:** add a protected My Jobs view with assigned, in-progress, and completed job lists, status filters, job details/location, priority, instructions, timestamps, and execution history. Provide Start Job and Complete Job actions with optional completion notes. Use one reusable layout for all five crew types, populated from the authenticated leader's own jobs.

**React navigation and access:** direct crew leaders to My Jobs after login, session restoration, and return from profile. Retain the existing Admin and resident destinations. Restrict crew screens to the five existing crew leader roles and coordinator screens to Admin; enforce ownership again in the API. A leader with no crew association sees an explanatory access state and cannot perform job actions. Do not use the Admin crew directory as the crew leader's job dashboard.

**Flutter:** implement crew login using existing authentication APIs, authenticated API access, assigned/history job lists, job details/location, start, and notes-only completion. Handle expired sessions, ownership errors, connection failures, and stale-state conflicts. Keep the resident mobile feature outside this Member 4 slice.

**Cross-platform behavior:** offer the same crew job lifecycle on React and Flutter, with layouts adapted to desktop and mobile. Both clients display server state, refresh after mutations and when returning to the job screen, and reload the job on a stale-state conflict. Handle loading, empty, expired-session, ownership, and connection-error states on both clients. A change made on either platform is visible on the other after refresh; live push updates are not required in this release. Administrator mobile screens remain outside this Member 4 slice.

Implement in this order:

1. Database relationships and recommendation normalization.
2. Review validation, audit, and atomic approval/rejection.
3. WorkOrder read/start/complete APIs and status propagation.
4. React coordinator integration, React crew dashboard/navigation, and Flutter crew screens.
5. Integrated verification, documentation updates, and `graphify update .`.
6. After Member 3's recommendation interface is agreed, design and implement functional regeneration as a separate follow-up.

## 5. Tests and acceptance criteria

- PostgreSQL integration tests prove concurrent approvals create exactly one order and prevent conflicting assignments.
- Rejection, editing, and failed validation never create WorkOrders.
- Two crew leaders cannot read or change each other’s jobs; residents cannot access crew operations.
- Start/complete enforce state transitions, preserve cancelled reports, propagate statuses, and roll back when audit persistence fails.
- Verify the current regenerate action is clearly identified as request recording only until the Member 3 follow-up implements a real rerun.
- Client tests cover actual request/response shapes, loading/error states, and repeated submissions.
- Verify web login, session restoration, and profile return direct each crew leader to My Jobs; check coordinator/resident screen restrictions and the missing-crew state.
- Verify the seeded Admin, resident, and five linked crew leaders can use the normal login flow; a newly registered account receives only the resident role, and repeat seeding does not duplicate users or change existing credentials.
- Exercise all five crew leader roles through the shared dashboard layout and verify isolation between two different crews on both platforms.
- Start a job in React and complete it in Flutter, then repeat with the platforms reversed. Verify refreshed job details, history, and coordinator monitoring agree.
- Submit competing start or complete actions from web and mobile; exactly one transition succeeds, and the other client refreshes after the conflict without duplicating audit events.
- Demonstrate: resident report → coordinator review → approval → Flutter crew start/complete → updated coordinator and resident status.

Baseline verification: backend build passed; React TypeScript compilation passed, while Vite packaging encountered an environment `spawn EPERM` error. The inspected Docker schema contains the prepared review and activity-history changes; runtime behavior and end-to-end operation remain unverified.
