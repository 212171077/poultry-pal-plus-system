# Poultry Pal Plus — Web

Offline-first Angular 20 PWA for poultry farmers. Farmers can keep working without internet; changes sync with the
Spring Boot backend (`../poultry-pal-service`, `/api/v1`) when a connection returns. See
[`../WEB_APP_ROADMAP.md`](../WEB_APP_ROADMAP.md) for the architecture and roadmap.

## Requirements

- **Node 22** (Angular 20 needs Node ≥ 20.19). With nvm: `nvm use 22`.
- The backend on port 8090, using HTTPS by default.

## Commands

| Command                             | What it does                                                                                                                                                                                                          |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm start` / `npm run start:https` | HTTPS dev server on port 4200; `/api` is proxied over verified HTTPS to `localhost:8090` (`proxy.https.cjs`). No service worker.                                                                                      |
| `npm run start:http`                | HTTP dev server on <http://localhost:4200>; use with `TLS_ENABLED=false` on the backend.                                                                                                                              |
| `npm run start:hosted`              | HTTP dev server on <http://localhost:4200>; proxies `/api` to `http://154.0.166.216:8091`, the mobile app's current hosted backend.                                                                                   |
| `npm run test:tls`                  | Check HTTPS and HTTP development proxy configuration.                                                                                                                                                                 |
| `npm run build`                     | Production build in `dist/poultry-pal-plus-web/browser`, with the service worker.                                                                                                                                     |
| `npm run lint`                      | ESLint (angular-eslint).                                                                                                                                                                                              |
| `npm run format` / `format:check`   | Prettier.                                                                                                                                                                                                             |
| `npm test` / `npm run test:ci`      | Unit tests (Karma + Jasmine); `test:ci` runs headless once.                                                                                                                                                           |
| `npm run e2e`                       | Builds, then runs Playwright against the production build in a **visible browser**, one test at a time, pausing 1 s before each action (change with `E2E_SLOWMO=<ms>`). First run: `npx playwright install chromium`. |
| `npm run e2e:slow`                  | Same, pausing 2 s before each action.                                                                                                                                                                                 |
| `npm run e2e:headless`              | Same tests without opening a browser, in parallel (also the default in CI).                                                                                                                                           |

### Testing against the mobile app's hosted service

From `poultry-pal-plus-web`, use Node 22, run `npm ci` on first setup, then
`npm run start:hosted`. Open <http://localhost:4200> and sign in with your existing
farm account. `proxy.hosted.json` forwards `/api` requests to the mobile app's
current backend, `http://154.0.166.216:8091`; no local Spring Boot process is needed.
Restart the dev server after changing proxy configuration.

The hosted backend must deploy the current `/api/v1/auth`, `/api/v1/sync`,
team and account-settings endpoints. Sharing the mobile API's host alone does not
make an older backend compatible. On 29 October 2026, the hosted OpenAPI document
listed only legacy endpoints for these features, and a request to v1 sign-in
returned 401; deploy the current backend against the existing database before
expecting web sign-in and sync to work.

In browser DevTools, inspect `/api/v1/auth/signin` and `/api/v1/sync/bootstrap`
after signing in, then compare the downloaded farm and coops with the mobile app.
The browser shows `localhost:4200` URLs because the dev server proxies them.
Both clients operate on real hosted data: use a test farm for edits.
The current upstream is plain HTTP, so credentials and data are not encrypted
between the dev server and the host; use HTTPS before testing with real credentials.
The Angular dev server does not enable the service worker. Playwright and
`e2e/serve.mjs` use a mock API, not this hosted service.

### Live full-stack e2e suite

A second suite runs against the real backend, MongoDB and Mailpit in Docker, with no mocks:
`../run-e2e-tests.sh`. See [`e2e-live/README.md`](e2e-live/README.md).

### Running the e2e tests with `scripts/e2e.sh`

The script picks Node 22 (via nvm) if needed, installs the Playwright browser on first use, stops a
leftover test server on port 4300, builds the app, and then runs the tests.

```bash
scripts/e2e.sh                                # all tests, visible browser, 1 s pause per action
scripts/e2e.sh -s slow                        # 2 s per action (or -s fast, or -s 1500 for ms)
scripts/e2e.sh -p desktop -g "sign"           # desktop only, tests whose title matches "sign"
scripts/e2e.sh e2e/auth.spec.ts --no-build    # one file, reuse the existing build
scripts/e2e.sh --headless --report            # fast run without a window, then open the HTML report
scripts/e2e.sh --ui                           # Playwright UI: pick tests and step through them
scripts/e2e.sh --help                         # all options
```

