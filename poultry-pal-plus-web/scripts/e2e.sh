#!/usr/bin/env bash
# Runs the Playwright end-to-end tests against a fresh production build.
# Run `scripts/e2e.sh --help` for options.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${E2E_PORT:-4300}"

speed="normal"
headless=0
build=1
ui=0
report=0
projects=()
grep_pattern=""
files=()
extra=()

usage() {
  cat <<'EOF'
Usage: scripts/e2e.sh [options] [test files...] [-- extra playwright args]

Runs the Playwright e2e tests against a fresh production build. By default a browser
window opens and each action pauses for 1 second, so you can follow along.

Options:
  -s, --speed <speed>    How long to pause before each browser action:
                           slow    2 s
                           normal  1 s (default)
                           fast    no pause
                           <ms>    any number of milliseconds, e.g. 1500
      --headless         Hide the browser and run tests in parallel (fast, like CI).
  -p, --project <name>   Only run on "desktop" or "mobile" (repeatable). Default: both.
  -g, --grep <text>      Only run tests whose title matches <text>.
      --no-build         Reuse the existing build in dist/ (faster when only tests changed).
      --ui               Open Playwright's interactive UI to pick and step through tests.
      --report           Open the HTML report after the run.
  -h, --help             Show this help.

Examples:
  scripts/e2e.sh                                  # everything, visible, 1 s per action
  scripts/e2e.sh -s slow -p desktop -g "sign"     # sign-in tests on desktop, 2 s per action
  scripts/e2e.sh e2e/auth.spec.ts --no-build      # one file, skip the build
  scripts/e2e.sh --headless                       # quick full run without a window
EOF
}

fail() {
  echo "e2e: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s | --speed) speed="${2:?--speed needs a value}"; shift 2 ;;
    --headless) headless=1; shift ;;
    -p | --project) projects+=("${2:?--project needs a value}"); shift 2 ;;
    -g | --grep) grep_pattern="${2:?--grep needs a value}"; shift 2 ;;
    --no-build) build=0; shift ;;
    --ui) ui=1; shift ;;
    --report) report=1; shift ;;
    -h | --help) usage; exit 0 ;;
    --) shift; extra+=("$@"); break ;;
    -*) fail "unknown option '$1' (see --help)" ;;
    *) files+=("$1"); shift ;;
  esac
done

case "$speed" in
  slow) slow_mo=2000 ;;
  normal) slow_mo=1000 ;;
  fast) slow_mo=0 ;;
  '' | *[!0-9]*) fail "--speed must be slow, normal, fast or a number of milliseconds" ;;
  *) slow_mo="$speed" ;;
esac

for project in "${projects[@]}"; do
  [[ "$project" == desktop || "$project" == mobile ]] ||
    fail "unknown project '$project' (use desktop or mobile)"
done

# Angular 20 needs Node >= 20.19. Fall back to nvm's Node 22 when the default node is older.
node_ok() {
  command -v node >/dev/null &&
    node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>20||(a===20&&b>=19)?0:1)'
}
if ! node_ok && [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
  set +u
  # shellcheck disable=SC1091
  source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  nvm use 22 >/dev/null 2>&1 || true
  set -u
fi
node_ok || fail "Node >= 20.19 is required (found $(node -v 2>/dev/null || echo none)). Try: nvm install 22"

cd "$APP_DIR"
export NG_CLI_ANALYTICS=false

[[ -d node_modules ]] || { echo "Installing dependencies…"; npm ci; }

if ! ls "${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}" 2>/dev/null | grep -q '^chromium'; then
  echo "Installing the Playwright Chromium browser…"
  npx playwright install chromium
fi

# Playwright reuses a server already listening on the port, so a test server left over from an
# earlier run would serve an old build or an old API mock. Stop it, but never touch other programs.
if command -v ss >/dev/null; then
  for pid in $(ss -ltnpH "sport = :$PORT" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u); do
    if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q 'e2e/serve.mjs'; then
      echo "Stopping the old test server on port $PORT (pid $pid)…"
      kill "$pid"
      sleep 1
    else
      fail "port $PORT is used by another program (pid $pid). Free it or set E2E_PORT."
    fi
  done
fi

if [[ $build -eq 1 ]]; then
  echo "Building the app…"
  npx ng build
elif [[ ! -f dist/poultry-pal-plus-web/browser/index.html ]]; then
  fail "no build found in dist/. Run without --no-build."
fi

args=()
for project in "${projects[@]}"; do args+=(--project "$project"); done
[[ -n "$grep_pattern" ]] && args+=(--grep "$grep_pattern")
[[ $ui -eq 1 ]] && args+=(--ui)
if [[ $report -eq 1 ]]; then
  args+=(--reporter list,html)
  export PLAYWRIGHT_HTML_OPEN=never
fi
args+=("${files[@]}" "${extra[@]}")

if [[ $headless -eq 1 ]]; then
  export E2E_HEADLESS=1
  echo "Running e2e tests without a visible browser…"
else
  export E2E_SLOWMO="$slow_mo"
  echo "Running e2e tests in a visible browser, pausing ${slow_mo} ms before each action…"
fi

status=0
npx playwright test "${args[@]}" || status=$?

if [[ $report -eq 1 ]]; then
  npx playwright show-report
elif [[ $status -ne 0 ]]; then
  echo
  echo "Some tests failed. To replay a failure step by step:"
  echo "  npx playwright show-trace test-results/<test-folder>/trace.zip"
fi
exit "$status"
