# Poultry Pal Plus Web: Offline-First Angular App Roadmap

> Goal: build a professional, responsive web app that farmers can use without internet access.
> Every action is saved on the device first. When connectivity returns, the app syncs changes
> with `poultry-pal-service` automatically and safely.

---

## 1. Current-State Analysis

### 1.1 Backend (`poultry-pal-service`)

| Area | Finding | Impact on offline web |
|---|---|---|
| Stack | Spring Boot 3.3.4, Java 21, **MongoDB**, JJWT, springdoc | Supports flexible documents and string UUID IDs |
| Data model | `Farm` document **embeds** `coops`, and each `Coop` embeds `sales`, `mortalities`, `expenses`, `eggPackagingRecords`, `reminder`, and `phaseTransition` (`model/dto/Coop.java:14-30`) | One large aggregate makes concurrent edits and partial sync risky |
| Controllers | Only `AuthController`, `FarmController` (~25 RPC-style endpoints such as `/api/farm/update-sales`), and `TestController` | No resource-oriented or versioned API |
| IDs | String IDs generated with `UUID.randomUUID()`; update DTOs accept client IDs | ✅ Clients can generate IDs offline |
| Auth | `POST /api/auth/signin` sets an HttpOnly cookie `poultry-pal` with path `/api` and a 24-hour expiry. The JWT secret is hard-coded | No refresh or logout endpoint. Cookies need same-origin deployment or credentialed CORS |
| CORS | `@CrossOrigin(origins="*")` on controllers | Browsers reject `*` for credentialed cookie requests |
| Response contract | No `ApiResponse {success,message,data}` envelope or `GlobalExceptionHandler`; errors are inconsistent | The sync engine cannot reliably classify errors as retryable, conflict, or fatal |
| Sync support | **None**: no `updatedAt`, `@Version`, soft deletes, delta query, idempotency key, or batch endpoint | ❌ This is the main blocker. See Phase 0 |
| Pagination | None | Large farms send the full farm document on each load |
| Roles | `ROLE_USER`, `ROLE_FARM_MANAGER`, `ROLE_FARM_WORKER`, `ROLE_ADMIN`. `FarmController.java:21-23` has a comment that `@PreAuthorize` was "NOT working" | Fix before exposing the API to another client |

### 1.2 Mobile app (`poultry_pal_plus_app`)

| Area | Finding |
|---|---|
| Architecture | Screen-centric code. `setState` is used everywhere. `poultry_pal_service.dart` is a single large service, and the API URL `http://154.0.166.216:8091` is hard-coded |
| Offline | **Not implemented.** There is no local database, outbox, connectivity listener, or retry logic. The last `farmData` snapshot is kept in session storage only. The "online/offline" dot in `reminders_screen.dart` shows `coop.active`, not network status |
| Features to mirror | Auth (login, register, remember me), Dashboard (KPIs, health score, financials, charts), My Coops (create, edit, archive, new batch, phase transition), Sales, Mortality, Expenses, Egg Packaging, Reminders (vaccine, feed, and medicine schedules; complete or N/A; comments), Profile and Farm (users, roles, coop assignment), Reports (PDF download, email report or schedule), Settings (currency) |
| Design system | `lib/theme/app_theme.dart`: primary sienna `#8B5A2B` (light `#A6703F`, dark `#6B4320`), secondary harvest amber `#F4A623`, success `#22C55E`, error `#EF4444`, warning `#F59E0B`, info `#3B82F6`, light surface variant `#F4EDE5`, dark background `#121A12`. Fonts are **Poppins** for headings and **Inter** for body text. Spacing uses a 4 px grid (4/8/16/24/32/48). Radii are 4–20 px. Light and dark themes are supported |

### 1.3 Web app (`poultry-pal-plus-web`): current scaffold

A blank Angular CLI project exists at `poultry-pal-plus-web/`.

| Area | Current state | Action needed |
|---|---|---|
| Angular | **20.3** (`@angular/core ^20.3.0`, CLI `^20.3.2`), TypeScript ~5.9 | ✅ Keep |
| Builder | `@angular/build:application` (esbuild/Vite) with SCSS styles | ✅ Keep |
| Bootstrap | Standalone `App` component (`src/app/app.ts`), `app.config.ts` with `provideZoneChangeDetection({ eventCoalescing: true })` and `provideBrowserGlobalErrorListeners()` | Add HTTP client, animations, service worker, and Material providers |
| Routing | `app.routes.ts` is empty (`routes: Routes = []`) | Add lazy-loaded feature routes |
| Strictness | `strict`, `strictTemplates`, `strictInjectionParameters`, `strictInputAccessModifiers` enabled | ✅ Keep |
| Formatting | Prettier config in `package.json` (`printWidth: 100`, `singleQuote: true`, Angular HTML parser) | Add ESLint (`ng add @angular-eslint/schematics`) |
| Unit tests | Karma and Jasmine (`ng test`) | Keep for unit tests and add Playwright for offline E2E tests |
| Budgets | Initial bundle: 500 kB warning, 1 MB error. Component styles: 4 kB warning, 8 kB error | Watch Material and Chart.js size. Put shared styles in global SCSS partials |
| Assets | `public/favicon.ico` only | Add the logo, PWA icons, and self-hosted Poppins and Inter fonts |
| PWA/offline | **Not installed** (no `@angular/service-worker`, `ngsw-config.json`, or manifest) | Run `ng add @angular/pwa` |
| UI library | **Not installed** | Run `ng add @angular/material` |
| Tooling | `.vscode/` (launch and tasks), `.github/copilot-instructions.md` inside the app folder | GitHub Copilot reads instructions only from the **repository-root** `.github/`, so merge them into `/.github/copilot-instructions.md` |
| Version control | No nested `.git`. The app is part of the monorepo | Commit the scaffold. `node_modules/` is already ignored by the app's `.gitignore` |
| Not present | SSR (fine, because this is a client-only offline PWA), environments, Docker, nginx, CI | Add these in Phase 1 |

