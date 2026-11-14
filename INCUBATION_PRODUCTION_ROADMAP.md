# Incubation, Hatching and Chicken Production Planning Roadmap

## Purpose and delivery boundary

This document defines the first implementation plan for a production-management module spanning the Spring Boot backend, Flutter app and offline-first Angular PWA. It is a roadmap, not an implementation: no application code or data model changes are included here. The business-rule decisions in “Review decisions” are confirmed; implementation proceeds one phase at a time (see “Implementation status”).

The module should support the complete production lifecycle: incubating eggs, transferring eggs to the hatcher, recording hatch results, brooding and housing chicks, tracking losses and removals, and planning future production against a target sale date. Production assumptions and equipment limits must be farm-configurable rather than embedded in calculations.

## Existing architecture to preserve

- The backend is Spring Boot with MongoDB. Farm records currently embed coops and their operational records; `Coop` includes chickens, mortality, sales and reminders. Production-cycle data should be modeled separately from a coop because one cycle spans multiple stages and capacity resources.
- The backend already has authenticated farm users, farm roles, sync tracking, reminders, and team management. Extend these mechanisms instead of creating a parallel identity, reminder, or sync system.
- The Angular app is offline-first: feature screens read local Dexie data and write through repositories, while the sync engine communicates with `/api/v1/sync`. Add a new Dexie version; never edit a previously released schema version.
- Flutter has a service/screen-oriented structure and calls the existing backend. Keep business calculations on the backend, with mobile screens limited to input, presentation, and validation feedback.
- Use the existing API envelope, DTO validation, centralized error handling, repository/service/controller layering, Angular signals and typed forms, and Flutter null-safe models.

## Proposed business rules and calculation policy

### Equipment and capacity

1. Equipment is configured per farm, with a stable ID, kind (`INCUBATOR`, `HATCHER`, or `CHICKEN_HOUSE`), display name, enabled state, capacity, and optional notes. The initial farm setup can seed:
   - Incubator: 2,000 eggs.
   - Hatcher: 400 eggs per cycle.
   - Chicken house: 800 birds.
2. Capacity is a hard limit on simultaneous occupancy, not a recommended production quantity. An operation that would exceed capacity must be rejected by the backend with a clear conflict response and the conflicting reservation/occupancy details.
3. Incubator occupancy is the sum of eggs in batches from incubation start until transfer. Hatcher occupancy is the sum of eggs assigned to hatching cycles whose configured occupancy windows overlap. A hatching cycle may contain no more eggs than its hatcher capacity.
4. Chicken-house occupancy is the current placed-bird count, reduced by recorded mortality, sales and other removals. Do not infer removal from a planned sale.
5. Capacity changes affect future scheduling immediately but do not erase or silently resize existing batches. If a change makes a committed plan over capacity, flag it as a conflict and require an explicit resolution.

### Dates, stages and status

1. Dates are farm-local calendar dates. Store instants consistently in UTC and use the farm time zone when deriving or displaying dates; do not calculate day offsets using elapsed milliseconds across daylight-saving changes.
2. Incubation duration defaults to 21 days. For a batch starting on date `S`:
   - Transfer due date: `S + 18 days`.
   - Expected hatch date: `S + 21 days`.
3. Distinguish the incubation batch from a hatcher cycle. An incubation batch may be split into one or more transfer lots/cycles, each with its own quantity, hatcher assignment and expected hatch date. Each hatcher cycle must fit the hatcher limit. Splitting is explicit and the sum of transferred quantities cannot exceed the batch quantity.
4. A production cycle has a state transition history, not a freely editable status string. Initial states: `PLANNED`, `INCUBATING`, `TRANSFER_DUE`, `IN_HATCHER`, `HATCHED`, `BROODING`, `IN_HOUSE`, `COMPLETED`, `CANCELLED`. Valid transitions and allowed corrections must be defined in the backend.
5. Record actual dates separately from planned dates (start, transfer, hatch, brooder/house placement, sale readiness). Changes to actual events must be auditable.

### Hatch and survival calculations

Use configurable decimal rates from 0 to 1 (displayed as percentages). Keep expected and actual results distinct.

- Expected chicks at hatch: `floor(eggs transferred × expected hatch rate)`.
- Expected birds at sale: `floor(expected chicks × (1 − expected mortality rate))`.
- Eggs needed for a target sale quantity: `ceil(target sale quantity / (expected hatch rate × (1 − expected mortality rate)))`.
- Day-old chicks needed for a target sale quantity: `ceil(target sale quantity / (1 − expected mortality rate))`.
- Actual hatch rate: `hatched chicks / eggs transferred × 100`; actual sale survival: `birds sold or ready / chicks placed × 100`, with a clear “not available” state when the denominator is zero.

Store counts as integers and rates with defined precision. Validate that eggs transferred equals hatched + unhatched + any explicitly categorized eggs, and that healthy + weak/unhealthy chicks do not exceed hatched chicks. Report rounding and denominators explicitly to avoid presenting estimates as guarantees.

### Target-date planning

