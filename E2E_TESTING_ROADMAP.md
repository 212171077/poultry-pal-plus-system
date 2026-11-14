# Full-stack Playwright E2E Roadmap

Source: `Comprehensive-Playwright-E2E-Testing-Requirements`. Scope: `poultry-pal-plus-web` against the real `poultry-pal-service` and a dedicated MongoDB. **Defects are documented, never fixed. The mobile app (`poultry_pal_plus_app`) is frozen and out of scope.**

## 1. Analysis summary

| Area | Finding |
|---|---|
| Web | Angular 20 offline-first PWA (Dexie + sync engine). Tests must run against the production build so the service worker is active. |
| Backend | Spring Boot on `:8090`, TLS on by default (`TLS_ENABLED=false` for HTTP), MongoDB `poultry-pal-db` on `:27017`. Dev proxy `/api` -> `localhost:8090`. |
| Existing e2e | `poultry-pal-plus-web/e2e/` (7 specs, ~1150 lines) runs against **`mock-api.mjs`** on port 4300, with desktop (Chrome) and mobile (Pixel 7) projects. It conflicts with the "no mocks" rule, so it stays untouched as the fast mocked suite and the new suite lives separately. |
| Routes | `login`, `register`, `forgot-password` (guest); `dashboard`, `coops`, `sales`, `mortality`, `expenses`, `eggs`, `reminders`, `reports`, `sync`, `settings`, `**` (auth); `team` (FARM_MANAGER); `production` (PRODUCTION_MANAGE: batches, placements, hatch results, plans...); `admin/app-config` (SYSTEM_ADMIN). |
| Roles | `ROLE_USER`, `ROLE_FARM_MANAGER` (owner flag), `ROLE_ADMIN`, plus the `PRODUCTION_MANAGE` and `SYSTEM_ADMIN` permissions. |
| Backend v1 | `AuthV1`, `Sync`, `Team`, `AccountSettings`, `Production`, `BatchArchive`, `AppConfigAdmin` controllers, plus legacy `/api/farm/*`. |

## 2. Risks and decisions (resolve in Phase 0)

1. **Database safety (critical).** Dev DB is `poultry-pal-db` with committed credentials in `docker-compose.yml`. Run a **throw-away MongoDB** (`docker run` on a random free port, e.g. `mongo:7`, database `poultry-pal-e2e`) and pass it via env (`SPRING_DATA_MONGODB_*`). Before any reset, a guard checks the DB name matches `^poultry-pal-e2e` and the port is not 27017. Abort otherwise. Credentials come from env, never committed.
2. **Seeding roles/users.** Registration creates a farm owner; roles come from a `roles` collection and `SYSTEM_ADMIN`/`PRODUCTION_MANAGE` need seeding. Seed via a Node script using the `mongodb` driver (roles, admin, production manager, manager, worker) plus API-driven setup for farm data. This avoids app changes.
3. **Email flows (Mailpit).** SMTP settings are now stored in `app_config` (`MAIL_HOST/PORT/AUTH/STARTTLS/USER/PASS`), seeded on startup from `poultry.pal.app.mail.*` properties (env `POULTRY_PAL_APP_MAIL_HOST`, etc.; Gmail by default) and re-read on every send (`MailSettings`, `EmailConfig`). The e2e compose sets them to Mailpit (`mailpit:1025`, auth/STARTTLS `false`); tests read mail via Mailpit's REST API (`:8025/api/v1/messages`).
8. **Docker-based startup (decided).** Everything runs from a dedicated `docker-compose.e2e.yml` (mongo, mailpit, backend, web), project name `ppp-e2e`, free ports, no volumes, `down -v` on exit. The backend jar is built with `./mvnw package -DskipTests` (JDK 21 needed; host has only 17, so build in a `maven:3.9-eclipse-temurin-21` container). The web image uses the existing web Dockerfile with `TLS_ENABLED=false`.
4. **TLS.** Start the backend with `TLS_ENABLED=false COOKIE_SECURE=false` and `CORS_ALLOWED_ORIGINS` for the test origin.
5. **Serving the web app.** Build once (`npm run build`), serve `dist` with a proxy to the real backend (adapt `e2e/serve.mjs` without the mock) on a dedicated port, e.g. 4310.
6. **Docker/Java/Node availability.** Docker, Java and Node are installed locally. `run-e2e-tests.sh` must verify them up front and fail clearly.
7. **Sync timing.** The UI writes locally and syncs later, so assertions must wait on sync completion (sync chip / `/api/v1/sync` response), then verify in the backend via API.

## 3. Target structure

```
run-e2e-tests.sh                       # single entry point (repo root)
poultry-pal-plus-web/e2e-live/
  playwright.live.config.ts            # desktop 1920x1080 + mobile 390x844, globalSetup/Teardown
  global-setup.ts / global-teardown.ts # start mongo, backend, web; health-wait; seed; stop
  infra/ (db-guard, process manager, seed.mjs, health checks)
  fixtures/ (auth per role via storageState, api client, console/network error collector)
  pages/ (Page Objects: Login, Shell, Coops, Records, Team, Production, ...)
  specs/<page>.spec.ts
  reporters/ (markdown-summary, defect-index)
  utils/screenshot.ts                  # test-results/screenshots/{desktop,mobile,failures}/<page>-<scenario>.png
test-results/{screenshots,defects,reports}/
```

Add `npm` scripts: `e2e:live`, `e2e:live:desktop`, `e2e:live:mobile`. The existing `e2e` script is unchanged.

## 4. Phases

