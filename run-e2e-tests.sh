#!/usr/bin/env bash
# Runs the live Playwright suite against a throw-away Docker stack
# (MongoDB + Mailpit + backend + web). Usage:
#   ./run-e2e-tests.sh                        # everything, desktop and mobile
#   ./run-e2e-tests.sh --project=desktop      # desktop only (or --project=mobile)
#   ./run-e2e-tests.sh coops                  # one page: extra args go to Playwright
#
# The browser is visible and paused before every action (800 ms) so you can follow along.
#   E2E_SLOWMO=2000 ./run-e2e-tests.sh   # slower (ms per action)
#   ./run-e2e-tests.sh --headless        # no window, full speed (also E2E_HEADLESS=1)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$ROOT/poultry-pal-plus-web"

for tool in docker node npm; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker daemon is not running." >&2; exit 1; }
node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)' \
  || { echo "Node 20+ is required (22 recommended)." >&2; exit 1; }

# Safety net: remove the stack even if Playwright was killed before its own teardown ran.
cleanup() {
  E2E_DB_NAME=poultry-pal-e2e E2E_MONGO_PASSWORD=x E2E_JWT_SECRET=x \
    docker compose -p ppp-e2e -f "$ROOT/docker-compose.e2e.yml" down --volumes --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# --headless is ours, not Playwright's.
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--headless" ]; then export E2E_HEADLESS=1; else ARGS+=("$arg"); fi
done
if [ "${E2E_HEADLESS:-}" != "1" ] && [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  echo "No display found; running headless. Set DISPLAY to watch the browser." >&2
  export E2E_HEADLESS=1
fi

cd "$WEB"
[ -d node_modules ] || npm ci --no-audit --no-fund
npx playwright install chromium >/dev/null

mkdir -p "$ROOT/test-results/reports"
npx playwright test -c "${E2E_CONFIG:-e2e-live/playwright.live.config.ts}" ${ARGS[@]+"${ARGS[@]}"}
