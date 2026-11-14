# Live E2E test plan (Phase 3)

All specs run on `desktop` (1920x1080) and `mobile` (Pixel 7) against the real backend, MongoDB and Mailpit.

| Spec              | Coverage                                                                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| 10-auth           | Register, login, bad credentials, logout, session handling, route guards                                                                      |
| 20-coops          | Coop create/edit/delete, batches, phases, worker visibility                                                                                   |
| 21-records        | Sales, mortality, expenses, eggs: create/edit/delete, deep links                                                                              |
| 30-dashboard      | KPI figures from seeded data, quick actions                                                                                                   |
| 31-reminders      | Reminder tabs, complete / not applicable / remove                                                                                             |
| 32-reports        | Report KPIs, by-coop table, report and schedule emails (Mailpit), PDF                                                                         |
| 33-sync-offline   | Offline writes, reload while offline, sync on reconnect, fresh copy                                                                           |
| 34-settings       | Profile, password policy, farm details, currency                                                                                              |
| 35-navigation     | Every nav entry, handset drawer/bottom bar, quick add                                                                                         |
| 36-sync-conflicts | Sync Center conflicts (keep mine/server/later), rejected change, discard                                                                      |
| 40-team           | Add/promote/assign coops/deactivate/production access/remove, roles                                                                           |
| 41-production     | Sections, settings, batch lifecycle to hatch result, houses, plans                                                                            |
| 42-admin-config   | App config create/edit/delete, masked secrets, protected mail entries                                                                         |
| 43-permissions    | Route x role matrix, API role matrix (401/403)                                                                                                |
| 50-ui-quality     | Overflow, controls in viewport, touch targets (48px), accessible names, single h1, focus visibility, skip link, dialog focus trap, fixed bars |

Known defects are asserted with `test.fail` and a `DEFECT` comment (chicken sale form, empty farm details on a new farm); they are triaged in Phase 6.
Candidate defect: the edit form submits unchanged fields, so changes to different fields of one record conflict instead of merging (36-sync-conflicts).

Phase 4 candidate defects: removed team member stays listed (40); custom batch reference is overwritten while typing (41); first production settings visit can show no equipment (parallel lazy initialisation, intermittent); admin's sync status spins forever because bootstrap answers 403 (42).

Phase 5 candidate defects (all `test.fail` in 50-ui-quality): handset touch targets under 48px (top-bar icon buttons 40px, toggle buttons 40px, sync badge 36px, action buttons 44px); equipment slide-toggle `aria-label` sits on the host so the inner switch has no accessible name; skip link navigates to `/#main-content` because of `<base href="/">`; `mat-button-toggle` shows no visible keyboard focus.

All defects are documented in `test-results/defects/DEF-###-*.md` (DEF-001 to DEF-016). Full-run history (Phase 6): run 1 had one failure (drawer still sliding in, a test bug, fixed in `ShellPage.openNavigation`); run 2 had two failures caused by an intermittent 504 on the production snapshot (DEF-016); run 3 had none. 15 known-defect tests (`test.fail`) and 5 skips per run.
