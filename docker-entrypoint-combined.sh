#!/usr/bin/env bash
set -euo pipefail

tls_args=()
export TLS_CERT_DIR="${TLS_CERT_DIR:-/etc/nginx/tls}"
case "${TLS_ENABLED:-true}" in
  true)
    for file in "$TLS_CERT_DIR/fullchain.pem" "$TLS_CERT_DIR/privkey.pem"; do
      if [[ ! -r "$file" || ! -s "$file" ]]; then
        echo "HTTPS requires a readable, non-empty $file; mount the TLS directory read-only." >&2
        exit 1
      fi
    done
    tls_args=(
      --server.ssl.bundle=hosted
      "--spring.ssl.bundle.pem.hosted.keystore.certificate=file:$TLS_CERT_DIR/fullchain.pem"
      "--spring.ssl.bundle.pem.hosted.keystore.private-key=file:$TLS_CERT_DIR/privkey.pem"
    )
    export API_UPSTREAM="${API_UPSTREAM:-https://127.0.0.1:8090}"
    ;;
  false) export API_UPSTREAM="${API_UPSTREAM:-http://127.0.0.1:8090}" ;;
  *) echo "TLS_ENABLED must be true or false" >&2; exit 1 ;;
esac

sh /opt/poultry-pal/configure-tls.sh
nginx -t

backend_pid=
nginx_pid=
cleanup() {
  trap - EXIT INT TERM
  if [[ -n "$nginx_pid" ]]; then kill -TERM "$nginx_pid" 2>/dev/null || true; fi
  if [[ -n "$backend_pid" ]]; then kill -TERM "$backend_pid" 2>/dev/null || true; fi
  wait || true
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

java -jar /app/poultry-pal.jar --server.port=8090 "${tls_args[@]}" &
backend_pid=$!
nginx -g 'daemon off;' &
nginx_pid=$!

status=0
wait -n "$backend_pid" "$nginx_pid" || status=$?
echo "A combined-image service exited (status $status); stopping the container." >&2
if (( status == 0 )); then status=1; fi
exit "$status"