To try offline behaviour locally, run `npm run build && node e2e/serve.mjs`, then open <http://localhost:4300>, reload once,
and switch DevTools → Network to _Offline_. `e2e/serve.mjs` also answers `/api/v1` with an in-memory mock of the sync
backend (`e2e/mock-api.mjs`, seeded with one layers coop), so sync can be tried without the Spring Boot service.

## Structure

```
src/app/
├─ core/        singleton services: config, http (ApiResponse, interceptor), theme, network, sync status, pwa, routing
├─ layout/      responsive shell: side-nav (desktop), rail (tablet), bottom-nav + quick add (phone), top-bar
├─ data/        offline data layer: db/ (Dexie schema, liveSignal), repositories/, sync/ (outbox, engine, merge), testing/
├─ shared/ui/   presentational components: page-header, kpi-card, empty-state, confirm-dialog, sync-badge, sync-chip, …
└─ features/    lazy-loaded routes, one folder per feature (<name>/<name>.routes.ts)
src/styles/     design tokens (_tokens.scss), Material 3 theme (_theme.scss), generated palettes
```

Conventions: standalone components with `OnPush`, signals, `input()`/`output()`, `inject()`, native control flow.
Style with `--pp-*` tokens and `--mat-sys-*` variables, never raw colours. Full rules are in
`../.github/copilot-instructions.md`.

## Offline data layer

The app is local-first: pages read from IndexedDB and write through repositories. Only the sync engine calls the API.

- **Read:** in a component field, use `liveSignal(() => repo.list())` (or `repo.watchAll()`). The signal updates when
  the data changes in any tab, including when a sync brings in new data.
- **Write:** `repo.create/update/remove` save the record and an outbox operation in one IndexedDB transaction, then
  ask the engine to sync. The record carries a `syncStatus` (`pending`, `synced`, `failed` or `conflict`); show it with `<app-sync-chip>`.
- **Sync** (`SyncEngine`): pushes the outbox, then pulls `/api/v1/sync/changes` since the last cursor (or calls
  `/sync/bootstrap` on a new device). Changes to different fields are merged automatically. Changes to the same field
  are listed in the Sync Center for the user to review.
- **Schema changes:** add `this.version(n + 1).stores({...}).upgrade(...)` in `data/db/app-db.ts`. Never edit an existing version.
- **Tests:** provide `provideTestDb(createTestDb())` and `provideFakeSyncServer(new FakeSyncServer())` from
  `data/testing/fake-sync-server.ts`, and delete the database in `afterEach`.

## Authentication

`AuthService` (`core/auth/auth.service.ts`) owns the session. The user is cached in IndexedDB (`users.current`), so a
person who signed in before can reopen the app offline.

- **Routes:** use `authGuard` for the app shell, `guestGuard` for `/login` and `/register`, and
  `permissionGuard('FARM_MANAGER')` for manager-only pages. In templates, hide actions with
  `*appCan="'FARM_MANAGER'"`, and in code check `auth.can('FARM_MANAGER')`.
- **API calls:** `core/auth/auth-api.ts` uses `unwrapApi()` from `core/http/api-error.ts`. It unwraps the envelope and
  throws an `ApiError` (`kind`, `status`, `code`, `fieldErrors`).
- **Remember me:** when it is off, the server sets a browser-session refresh cookie and the app sets a `pp_session` marker
  cookie. The app treats the user as signed out once the browser has been closed.
- **Switching user / signing out** clears every local table. Both warn first if the outbox still has changes.
- **Expired session:** the sync engine pauses, a banner appears, and "Sign in again" opens the lazy-loaded re-auth
  dialog. The outbox is kept.
- **Tests:** `provideFakeAuthApi()` from `core/auth/testing/fake-auth-api.ts`. In e2e, call `signIn(page)` from
  `e2e/helpers.ts` (mock user `thandi@example.com` / `secret1`).

## Farm operations

Coops (`/coops`), sales, mortality, expenses and egg production are list pages built on the same pattern:

- **Pages** extend `RecordListPage` (`shared/records/record-page.ts`). It opens the form for `?action=new` (and
  preselects `&coop=<id>`), checks that a coop exists, and confirms deletes. Shared styles live in
  `shared/records/record-list.scss` and `record-form.scss`.
- **Coop rules** (`data/models/coop-rules.ts`): labels, flock age, the expected growth phase for the age, transition
  targets and the mortality rate. Catalogs such as mortality reasons and egg/box sizes are in `data/models/record-options.ts`.
- **Coop lifecycle:** `CoopRepository.startNewBatch()` and `transitionPhase()` update the device at once and queue one
  `COOP` `ACTION` operation (`NEW_BATCH` / `PHASE_TRANSITION`). The server archives or moves the coop's records in the
  same transaction. Records queued before the action still sync, into the archive or the new coop.