The calculator takes target sale-ready date, target sale quantity, target age in days, expected mortality, selected sourcing method (`INCUBATE_EGGS` or `PURCHASE_DAY_OLD_CHICKS`), and farm assumptions.

1. Calculate house placement date as `target sale-ready date − expected house grow-out age`.
2. If chicks spend a configurable brooding period outside the chicken house, calculate hatch/arrival date as `house placement date − brooding days`. If brooding occurs in the chicken house, brooding days are zero for this date calculation and occupancy starts on hatch/arrival.
3. For own incubation, calculate incubation start date as `hatch date − 21 days`, and transfer date as `incubation start + 18 days`.
4. For purchased day-old chicks, recommend delivery/arrival on the calculated hatch/arrival date and treat that date as the latest recommended order/arrival date pending supplier lead-time configuration. Do not claim a purchasing deadline until a configurable supplier lead time is supplied.
5. Compute required eggs or purchased chicks with the configured expected rates, then check incubator, hatcher, and house capacity against existing committed batches, reservations, and current occupancy.
6. Results must include estimated counts, each calculated date, constraints/conflicts, assumptions used, and a freshness timestamp. The user can save the recommendation as a plan; calculations alone do not reserve capacity.

### Schedule adjustment

- Recompute recommendations when actual sale, mortality, hatch results, date changes, capacity changes or farm assumptions change.
- Never rewrite actual records or silently move a committed plan. Mark affected plans `NEEDS_REVIEW`, show old and recalculated values, and require an authorized user to accept schedule changes.
- Keep an auditable reason and actor for user-confirmed rescheduling, cancellation, and manual override. Capacity override is not part of the initial release.

## Proposed domain and persistence model

