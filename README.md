# tunnelrover-exit-node (TCP + REALITY)

Выходная нода: один Xray на `:443`, VLESS TCP + REALITY. Клиент этого inbound — middle-нода (`exit.id`).

```
middle-node-tcp ──REALITY/TCP──► exit (этот репозиторий) ──► интернет
```

## Конфиг

```bash
cp deploy/nodes.example.json deploy/nodes.json
```

`relayUuid` — UUID, который middle передаёт как `exit.id`. `dest` и `serverNames` — сайт, под который маскируется REALITY. `privateKey` оставь пустым: первый запуск создаст пару ключей и запишет её в `nodes.json`.

## Запуск

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

Повторный запуск безопасен: шаблоны только читаются, `generated/` собирается заново, ключи и short id не меняются.

`publicKey` и `shortIds` из вывода пропиши на middle в `exit.publicKey` и `exit.shortId`. `exit.sni` — имя из `serverNames`.
