#!/usr/bin/env bash
# Build and push the combined Angular/Spring Boot image.
# Usage: ./push-image.sh [tag]
# Prompts for prod (poultry-pal-db, default tag latest) or dev (poultry-pal-db-dev, default tag dev).
# Overrides: DOCKER_USER (212171077), DOCKER_REGISTRY (empty for Docker Hub).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${1:-}"
IMAGE_NAME="poultry-pal"
DOCKER_USER="${DOCKER_USER:-212171077}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
REMOTE_REPO="${DOCKER_USER}/${IMAGE_NAME}"
if [[ -n "$DOCKER_REGISTRY" ]]; then
  REMOTE_REPO="${DOCKER_REGISTRY%/}/${REMOTE_REPO}"
fi
log() { echo "[push-image] $*"; }
error() { echo "[push-image][ERROR] $*" >&2; }

if (( $# > 1 )) || [[ -n "$TAG" && ! "$TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]]; then
  error "Usage: $0 [valid-docker-tag]"
  exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
  error "docker CLI not found. Install Docker and try again."
  exit 2
fi
if ! docker info >/dev/null 2>&1; then
  error "Docker is unavailable. Start Docker and check your permissions."
  exit 3
fi

while true; do
  printf 'Choose environment: [1] prod (poultry-pal-db)  [2] dev (poultry-pal-db-dev): '
  if ! read -r choice; then
    error "No environment selection received; build cancelled."
    exit 2
  fi
  case "$choice" in
    1|[Pp][Rr][Oo][Dd])
      ENV_NAME=prod; DB_NAME=poultry-pal-db; DEFAULT_TAG=latest
      break
      ;;
    2|[Dd][Ee][Vv])
      ENV_NAME=dev; DB_NAME=poultry-pal-db-dev; DEFAULT_TAG=dev
      break
      ;;
    *) error "Choose 1/prod or 2/dev." ;;
  esac
done
TAG="${TAG:-$DEFAULT_TAG}"
LOCAL_IMAGE="${IMAGE_NAME}:${TAG}"
REMOTE_IMAGE="${REMOTE_REPO}:${TAG}"

while true; do
  printf 'Choose protocol: [1] HTTPS (default)  [2] HTTP: '
  if ! read -r choice; then
    error "No protocol selection received; build cancelled."
    exit 2
  fi
  case "$choice" in
    ""|1|[Hh][Tt][Tt][Pp][Ss])
      TLS_ENABLED=true
      PROTOCOL=https
      break
      ;;
    2|[Hh][Tt][Tt][Pp])
      TLS_ENABLED=false
      PROTOCOL=http
      break
      ;;
    *) error "Choose 1/HTTPS or 2/HTTP." ;;
  esac
done

log "Building $LOCAL_IMAGE ($ENV_NAME, database $DB_NAME) with ${PROTOCOL^^} as the default protocol"
docker build \
  --build-arg "TLS_ENABLED=$TLS_ENABLED" \
  --build-arg "DB_NAME=$DB_NAME" \
  -f "$ROOT/Dockerfile.combined" -t "$LOCAL_IMAGE" "$ROOT"
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"
log "Pushing $REMOTE_IMAGE using your existing docker login"
if ! docker push "$REMOTE_IMAGE"; then
  error "Push failed for $REMOTE_IMAGE. Check docker login and repository permissions."
  exit 5
fi
log "Published $REMOTE_IMAGE"
log "Publish ports with -p 8086:8086 -p 8091:8090."
log "Web: $PROTOCOL://tertiaryverify.dedicated.co.za:8086; API: $PROTOCOL://tertiaryverify.dedicated.co.za:8091"
log "Override at runtime with -e TLS_ENABLED=true or -e TLS_ENABLED=false."
log "Supply MongoDB/JWT settings and mount fullchain.pem/privkey.pem for HTTPS (no keystore password); see poultry-pal-service/README.md."
