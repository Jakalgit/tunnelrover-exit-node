# tunnelrover-exit-node (Hysteria)

Простая **выходная** нода за рубежом — только Hysteria2 в Docker, без Nest/Redis/nginx.  
Аналог ветки `main` (xray + `config.json`), но для Hysteria.

```
middle-node (РФ) ──Hysteria2──► exit-node (этот репозиторий) ──► интернет
```

## Файлы

| Файл | Назначение |
|------|------------|
| `deploy/nodes.json` | Домен, relay UUID, email certbot, masquerade, bandwidth |
| `templates/hysteria-config.yaml.template` | Шаблон сервера, скрипт его не меняет |
| `templates/docker-compose.yaml.template` | Шаблон compose, скрипт его не меняет |
| `generated/` | Собранные конфиги, пересоздаются при каждом запуске |
| `certs/` | `fullchain.pem` + `privkey.pem` (Let's Encrypt) |
| `deploy.sh` | Сертификат и `docker compose up` |

## 1. Домен

Создай DNS **A-запись**:

```
exit-nl-1.tunnelrover.com  →  IP exit VPS
```

## 2. Конфиг

```bash
cp deploy/nodes.example.json deploy/nodes.json
```

`relayUuid` — тот же UUID, что `exit.auth` на middle. Одна exit-нода = один relay UUID. Несколько middle — отдельные exit VPS.

## 3. Запуск

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

Повторный запуск безопасен: файлы в `templates/` только читаются, корневые `hysteria-config.yaml` и `docker-compose.yaml` скрипт не меняет, `generated/` собирается заново, certbot пропускается, если сертификат для домена уже есть. Проверка: `443/udp` и `443/tcp` открыты на firewall.

## Связка с middle-node

В `tunnelrover-node/deploy/nodes.json` на middle:

```json
"exit": {
  "address": "exit-nl-1.tunnelrover.com",
  "port": 443,
  "auth": "7f3a9c2e-4b1d-4e8a-9f0c-123456789abc",
  "sni": "exit-nl-1.tunnelrover.com"
}
```

## vs xray exit (`main`)

| | `main` (xray) | `hysteria` |
|--|---------------|------------|
| Конфиг | `config.json` | `deploy/nodes.json` |
| Клиенты | `clients[].id` (UUID) | `auth.password` (UUID relay) |
| Порт | 443 TCP | 443 UDP+TCP |
| REALITY | да | нет (обычный TLS) |
