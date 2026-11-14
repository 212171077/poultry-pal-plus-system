# Production module – rollout and rollback

## Enablement

- **Global kill switch:** `poultry.pal.production.enabled` (default `true`). Set `false` to make every production REST and sync operation return 403 ("Production management is not enabled"). Clients keep their queued production operations and show them as failed in the Sync Center; nothing is lost.
- **Per farm / per user:** a user needs the `PRODUCTION_MANAGE` permission (granted by the farm owner or an admin). Without it the web app hides the Production menu and the API denies the request. Roll out by granting it to a pilot farm first.
- **Defaults:** settings and equipment (Incubator 2000, Hatcher 400, Chicken house 800) are seeded lazily per farm on first access, so existing farms need no migration script.

## Migration and indexes

- New collections only: `incubation_batches`, `hatcher_cycles`, `hatch_results`, `bird_placements`, `production_plans`, `production_reminders`, `production_equipment`, `production_settings`. No existing collection is altered. The new `PRODUCTION` sync entity type reuses `sync_operation_log`.
- `ProductionIndexInitializer` creates farm-scoped compound indexes at startup (idempotent; failures are logged as warnings, not fatal). Verify after deploy: `db.<collection>.getIndexes()`.

## Monitoring (no payloads or personal data are logged)

- `WARN Production sync op rejected: farm=… op=… code=…` – offline writes rejected by the server (e.g. `CAPACITY_CONFLICT`). A sustained rise means users are overbooking offline.
- `WARN Could not create index …` – index creation failed; queries still work but may be slow.
- Watch 403 rates on `/api/v1/production/**` and `/api/v1/sync/push` after enabling.

## Pre-deploy checklist

- [ ] `./mvnw test` in `poultry-pal-service` (production tests green; known unrelated failures: `AuthV1ControllerTest`, date-dependent `FarmControllerTest`).
- [ ] `npm run lint`, `npm run test:ci`, `npm run build` (initial bundle < 800 kB), `npm run e2e` in `poultry-pal-plus-web`.
- [ ] `dart analyze` on production files in `poultry_pal_plus_app` (production screens live in `lib/screens/production/`; the entry is the egg icon in the home app bar, shown to users with `PRODUCTION_MANAGE`).
- [ ] Deploy backend with the module enabled, grant `PRODUCTION_MANAGE` to the pilot farm, deploy web, monitor warnings for a few days, then widen.

## Rollback

1. Set `poultry.pal.production.enabled=false` and restart (instant, data preserved).
2. If needed, redeploy the previous web/backend build; the new collections and Dexie `productionCache` table are ignored by older versions.
3. Data removal (only if required): drop the eight production collections and delete `sync_operation_log` entries whose `entityType` is `PRODUCTION`.
4. Re-enable by flipping the flag back; queued client operations then sync normally.
