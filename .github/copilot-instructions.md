### Poultry Pal Plus – Application Context

Poultry Pal Plus is a farm management system designed specifically for poultry farmers, particularly in regions with unreliable internet connectivity.

The system helps farmers manage daily operations such as:
- Tracking chicken batches (broilers and layers)
- Managing coops and their lifecycle
- Recording sales (eggs and chickens)
- Tracking mortality and identifying causes
- Recording expenses (feed, medicine, utilities, etc.)
- Managing egg production and packaging
- Handling farm workers and roles
- Managing reminders (vaccination, feeding, medication schedules)
- Generating farm reports
- Sending email summaries and schedules

### Target Users

- Small to medium-scale poultry farmers
- Farm workers with limited technical experience
- Users operating in low or intermittent internet environments

## Project Overview
This is a monorepo for Poultry Pal Plus:
- poultry-pal-service (Spring Boot backend)
- poultry_pal_plus_app (Flutter mobile app) — **ON HOLD: do not modify until the owner says otherwise**
- poultry-pal-plus-web (Angular 20 offline-first PWA; see WEB_APP_ROADMAP.md)

## Global Rules
- **MOBILE APP FREEZE (CRITICAL):** Do NOT make any changes to `poultry_pal_plus_app` (Flutter/Dart code, models, services, UI, tests, config, docs) until the owner explicitly lifts this freeze. This overrides every other rule below, including the Cross-System Rule.
- You are a senior full-stack engineer (Spring Boot + Flutter + Web-ready architecture)
- Always produce clean, production-ready, scalable code
- Always ensure backend and frontend stay in sync
- Never break existing contracts without updating all consumers and documenting changes

Cross-System Rule (CRITICAL)
Whenever endpoints or DTOs change:
1. Update backend
2. Update the Angular web app (`core/http` types, repositories, UI) when it consumes the endpoint
3. Do NOT update Flutter while the mobile freeze is active; mention in your response any endpoint/DTO change the mobile app will need later
4. Ensure no breaking changes


### Backend (Spring Boot)
- Controller -> Service -> Repository -> Domain
- Use DTOs (never expose entities)
- Use @Valid for validation
- Centralized exception handling
- SOLID principles

### API–Frontend Contract Enforcement
- Do not update Flutter models & services while the mobile freeze is active; note required mobile changes for later
- Suggest versioning if breaking changes

### Mobile (Flutter) — FROZEN, do not change until told otherwise
- Guidelines below apply only once the freeze is lifted
- Clean architecture
- No business logic in UI
- Strong typing
- Handle nulls safely
- Feature-based structure
- Separate UI, state, and services

### Web (Angular, `poultry-pal-plus-web`)
- Node 22 (`>=20.19`); Angular 20 + Angular Material 3. Commands: `npm run lint`, `npm run test:ci`, `npm run build`, `npm run e2e`
- Offline-first: the UI reads/writes the local store (Dexie, Phase 2); only the sync engine talks to the API. Never cache API responses in the service worker
- Data layer (`src/app/data/`): components read via `liveSignal()`/repositories and write only through repository commands (`create`/`update`/`remove`), which store the record and its outbox op in one Dexie transaction. Never call `/api/v1/sync` or write to Dexie tables from features
- New synced entities: add an `EntityDef` in `data/sync/entities.ts`, a repository in `data/repositories/`, and a new Dexie `version(n)` (never edit an existing one); keep `payloadFields` in sync with the backend `*Payload` DTOs
- Auth (`core/auth/`): read the session from `AuthService` signals (`user`, `signedIn`, `canManageFarm`). Protect routes with `authGuard`/`permissionGuard('FARM_MANAGER')`, and hide manager-only actions with `*appCan="'FARM_MANAGER'"`. API calls outside sync use `unwrapApi()` and get an `ApiError`
- Keep the initial bundle under the 800 kB warning budget: lazy-load dialogs (`MatDialog`, confirm and re-auth) from shell, top-bar or nav code with `await import()` + `Injector.get`
- Record pages (sales, mortality, eggs, …) extend `RecordListPage` (`shared/records/record-page.ts`) so `?action=new&coop=<id>` opens the form; quick actions live in `QUICK_ACTIONS` (`layout/navigation.ts`)
- Coop batch/phase changes go through `CoopRepository.startNewBatch()`/`transitionPhase()` (a `COOP` `ACTION` sync op); coop rules (growth phases, mortality rate) live in `data/models/coop-rules.ts`
- Show per-record sync state with `<app-sync-chip>`; send users to the Sync Center (`/sync`) for failures and conflicts
- Structure: `core/` (singleton services), `layout/` (shell, navigation), `shared/ui/` (reusable presentational components), `features/<name>/` (lazy routes via `<name>.routes.ts`)
- Standalone components (do NOT set `standalone: true`), `ChangeDetectionStrategy.OnPush`, `input()`/`output()`, signals + `computed()` for state (never `mutate`)
- Use `inject()`, `providedIn: 'root'` for singleton services, and the `host` object instead of `@HostBinding`/`@HostListener`
- Native control flow (`@if`, `@for`, `@switch`); class/style bindings instead of `ngClass`/`ngStyle`; `NgOptimizedImage` for static images
- Reactive forms; strict typing (no `any`, use `unknown`)
- Styling: use `--pp-*` design tokens and `--mat-sys-*` variables (never raw hex in components); keep component styles under the 4 kB budget
- Accessibility: WCAG AA contrast, visible focus, ARIA labels on icon-only buttons, 48px touch targets

## API Contract
All responses:
{
  "success": true,
  "message": "string",
  "data": {}
}

## Coding Standards

### Java
- No business logic in controllers
- Use ResponseEntity
- Clean service layer

### Dart (applies only once the mobile freeze is lifted)
- Keep widgets small
- No business logic in UI
- Use proper null safety

## Performance
- Avoid N+1 queries
- Use pagination
- Optimize queries

## Security
- Never expose sensitive data
- Validate all inputs

## Testing
- Backend: Unit + Integration + REST Assured
- Mobile: Service + UI tests (frozen until the freeze is lifted)
- Web: Jasmine/Karma unit tests for services and components, Playwright e2e (including offline)

## Sync & Consistency
- Handle duplicates
- Eventual consistency
- Prevent stale overwrites

## Copilot Instructions
- Follow existing patterns
- Keep consistency
- Do not introduce unnecessary frameworks

## Summary
Focus on:
- Reliability
- Maintainability
- Scalability