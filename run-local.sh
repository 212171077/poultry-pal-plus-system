#!/usr/bin/env bash
# Starts Poultry Pal Plus locally in Docker (MongoDB + Mailpit + backend + web) and runs the tests.
#
#   ./run-local.sh up              # build and start the stack, then print the URLs
#   ./run-local.sh status          # show container state and URLs
#   ./run-local.sh logs [service]  # follow logs (backend, web, mongo, mailpit)
#   ./run-local.sh down            # stop and remove the stack and its data
#   ./run-local.sh restart         # down + up (fresh, empty database)
#   ./run-local.sh test unit       # lint + web unit tests + production build
#   ./run-local.sh test e2e [args] # Playwright suite on its own throw-away stack (see run-e2e-tests.sh)
#   ./run-local.sh test all        # unit, then e2e
#
# The local stack uses its own ports, so it can run next to the E2E stack. The database is
# empty on every `up` and mail is caught by Mailpit. Never point this at dev or prod data.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$ROOT/poultry-pal-plus-web"
PROJECT=ppp-local
COMPOSE_FILE="$ROOT/docker-compose.e2e.yml"

export E2E_WEB_PORT="${LOCAL_WEB_PORT:-4320}"
export E2E_BACKEND_PORT="${LOCAL_BACKEND_PORT:-8200}"
export E2E_MONGO_PORT="${LOCAL_MONGO_PORT:-27120}"
export E2E_MAILPIT_PORT="${LOCAL_MAILPIT_PORT:-8130}"
export E2E_DB_NAME="${LOCAL_DB_NAME:-poultry-pal-local}"
export E2E_MONGO_PASSWORD="${LOCAL_MONGO_PASSWORD:-local-mongo-password}"
# Must be base64 (the backend decodes it) and at least 32 bytes when decoded
export E2E_JWT_SECRET="${LOCAL_JWT_SECRET:-bG9jYWwtb25seS1qd3Qtc2VjcmV0LWNoYW5nZS1tZS0wMTIzNDU2Nzg5YWJjZGVm}"

need() {
  for tool in "$@"; do
    command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
  done
}

need_docker() {
  need docker
  docker info >/dev/null 2>&1 || { echo "Docker daemon is not running." >&2; exit 1; }
}

compose() { docker compose -p "$PROJECT" -f "$COMPOSE_FILE" "$@"; }

need_node() {
  need node npm
  node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)' \
    || { echo "Node 20+ is required (22 recommended)." >&2; exit 1; }
}

urls() {
  cat <<EOF

  Web app   http://localhost:${E2E_WEB_PORT}
  API       http://localhost:${E2E_BACKEND_PORT}
  Mailpit   http://localhost:${E2E_MAILPIT_PORT}   (all outgoing mail is caught here)
  MongoDB   localhost:${E2E_MONGO_PORT}

  Sign up in the web app to create a farm; verification/reset emails appear in Mailpit.
  System admin (seeded): systemnotification.cs@gmail.com
  Stop with: ./run-local.sh down
EOF
}

up() {
  need_docker
  echo "Building and starting the local stack (first run takes a few minutes)..."
  compose up -d --build --wait --wait-timeout 300
  echo "Stack is healthy."
  urls
}

unit_tests() {
  need_node
  cd "$WEB"
  [ -d node_modules ] || npm ci --no-audit --no-fund
  echo "== Lint =="; npm run lint
  echo "== Unit tests =="; npm run test:ci
  echo "== Production build =="; npm run build
}

e2e_tests() {
  "$ROOT/run-e2e-tests.sh" "$@"
}

case "${1:-help}" in
  up) up ;;
  down) need_docker; compose down --volumes --remove-orphans ;;
  restart) need_docker; compose down --volumes --remove-orphans; up ;;
  status) need_docker; compose ps; urls ;;
  logs) need_docker; shift; compose logs -f --tail=100 "$@" ;;
  test)
    case "${2:-all}" in
      unit) unit_tests ;;
      e2e) shift 2; e2e_tests "$@" ;;
      all) unit_tests; e2e_tests ;;
      *) echo "Usage: $0 test [unit|e2e [playwright args]|all]" >&2; exit 1 ;;
    esac
    ;;
  *) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