Use farm-scoped MongoDB documents with string IDs. Every record carries `farmId`, `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, and a concurrency/version field. Enforce farm scoping in repository/service queries, not just in clients.

| Model | Important fields and purpose |
|---|---|
| `ProductionSettings` | `farmId`; `timeZone`; `incubationDays` (21); `transferDay` (18); `broodingDays`; expected hatch and mortality rates; default grow-out/selling age; reminder offsets/templates; assumptions version. Rates and durations are validated and editable by authorized users. |
| `ProductionEquipment` | `id`, `farmId`, `type`, `name`, `capacity`, `enabled`, optional `hatcherOccupancyDays` (default 3), version. Unique active capacity resource per farm/type can be a UI default, while the model permits multiple units. |
| `IncubationBatch` | `id`, `farmId`, `reference`, `equipmentId`, eggs set, planned/actual start, planned transfer and hatch dates, status, source/egg details (optional), expected rate snapshot, notes, version and audit fields. Reference is unique within a farm. |
| `HatcherCycle` | `id`, `farmId`, `incubationBatchId`, hatcher equipment ID, cycle reference, egg quantity, planned/actual transfer, expected/actual hatch date, cycle status, version. Quantity is constrained by equipment capacity. |
| `HatchResult` | `id`, `farmId`, `hatcherCycleId`, transferred eggs, hatched chicks, unhatched eggs, weak/unhealthy chicks, optional other categorized outcomes, result date, calculated hatch rate, notes and audit fields. One finalized result per cycle; edits are audited. |
| `BirdPlacement` | `id`, `farmId`, `productionCycleId`, source (`OWN_HATCH` or `PURCHASED_DAY_OLD`), source cycle/reference, quantity, brooder/house ID, planned/actual arrival and house placement dates, age baseline, status and version. Supports partial placement. |
| `BirdMovement` | Append-only event with `id`, `farmId`, `placementId`, type (`MORTALITY`, `SALE`, `TRANSFER`, `OTHER_REMOVAL`, `CORRECTION`), positive count, date, optional reason/related existing sale or mortality record, actor and idempotency key. A correction is an explicit compensating event, not destructive edit. |
| `ProductionPlan` | `id`, `farmId`, target sale-ready date/quantity, source method, age and rate assumptions snapshot, calculated timeline/quantities, status (`DRAFT`, `COMMITTED`, `NEEDS_REVIEW`, `COMPLETED`, `CANCELLED`), linked batches/placements, conflicts, version and audit fields. |
| `ProductionReminder` / shared reminder linkage | Existing reminder/task ID and source production entity/event, due date, task type, configurable offset, completion state, completed by/at. Generated reminders must be idempotent and user-completable. |

Indexes to add: `(farmId, reference)` unique for batch references; `(farmId, status, plannedHatchDate)` for active pipeline; `(farmId, equipmentId, plannedStart/plannedEnd)` for capacity checks; `(farmId, houseId, status)` for occupancy; and unique idempotency keys scoped to farm for append-only movement/result commands. Validate all nested references belong to the same farm.

## Workflow

1. An authorized user configures the farm assumptions and equipment capacities.
2. The user creates an incubation batch. The API validates the egg quantity against active incubator capacity and records the planned transfer/hatch dates.
3. The dashboard lists upcoming day-18 transfer and day-21 hatch events. The user assigns transfer lots to hatcher cycles; each reservation is validated against hatcher occupancy for the cycle window.
4. The system generates reminders from configured offsets (transfer, brooder preparation, packaging, vaccination and other custom tasks). Users can complete tasks and the system records actor/time.
5. On hatch, the user records transferred, hatched, unhatched and weak/unhealthy counts. The backend validates reconciliations and computes actual rates.
6. The user records brooding/arrival and house placements. Placement checks available house capacity, then mortality/sales/removals are captured as movement events, optionally linked to existing records.
7. The planning tool calculates a target-date recommendation, reports capacity and timing constraints, and saves it as a draft. Committing a plan revalidates all relevant capacity in one backend operation.
8. Changes to outcomes or assumptions flag committed future plans for review and present a recalculation; the user explicitly accepts any new dates or quantities.

## API requirements

Versioned routes are proposed under `/api/v1/production`. Use request/response DTOs, `@Valid`, the standard response envelope, stable error codes, pagination for history, and `Idempotency-Key` for event-creation commands.

| Endpoint | Purpose |
|---|---|
| `GET/PUT /settings` | Read/update production assumptions. |
| `GET/POST /equipment`, `PUT/DELETE /equipment/{id}` | Manage capacities; deletion should be disable/archive if referenced. |
| `GET/POST /batches`, `GET/PUT /batches/{id}`, `POST /batches/{id}/start`, `POST /batches/{id}/cancel` | Manage incubation batches and lifecycle commands. |
| `GET/POST /batches/{id}/hatcher-cycles`, `POST /hatcher-cycles/{id}/transfer`, `POST /hatcher-cycles/{id}/results` | Reserve/transfer eggs and record hatch outcomes with capacity checks. |
| `GET/POST /placements`, `POST /placements/{id}/movements` | Record chick arrival/house placement and append movement events. |
| `POST /plans/calculate` | Return an unsaved recommendation and conflicts. |
| `GET/POST /plans`, `POST /plans/{id}/commit`, `POST /plans/{id}/recalculate`, `POST /plans/{id}/accept-recalculation`, `POST /plans/{id}/cancel` | Save and manage planning decisions. |
| `GET /dashboard`, `GET /calendar`, `GET /reports/hatching` | Return farm-scoped dashboard, date range schedule and paginated historical performance. |
| `GET/PUT /access` or the existing team access resource | Read/update production access grants for farm users. |

Capacity validation and plan commit must be transactional or protected with optimistic locking and a final atomic recheck. Return `409 CAPACITY_CONFLICT` (including resource, requested amount, available amount, interval, and conflicting references) for overlapping reservations; return validation errors for malformed ranges or impossible counts. Use `403` for missing permission, `404` for inaccessible/nonexistent farm records, and avoid revealing records from another farm.

### Offline-first synchronization

The backend must define production entities and payload fields in the existing sync registry if these records are to be created or edited offline. Add an `EntityDef` for each entity supported by sync, append a new Dexie schema version, and add typed repositories/commands. Append-only events use idempotent operation IDs; mutable plans/settings use optimistic versions. The server remains the authority for capacity; offline-created batches/plans are marked pending and unconfirmed until sync validates them. A rejected operation must appear in Sync Center with the server conflict and must not be presented as a confirmed reservation. Calculator previews can use the latest locally cached snapshot but must be labeled stale/offline and cannot be committed offline.

## Permissions and access control

Introduce a farm-scoped `PRODUCTION_MANAGE` grant, independent of broad worker data-entry roles. The farm owner and `ROLE_ADMIN` can grant/revoke it; whether `ROLE_FARM_MANAGER` may do so is a decision for review. Keep the system-admin role distinct from farm-level grants.

- Add a typed backend permission/grant representation to the user/farm team membership, include it in the authenticated user/team response, validate grant changes server-side, and audit grant actor/time.
- Protect every production endpoint at the service/API boundary, including dashboard, reports, lookup endpoints and sync push/pull. Route hiding alone is not authorization.
- Ensure sync operations for production entities perform the same permission and farm ownership checks. A user must not spoof `farmId`, user IDs, equipment IDs or links to another farm.
- On Angular, add a typed permission and guard/directive, lazy-load the feature, and hide navigation/actions for unauthorized users. On Flutter, hide feature entry points and handle backend `403` clearly.
- Test authorized, unauthorized, revoked, cross-farm, removed and pending/unapproved accounts. Revocation must take effect on the next API request and sync operation.

## Phased milestones

### Phase 0 — Requirements and rules review

- Confirm assumptions in the review checklist below.
- Agree date/time-zone semantics, permitted stage transitions, correction/audit policy, forecast-rate precision and whether brooding consumes house capacity.
- Produce example scenarios for one batch, a split transfer, overlapping batches, a capacity conflict, and a target sale date.
- **Exit:** signed-off rules and validated example calculations; no code changes yet.

### Phase 1 — Domain design, persistence and access foundation

- Finalize Mongo document schemas, indexes, DTOs, enums, audit/version strategy and API error contract.
- Add farm-scoped production grants and the authorized grant-management API/UI using existing team management patterns.
- Add authorization and cross-farm isolation tests before feature endpoints are exposed.
- **Exit:** schema/API contract reviewed; grant and denial tests pass.

### Phase 2 — Settings and equipment capacity

- Implement settings and equipment services/endpoints with default setup for 2,000/400/800, editable values, validation and capacity-change conflict detection.
- Add web and mobile settings views for authorized users.
- **Exit:** a farm can configure assumptions/equipment and invalid values are rejected consistently.

### Phase 3 — Incubation and hatcher lifecycle

- Implement batch creation, references, planned dates, state transitions, hatcher lot/cycle reservations and transactional capacity checks.
- Add web and mobile batch lists/forms, timeline and transfer workflow.
- **Exit:** multiple overlapping batches work; a hatcher cycle cannot exceed capacity and split lots reconcile with the source batch.

### Phase 4 — Reminders and preparation tasks

- Reuse existing reminder processing and task completion behavior. Add event-derived reminders for transfer, brooder preparation, packaging, vaccination and configurable custom offsets.
- Generate reminders idempotently as source dates change; cancel/replace only generated future tasks and preserve completion/audit history.
- **Exit:** offset changes and date changes create no duplicate or stale actionable reminders.

### Phase 5 — Hatch results and performance history

- Implement result validation and actual hatch metrics, history filters, trend summaries and downloadable/report-ready output.
- **Exit:** count reconciliation, zero-denominator behavior and historical calculations are tested.

### Phase 6 — Brooding, chicken-house occupancy and movements

- Implement placement, occupancy projection, mortality/sale/removal events, links to existing sale/mortality records and capacity validation.
- Derive current occupancy from placements plus movement ledger; do not maintain a separately editable total as the source of truth.
- **Exit:** every movement is idempotent/auditable and actual occupancy cannot fall below zero or exceed capacity on placement.

### Phase 7 — Production scheduling

- Build a backend scheduling service that evaluates incubator occupancy, hatcher intervals, house occupancy, active plans, expected hatch/survival rates and planned removals.
- Return multiple feasible start windows or a clear no-feasible-window explanation; do not silently select a plan that violates constraints.
- Recalculate on relevant changes and mark committed plans `NEEDS_REVIEW` rather than rewriting them.
- **Exit:** deterministic, explainable recommendations pass scenario tests and concurrency tests.

### Phase 8 — Target-date calculator

- Implement both own-incubation and purchased-day-old options, configurable lead-time assumptions, timeline dates, required quantities and constraint explanation.
- Show calculations and assumptions before saving a plan; saving/committing is a separate explicit action.
- **Exit:** documented examples match unit tests, including rounding up and impossible capacity cases.

### Phase 9 — Offline sync and cross-client integration

- Add production sync entity definitions, payload fields, server operation handlers, idempotency, versioning, tombstones where deletion is supported, Dexie schema/repositories, and Sync Center handling.
- Add typed Flutter models/service calls and screens; preserve server validation and surface pending/rejected sync states.
- **Exit:** offline read/cache works, queued writes recover after reconnect, and server-rejected capacity operations are visible and recoverable.

### Phase 10 — Dashboard, calendar and reporting

- Deliver production dashboard cards and a calendar/timeline for transfers, hatch dates, placements, tasks and expected sale-ready dates.
- Add filters by date, status, equipment and cycle, plus hatching success history. Explain forecast versus actual values and stale/offline data.
- **Exit:** dashboard totals reconcile with underlying batches, results, occupancy and movement events.

### Phase 11 — Hardening, rollout and deployment

- Complete automated backend unit/integration/security tests, Angular unit/e2e tests, Flutter tests, API contract checks, sync conflict tests and migration/index verification.
- Add observability for failed reminder generation, scheduling conflicts, sync rejection and calculation errors without logging sensitive user data.
- Deploy behind a feature flag or farm-level enablement. Seed defaults safely for existing farms, document rollback, and monitor before broad access.
- **Exit:** verified migration, deployment checklist, rollback path and acceptance sign-off.

## Testing and acceptance criteria

### Calculation and validation tests

- 21-day hatch and day-18 transfer calculations across month/year boundaries and farm time zones.
- Hatcher and incubator capacity exactly at, below and above limits; overlapping and adjacent reservations; split cycles whose total equals the source eggs.
- Formula rounding, 0%/100% validation boundaries, missing assumptions, zero denominators and hatch-result reconciliation.
- Target-date planning with variable brooding, grow-out age, mortality, hatch rate, planned sales and a capacity conflict in each resource.
- Actual sales/mortality/hatch results trigger a new forecast without mutating actual records or committed dates.

### Integration and authorization tests

- API DTO validation, farm scoping, atomic plan commit, concurrent reservation race, idempotent retries, optimistic-lock conflicts and correct error envelope.
- Every endpoint and sync operation is denied without `PRODUCTION_MANAGE`, after revocation, for another farm, and for removed or pending users.
- Reminder generation is repeatable and stable across retries and date updates.

### Client tests

- Angular repository/command transaction and sync queue specs, form/date/validation tests, permission guard tests, and offline/online e2e scenarios.
- Flutter serialization, service parsing/error tests, state transitions, permission-based visibility, capacity feedback and key workflow widget tests.
- Cross-client contract fixtures ensure both clients send/receive the same DTO fields, enums, dates and result counts.

### Acceptance

An authorized user can configure assumptions, create overlapping incubation batches, reserve hatcher cycles without exceeding capacity, receive/manage preparation reminders, record reconciled hatch results, place birds only within available house capacity, track mortality/sales/removals, and calculate/save both sourcing options for a target date. The dashboard agrees with source records, all recommendations expose their assumptions, and an unauthorized user cannot access the UI, API or sync operations.

## Implementation status

| Phase | Status |
|---|---|
| 0 — Requirements and rules review | ✅ Complete |
| 1 — Domain design, persistence and access foundation | ✅ Complete (see notes below) |
| 2 — Settings and equipment capacity | ✅ Complete (see notes below) |
| 3 — Incubation and hatcher lifecycle | ✅ Complete (see notes below) |
| 4 — Reminders and preparation tasks | ✅ Complete (see notes below) |
| 5 — Hatch results and performance history | ✅ Complete (see notes below) |
| 6 — Brooding, house occupancy and movements | ✅ Complete (see notes below) |
| 7 — Production scheduling | ✅ Complete (see notes below) |
| 8 — Target-date calculator and plans | ✅ Complete (see notes below) |
| 9 — Offline sync and cross-client integration | ✅ Complete (see notes below) |
| 10 — Dashboard, calendar and reporting | ✅ Complete (see notes below) |
| 11 — Hardening, rollout and deployment | ✅ Complete (see notes below) |

### Phase 1 notes

- `User.permissions` (`PRODUCTION_MANAGE`) with audit fields `permissionsUpdatedByUserId/At`. The farm owner always has access; `ROLE_ADMIN` and `ROLE_FARM_MANAGER` do not get it implicitly.
- `PUT /api/v1/team/{memberId}/production-access` `{ "granted": boolean }`: only the farm owner or `ROLE_ADMIN` may call it (managers get 403); members of other farms return 404; the owner's implicit access cannot be edited.
- `GET /api/v1/production/access`: 403 without the grant. Every production service must call `ProductionAccessService.requireManage(actor)` and derive `farmId` from the caller. Permissions are loaded per request, so revocation, deactivation and removal apply immediately.
- `UserInfoResponse.permissions` is exposed to Angular (`LocalUser.permissions`, `'PRODUCTION_MANAGE'` in `hasPermission`, Team page grant/revoke action) and Flutter (`User.permissions`, `canManageProduction`).
- Error contract: `409 CAPACITY_CONFLICT` (`ErrorCodes.CAPACITY_CONFLICT`, `ApiException.capacityConflict`). Collections, DTOs and indexes are created with the phase that first uses them.

### Phase 2 notes

- Endpoints (`/api/v1/production`, all require `PRODUCTION_MANAGE`): `GET|PUT /settings`, `GET|POST /equipment`, `PUT|DELETE /equipment/{id}` (DELETE archives).
- Settings and three equipment items (Incubator 2000, Hatcher 400 with 3-day occupancy, Chicken house 800) are seeded lazily on first read; `estimatesOnly` stays true until a user saves settings. Rates are fractions (0–1, 4 dp); Angular shows percentages.
- PUTs require the `version` last read; stale versions return 409. Equipment is listed Incubator, Hatcher, Chicken house, then by name; names are unique per farm and type.
- `EquipmentUsageChecker` is the hook later phases implement; lowering capacity, disabling or archiving below committed usage returns `409 CAPACITY_CONFLICT` with `details {resource, requested, available, conflictingReferences}`. No implementation exists until Phase 3, so no conflicts occur yet.
- Angular: `/production` (guarded, nav entry, online-only for now; offline sync arrives in Phase 9). Flutter: `ProductionSettings`/`ProductionEquipment` models and `ProductionService`; the screen is deferred until the mobile app has v1 auth/sync (Phase 9), since it uses legacy cookie sessions.

### Phase 3 notes

- Collections `incubation_batches` and `hatcher_cycles` (indexes: unique `(farmId, reference)`, status/hatch date, equipment/start, cycle by batch and hatcher). Statuses: batch `PLANNED → INCUBATING → TRANSFERRED` (`COMPLETED` arrives with Phase 5 results, `CANCELLED`); cycle `RESERVED → IN_HATCHER` (`COMPLETED`, `CANCELLED`).
- Endpoints: `GET|POST /batches`, `GET|PUT /batches/{id}` (PUT only while `PLANNED`, requires `version`), `POST /batches/{id}/start|cancel`, `GET|POST /batches/{id}/hatcher-cycles`, `POST /hatcher-cycles/{id}/transfer|cancel`. Commands take an optional `{ actualDate, reason }` body. `GET /batches` accepts `status`, `page`, `size`.
- Dates are calendar days. Settings (incubation days, transfer day, hatch rate) are snapshotted on the batch. `plannedStartDate/TransferDate/HatchDate` are the effective schedule; starting with a different `actualDate` recomputes them and shifts reserved cycles after re-checking capacity.
- Capacity (half-open intervals): the incubator holds `eggsSet` over `[start, transfer)`; a hatcher holds a cycle's quantity over `[transfer, transfer + occupancyDays)`. Violations return `409 CAPACITY_CONFLICT` with `resource, requested, available, intervalStart, intervalEnd, conflictingReferences`. Mutations take a per-farm in-process lock; a multi-instance deployment would need a distributed lock or a post-save recheck (Phase 11).
- `ProductionUsageChecker` now implements `EquipmentUsageChecker`, so lowering capacity below current/future usage is rejected.
- Split lots reconcile: cycle quantities cannot exceed `eggsSet`; the batch becomes `TRANSFERRED` only when every egg is reserved and transferred. Cancelling is blocked once eggs are in a hatcher.
- Angular: `/production` is now the batches page (create, start, reserve hatcher, transfer, cancel); settings moved to `/production/settings`. Flutter: `IncubationBatch`/`HatcherCycle` models and `ProductionService` batch calls; screens still deferred to Phase 9.

### Phase 4 notes

- Deviation: the existing reminders are embedded in coops (feed/vaccine/medicine) and drive the daily email job, so production tasks use a separate `production_reminders` collection (unique `(farmId, sourceType, sourceId, ruleKey)`; index on `(farmId, status, dueDate)`). Generation is idempotent per batch and rule.
- Rules live in `ProductionSettings.reminderRules` (`key, taskType, anchor, offsetDays -60..60, title, enabled`). Defaults when none saved: transfer (transfer day, 0), brooder preparation (hatch, -2), packaging (hatch, 0), vaccination (hatch, 0). Blank keys become `CUSTOM-n`; duplicate keys are rejected. A settings PUT without `reminderRules` keeps the current rules; with it, all live batches are reconciled.
- Reconcile (after batch create/update/start/cancel and rule changes): live batches are PLANNED/INCUBATING/TRANSFERRED. OPEN reminders move with changed dates/titles; OPEN reminders for disabled/removed rules or cancelled/completed batches become CANCELLED; CANCELLED ones reopen when active again; COMPLETED ones are never touched.
- Endpoints: `GET /reminders?status&page&size` (OPEN default, soonest first, `overdue` flag in the farm time zone), `POST /reminders/{id}/complete` (idempotent; records actor and time; optional note).
- Angular: "Production tasks" list with Done on the batches page. A rule editor is not built yet (rules are editable via the API). Flutter: `ProductionReminder` model plus `getReminders`/`completeReminder`.
- Not yet: production reminders are not in the daily email summary; offline sync arrives in Phase 9.

### Phase 5 notes

- Collection `hatch_results` (unique `(farmId, hatcherCycleId)`, index `(farmId, resultDate)`): one finalised result per cycle with batch/cycle/hatcher references denormalised for history.
- Reconciliation: `hatched + unhatched + other outcomes = eggs transferred` (the cycle quantity); weak chicks are a subset of hatched. Result date cannot precede the transfer date. Other outcomes are categorised (max 10, unique names).
- Endpoints: `GET|POST|PUT /hatcher-cycles/{id}/results` (POST only for `IN_HATCHER` cycles, 409 if one exists; PUT requires `version` and appends a revision snapshot of the previous values), `GET /reports/hatching?from&to&batchId&hatcherId&page&size` and `GET /reports/hatching.csv` (formula-injection-safe).
- Report: summary (weighted hatch and weak rates), monthly trend and newest-first paged rows. Rates are percentages to 2 dp and `null` when the denominator is zero.
- Recording completes the cycle; the batch becomes `COMPLETED` once every non-cancelled cycle is completed and all eggs are reserved. `COMPLETED` batches stay "live" for reminders so brooder/vaccination tasks remain open.
- Angular: record-result form per in-hatcher cycle on the batches page, new `/production/results` page (summary, trend, history, CSV download). Flutter: `HatchResult`/`HatchingReport` models and service calls. Editing a result has no UI yet (API only).

### Phase 6 notes

- **Model:** `bird_placements` (reference `PL-yyyyMMdd-n`, source OWN_HATCH or PURCHASED_DAY_OLD, house, quantity, dates) and an append-only `bird_movements` ledger (MORTALITY, SALE, TRANSFER, OTHER_REMOVAL, CORRECTION).
- **Endpoints** (`/api/v1/production`): `GET|POST /placements`, `GET /placements/{id}`, `POST /placements/{id}/movements` (optional `Idempotency-Key`), `GET /occupancy`.
- **Derived occupancy:** never stored. Remaining = quantity + sum of movement deltas; status is ACTIVE while remaining > 0, otherwise CLOSED.
- **Capacity:** placing, or a correction that adds birds, past house capacity returns `409 CAPACITY_CONFLICT`. `PlacementService` is the house `EquipmentUsageChecker`, so lowering a house's capacity or disabling it below occupancy is rejected.
- **Source rules:** OWN_HATCH needs a COMPLETED cycle with a recorded result and total placed cannot exceed `hatchedChicks`. PURCHASED_DAY_OLD must not send a cycle.
- **Movement rules:** dates between placement date and today; removals cannot go below zero; only a CORRECTION may set `increase` and it needs a reason.
- **Idempotency:** a repeated key returns the original movement; a key reused on another placement returns 409. The unique index is partial (string keys only) so movements without a key do not collide.
- **Links:** `relatedRecordType`/`relatedRecordId` optionally point at coop sale or mortality records and are not validated.
- **Clients:** web `/production/placements`; Flutter models and service calls only (screens in Phase 9).

### Phase 7 notes

- **Endpoint:** `POST /api/v1/production/schedule/search` (`eggs`, `earliestStart`, `latestStart`, optional unit IDs; at most 180 days). It is read-only and reserves nothing.
- **Method:** `SchedulingService` tests every start date in the range against the incubator `[start, transfer)`, the hatcher `[transfer, transfer + occupancy days)` and, when a house exists, today's house occupancy plus expected chicks (`floor(eggs x hatch rate)`). It reuses `ProductionCapacity` and the intervals `IncubationService` uses for real reservations.
- **Output:** the earliest start, merged feasible windows, every date with its reasons, a plain-language explanation (including why nothing fits), assumptions and a timestamp. Output is deterministic for the same data.
- **Deferred:** house space ignores future sales and removals (stated in the assumptions). `ProductionPlan`, `NEEDS_REVIEW` flagging and recalculation need saved plans, so they come with Phase 8.
- **Clients:** web `/production/schedule`; Flutter model and `searchSchedule` call.

### Phase 8 notes

- **Endpoints** (`/api/v1/production`): `POST /plans/calculate` (nothing saved), `GET|POST /plans`, `GET /plans/{id}`, `POST /plans/{id}/commit`, `/recalculate`, `/accept-recalculation`, `/cancel`, and `POST /plans/recalculate` for every open plan.
- **Calculation** (`PlanningService.timeline`, pure and unit tested): house placement = ready date - age; hatch/arrival = placement - brooding days; own eggs: start = hatch - 21 days, transfer = start + 18, `eggs = ceil(qty / (hatch x (1 - mortality)))`; purchased: `chicks = ceil(qty / (1 - mortality))` and an order deadline only when a supplier lead time is set. Hatch rate, mortality and age can be overridden per plan.
- **Constraints:** dates already passed, incubator and hatcher capacity (via `SchedulingService`) and house space. A batch above the hatcher capacity (400 eggs) is reported as not fitting, because lots share one hatcher window.
- **Plans:** `ProductionPlan` stores a calculation snapshot. Saving makes a DRAFT; commit revalidates under the farm lock (409 `CAPACITY_CONFLICT` if it no longer fits). Plans reserve no capacity and are not linked to batches yet.
- **Review:** recalculating a COMMITTED plan whose dates, quantities or feasibility changed keeps the old numbers, stores the new ones in `recalculation` and sets NEEDS_REVIEW. Accepting needs a reason; the actor and time are on the plan. Recalculation is on request, not triggered automatically by other edits.
- **Clients:** web `/production/plans`; Flutter `ProductionPlan` model and calls.

### Phase 9 notes

- **Reuses the farm sync outbox.** New `PRODUCTION` entity type; every op is `operation: ACTION` with `payload = {command, body}` sent through `/api/v1/sync/push`. `ProductionSyncService` dispatches to the existing services (so rules and capacity checks are identical online and offline).
- **Commands:** `BATCH_CREATE/START/CANCEL`, `CYCLE_RESERVE/TRANSFER/CANCEL`, `REMINDER_COMPLETE`, `RESULT_RECORD/EDIT`, `PLACEMENT_CREATE`, `MOVEMENT_ADD`, `PLAN_SAVE/COMMIT/ACCEPT/CANCEL`.
- **Idempotency:** each op is logged as `farmId:opId`; a replay returns the stored result (`duplicate=true`). `MOVEMENT_ADD` uses the opId as its idempotency key.
- **Per-op rejection:** validation, not-found and `CAPACITY_CONFLICT` failures become a `REJECTED` result for that op only; later ops still run.
- **Offline reads:** `GET /api/v1/production/snapshot` returns settings, equipment, batches, reminders, placements, occupancy and plans. The web `ProductionSnapshotStore` caches it in Dexie (`productionCache`, schema v3), refreshes it after each sync cycle (only for users with `PRODUCTION_MANAGE`) and serves it when offline; pages show an "offline data" note.
- **Web writes:** `ProductionRepository` sends a command directly when reachable (errors, including capacity conflicts, show immediately). When offline, or behind earlier queued production ops, it is queued in the outbox and the user is told it will sync. A queued create cannot be followed up (start, reserve…) until the server has applied it and the lists refresh.
- **Recovery:** failed ops appear in the Sync Center with Retry/Discard; `CAPACITY_CONFLICT` shows a hint to free capacity then retry, or discard.
- **Online only:** settings and equipment edits, plan recalculation, the calculator, schedule search and reports.
- **Flutter:** `ProductionSnapshot` model and `getSnapshot()` only; offline caching/queue and screens remain deferred, as before.
- **Tests:** `ProductionSyncControllerTest` (backend), `ProductionRepository` spec (web).

### Phase 10 notes

- **Web only, client-side:** `/production/dashboard` derives totals and a timeline from the cached production snapshot (batches, reminders, placements, occupancy, plans), so it works offline and always reconciles with source records (`production-dashboard.ts`, unit-tested).
- **Cards:** active batches, eggs incubating / in hatcher / unassigned, birds in houses vs capacity, mortality, sold, open and overdue tasks, plans needing review.
- **Timeline:** transfers, expected hatches, placements, open tasks and plan sale-ready dates; filter by type, equipment/house and date range. Planned items are labelled "Forecast", done items "Actual"; stale data shows the offline note.
- **Hatching success history** stays on the Hatch results page (online report); not duplicated here.
- **Flutter:** screens remain deferred.

### Phase 11 notes

- **Enablement:** global kill switch `poultry.pal.production.enabled` (default true) enforced in `ProductionAccessService`; per-farm rollout is the existing `PRODUCTION_MANAGE` grant; defaults seed lazily so no migration script is needed.
- **Indexes:** `ProductionIndexInitializer` creates farm-scoped compound indexes on the eight production collections at startup (idempotent, non-fatal), verified by `ProductionHardeningTest`.
- **Observability:** sync rejections are logged with farm, opId and error code only (no payloads).
- **Docs:** `PRODUCTION_ROLLOUT.md` has the enablement, migration, monitoring, checklist and rollback steps.
- **Test coverage:** authorization (no permission, other farm, kill switch), sync idempotency/rejection, capacity, planning, reminders and web repository/dashboard specs exist from earlier phases.
- **Remaining gaps (not done):** Flutter UI/tests and offline queue, cross-client contract fixtures, Playwright offline e2e for production, metrics counters (logs only), and a distributed lock for multi-instance deployments (the per-farm lock is in-process, so run a single backend instance or add one before scaling out).

## Review decisions (confirmed)

All items below are confirmed using the defaults proposed in this document: 3-day hatcher occupancy (configurable), brooding days configurable (house occupancy starts at placement), owner/system admin grant access, explicit batch splitting, editable seeded estimates, supplier lead time optional until configured, optional links to existing records, and provisional offline batches allowed but unconfirmed until sync.

1. ✅ **Hatcher occupancy:** should each cycle occupy the hatcher for three days (day 18 through day 21), or should the farm configure another occupancy interval?
2. ✅ **Brooding and housing:** are chicks brooded in a separate brooder, and for how many configurable days before the 800-bird house? If brooding occurs in the house, occupancy should begin at hatch/arrival.
3. ✅ **Permissions:** should only the farm owner and system admin grant `PRODUCTION_MANAGE`, or should farm managers also be able to grant it?
4. ✅ **Batch sizing:** if an incubation batch has more eggs than one hatcher cycle can hold, is explicit splitting into multiple hatcher cycles acceptable? They may hatch on the same or different dates depending on incubator start.
5. ✅ **Forecast assumptions:** what initial expected hatch rate, mortality rate, and selling age should be seeded? Defaults remain editable and must be clearly labeled as estimates.
6. ✅ **Purchase deadline:** what supplier lead time should be used to calculate the latest day-old chick order date? Without it, the system can only calculate the recommended arrival date.
7. ✅ **Existing records:** should this module link to existing coop sale and mortality entries automatically, or should users enter production movements separately and optionally link them?
8. ✅ **Offline commitment:** should a user be allowed to create provisional batches offline (subject to rejection on sync), or must capacity-reserving production operations require a live server connection?

## UX and fix round

- Web: sticky production menu (`ProductionShell`) with the active page highlighted; the back-to-Batches buttons are gone.
- Web: info icon on every page header (`PageHeader` `info` input); hints on form fields; calendar `app-date-field` replaces native date inputs.
- Web: batch reference auto-generated as `{MON}{DD}-{eggs}` (editable); Unhatched is calculated from Hatched; Plan a batch start dates and Hatch results history are tables; Chicken houses pre-fills house, quantity and dates.
- Backend: plan and schedule house-capacity checks now project occupancy on the placement date (birds leave after the grow-out period) instead of using today's count. Only the constraint text changed; no contract change.

## Flutter screens

- `poultry_pal_plus_app/lib/screens/production/`: Dashboard, Batches, Hatch results, Chicken houses (placements and movements) and Plans (calculate, commit, recheck, accept new dates, find start dates) tabs, plus a settings screen (timings, rates, equipment capacity).
- Entry: egg icon in the home app bar, shown when `User.canManageProduction`. Data loads from `/snapshot` with pull-to-refresh; a 403 shows an access message.
- Online only for now: unlike the web app, Flutter does not queue production writes offline.