### 1.4 Key conclusion

The web app's offline features depend on backend sync support. The Flutter app has the same gap, so the
**Phase 0 backend work can later be reused to make Flutter offline-first too**.

---

## 2. Target Architecture

```
┌──────────────────────── Browser (PWA) ────────────────────────┐
│  Angular UI (standalone components + Signals)                  │
│        │ reads (live queries)          │ writes (commands)     │
│        ▼                               ▼                       │
│  Feature Stores (signals) ──► Repositories ──► IndexedDB (Dexie)│
│                                   │          ├─ entity tables   │
│                                   │          ├─ outbox (queue)  │
│                                   │          └─ sync_meta       │
│                                   ▼                             │
│                  Sync Engine (push outbox → pull deltas)        │
│                  ▲ online/offline events, Web Locks, backoff    │
│  Angular Service Worker: app shell, fonts, icons cached         │
└───────────────────────────────┬────────────────────────────────┘
                                │ HTTPS same-origin /api/v1
                     nginx (serves SPA + proxies /api)
                                │
                     poultry-pal-service (Spring Boot + MongoDB)
```

### 2.1 Technology choices

| Concern | Choice | Reason |
|---|---|---|
| Framework | **Angular 20.3** (already scaffolded), standalone components, Signals, new control flow, strict TypeScript, Zone.js change detection kept for now | Modern Angular without NgModules. Zoneless mode can be considered later |
| UI kit | **Angular Material 3** with a custom theme generated from the Flutter tokens and SCSS design tokens | Professional, accessible, and responsive. Matches the mobile app's style |
| Charts | **ng2-charts (Chart.js)** | Lightweight equivalent to `fl_chart` |
| Local DB | **Dexie.js** (IndexedDB) with `liveQuery` | Indexed queries and transactions. Works with signals |
| App shell offline | **@angular/service-worker** (`ng add @angular/pwa`) | Caches the app shell and assets. Supports install prompts and update notifications |
| Forms | Typed Reactive Forms | Strong typing and validation that matches backend `@Valid` rules |
| Dates/i18n | `date-fns` and Angular `LOCALE_ID`. Currency comes from user settings | Matches the mobile currency setting |
| Testing | **Karma and Jasmine** for unit tests (already configured), **Playwright** with network-offline emulation for E2E tests, and `fake-indexeddb` for data-layer specs | Uses the existing setup and lets us test offline scenarios directly |
| Deployment | Docker multi-stage build, then **nginx** serving the SPA and reverse-proxying `/api` | Same-origin deployment avoids cookie and CORS problems |

Avoid NgRx unless complexity requires it. Signal-based stores keep the dependency footprint small, in line with "Do not
introduce unnecessary frameworks."

### 2.2 Offline data strategy

1. **Local-first reads.** Every screen reads from IndexedDB, never directly from HTTP. The UI renders immediately,
   even offline.
2. **Commands, not direct API calls.** A user action such as "Record sale":
   - generates a client UUID (`crypto.randomUUID()`) for the record **and** an `idempotencyKey`
   - writes the record locally with `syncStatus = 'pending'`
   - appends an operation to the `outbox`: `{opId, entity, entityId, type, payload, baseVersion, createdAt, attempts}`
   - runs as **one Dexie transaction**, so the record and its queued operation are always saved together
3. **Sync engine** (singleton, triggered by `online` event, app start, focus, a 60 s timer, and a manual "Sync now" action):
   - acquires a **Web Lock** (`navigator.locks`) so only one browser tab syncs at a time. `BroadcastChannel` tells other tabs to refresh
   - **Push:** sends the outbox in FIFO batches to `POST /api/v1/sync/push`. A per-operation response of `applied`,
     `duplicate`, `conflict`, or `rejected` updates the local record
   - **Pull:** calls `GET /api/v1/sync/changes?since=<cursor>` and applies upserts and tombstones. The new cursor is saved in `sync_meta`
   - retries with **exponential backoff and jitter** (1 s → 5 min cap). `4xx` validation errors are treated as permanent
     failures and shown to the user. They are never retried indefinitely
