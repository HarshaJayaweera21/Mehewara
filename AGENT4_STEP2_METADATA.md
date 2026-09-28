# Agent 4 — Step 2: review tracking in existing JSON fields

## Scope and delivery status

Step 2 adds versioned C# JSON contracts and connects them to the existing persistence paths. It uses the schema from migration 9 (`20260928090000_AddAgent4Review`), which the user reports applying. **No database schema, EF model, migration, index, or constraint changes are part of this step.** The database has not been inspected or modified by this work.

Builds, tests, model calls, migrations and runtime behavior have **not been verified**, as requested. Only source/diff inspection was performed. Step 3 has not started.

Graphify reported refreshing the code graph (3,783 nodes, 6,689 edges). It fell back to sequential extraction because parallel extraction was denied and warned that the existing Flutter Linux header `my_application.h` could not be parsed at line 18. The command returned exit code 1 despite reporting the output files updated. Documentation semantic extraction and application compilation were not performed.

## Storage map

Every new metadata object lives under a `reviewMetadata` key with `schemaVersion: 1`. Existing payload fields remain in place.

| Existing column | Metadata stored here | Purpose |
| --- | --- | --- |
| `ai_review_jobs.input_data` | `chainId`, `parentJobId`, `origin`, `correctionCount`, `nextAttemptAt`, `feedback` | Identify a request chain and reserve tracking for later automatic correction/retry scheduling. |
| `workflow_runs.state_data` | Recommendation ID/revision, job/chain IDs, progress, attention reason, UTC update time | Track the current review operation without changing database status enums. |
| `workflow_events.input_data` on recommendations | `origin`, `revision`, job/chain IDs, editor/time when applicable | Distinguish AI output from a coordinator edit. |
| `workflow_events.input_data` on validation events | Recommendation ID/revision, job/chain IDs, worker attempt | Identify exactly which recommendation attempt was reviewed. Existing top-level `recommendationId`, `revision`, `jobId` and `reviewInput` remain for compatibility. |
| `activity_history.before_data` / `after_data` | `revision`, `origin` alongside existing recommendation fields | Record the revision before and after an edit. Actor, reason, timestamp and recommendation ID continue to use existing columns. |

These contracts are in `backend/Mehewara.API/DTOs/Dispatch/ReviewMetadata.cs`. They are DTOs, not EF entities.

## What now happens in existing code paths

1. A coordinator queues validation or regeneration. The new job starts a chain with `chainId = job.id`, `origin = COORDINATOR`, `correctionCount = 0`, and the previous findings/coordinator reason. `requested_by` continues to hold the authenticated coordinator's user ID.
2. When the worker rebuilds evidence, fresh execution fields replace the old execution fields, while saved metadata and unrelated fields are preserved. The execution payload remains flat (`report`, `context`, `priorityAnalysis`, etc.) for compatibility with Python and evidence authorization. No new Python contract is required in this step.
3. New initial and regenerated recommendations are marked `AI_GENERATED`. Regenerated recommendations include their job and chain links; existing predecessor linkage remains unchanged.
4. Each validation event gets its exact recommendation revision, job, chain, and worker claim number. An initial inline validation has no job/chain/worker number because it was not queued.
5. Workflow tracking records `QUEUED`, `VALIDATED`, or `NEEDS_ATTENTION` at the existing persistence points. `RUNNING` is a supported metadata value reserved for the later worker tracking integration. `VALIDATED` records a bound Agent 4 result; it does not itself authorize approval.
6. The existing edit operation records `HUMAN_OVERRIDE`, authenticated editor, UTC edit time, and revision. The audit JSON preserves recommendation fields at their existing positions and adds revision/provenance metadata. Old validation events and original AI output are retained.

### Important boundary: provenance versus approval

Marking an edit `HUMAN_OVERRIDE` records who changed the recommendation. **Step 2 does not yet implement the agreed exemption from Agent 4 revalidation.** Existing edit behavior still clears validation and existing backend approval checks still apply. Step 6 will implement the human-override approval policy, responsibility acknowledgement, and handling of edits that do not change any values.

Metadata is written by the backend. AI response metadata does not replace backend job/recommendation metadata. Tracking values are not permissions, authentication, validation results, or instructions to dispatch.

## Example job metadata

Illustrative values; these are not database records:

```json
{
  "previousValidation": {
    "status": "REVISION_REQUIRED",
    "issues": ["The selected crew is busy."]
  },
  "reviewMetadata": {
    "schemaVersion": 1,
    "chainId": "11111111-1111-4111-8111-111111111111",
    "parentJobId": null,
    "origin": "COORDINATOR",
    "correctionCount": 0,
    "nextAttemptAt": null,
    "feedback": {
      "status": "REVISION_REQUIRED",
      "issues": ["The selected crew is busy."],
      "rejectedCrewIds": [],
      "suggestedAction": null,
      "coordinatorReason": "Please select an available road crew."
    }
  }
}
```

The existing Python adapter still builds Agent 3's `validation_feedback` from the existing execution fields. Automatic accumulation of rejected crew IDs and mapping correction counts into that feedback are later worker/loop work. The metadata contract alone does not introduce a loop.

## Identity and legacy rules for subsequent steps

- Automatic initial review jobs will use the source report's existing `ResidentId` for the required `requested_by` foreign key and `origin = SYSTEM` in job metadata. This identifies the initiating resident, not a resident approval or administrative action. No system user or nullable-column migration is needed. Initial job creation remains Step 3.
- Child jobs will inherit the initiating user and chain ID, set their parent job ID, and increment `correctionCount` only for recommendation corrections. Worker claims remain separately counted by `ai_review_jobs.attempts`. Child creation and limits remain Step 5.
- `nextAttemptAt` is reserved for Step 5's delayed retry selector. The current worker does not yet schedule using this field.
- Existing records are not backfilled or assigned invented origins. Typed reads return `null` for absent, malformed or unsupported metadata. Missing metadata is never converted into `VALID` or a human approval exemption.
- Legacy jobs can continue through the existing execution path without metadata. They retain null chain links rather than receiving a guessed chain/origin. Legacy edit audit entries remain unchanged; a new edit captures its known before/after revision, with null before-origin when unknown.
- No new database job kinds or statuses were added. Existing request-ID deduplication, one-active-job constraint, leases, revision checks, and approval checks remain in force.

## Next steps, not implemented here

3. Persist initial Agent 3 output and enqueue Agent 4 atomically, using the existing job table.
4. Complete Agent 4 evidence/validation refinements and exact evidence binding.
5. Implement bounded Agent 3 → Agent 4 correction chains and recovery/scheduling metadata consumers.
6. Implement human-override approval with mandatory backend checks and an audit trail.
7. Add dashboard review tabs, API filtering, progress and allowed actions.
8. Complete setup documentation and the user-run verification checklist.

Stop after Step 2 and report to the user before proceeding.
