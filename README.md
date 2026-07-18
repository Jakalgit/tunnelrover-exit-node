# tunnelrover-exit-node (xhttp)

Выходная **xhttp**-нода за рубежом — nginx (TLS) + xray (VLESS xhttp) в Docker.

```
middle-node-xhttp ──xhttp/TLS──► exit-node (этот репо) ──► интернет
```

## Файлы

| Файл | Назначение |
|------|------------|
| `templates/config.json.template` | xray exit: xhttp inbound + freedom |
| `templates/nginx.conf.template` | TLS + proxy path → xray |
| `deploy.sh` | certbot + генерация `config.json`, `nginx.conf` |
| `docker-compose.yaml` | `nginx` + `xray` |
| `nginx-certs/` | Let's Encrypt (gitignored) |

## 1. DNS

```
exit-nl-1.tunnelrover.com  →  IP exit VPS
```

## 2. Relay UUID

UUID middle-ноды — тот же, что `exit.id` в `tunnelrover-node/deploy/nodes.json`:

```bash
export DOMAIN=exit-nl-1.tunnelrover.com
export RELAY_UUID=7f3a9c2e-4b1d-4e8a-9f0c-123456789abc
export XHTTP_PATH=/assets/build/_app/immutable/chunks/
export XHTTP_MODE=packet-up
sudo ./deploy.sh
```

## 3. Запуск

```bash
docker compose up -d
```

Порты: `80`, `443`.

## Связка с middle-node-xhttp

В `tunnelrover-node/deploy/nodes.json`:

```json
"exit": {
  "address": "exit-nl-1.tunnelrover.com",
  "id": "7f3a9c2e-4b1d-4e8a-9f0c-123456789abc",
  "sni": "exit-nl-1.tunnelrover.com",
  "xhttpPath": "/assets/build/_app/immutable/chunks/",
  "xhttpMode": "packet-up"
}
```

`xhttpPath` / `xhttpMode` на middle и exit **должны совпадать**.

## vs `main` (REALITY)

| | `main` | `xhttp` |
|--|--------|---------|
| Транспорт | VLESS REALITY TCP | VLESS xhttp |
| TLS | в xray (REALITY) | nginx |
| Клиент middle | publicKey + shortId | relay UUID + path |