4. **Conflict policy** (agreed with the backend):
   - *Append-only records* (sales, mortality, expenses, egg packaging, phase transitions): no conflicts are expected
     because each record has a unique client UUID. Idempotency handles retries.
   - *Mutable records* (coop details, reminders, settings, users): use **optimistic concurrency** with `version`.
     On a `409`, the server returns its current copy. The client applies **field-level last-writer-wins** for
     non-overlapping fields. If the same field changed on both sides, it opens a **conflict-resolution dialog**.
   - *Deletes*: use soft-delete tombstones (`deleted=true`) so other devices learn about deletions.
5. **Offline authentication.** The 24 h cookie cannot be renewed offline. Cache the signed-in user profile and roles
   in IndexedDB, and let the user keep working offline. When the connection returns and the server replies `401`,
   **pause sync** and show a non-blocking "Sign in to sync" prompt. **Never discard the outbox**. Clear local data only on an
   explicit logout, after warning about unsynced items.
6. **Storage durability.** Call `navigator.storage.persist()` and show storage usage in Settings. Encourage users to install the
   PWA because Safari can evict IndexedDB for sites that are not installed and are not visited regularly.
7. **Server-only features offline.** PDF reports and emails are queued as outbox operations (`SEND_REPORT`) and
   run on reconnect. The dashboard and reports preview are **computed client-side** from local data, so they work offline.

### 2.3 Proposed project structure

```
poultry-pal-plus-web/
├─ public/             # favicon, PWA icons, fonts, logo
├─ src/environments/   # environment.ts / environment.development.ts (apiBaseUrl)
├─ src/app/
│  ├─ app.ts, app.config.ts, app.routes.ts   # existing scaffold files
│  ├─ core/            # auth, http interceptors, config, error handling, guards
│  ├─ data/            # Dexie db schema, repositories, sync engine, outbox
│  ├─ shared/          # ui components (kpi-card, empty-state, sync-badge, page-header), pipes
│  ├─ layout/          # shell: responsive sidenav/topbar/bottom-nav, connectivity banner
│  └─ features/
│     ├─ auth/  dashboard/  coops/  sales/  mortality/  expenses/
│     ├─ eggs/  reminders/  team/  reports/  settings/
│     └─ (each: pages/, components/, store, models)
├─ src/styles/         # design tokens (_tokens.scss), material theme, typography
├─ ngsw-config.json
├─ Dockerfile / nginx.conf
└─ e2e/ (Playwright)
```

---

## 3. UI/UX Direction (Professional, Responsive, Farmer-Friendly)

- **Brand:** Flutter design tokens exported to CSS custom properties (`--pp-primary: #8B5A2B`, `--pp-secondary: #F4A623`, …).
  Self-host Poppins and Inter so fonts work offline. Light and dark themes follow the system setting, with a manual toggle.
- **Responsive shell:**
  - **≥ 1024 px (desktop/tablet landscape):** persistent side navigation, top bar with farm switcher, user menu, and **sync status chip**
  - **600–1023 px:** collapsible navigation rail
  - **< 600 px (phone):** bottom navigation with Dashboard, Coops, Quick Add (FAB), Reminders, and More. Matches the Flutter navigation
- **Dashboard:** 4 KPI cards (Revenue, Expenses, Net Profit, Mortality rate) with trend arrows, a revenue-vs-expenses line chart,
  an expense breakdown donut chart, a coop health list, today's reminders, and a quick-action strip.
- **Coops:** card grid on mobile, sortable `mat-table` on desktop. The coop detail page has tabs for Overview, Sales, Expenses,
  Mortality, Eggs, Reminders, and History.
- **Forms:** large touch targets (≥ 48 px), numeric keypads (`inputmode="decimal"`), +/- steppers, currency formatting,
  inline validation, and saving to IndexedDB immediately (no network spinners).
- **Offline visibility:**
  - global banner: "You're offline — changes are saved on this device"
  - sync chip: `Synced ✓` / `3 pending ⟳` / `Sign in to sync` / `1 needs attention ⚠`
  - a small "pending" badge on each unsynced record, plus a **Sync Center** page listing queued and failed operations with
    Retry and Discard actions
- **Quality:** skeleton loaders, illustrated empty states, toasts, WCAG AA contrast, keyboard navigation, `prefers-reduced-motion` support,
  and a Lighthouse PWA/Accessibility score ≥ 90.

---

## 4. Roadmap

Estimates assume 1–2 developers. ✅ marks exit criteria.

### Phase 0: Backend sync readiness (2–3 weeks) **[prerequisite]** ✅ Done