- **Archived batches** (`/coops/archive`, owner/manager) are read from `GET /api/v1/farm/archived-batches` through
  `ArchiveApi`. They are online-only history and are not stored in IndexedDB.
- **Live birds** are birds placed minus recorded deaths. The server keeps `numberOfChickens` as placed, like the mobile app.
- **Quick Add:** add entries to `QUICK_ACTIONS` in `layout/navigation.ts` (use `requires` for manager-only actions).
  They appear in the phone's "+" menu, the top bar's "Quick add" menu, the dashboard and the `N` shortcut.

## Team, profile and settings

- **Team** (`/team`) reads its member list from the farm-scoped `/api/v1/team` API and caches it locally.
  Managers can add members, activate/deactivate accounts, and assign coops; only the farm owner can grant
  manager roles. Removal is a soft removal and clears coop assignments.
- **Profile and farm details** are editable online through authenticated `/api/v1/auth/profile`, `/api/v1/account/password`, `/api/v1/farm/details` and `/api/v1/account/settings/currency` endpoints; user and farm IDs are derived from the session rather than sent by the browser. Email changes rotate the session, and farm details refresh the local snapshot from the server.
- **Settings** include the account password, currency, theme, browser storage estimate, local-data refresh,
  install prompt and service-worker update status. Clearing the local database requires an online connection
  and an empty sync outbox.

## Dashboard, reminders and reports

- **Dashboard** (`features/dashboard`): every figure is computed from IndexedDB by `features/analytics/farm-metrics.ts`,
  so it loads offline. The range filter drives the KPIs and the SVG charts (`shared/ui/bar-chart`).
- **Reminders** (`/reminders`): tasks are generated by the server. Completing one (or marking it N/A) goes through
  `ReminderRepository.complete()` and syncs as a `REMINDER` `ACTION`. Browser notifications are opt-in and shown at most once a day.
- **Reports** (`/reports`): preview, CSV and Excel (`shared/export/table-export.ts`) work offline. PDFs come from the
  server (`/api/farm/download-*`, online only). Email requests are stored in the `reportRequests` table and sent by
  `ReportQueue.flush()` when the server is reachable.

## Deployment

`Dockerfile` builds the app and serves it with nginx on port 8080, using HTTPS by default.
For a single image containing both Angular and Spring Boot, use the repository-root
`Dockerfile.combined`. It serves the web app on **8086** and the backend on internal
port **8090** (publish as **8091** to retain the hosted API port). See
[`../poultry-pal-service/README.md`](../poultry-pal-service/README.md#building-and-pushing-the-combined-image)
for build commands, HTTPS mounts and existing-database configuration.
`/api/` is proxied over verified HTTPS to `poultry-pal-app:8090`, so the app and API
share one origin and the auth cookies work without CORS.
`index.html` and the service-worker files are sent with `no-cache` so updates reach users; hashed assets are cached
for a year.

```bash
docker build -t poultry-pal-web .
docker run -p 8080:8080 \
  -v "$PWD/config:/etc/nginx/tls:ro" \
  -e API_UPSTREAM=https://host.docker.internal:8090 poultry-pal-web
# HTTP fallback (backend must also use HTTP):
docker run -p 8080:8080 -e TLS_ENABLED=false \
  -e API_UPSTREAM=http://host.docker.internal:8090 poultry-pal-web
```

With `../poultry-pal-service/docker-compose.yml`, `TLS_ENABLED=false docker compose up -d`
switches **both** services to HTTP; `TLS_ENABLED=true docker compose up -d` restores HTTPS.
See the backend README for the initial build and environment setup.

The ignored `config/fullchain.pem` and `config/privkey.pem` files contain the
renewed certificate and matching key. Supply them separately on a fresh checkout;
they are excluded from the Docker build context and mounted at runtime.
The certificate covers only `tertiaryverify.dedicated.co.za`, expiring on 9 May 2027.
For local browser access, map that hostname to `127.0.0.1` in your hosts file and run
`npm run start:https -- --host 0.0.0.0`, then open
`https://tertiaryverify.dedicated.co.za:4200`. The HTTPS proxy connects locally but
verifies the certificate against its certified hostname; it does not disable TLS validation.
`API_UPSTREAM` and `TLS_SERVER_NAME` override the HTTPS proxy destination and
certificate hostname (also supported by the web container).

For HTTP development, use `npm run start:http` and start Spring Boot with
`TLS_ENABLED=false`. Secure cookies follow the backend TLS switch unless
`COOKIE_SECURE` is explicitly set. Clear site cookies when changing protocols.
Service workers only run on HTTPS or `localhost`; remote HTTP loses offline PWA support.
