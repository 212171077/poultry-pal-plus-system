#!/bin/bash
# Builds the poultry-pal jar, then the poultry-pal image, and pushes it to Docker Hub.
# Usage: ./build-and-push.sh [prod|dev] [tag]   (prompts for prod/dev if omitted)
#   prod (default): database poultry-pal-db,     tag defaults to "latest"
#   dev:            database poultry-pal-db-dev, tag defaults to "dev"

#./build-and-push.sh              # prompts, then builds
#./build-and-push.sh prod         # prod -> 212171077/poultry-pal:latest
#./build-and-push.sh dev          # dev  -> 212171077/poultry-pal:dev
#./build-and-push.sh prod v1.0    # prod with a specific tag

set -e

cd "$(dirname "$0")"

IMAGE="212171077/poultry-pal"
ENV_NAME="$1"

if [ -z "$ENV_NAME" ]; then
  echo "Select environment to build:"
  select ENV_NAME in prod dev; do
    [ -n "$ENV_NAME" ] && break
    echo "Invalid choice, enter 1 or 2."
  done
fi

case "$ENV_NAME" in
  prod) DB_NAME="poultry-pal-db";     DEFAULT_TAG="latest" ;;
  dev)  DB_NAME="poultry-pal-db-dev"; DEFAULT_TAG="dev" ;;
  *) echo "Unknown environment '$ENV_NAME' (use prod or dev)"; exit 1 ;;
esac
TAG="${2:-$DEFAULT_TAG}"

# Built in a JDK 21 container so the host JDK version doesn't matter.
echo "🔹 Building jar..."
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$PWD":/app -v "$HOME/.m2":/tmp/.m2 -w /app \
  maven:3.9-eclipse-temurin-21 \
  mvn -Dmaven.repo.local=/tmp/.m2/repository clean package -DskipTests

echo "🔹 Building $IMAGE:$TAG ($ENV_NAME, database $DB_NAME)..."
docker build -f Dockerfile --build-arg DB_NAME="$DB_NAME" -t "$IMAGE:$TAG" .

echo "🔹 Pushing $IMAGE:$TAG..."
docker push "$IMAGE:$TAG"

echo "🚀 Done. On the server run docker compose pull && docker compose up -d."