> **Status: implemented.** See `poultry-pal-service/README.md` §6.1 for the contract.
>
> What was built:
>
> - **Envelope and errors:** `ApiResponse` and `V1ExceptionHandler` (scoped to v1 controllers).
> - **Version stamping and tombstones:** `FarmChangeTracker` applies them on every farm save, including legacy writes.
> - **Startup tasks:** `SyncDatabaseInitializer` runs the migration and creates the indexes.
> - **Sync endpoints:** `SyncService` and `SyncController` provide `push`, `changes` and `bootstrap`.
> - **Auth:** `AuthV1Controller` provides cookie auth with refresh rotation and reuse detection.
> - **Security config:** env-based JWT secret, a CORS allow-list, and v1-aware 401/403 handlers.
> - **Tests:** 21 MockMvc integration tests.
>
> Where the implementation differs from the plan below:
>
> 1. **Duplicate detection:** idempotency is keyed by the per-operation `opId`, stored in `sync_operations` with a 30-day TTL. There is no request-level `Idempotency-Key` header.
> 2. **Versions:** records carry the farm version as a sync cursor. `Reminder`, `PhaseTransition`, `User` and `UserSettings` are not versioned individually: reminders change through their coop, and the team and settings come from `bootstrap`.
> 3. **Deletes:** they are recorded as tombstones instead of a `deleted` flag on each record.
> 4. **Role enforcement:** roles are enforced in the v1 service layer. Legacy `@PreAuthorize` is still inactive, because enabling method security globally would change Flutter behaviour.
>
> Follow-ups:
>
> - Legacy `/api/farm/*` endpoints trust a `farmId` from the request, so they are open to IDOR.
> - Rotate the JWT secret that was committed to git history.
> - The 2 date-dependent `FarmControllerTest` failures were already failing before this work and are still open.

Deliver these changes under **`/api/v1`**, and keep the existing `/api/farm/*` endpoints unchanged so the Flutter app keeps working.

