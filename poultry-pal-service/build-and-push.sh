#!/bin/bash
# Builds the poultry-pal jar, then the poultry-pal image, and pushes it to Docker Hub.
# Usage: ./build-and-push.sh [tag]   (default tag: latest)

#./build-and-push.sh          # builds and pushes 212171077/poultry-pal:latest
#./build-and-push.sh v1.0     # use a specific tag instead of latest

set -e

cd "$(dirname "$0")"

IMAGE="212171077/poultry-pal"
TAG="${1:-latest}"

# Built in a JDK 21 container so the host JDK version doesn't matter.
echo "🔹 Building jar..."
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$PWD":/app -v "$HOME/.m2":/tmp/.m2 -w /app \
  maven:3.9-eclipse-temurin-21 \
  mvn -Dmaven.repo.local=/tmp/.m2/repository clean package -DskipTests

echo "🔹 Building $IMAGE:$TAG..."
docker build -f Dockerfile -t "$IMAGE:$TAG" .

echo "🔹 Pushing $IMAGE:$TAG..."
docker push "$IMAGE:$TAG"

echo "🚀 Done. On the server run docker compose pull && docker compose up -d."
