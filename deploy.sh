#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -z "${POULTRY_PAL_TAG:-}" ]]; then
    echo "Select Poultry Pal image to deploy:"
    select ENV_NAME in "prod (poultry-pal-db, :latest)" "dev (poultry-pal-db-dev, :dev)"; do
        case "$REPLY" in
            1) POULTRY_PAL_TAG=latest; break ;;
            2) POULTRY_PAL_TAG=dev; break ;;
            *) echo "Choose 1 or 2." ;;
        esac
    done
fi
export POULTRY_PAL_TAG
echo "Deploying 212171077/poultry-pal:$POULTRY_PAL_TAG"

command -v python3 >/dev/null || {
    echo "python3 is required to validate the resolved Compose TLS mounts." >&2
    exit 1
}

echo "Checking deployment configuration..."
docker compose config --quiet

TLS_DIR=$(docker compose config --format json | python3 -c '
import json, sys
service = json.load(sys.stdin)["services"].get("poultry-pal")
if service is None:
    sys.exit("Compose configuration must contain the poultry-pal service.")
target = service.get("environment", {}).get("TLS_CERT_DIR")
if not target:
    sys.exit("Set poultry-pal environment.TLS_CERT_DIR to /etc/nginx/tls.")
mount = next((m for m in service.get("volumes", [])
              if m.get("type") == "bind" and m.get("target") == target), None)
if mount is None:
    sys.exit("Poultry Pal requires a bind mount at TLS_CERT_DIR: " + target)
print(mount["source"])
')

for FILE in "$TLS_DIR/fullchain.pem" "$TLS_DIR/privkey.pem"; do
    if [[ ! -f "$FILE" || ! -r "$FILE" || ! -s "$FILE" ]]; then
        echo "Missing, empty or unreadable TLS file: $FILE" >&2
        echo "Install the renewed fullchain.pem and matching privkey.pem in $TLS_DIR." >&2
        exit 1
    fi
done

command -v openssl >/dev/null || {
    echo "openssl is required to validate the deployment certificates." >&2
    exit 1
}
openssl x509 -in "$TLS_DIR/fullchain.pem" -checkend 0 -noout
openssl x509 -in "$TLS_DIR/fullchain.pem" -checkhost tertiaryverify.dedicated.co.za -noout
CERT_PUBLIC_KEY=$(openssl x509 -in "$TLS_DIR/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)
KEY_PUBLIC_KEY=$(openssl pkey -in "$TLS_DIR/privkey.pem" -passin pass: -pubout -outform DER | openssl dgst -sha256)
if [[ "$CERT_PUBLIC_KEY" != "$KEY_PUBLIC_KEY" ]]; then
    echo "The TLS certificate and private key do not match." >&2
    exit 1
fi

echo "Stopping running containers..."
docker compose down --remove-orphans || true

echo "Removing any leftover containers..."
docker rm -f tertiary-verify 2>/dev/null || true
docker rm -f poultry-pal 2>/dev/null || true
docker rm -f school-verify 2>/dev/null || true

echo "Waiting for Docker to release ports..."
sleep 5

echo "Checking for containers using required ports..."
PORTS=$(docker compose config --format json | python3 -c '
import json, sys
services = json.load(sys.stdin)["services"]
for service in services.values():
    for port in service.get("ports", []):
        if port.get("published"):
            print(port["published"])
')

for PORT in $PORTS; do
    mapfile -t CONTAINERS < <(docker ps --filter "publish=$PORT" --format "{{.ID}}")
    if (( ${#CONTAINERS[@]} > 0 )); then
        echo "Stopping containers using port $PORT..."
        docker rm -f "${CONTAINERS[@]}"
    fi
done

echo "Cleaning unused Docker networks..."
docker network prune -f

echo "Removing old images..."
for IMAGE in \
    212171077/tertiary-verify \
    212171077/poultry-pal \
    212171077/school-verify-front-and-backend; do
    mapfile -t IMAGE_IDS < <(docker images "$IMAGE" -q)
    if (( ${#IMAGE_IDS[@]} > 0 )); then
        docker rmi -f "${IMAGE_IDS[@]}" || true
    fi
done

echo "Pulling latest images..."
docker compose pull

echo "Starting containers..."
docker compose up -d --wait --wait-timeout 180

docker compose ps
echo "Deployment complete. Web: https://tertiaryverify.dedicated.co.za:8086"

999