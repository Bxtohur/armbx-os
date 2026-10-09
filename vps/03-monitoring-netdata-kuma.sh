set -e

echo "=========================================="
echo "FASE 3 v2: Monitoring (containerized)"
echo "=========================================="

# Clean any failed netdata apt attempt
sudo apt-get purge -y netdata 2>/dev/null || true

echo
echo "=== 3.1 Create monitoring stack ==="
sudo mkdir -p /media/armbx-storage/stacks/monitoring
sudo chown -R 1000:1000 /media/armbx-storage/stacks/monitoring
cd /media/armbx-storage/stacks/monitoring

cat > compose.yml <<'COMPOSE'
services:
  netdata:
    image: netdata/netdata:latest
    container_name: netdata
    restart: unless-stopped
    hostname: armbx
    ports:
      - "127.0.0.1:19999:19999"
    cap_add:
      - SYS_PTRACE
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
    environment:
      - DOCKER_HOST=/var/run/docker.sock
      - NETDATA_DISABLE_CLOUD=1
    volumes:
      - netdata_config:/etc/netdata
      - netdata_lib:/var/lib/netdata
      - netdata_cache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /etc/localtime:/etc/localtime:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro
      - /var/log:/host/var/log:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "127.0.0.1:3001:3001"
    volumes:
      - uptime_data:/app/data

volumes:
  netdata_config:
  netdata_lib:
  netdata_cache:
  uptime_data:
COMPOSE

echo
echo "=== 3.2 Deploy stack ==="
docker compose pull 2>&1 | tail -5
docker compose up -d
sleep 10
docker compose ps

echo
echo "=== 3.3 Test endpoints ==="
curl -s -o /dev/null -w "Netdata     : %{http_code}\n" http://127.0.0.1:19999 || true
curl -s -o /dev/null -w "Uptime Kuma : %{http_code}\n" http://127.0.0.1:3001 || true

echo
echo "=== 3.4 Memory snapshot ==="
free -h | head -2

echo
echo "=========================================="
echo "Fase 3 v2 DONE"
echo "=========================================="
echo "- Netdata     : http://127.0.0.1:19999 (host metrics via container)"
echo "- Uptime Kuma : http://127.0.0.1:3001  (service monitoring + alerts)"
echo ""
echo "Semua bind localhost - expose via Caddy/CF Tunnel di Fase 4."
