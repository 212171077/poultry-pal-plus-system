#!/usr/bin/env bash
set -euo pipefail

port="${WEB_PORT:-8086}"
args=(--silent --show-error --noproxy '*' --connect-timeout 2 --max-time 4)
case "${TLS_ENABLED:-true}" in
  true)
    host="${TLS_SERVER_NAME:-tertiaryverify.dedicated.co.za}"
    args+=(--resolve "$host:$port:127.0.0.1")
    base="https://$host:$port"
    ;;
  false) base="http://127.0.0.1:$port" ;;
  *) echo "TLS_ENABLED must be true or false" >&2; exit 1 ;;
esac

curl "${args[@]}" --fail --output /dev/null "$base/"
status=$(curl "${args[@]}" --output /dev/null --write-out '%{http_code}' \
  --header 'Content-Type: application/json' --data '{}' "$base/api/v1/auth/signin")
if [[ "$status" != 400 ]]; then
  echo "Expected v1 sign-in validation status 400; received $status" >&2
  exit 1
fi
