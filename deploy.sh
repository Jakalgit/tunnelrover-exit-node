#!/bin/bash
# TCP REALITY exit. One VPS = one Xray inbound on :443.
#
#   cp deploy/nodes.example.json deploy/nodes.json
#   sudo ./deploy.sh
#
# Safe to run again: templates are only read, generated files are rebuilt,
# the REALITY keypair and short ids stay in nodes.json.

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

load_config() {
  local parsed
  parsed="$(python3 - "$NODES_FILE" <<'PY'
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
relay = cfg.get("relayUuid") or ""
dest = cfg.get("dest") or ""
names = cfg.get("serverNames") or []
if isinstance(names, str):
    names = [names]
short_ids = cfg.get("shortIds") or []
if isinstance(short_ids, str):
    short_ids = [short_ids]

missing = [
    label
    for label, value in (
        ("name", name),
        ("relayUuid", relay),
        ("dest", dest),
    )
    if not value or str(value).startswith("REPLACE_")
]
if not names:
    missing.append("serverNames")
if missing:
    raise SystemExit("Fill in deploy/nodes.json: " + ", ".join(missing))

print(f"NODE_NAME={q(name)}")
print(f"RELAY_UUID={q(relay)}")
print(f"DEST={q(dest)}")
print(f"PRIVATE_KEY={q(cfg.get('privateKey') or '')}")
print(f"PUBLIC_KEY={q(cfg.get('publicKey') or '')}")
print("SERVER_NAMES_JSON=" + shlex.quote(json.dumps(names)))
print("SHORT_IDS_JSON=" + shlex.quote(json.dumps(short_ids)))
PY
)" || exit 1
  eval "$parsed"
}

load_config

export PRIVATE_KEY PUBLIC_KEY SHORT_IDS_JSON

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh
  fi
  systemctl enable --now docker

  if ! docker compose version >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y docker-compose-plugin
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y openssl
  fi
}

ensure_reality_keys() {
  local short_count
  short_count="$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1])))' "$SHORT_IDS_JSON")" || exit 1
  if [[ -n "$PRIVATE_KEY" && -n "$PUBLIC_KEY" && "$short_count" -gt 0 ]]; then
    return
  fi

  if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
    local output
    output="$(docker run --rm teddysun/xray xray x25519)" || exit 1
    local parsed
    parsed="$(python3 - "$output" <<'PY'
import shlex, sys
text = sys.argv[1]
private = public = None
for line in text.splitlines():
    if ":" not in line:
        continue
    key, value = line.split(":", 1)
    key = key.strip().lower().replace(" ", "")
    value = value.strip()
    if key in ("privatekey", "private"):
        private = value
    elif key == "publickey":
        public = value
    elif key == "password" and not public:
        public = value
if not private or not public:
    raise SystemExit("Could not parse xray x25519 output:\n" + text)
print(f"PRIVATE_KEY={shlex.quote(private)}")
print(f"PUBLIC_KEY={shlex.quote(public)}")
PY
)" || exit 1
    eval "$parsed"
  fi

  if [[ "$short_count" -eq 0 ]]; then
    SHORT_IDS_JSON="$(python3 - <<'PY'
import json, secrets
print(json.dumps([secrets.token_hex(8)]))
PY
)"
  fi

  python3 - "$NODES_FILE" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_IDS_JSON" <<'PY'
import json, sys
path, private_key, public_key, short_ids = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    raw = json.load(f)
cfg = raw[0] if isinstance(raw, list) else raw
cfg["privateKey"] = private_key
cfg["publicKey"] = public_key
cfg["shortIds"] = json.loads(short_ids)
with open(path, "w", encoding="utf-8") as f:
    json.dump(raw, f, indent=2)
    f.write("\n")
PY
}

render() {
  python3 - "$1" "$2" <<'PY'
import json, os, pathlib, sys
src, dst = sys.argv[1], sys.argv[2]
text = pathlib.Path(src).read_text()
mapping = {
    "NODE_NAME": os.environ["NODE_NAME"],
    "RELAY_UUID": os.environ["RELAY_UUID"],
    "DEST": os.environ["DEST"],
    "PRIVATE_KEY": os.environ["PRIVATE_KEY"],
    "SERVER_NAMES_JSON": os.environ["SERVER_NAMES_JSON"],
    "SHORT_IDS_JSON": os.environ["SHORT_IDS_JSON"],
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

install_docker
ensure_reality_keys

export NODE_NAME RELAY_UUID DEST PRIVATE_KEY SERVER_NAMES_JSON SHORT_IDS_JSON
export ROOT="$SCRIPT_DIR"

rm -rf "$GENERATED_DIR"
mkdir -p "$GENERATED_DIR"

render templates/config.json.template "$GENERATED_DIR/config.json"
render templates/docker-compose.yaml.template "$GENERATED_DIR/docker-compose.yaml"

docker compose --project-directory "$SCRIPT_DIR" -f "$SCRIPT_DIR/$GENERATED_DIR/docker-compose.yaml" up -d

echo
echo "Done. TCP REALITY exit ($NODE_NAME):"
echo "  relay UUID:  $RELAY_UUID"
echo "  public key:  $PUBLIC_KEY"
echo "  short ids:   $SHORT_IDS_JSON"
echo "  sni / dest:  $DEST"
