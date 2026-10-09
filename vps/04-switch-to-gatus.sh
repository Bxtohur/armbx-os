#!/bin/bash
set -e

BOT_TOKEN='8913913974:AAFhEdvu-qolobUrqM-k1FBIPzSaBOAx9XE'
CHAT_ID='5503405982'

echo "=========================================="
echo "Migrate: remove Dozzle+Glances+UptimeKuma, deploy Gatus"
echo "=========================================="

echo
echo "=== 1. Stop + remove containers ==="
cd /media/armbx-storage/stacks/ops
docker compose stop dozzle 2>&1 | tail -3
docker compose rm -f dozzle 2>&1 | tail -3

cd /media/armbx-storage/stacks/monitoring
docker compose stop glances uptime-kuma 2>&1 | tail -3
docker compose rm -f glances uptime-kuma 2>&1 | tail -3
docker volume rm monitoring_uptime_data 2>&1 || true

echo
echo "=== 2. Rewrite ops/compose.yml (keep only Watchtower) ==="
cd /media/armbx-storage/stacks/ops
cat > compose.yml <<'OPS'
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
      - WATCHTOWER_NOTIFICATIONS_LEVEL=warn
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
OPS
docker compose up -d

echo
echo "=== 3. Setup monitoring/ dir for Gatus ==="
cd /media/armbx-storage/stacks/monitoring
rm -f compose.yml
mkdir -p gatus-config
cat > gatus-config/config.yaml <<EOF
# ArmBX Gatus config
# Edit: /media/armbx-storage/stacks/monitoring/gatus-config/config.yaml
# After edit: docker restart gatus

storage:
  type: memory

ui:
  title: "ArmBX Monitoring"
  header: "ArmBX STB — Service Status"
  logo: ""

alerting:
  telegram:
    token: "${BOT_TOKEN}"
    id: "${CHAT_ID}"
    default-alert:
      failure-threshold: 3
      success-threshold: 2
      send-on-resolved: true

endpoints:
  - name: "Internet (Cloudflare 1.1.1.1)"
    group: core
    url: "icmp://1.1.1.1"
    interval: 60s
    conditions:
      - "[CONNECTED] == true"
    alerts:
      - type: telegram

  - name: "Public DNS (Google 8.8.8.8)"
    group: core
    url: "icmp://8.8.8.8"
    interval: 60s
    conditions:
      - "[CONNECTED] == true"

  - name: "SSH (localhost)"
    group: core
    url: "tcp://host.docker.internal:22"
    interval: 60s
    conditions:
      - "[CONNECTED] == true"
    alerts:
      - type: telegram

  - name: "Gatus itself (public)"
    group: armbx-services
    url: "https://up.bxtohur.my.id"
    interval: 60s
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 2000"
    alerts:
      - type: telegram
EOF

cat > compose.yml <<'COMPOSE'
services:
  gatus:
    image: twinproduction/gatus:latest
    container_name: gatus
    restart: unless-stopped
    ports:
      - "127.0.0.1:8081:8080"
    cap_add:
      - NET_RAW   # for ICMP ping
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./gatus-config/config.yaml:/config/config.yaml:ro
      - gatus_data:/data
    environment:
      - TZ=Asia/Jakarta

volumes:
  gatus_data:
COMPOSE

echo
echo "=== 4. Deploy Gatus ==="
docker compose pull 2>&1 | tail -3
docker compose up -d
sleep 10
docker compose ps

echo
echo "=== 5. Verify ==="
curl -s -o /dev/null -w 'Gatus: %{http_code}\n' http://127.0.0.1:8081

echo
echo "=== 6. Memory snapshot ==="
free -h | head -2
echo
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}'

echo
echo "=========================================="
echo "DONE"
echo "=========================================="
echo ""
echo "ACTION di Cloudflare dashboard:"
echo "  1. Edit 'up.bxtohur.my.id'       → URL: localhost:8081 (was 3001)"
echo "  2. HAPUS 'logs.bxtohur.my.id'    (Dozzle removed)"
echo "  3. HAPUS 'netdata.bxtohur.my.id' (Glances removed)"
echo ""
echo "Setelah update CF: https://up.bxtohur.my.id → Gatus dashboard"
echo ""
echo "First telegram alert kemungkinan terkirim ketika Gatus mulai scan + ada endpoint down."
echo "Test: hidupkan ambil cabutan jaringan sebentar → dapet 'Internet down' alert di Telegram."