1. **Contract and errors:** add an `ApiResponse<T>{success,message,data}` envelope and a `@RestControllerAdvice GlobalExceptionHandler`
   with stable error codes (`VALIDATION_ERROR`, `CONFLICT`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`).
2. **Sync metadata** on `Farm` and every embedded record (`Coop`, `Sale`, `Mortality`, `Expense`, `EggPackagingRecord`, `Reminder`,
   `PhaseTransition`, `User`, `UserSettings`): `updatedAt`, `updatedBy`, `version`, and `deleted`. Use Mongo `@Version` on
   `Farm` for document-level optimistic locking.
3. **Idempotent upserts** keyed by client-supplied UUID, plus an `Idempotency-Key` store with a TTL collection.
4. **Sync endpoints:**
   - `POST /api/v1/sync/push`: batch of operations, returning per-operation results (`applied|duplicate|conflict|rejected`, server copy on conflict)
   - `GET /api/v1/sync/changes?since=&limit=`: farm-scoped changes and tombstones, with the next cursor
   - `GET /api/v1/sync/bootstrap`: initial snapshot, paginated
5. **Auth hardening:** add `POST /api/v1/auth/refresh` (sliding refresh cookie) and `POST /api/v1/auth/logout`. Set cookies with `Secure` and
   `SameSite=Lax`. Move the JWT secret to an environment variable. Replace the wildcard CORS rule with a global
   `CorsConfigurationSource` that allows explicit origins and credentials.
6. **Fix role enforcement** (`@PreAuthorize`) and **farm scoping**: every sync query must be filtered by the caller's `farmId`.
7. **Tests:** unit and integration tests, plus REST Assured tests for push, pull, idempotency, and conflict handling. Update `README` and OpenAPI docs.
   ✅ Replaying the same push twice creates no duplicates. A stale `version` returns `conflict`. The Flutter app still works.

### Phase 1: Web foundation and design system (1–2 weeks) ✅ Done

> **Status: implemented.** See `poultry-pal-plus-web/README.md`. Requires **Node 22** (Angular 20 needs ≥ 20.19).
>
> What was built:
>
> - **Tooling:** ESLint (`angular-eslint`), Prettier (`format`, `format:check`), Karma headless (`test:ci`), Playwright (`e2e`).
> - **PWA:** service worker that precaches the app shell, every lazy route, and the self-hosted fonts and icon font.
>   Includes a manifest, maskable icons generated from the Flutter hen logo, an update prompt (`AppUpdateService`) and install
>   prompt (`InstallPromptService`).
> - **Design system:** Material 3 theme generated from the Flutter palette: sienna `#8B5A2B` and amber `#F4A623` for light,
>   and the "Farm night" green `#6FAF5B` for dark. Brand tokens are `--pp-*` CSS variables. Fonts are self-hosted Poppins
>   and Inter plus Material Icons Round.
> - **Theme switching:** system, light, dark or "Sunlight" (high contrast for outdoor use: white surfaces, black text,
>   solid borders, 7:1 contrast), stored on the device.
> - **Core services:** `APP_CONFIG`, `ApiResponse<T>` types that match the backend envelope, and an interceptor that sends
>   cookies only to `/api`. Also `ThemeService`, `ConnectivityService`, the `SyncStatusService` read model (fed by Phase 2),
>   and a `PageTitleStrategy`.
> - **Shell:** sidebar at ≥ 1024 px, navigation rail at 600–1023 px, and on phones a bottom bar with a Quick-add FAB and a
>   "More" drawer. The top bar holds the sync badge, appearance menu and account menu. Also an offline banner
>   (`aria-live`), a skip link, and a 404 page.
> - **Shared UI:** `page-header`, `kpi-card`, `empty-state`, `confirm-dialog` with its service, `sync-badge`,
>   `connectivity-banner` and `skeleton`.
> - **Pages:** dashboard (KPI cards, quick actions, reminders, activity) and Settings (appearance, install). The other
>   features are lazy-loaded placeholders driven by route data.
> - **Deployment:** multi-stage `Dockerfile`, then nginx (`nginx.conf.template`) with SPA fallback, same-origin `/api`
>   proxy (`API_UPSTREAM`), immutable caching of hashed assets, no-cache for the shell and service-worker files, and CSP
>   and security headers. Also a `poultry-pal-web` service in `poultry-pal-service/docker-compose.yml` and
>   `.github/workflows/web-ci.yml` (lint, format, unit, build, e2e).
> - **Tests:** 23 unit tests and 6 Playwright tests (desktop and mobile), including *reload with the network disabled*.
>   The initial bundle is about 146 kB transferred.
>
> Where the implementation differs from the plan below:
>
> 1. **No `@angular/animations`:** `provideAnimationsAsync()` was dropped because Material 20 no longer needs it.
> 2. **Critical-CSS inlining is off** in production, because its inline `onload` handler would violate the CSP.
> 3. **Update checks** run when the app becomes visible or goes back online, not on a timer. A timer keeps the app from
>    becoming stable and delays service-worker registration.
> 4. **No Lighthouse score:** Lighthouse 12 removed the PWA category, so the offline Playwright test is the exit check.
> 5. **Brand colours:** `DESIGN_SYSTEM_QUICK_REF.md` is stale (it lists green `#2D5016`).
>    `poultry_pal_plus_app/lib/theme/app_theme.dart` is the source of truth.
> 6. **Not done:** Husky and lint-staged (optional), and committing the scaffold. These are left to the team.

- ✅ ~~Scaffold the Angular app~~: `poultry-pal-plus-web` (Angular 20.3, strict mode, SCSS, Prettier, Karma and Jasmine) is done.
- Commit the scaffold. Move `poultry-pal-plus-web/.github/copilot-instructions.md` content to the repository-root `.github/`.
- Tooling: `ng add @angular-eslint/schematics`, add `lint` and `format` npm scripts, and optionally add Husky with lint-staged.
- Run `ng add @angular/pwa` (service worker, manifest, icons) and `ng add @angular/material` (custom theme instead of a prebuilt one).
- Install `dexie`, `ng2-charts`, `chart.js`, and `date-fns`. Add Playwright as a dev dependency.
- Generate environment files with `ng generate environments` and set `apiBaseUrl`: `/api` behind nginx in production,
  plus a `proxy.conf.json` that sends `/api` to `http://localhost:8090` for `ng serve`. Using the same origin in development keeps the auth cookie working.
- Update `app.config.ts`: add `provideHttpClient(withFetch(), withInterceptors([...]))`, `provideAnimationsAsync()`,
  `provideServiceWorker('ngsw-worker.js', { enabled: !isDevMode(), registrationStrategy: 'registerWhenStable:30000' })`,
  and `withComponentInputBinding()` on the router.
- Replace the CLI placeholder `app.html` with the app shell.
- Create design tokens, the Material 3 theme from the Flutter palette, self-hosted fonts, light and dark modes.
- Build the responsive app shell (sidenav, rail, and bottom navigation), routing with lazy-loaded features, and a 404 page.
- Add shared components: `kpi-card`, `page-header`, `empty-state`, `confirm-dialog`, `sync-badge`, `connectivity-banner`, `skeleton`.
- Set up CI (GitHub Actions) for lint, tests, and build, plus Docker and nginx.
  ✅ The installed PWA opens the shell with the network disabled. Lighthouse PWA ≥ 90.

### Phase 2: Offline data layer and sync engine (2–3 weeks) **[core]** ✅ Done

> **Status: implemented.** The code is in `poultry-pal-plus-web/src/app/data/`. See the README section "Offline data layer".
>
> What was built:
>
> - **Dexie schema v1** (`data/db/app-db.ts`): `farms, coops, sales, mortalities, expenses, eggRecords, reminders, users,
>   settings, outbox, syncMeta, conflicts`. It documents the migration strategy (add `version(n)` and never edit old ones).
>   `liveSignal()` turns any Dexie `liveQuery` into a signal and updates across tabs.
> - **Repositories** (`data/repositories/`): reads come from IndexedDB. Every write (create, update, delete) stores the
>   record and its outbox operation in one transaction, and server-derived totals are computed locally.
>   - Coop, sale, mortality, expense, egg-packaging and reminder repositories are provided, plus `FarmContextRepository`
>     for the user and settings.
> - **Outbox** (`SyncQueue`): client UUIDs and FIFO order.
>   - Coalescing: five offline edits are sent as one UPSERT, and a record created and then deleted offline sends nothing.
>   - Commands: retry, discard, keep mine, use server.
> - **Sync engine** (`SyncEngine`):
>   - Runs single-flight, guarded by a Web Lock across tabs. It pushes in batches of 200, isolating a malformed operation
>     if a batch fails validation.
>   - Pulls with the cursor, or bootstraps a new device.
>   - Triggers: app start, coming online, the tab becoming visible, a local change (debounced), every 60 s, and "Sync now".
>   - Exponential backoff with jitter. On a 401 it refreshes the session once, then pauses with "Sign in to sync".
>   - Shares syncing and auth state with other tabs through a `BroadcastChannel`.
>   - Asks for persistent storage. Pulled data never overwrites records that have unsynced changes.
> - **Conflicts:**
>   - Changes to different fields are merged automatically, and the result is re-sent under a new opId.
>   - Changes to the same field go to the conflict store. The **Review dialog** shows each field side by side with
>     "Keep mine" and "Keep server version".
>   - Later changes to the same record wait behind the conflict, and a coop's records wait behind the coop.
> - **Sync Center** (`/sync`):
>   - Shows the current state, "Sync now", "Needs your attention" (review, retry, discard) and "Waiting to sync".
>   - Shows how much storage the device is using, with a "Download fresh copy" button.
> - **Expenses page** (moved forward from Phase 4 as the first real feature, so the exit test runs through the UI):
>   - A list with a sync chip on every record and this month's total.
>   - An add/edit dialog using the mobile app's 18 expense categories, plus delete. `?action=new` opens the add dialog.
> - **Dashboard KPIs** are now live from IndexedDB: live birds, eggs packaged today, sales this month, losses in the last 7 days.
> - **Tests:**
>   - 53 unit tests, including a `FakeSyncServer` that implements the backend contract. They cover coalescing,
>     atomicity, applied, rejected, auto-merge, conflict resolution, tombstones, protection of pending records,
>     backoff and 401 handling.
>   - 10 Playwright tests run against an in-memory mock `/api/v1` (`e2e/mock-api.mjs`, with an isolated tenant per test).
>     The **exit test passes**: go offline, create 20 expenses, reload, go online, and all 20 exist on the server exactly once.
>     A second test checks that a change made on another device is pulled.
>   - The initial bundle is about 189 kB transferred (Dexie adds about 40 kB).
>
> Where the implementation differs from the plan below:
>
> 1. **No `farmId` index on child tables:** the local store holds one farm (the signed-in user's), so a coop index is enough.
>    Signing in to a different farm will clear the store (Phase 3).
> 2. **No separate heartbeat request:** the 60 s pull doubles as the reachability check. `ConnectivityService.online` is
>    `navigator.onLine && serverReachable`.
> 3. **Expenses page added early** (see above). The other Phase 4 features will reuse the same repository, `SyncChip` and
>    form-dialog pattern.
> 4. **Before the first sync completes, the sync status shows "Syncing…"** rather than "Synced".


- Dexie schema: `farms, coops, sales, mortalities, expenses, eggRecords, reminders, users, settings, outbox, syncMeta, conflicts`,
  with indexes on `farmId`, `coopId`, `date`, and `syncStatus`.
- Repositories expose `liveQuery` results as signals and implement the command pattern (atomic local write plus outbox entry).
- Sync engine: connectivity service (`online`/`offline` events plus a heartbeat ping, because `navigator.onLine` can be wrong),
  Web Locks, push and pull, backoff, 401 pause, and a cross-tab `BroadcastChannel`.
- Add the conflict store and resolution dialog, plus the Sync Center page.
- Add a schema-migration strategy using Dexie versioning.
  ✅ Playwright test: go offline, create 20 records, reload the page, go online, and confirm all 20 records exist on the server exactly once.

### Phase 3: Authentication and onboarding (1 week) ✅ Done

> **Status: implemented.** See the README section "Authentication" in `poultry-pal-plus-web/README.md`.
> - `AuthService` (`core/auth/`) restores the cached user from IndexedDB at startup, so someone who signed in before can
>   reopen the app offline. Signing in as a different user clears the device first, with a warning if changes are unsynced.
> - `authGuard`, `guestGuard`, `permissionGuard('FARM_MANAGER')` and the `*appCan` directive. Workers do not see Team
>   in the navigation and are redirected away from it.
> - Login (with "Keep me signed in"), register (creates the farm), a re-authentication dialog that keeps the outbox,
>   and sign-out that tries a final sync and warns before discarding unsynced changes.
> - Backend: `LoginRequest.rememberMe`. When it is `false`, the refresh cookie is a browser-session cookie, and refresh
>   rotation keeps that setting.
> - Tests: unit specs for the service, guards, directive and login page; Playwright `e2e/auth.spec.ts` covers the exit
>   criterion (sign in, go offline, reload, record an expense), sign-out, wrong password and registration.
>
> **Deviations from the plan:**
> - The `{success,message,data}` envelope is unwrapped and errors are mapped by `unwrapApi()`/`ApiError`
>   (`core/http/api-error.ts`), not by the interceptor. The interceptor still only adds credentials.
> - "Remember me off" is tracked with a `pp_session` browser-session cookie rather than `sessionStorage`, so all tabs agree.
> - Signing out while offline can't clear the HttpOnly cookies. The local data is still wiped and the guard plus the
>   suspended sync engine still block access.
> - The re-auth and confirm dialogs are lazy-loaded so the initial bundle stays under the 750 kB budget.


- Login (remember me) and registration (farm creation). Use an HTTP interceptor for credentials, envelope unwrapping, and error mapping.
- Bootstrap sync after the first login. Cache the user and roles for offline sessions.
- Route guards and a role-based `*appCan="'FARM_MANAGER'"` directive that hides actions workers cannot perform.
- Re-authentication prompt that preserves the outbox, and logout with an unsynced-data warning.
  ✅ A user who signed in previously can open the app offline and continue working.

### Phase 4: Core farm operations (3–4 weeks) ✅ Done

> **Status: implemented.** See "Farm operations" in `poultry-pal-plus-web/README.md`.
> - **Coops & batches** (`/coops`): card and table views (the choice is remembered), with live birds, flock age,
>   deaths and mortality rate (red above 5 %). Each card links straight to a sale, loss or (layers only) egg form for
>   that coop. Managers add, edit and delete coops, and start a new batch after the mobile app's "Confirm New Batch
>   Addition" prompt. Anyone can change a growth phase in place or move the flock into an empty coop of the same type.
>   A banner offers to update every coop that is due for a phase change according to its age (broilers 3/6 weeks,
>   layers 6/12 weeks, as in the backend).
> - **Sales, Mortality, Egg production:** list pages with summaries and sync chips, plus add/edit dialogs with live
>   totals (dozens × price or chickens × price; boxes × box size). Sales can be marked as paid. Mortality reasons
>   come with suggestions. Egg packaging only offers layer coops.
> - **Quick Add:** the phone's "+" button, a "Quick add" menu in the top bar on tablet and desktop, and the `N` shortcut
>   (ignored while typing or when a dialog or menu is open). Each action opens its page with `?action=new` (and
>   `&coop=<id>` from a coop card), which opens the form: 3 taps. "Add a coop" is shown to managers only.
> - **Backend:** the sync push accepts `COOP` `ACTION` operations (`NEW_BATCH`, `PHASE_TRANSITION`) that are applied
>   atomically with the coop's records (README §6.1, `SyncControllerTest`).
> - **Tests:** 91 unit tests (coop rules, the coop lifecycle in the repository, the `N` shortcut) and 28 Playwright tests.
>   The new `e2e/farm-operations.spec.ts` covers an offline sale through Quick Add, a loss and eggs from a coop card,
>   and a flock move followed by a new batch, all checked on the mock server.
>
> **Deviations from the plan:**
> - **Flock size is not reduced on the server.** The backend and the mobile app keep `numberOfChickens` as the
>   number of birds placed. The web app shows *live birds* = placed − recorded deaths (on the coop cards and the
>   dashboard), and the mortality rate uses the mobile app's formula, deaths / (birds + deaths).
> - **Phase transitions:** the target coop must be empty and of the same type. The records move with the flock
>   (the legacy endpoint dropped them) and the coop's responsible users are kept.
> - **Archive browsing** is done: `GET /api/v1/farm/archived-batches` (owner/manager only) feeds `/coops/archive`, which is online-only because archives are history and not synced.
> - **Bundle budget:** the shell-level Quick Add menu and the coop-action sync code bring the initial bundle to about
>   751 kB, so the warning budget was raised to 800 kB (the error limit stays at 1 MB). Dialogs are still lazy-loaded.

Each feature is built offline-first and is fully responsive.

| Feature | Scope |
|---|---|
| Coops and batches | List, grid, and table views. Create and edit coops (type, chicken count, arrival date, growth phase). Archive coops, add new batches, and run phase transitions across several coops |
| Sales | Egg sales (dozens × price) and chicken sales, buyer, payment status, and auto-calculated total |
| Mortality | Date, count, reason (with suggestions), and automatic recalculation of the flock size |
| Expenses | Type (feed, medicine, utilities, …), amount, and notes |
| Egg packaging | Egg size, box size, number of boxes, and auto-calculated total eggs |
| Quick Add | FAB and keyboard shortcut (`N`) to record any of the above in ≤ 3 taps |

✅ All CRUD actions work offline, show a pending badge, and sync. Totals match the Flutter app's results for the same data.

**************************START******************************
### Phase 5: Dashboard, reminders and reports (2 weeks) ✅ Done

> **Status: implemented.** See "Dashboard, reminders and reports" in `poultry-pal-plus-web/README.md`.
> - **Dashboard:** KPIs (live birds, eggs, sales, expenses, profit, losses), sales/expenses and loss charts, due reminders
>   and recent activity, all computed from IndexedDB with a date-range filter (7 days to this year).
> - **Reminders:** overdue, upcoming and completed tasks across coops; Complete or N/A with a comment (a `REMINDER`
>   `ACTION` sync op, same values as the mobile app); optional browser notification once a day when tasks are due.
> - **Reports:** per-coop preview from local data, CSV (summary) and Excel (summary plus sales, expenses, mortality and
>   egg sheets), server PDFs (online only), and email report/schedule requests stored in a new `reportRequests` Dexie
>   table (schema v2) and sent when the server is reachable.
> - Charts are small inline SVG components, so no chart library was added to the bundle.
> - Excel export writes an Excel 2003 XML workbook (`.xls`), avoiding a spreadsheet dependency.
> - Tests: unit specs for metrics, export and reminder grouping; `e2e/dashboard-reports.spec.ts` covers the exit
>   criterion offline.
>
> **Deviations:** the report preview is on-screen tables (no in-browser PDF); PDF files come from the existing
> `/api/farm/download-*` endpoints. Archived-batch browsing is online-only at `/coops/archive`.

- Dashboard KPIs and charts computed locally, with a date-range filter.
- Reminders: upcoming and overdue tasks, complete or N/A, comments, and an optional browser Notifications API prompt.
- Reports: on-screen preview from local data, PDF download, and email report or schedule requests (queued when offline).
- Client-side CSV and Excel export of tables.
  ✅ The dashboard loads in under 1 s from IndexedDB with no network connection.

### Phase 6: Team, profile and settings (1 week)

- Farm details and address, team members, roles, coop assignment, user activation and removal (manager only).
- Login details, currency setting, theme toggle, storage usage, a "Clear local data" action, and the app version or "Update available" status.
  ✅ Implemented in the web app. Team administration uses farm-scoped `/api/v1/team` endpoints; profile, password, farm details and currency changes use authenticated `/api/v1` endpoints that derive the acting user and farm from the session. Clearing local data requires an online connection and no pending sync operations, then reloads the server copy.

### Phase 7: Hardening and release (1–2 weeks)

- **Testing:** service tests at ≥ 80% coverage for the data and sync layers, component tests, and Playwright E2E tests for offline, flaky
  network, multi-tab, conflict, and token-expiry scenarios.
- **Performance:** bundle budgets, route-level lazy loading, virtual scrolling for long lists, image optimisation.
- **Security:** CSP headers, no tokens in `localStorage` (HttpOnly cookie only), input validation, dependency audit,
  and wiping IndexedDB on logout.
- **Observability:** client error logging with a queued upload, plus sync metrics (queue depth, failures).
- **Docs:** user guide ("Working offline"), deployment guide, and API changelog.
  ✅ Pilot with 2–3 farms. No data-loss incidents during a 2-week trial.

### Phase 8 (follow-up): Bring Flutter to parity

Reuse the `/api/v1/sync` contract in Flutter: `drift` or `sqflite` local storage, an outbox, `connectivity_plus`, and the same conflict rules.
Fix the reminders status dot so it shows real connectivity. Then deprecate the legacy `/api/farm/*` endpoints with a versioning notice.

---

## 5. Timeline Summary

| Phase | Duration | Depends on |
|---|---|---|
| 0 Backend sync readiness | 2–3 wks | — |
| 1 Foundation and design system | 1–2 wks | can run in parallel with Phase 0 |
| 2 Offline data and sync engine | 2–3 wks | 0, 1 |
| 3 Auth and onboarding | 1 wk | 0, 2 |
| 4 Core operations | 3–4 wks | 2, 3 |
| 5 Dashboard, reminders, reports | 2 wks | 4 |
| 6 Team and settings | 1 wk | 3 |
| 7 Hardening and release | 1–2 wks | all |
| **Total** | **≈ 12–17 weeks** | |

## 6. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Embedded `Farm` aggregate causes write contention | Use `@Version` with per-record merge on the server. Later, consider moving high-volume records (sales, mortality, expenses) into their own collections |
| Browser evicts IndexedDB (Safari) | `storage.persist()`, an install prompt, and a warning when unsynced data is older than N days |
| Session expires while offline | Pause sync without data loss, and use the refresh-token endpoint |
| Clock skew between devices | Server assigns `updatedAt` and the cursor. Client timestamps are informational only |
| Duplicate submissions on flaky networks | Client UUIDs plus `Idempotency-Key` |
| Contract drift between web, Flutter, and backend | A versioned `/api/v1` contract, an OpenAPI-generated TypeScript client (`openapi-typescript`), and contract tests in CI |

## 7. Immediate Next Steps

1. Approve the architecture, especially same-origin nginx deployment and the conflict policy.
2. ~~Phase 0~~ and ~~Phase 1~~ are done.
3. ~~Phase 2~~ is done: offline data layer, sync engine, Sync Center, conflict review and Expenses.
4. ~~Phase 3~~ is done: sign-in, registration, offline sessions, role-based UI and safe sign-out.
5. ~~Phase 4~~ is done: coops and batches, archived-batch browsing, sales, mortality, egg packaging and Quick Add.
6. ~~Phase 5~~ is done: dashboard, reminders and reports.
7. ~~Phase 6~~ is done: team administration, profile, farm details and settings.
8. Next is Phase 7: hardening and release.
