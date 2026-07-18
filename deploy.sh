#!/bin/bash
# TLS + xhttp exit configs. Run on VPS as root before docker compose up.
#
#   export DOMAIN=exit-nl-1.tunnelrover.com
#   export RELAY_UUID=00000000-0000-0000-0000-000000000000
#   sudo ./deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DOMAIN="${DOMAIN:-exit-nl-1.tunnelrover.com}"
RELAY_UUID="${RELAY_UUID:-REPLACE_RELAY_UUID}"
XHTTP_PATH="${XHTTP_PATH:-/assets/build/_app/immutable/chunks/}"
XHTTP_MODE="${XHTTP_MODE:-packet-up}"
EMAIL="${CERTBOT_EMAIL:-info@tunnelrover.com}"

TEMPLATE_CONFIG="templates/config.json.template"
TEMPLATE_NGINX="templates/nginx.conf.template"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./deploy.sh"
  exit 1
fi

if [[ "$RELAY_UUID" == "REPLACE_RELAY_UUID" ]]; then
  echo "Set RELAY_UUID to middle-node relay UUID (exit.id in nodes.json)"
  exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y certbot
fi

echo "==> Certificate for $DOMAIN"
certbot certonly \
  --standalone \
  -d "$DOMAIN" \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  --no-eff-email

mkdir -p ./nginx-certs
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ./nginx-certs/fullchain.pem
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ./nginx-certs/privkey.pem
chmod 644 ./nginx-certs/*.pem

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\\/&|]/\\&/g'
}

DOMAIN_ESC="$(escape_sed "$DOMAIN")"
RELAY_ESC="$(escape_sed "$RELAY_UUID")"
PATH_ESC="$(escape_sed "$XHTTP_PATH")"
MODE_ESC="$(escape_sed "$XHTTP_MODE")"

sed \
  -e "s|{{DOMAIN}}|$DOMAIN_ESC|g" \
  -e "s|{{RELAY_UUID}}|$RELAY_ESC|g" \
  -e "s|{{XHTTP_PATH}}|$PATH_ESC|g" \
  -e "s|{{XHTTP_MODE}}|$MODE_ESC|g" \
  "$TEMPLATE_CONFIG" > ./config.json

sed \
  -e "s|{{DOMAIN}}|$DOMAIN_ESC|g" \
  -e "s|{{XHTTP_PATH}}|$PATH_ESC|g" \
  "$TEMPLATE_NGINX" > ./nginx.conf

echo "Done."
echo "  config.json  — xhttp exit (relay UUID: $RELAY_UUID)"
echo "  nginx.conf   — TLS + path $XHTTP_PATH"
echo "Next: docker compose up -d"
