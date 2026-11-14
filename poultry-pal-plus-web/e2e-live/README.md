# Live E2E suite

Full-stack Playwright tests that drive the Angular app against the **real** Spring Boot backend, a dedicated MongoDB and Mailpit, all started in Docker. Nothing is mocked. Every spec runs twice: `desktop` (1920x1080) and `mobile` (Pixel 7, 390x844).

This is separate from the mock-API suite in `../e2e` (`npm run e2e`).

## Prerequisites

- Docker with the daemon running (and `docker compose`)
- Node 20+ (22 recommended)
- Free ports 4310 (web), 8190 (backend), 27117 (MongoDB), 8125 (Mailpit). Override with `E2E_WEB_PORT`, `E2E_BACKEND_PORT`, `E2E_MONGO_PORT`, `E2E_MAILPIT_PORT`.

First time only: `cd poultry-pal-plus-web && npm ci && npx playwright install chromium` (the runner does both if missing).

## Running

From the repository root:

```bash
./run-e2e-tests.sh                              # everything, desktop and mobile
./run-e2e-tests.sh --project=desktop            # or --project=mobile
./run-e2e-tests.sh coops                        # one page: a spec filename regex
./run-e2e-tests.sh 21-records --project=mobile  # one page, one project
./run-e2e-tests.sh coops -g "create"            # tests whose title matches
./run-e2e-tests.sh --retries=0                  # extra arguments go to Playwright
```

By default the browser is **visible** and pauses 800 ms before every action so you can follow along (about 2.5x slower). Adjust or turn it off:

```bash
E2E_SLOWMO=2000 ./run-e2e-tests.sh coops   # slower, in ms per action
E2E_SLOWMO=300 ./run-e2e-tests.sh coops    # faster
./run-e2e-tests.sh --headless              # no window, full speed (also E2E_HEADLESS=1)
```

Without a display (`DISPLAY`/`WAYLAND_DISPLAY` unset) it falls back to headless. A full headless run takes about 35 minutes (one worker, because tests share one stack); a visible run takes longer.

## Reproducing the defects on video

```bash
./run-e2e-defects.sh                    # every defect, desktop and mobile
./run-e2e-defects.sh --project=mobile -g "@DEF-004"   # one defect
E2E_SLOWMO=3000 ./run-e2e-defects.sh    # slower (default 1500 ms per action)
./run-e2e-defects.sh --headless         # no window; videos are still recorded
```

It runs the tests tagged `@DEF-###` (the `test.fail` tests) on the same Docker stack, in a visible slow browser, and saves `test-results/defect-videos/DEF-###-<project>.webm` plus an `index.md` that shows the assertion where each defect appears. Each test asserts the correct behaviour, so it "fails" at the defect; when a defect is fixed its test passes and the index says so (then remove the `test.fail`). Only defects with a test are covered: DEF-001 to DEF-008; the others (see `test-results/defects/`) have no automated reproduction. To cover a new defect, tag its `test.fail` with `{ tag: '@DEF-###' }`.

## What happens on a run

1. **Global setup** (`global-setup.ts`): checks Docker and ports, refuses anything that is not the dedicated `poultry-pal-e2e` database (`infra/db-guard.ts`), clears `test-results/screenshots`, builds and starts the stack from `docker-compose.e2e.yml` with throw-away secrets, waits for health, and seeds the system admin.
2. **Tests** create their own farms through the API (`freshFarm`, or the worker-scoped `sharedFarm` / `seededFarm`, which must not be mutated) and then drive the UI.
3. **Global teardown**: saves the stack log to `test-results/logs/stack.log` and removes the containers and volumes. The runner script also removes the stack if it is killed.

The database is created empty on every run and destroyed afterwards; no dev or production database is ever reachable.

## Structure

```
e2e-live/
  specs/          NN-page.spec.ts   (10 auth, 20-21 coops/records, 30-36 pages, 40-43 team/production/admin/permissions, 50 UI quality)
  fixtures/       test fixtures: farms, sign-in, numbered screenshots, browser diagnostics
  pages/          page helpers (records, shell, quality audit)
  infra/          Docker stack, API client, Mailpit client, DB guard, summary reporter
  TEST_PLAN.md    coverage per spec and candidate defects
```

Conventions:

- Browser console errors, page errors, failed requests and 5xx responses fail a test automatically. Expected 4xx responses are declared with `diagnostics.expect(...)`.
- A confirmed application defect is asserted with `test.fail(...)` and a `DEFECT` comment. The test passes while the defect exists and fails when it is fixed, which is the signal to remove `test.fail`. Defects are documented, not fixed, by this suite.
- Screenshots are named `<n>-<page>--<scenario>.png`, numbered in the order they were taken.

## Output (`test-results/` at the repository root)

| Path                      | Content                                                                            |
| ------------------------- | ---------------------------------------------------------------------------------- |
| `reports/summary.md`      | Totals, duration, by project and page, defects, screenshots, backend errors        |
| `reports/html/index.html` | Playwright HTML report (`npx playwright show-report ../test-results/reports/html`) |
| `screenshots/<project>/`  | Numbered screenshots; `screenshots/failures/` for failures                         |
| `artifacts/`              | Traces, videos and failure screenshots of failed tests                             |
| `logs/stack.log`          | Backend, MongoDB and Mailpit logs of the run                                       |
| `defect-videos/`          | Videos and index from `run-e2e-defects.sh`                                         |
| `defects/DEF-###-*.md`    | One file per documented application defect                                         |

## Cleaning up

`./clean-e2e-results.sh` deletes everything saved by test runs (screenshots, videos, traces, logs, reports). It keeps the defect write-ups in `test-results/defects/`; add `--all` to delete those too, or `--dry-run` to only list what would go.
