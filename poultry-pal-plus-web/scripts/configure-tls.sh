#!/bin/sh
set -eu

case "${TLS_ENABLED:-true}" in
  true)
    TLS_LISTEN_OPTIONS=ssl
    TLS_CERTIFICATE_DIRECTIVES="ssl_certificate ${TLS_CERT_DIR:-/etc/nginx/tls}/fullchain.pem;
    ssl_certificate_key ${TLS_CERT_DIR:-/etc/nginx/tls}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;"
    TLS_PROXY_DIRECTIVES="proxy_ssl_server_name on;
    proxy_ssl_name ${TLS_SERVER_NAME:-tertiaryverify.dedicated.co.za};
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate /etc/ssl/cert.pem;
    proxy_ssl_verify_depth 3;"
    API_UPSTREAM="${API_UPSTREAM:-https://poultry-pal-app:8090}"
    ;;
  false)
    TLS_LISTEN_OPTIONS=
    TLS_CERTIFICATE_DIRECTIVES=
    TLS_PROXY_DIRECTIVES=
    API_UPSTREAM="${API_UPSTREAM:-http://poultry-pal-app:8090}"
    ;;
  *)
    echo "TLS_ENABLED must be true or false" >&2
    exit 1
    ;;
esac

WEB_PORT="${WEB_PORT:-8080}"
case "$WEB_PORT" in
  ''|*[!0-9]*) echo "WEB_PORT must be a port number between 1 and 65535" >&2; exit 1 ;;
esac
if [ "$WEB_PORT" -lt 1 ] || [ "$WEB_PORT" -gt 65535 ]; then
  echo "WEB_PORT must be a port number between 1 and 65535" >&2
  exit 1
fi

export TLS_LISTEN_OPTIONS TLS_CERTIFICATE_DIRECTIVES TLS_PROXY_DIRECTIVES API_UPSTREAM WEB_PORT
envsubst '${TLS_LISTEN_OPTIONS} ${TLS_CERTIFICATE_DIRECTIVES} ${TLS_PROXY_DIRECTIVES} ${API_UPSTREAM} ${WEB_PORT}' \
  < /opt/poultry-pal/nginx.conf.template > /etc/nginx/conf.d/default.conf