**Phase 0 - Discovery & plan (0.5 d)**
- Confirm decisions above; read SMTP/config, role seeding and `/actuator`/health endpoint availability.
- Produce the page-by-page test plan (`e2e-live/TEST_PLAN.md`): each route -> features, roles, scenarios, negative cases.

**Phase 1 - Environment orchestration (1-1.5 d) - DONE**
- Throw-away Mongo container with DB guard and clean recreate each run.
- Start backend (`./mvnw spring-boot:run` or built jar) and web server; wait for readiness (poll health URLs with timeout).
- Seed script; teardown that stops only processes/containers this run started (PID/container-ID tracking, runs on failure and Ctrl-C).
- `run-e2e-tests.sh`: prerequisites check, build, run, report, exit code reflects test result.
- *Exit:* one command boots everything, seeds, runs a smoke test, shuts down cleanly, repeatably.

**Phase 2 - Framework (1 d) - DONE**
- Playwright live config: projects `desktop` (1920x1080) and `mobile` (390x844, Pixel 7 emulation), `retries: 1` (traces retained, flaky tests flagged rather than hidden), traces/video on failure, HTML reporter to `test-results/reports/html`.
- Fixtures: per-role authenticated contexts, API helper for data setup/verification, collector that records console errors, failed requests and 4xx/5xx and **fails or annotates the test** (no silent ignoring).
- Screenshot helper (waits for network idle, animations finished, fonts loaded) and an auto-screenshot on failure into `screenshots/failures`.
- Page Objects for shell/navigation first. Reuse the service-worker readiness logic from `e2e/helpers.ts`.

**Phase 3 - Core coverage (3-4 d) - DONE**
Each spec runs on both projects, with a screenshot per page and key state.
1. Auth: register (validation, duplicate, password strength), login (bad credentials, lockout if any), logout, session expiry/refresh, forgot-password, guest/auth guards.
2. Shell & navigation: nav items per role, bottom-nav on mobile, 404 page, deep links, redirects.
3. Dashboard, Coops (create/edit/archive, batch and phase transitions, validation), Sales, Mortality, Expenses, Eggs, Reminders: full CRUD, filters/search/sort, empty/loading states, `?action=new&coop=` deep link, backend verification after sync.
4. Reports and analytics: figures checked against known seeded data.
5. Sync Center & offline: offline writes, reconnect, conflicts, failures.
6. Settings/account: profile, password change, re-auth dialog.

**Phase 4 - Role-based & privileged areas (1.5-2 d) - DONE**
- Team (invite/role change/restrictions, owner-only manager grant), Production (batches, placements, hatch results, plans), Admin app-config.
- Permission matrix: for each route x role assert allow/redirect/hidden actions (`*appCan`), plus direct API calls with wrong roles expecting 401/403.

**Phase 5 - Responsive & UI quality (1 d) - DONE** (hand-rolled checks in `pages/quality.ts`; `@axe-core/playwright` not added, awaiting approval)
- Mobile checks on every page: no horizontal overflow (`scrollWidth <= clientWidth`), controls inside viewport and >=48px, no overlapping fixed bars, scrollability of tables/dialogs.
- Basic a11y checks (axe via `@axe-core/playwright` is a new dev dependency, so confirm before adding): labels, focus visibility.

**Phase 6 - Execute, triage, document defects (1-2 d) - DONE** (DEF-001..016 in `test-results/defects/`; 3 full runs: 1, 2 and 0 unexpected failures; the first was a test bug, now fixed, and the second was an intermittent 504 = DEF-016)
- Run the full suite; investigate each failure: test bug (fix the test) vs application defect (document only).
- Create `test-results/defects/DEF-###-slug.md` using the required template (ID, title, page, scenario, steps, expected, actual, severity, evidence, errors, root cause, suggestion), de-duplicated across tests. Features that can't be tested are documented with the reason.
- Re-run 3x to confirm repeatability; flaky tests get fixed or recorded.

**Phase 7 - Reporting & docs (0.5-1 d) - DONE** (`infra/summary-reporter.ts`, `e2e-live/README.md`)
- Markdown summary reporter -> `test-results/reports/summary.md` (totals, duration, by page, by desktop/mobile, defect list, screenshot links, backend/frontend errors; backend log captured to `test-results/logs/`).
- Documentation (`poultry-pal-plus-web/e2e-live/README.md` + link from the web README): install (`npx playwright install`), structure, commands for all/desktop/mobile/single page, startup and DB reset flow, output locations.
- CI job optional and only if requested.

Estimated total: ~9-12 working days.

## 5. Command surface

```
./run-e2e-tests.sh                      # everything
./run-e2e-tests.sh --project=desktop    # desktop only
./run-e2e-tests.sh --project=mobile     # mobile only
./run-e2e-tests.sh specs/coops          # one page (args pass through to Playwright)
```

## 6. Definition of done

- One command starts Mongo, backend and web, seeds clean data, runs desktop + mobile suites, writes screenshots/HTML report/Markdown summary, and tears everything down (including on failure).
- Every route in `app.routes.ts` has tests and screenshots at both viewports.
- No mocked API in the live suite; console errors and failed requests are surfaced.
- Defects documented as individual files; **no application code changed**.
- Documentation updated and the suite executed with results recorded.

## 7. Decisions

- Email: `EmailConfig` now reads SMTP settings from the database (done); e2e uses Mailpit through env-seeded settings (section 2, item 3). No hostname/TLS workaround needed.
- Services run in Docker (section 2, item 8); Playwright runs on the host against the compose stack.
- Dev dependencies: `mongodb` is no longer needed (seeding runs through `docker exec mongosh`). `@axe-core/playwright` (automated accessibility scanning) remains optional, pending approval.
