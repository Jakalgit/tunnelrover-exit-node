# tunnelrover-exit-node (Hysteria)

Простая **выходная** нода за рубежом — только Hysteria2 в Docker, без Nest/Redis/nginx.  
Аналог ветки `main` (xray + `config.json`), но для Hysteria.

```
middle-node (РФ) ──Hysteria2──► exit-node (этот репозиторий) ──► интернет
```

## Файлы

| Файл | Назначение |
|------|------------|
| `hysteria-config.yaml` | Конфиг сервера (TLS, relay UUID) |
| `docker-compose.yaml` | Один контейнер `hysteria-exit` |
| `certs/` | `fullchain.pem` + `privkey.pem` (Let's Encrypt) |
| `deploy.sh` | Получить сертификат для домена |

## 1. Домен

Создай DNS **A-запись**:

```
exit-nl-1.tunnelrover.com  →  IP exit VPS
```

## 2. Relay UUID (кто может подключаться)

В `hysteria-config.yaml` укажи UUID middle-ноды — тот же, что `exit.auth` на middle:

```yaml
auth:
  type: password
  password: "7f3a9c2e-4b1d-4e8a-9f0c-123456789abc"
```

Одна exit-нода = один relay UUID (как один `clients[]` в xray). Несколько middle — отдельные exit VPS или ветка `tunnelrover-node/hysteria` с Redis.

## 3. TLS

```bash
export DOMAIN=exit-nl-1.tunnelrover.com
chmod +x deploy.sh
sudo ./deploy.sh
```

Или вручную положи сертификаты в `certs/fullchain.pem` и `certs/privkey.pem`.

## 4. Запуск

```bash
docker compose up -d
```

Проверка: `443/udp` и `443/tcp` открыты на firewall.

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
| Конфиг | `config.json` | `hysteria-config.yaml` |
| Клиенты | `clients[].id` (UUID) | `auth.password` (UUID relay) |
| Порт | 443 TCP | 443 UDP+TCP |
| REALITY | да | нет (обычный TLS) |
