#!/usr/bin/env bash
# Reproduces the documented application defects and records a video of each one in
# test-results/defect-videos/ (DEF-###-<project>.webm plus index.md). Runs on the same throw-away
# Docker stack as run-e2e-tests.sh, in a visible browser at slow speed.
#   ./run-e2e-defects.sh                       # all defects, desktop and mobile
#   ./run-e2e-defects.sh --project=mobile      # one project
#   ./run-e2e-defects.sh -g "@DEF-004"         # one defect
#   E2E_SLOWMO=3000 ./run-e2e-defects.sh       # slower (ms per action, default 1500)
#   ./run-e2e-defects.sh --headless            # no window, videos are still recorded
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export E2E_CONFIG=e2e-live/playwright.defects.config.ts
exec "$ROOT/run-e2e-tests.sh" "$@"
