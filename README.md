# tunnelrover-exit-node (xhttp)

Выходная **xhttp**-нода за рубежом — nginx (TLS) + xray (VLESS xhttp) в Docker.

```
middle-node-xhttp ──xhttp/TLS──► exit-node (этот репо) ──► интернет
```

## Файлы

| Файл | Назначение |
|------|------------|
| `deploy/nodes.json` | Домен, relay UUID, path и mode xhttp |
| `templates/config.json.template` | Шаблон xray, скрипт его не меняет |
| `templates/nginx.conf.template` | Шаблон nginx, скрипт его не меняет |
| `templates/docker-compose.yaml.template` | Шаблон compose, скрипт его не меняет |
| `generated/` | Собранные конфиги, пересоздаются при каждом запуске |
| `nginx-certs/` | Let's Encrypt (gitignored) |
| `deploy.sh` | Сертификат и `docker compose up` |

## 1. DNS

```
exit-nl-1.tunnelrover.com  →  IP exit VPS
```

## 2. Конфиг

```bash
cp deploy/nodes.example.json deploy/nodes.json
```

`relayUuid` — тот же UUID, что `exit.id` на middle. `xhttpPath` и `xhttpMode` должны совпадать с middle.

## 3. Запуск

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

Повторный запуск безопасен: файлы в `templates/` только читаются, корневой `docker-compose.yaml` скрипт не меняет, `generated/` собирается заново, certbot пропускается, если сертификат для домена уже есть. Порты: `80`, `443`.

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
