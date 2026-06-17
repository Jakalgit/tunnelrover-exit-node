#!/bin/bash
# TLS для exit Hysteria2. Запускать на VPS от root, до docker compose up.
#
#   export DOMAIN=exit-nl-1.tunnelrover.com
#   sudo ./deploy.sh

set -euo pipefail

DOMAIN="${DOMAIN:-exit-nl-1.tunnelrover.com}"
EMAIL="${CERTBOT_EMAIL:-info@tunnelrover.com}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./deploy.sh"
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

mkdir -p ./certs
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ./certs/fullchain.pem
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ./certs/privkey.pem
chmod 644 ./certs/*.pem

echo "Done. Certs in ./certs/"
echo "Edit hysteria-config.yaml (relay UUIDs), then: docker compose up -d"
