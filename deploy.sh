#!/bin/bash
# xhttp exit. One VPS = one relay.
#
#   cp deploy/nodes.example.json deploy/nodes.json
#   sudo ./deploy.sh
#
# Safe to run again: templates are only read, generated files are rebuilt,
# certbot runs only when the certificate is missing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NODES_FILE="${NODES_FILE:-deploy/nodes.json}"
GENERATED_DIR="generated"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./deploy.sh" >&2
  exit 1
fi

if [[ ! -f "$NODES_FILE" ]]; then
  if [[ -f deploy/nodes.example.json ]]; then
    cp deploy/nodes.example.json "$NODES_FILE"
    echo "Created $NODES_FILE from example. Fill it and run again." >&2
    exit 1
  fi
  echo "Missing $NODES_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y python3
fi

eval "$(python3 - "$NODES_FILE" <<'PY'
import json, shlex, sys

with open(sys.argv[1], encoding="utf-8") as f:
    cfg = json.load(f)

if isinstance(cfg, list):
    if len(cfg) != 1:
        raise SystemExit("deploy/nodes.json must describe exactly one node")
    cfg = cfg[0]

def q(value):
    return shlex.quote("" if value is None else str(value))

name = cfg.get("name") or ""
domain = cfg.get("domain") or ""
relay = cfg.get("relayUuid") or ""
missing = [
    label
    for label, value in (
        ("name", name),
        ("domain", domain),
        ("relayUuid", relay),
    )
    if not value or str(value).startswith("REPLACE_")
]
if missing:
    raise SystemExit("Fill in deploy/nodes.json: " + ", ".join(missing))

print(f"NODE_NAME={q(name)}")
print(f"DOMAIN={q(domain)}")
print(f"RELAY_UUID={q(relay)}")
print(f"CERTBOT_EMAIL={q(cfg.get('certbotEmail') or 'info@tunnelrover.com')}")
print(f"XHTTP_PATH={q(cfg.get('xhttpPath') or '/assets/build/_app/immutable/chunks/')}")
print(f"XHTTP_MODE={q(cfg.get('xhttpMode') or 'packet-up')}")
PY
)"

render() {
  python3 - "$1" "$2" <<'PY'
import json, os, pathlib, sys

src, dst = sys.argv[1], sys.argv[2]
text = pathlib.Path(src).read_text()
mapping = {
    "NODE_NAME": os.environ["NODE_NAME"],
    "DOMAIN": os.environ["DOMAIN"],
    "RELAY_UUID": os.environ["RELAY_UUID"],
    "XHTTP_PATH": os.environ["XHTTP_PATH"],
    "XHTTP_MODE": os.environ["XHTTP_MODE"],
    "ROOT": os.environ["ROOT"],
}
for key, value in mapping.items():
    text = text.replace("{{" + key + "}}", value)
if "{{" in text and "}}" in text:
    raise SystemExit(f"Unresolved placeholder left in {dst}")
path = pathlib.Path(dst)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text)
if dst.endswith(".json"):
    json.loads(text)
PY
}

export NODE_NAME DOMAIN RELAY_UUID XHTTP_PATH XHTTP_MODE
export ROOT="$SCRIPT_DIR"

rm -rf "$GENERATED_DIR"
mkdir -p "$GENERATED_DIR"

render templates/config.json.template "$GENERATED_DIR/config.json"
render templates/nginx.conf.template "$GENERATED_DIR/nginx.conf"
render templates/docker-compose.yaml.template "$GENERATED_DIR/docker-compose.yaml"

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh
  fi
  systemctl enable --now docker

  if ! command -v certbot >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y certbot
  fi

  if ! docker compose version >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y docker-compose-plugin
  fi
}

compose() {
  docker compose --project-directory "$SCRIPT_DIR" -f "$SCRIPT_DIR/$GENERATED_DIR/docker-compose.yaml" "$@"
}

issue_certs() {
  local live_dir="/etc/letsencrypt/live/${DOMAIN}"

  if [[ ! -f "${live_dir}/fullchain.pem" ]]; then
    compose down || true
    certbot certonly \
      --standalone \
      -d "$DOMAIN" \
      --non-interactive \
      --agree-tos \
      --email "$CERTBOT_EMAIL" \
      --no-eff-email
  fi

  mkdir -p ./nginx-certs
  cp "${live_dir}/fullchain.pem" ./nginx-certs/fullchain.pem
  cp "${live_dir}/privkey.pem" ./nginx-certs/privkey.pem
  chmod 644 ./nginx-certs/*.pem
}

install_docker
issue_certs

if [[ ! -f index.html ]]; then
  echo "Missing index.html" >&2
  exit 1
fi

compose up -d

echo
echo "Done. xhttp exit ($NODE_NAME):"
echo "  middle exit.id = $RELAY_UUID"
echo "  middle exit.address = $DOMAIN"
echo "  path $XHTTP_PATH  mode $XHTTP_MODE"
