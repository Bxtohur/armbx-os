set -e

echo "=========================================="
echo "Replace Netdata with Glances"
echo "=========================================="

cd /media/armbx-storage/stacks/monitoring

echo
echo "=== 1. Stop + remove Netdata ==="
docker compose stop netdata
docker compose rm -f netdata
docker volume rm monitoring_netdata_config monitoring_netdata_lib monitoring_netdata_cache 2>&1 || true

echo
echo "=== 2. Pull Glances image ==="
docker pull nicolargo/glances:latest-full 2>&1 | tail -3

echo
echo "=== 3. Rewrite compose.yml ==="
cat > compose.yml <<'COMPOSE'
services:
  glances:
    image: nicolargo/glances:latest-full
    container_name: glances
    restart: unless-stopped
    hostname: armbx
    pid: host
    network_mode: host
    environment:
      - GLANCES_OPT=-w --disable-webui-cache
      - TZ=Asia/Jakarta
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/os-release:/etc/os-release:ro
    # port 61208 bind via network_mode=host but we only expose localhost via UFW
    # (UFW default deny inbound sudah block external access)

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "127.0.0.1:3001:3001"
    volumes:
      - uptime_data:/app/data

volumes:
  uptime_data:
COMPOSE

echo
echo "=== 4. Deploy ==="
docker compose up -d
sleep 8
docker compose ps

echo
echo "=== 5. Verify Glances ==="
curl -s -o /dev/null -w "Glances: %{http_code}\n" http://127.0.0.1:61208 || true

echo
echo "=== 6. Memory snapshot (before/after comparison) ==="
free -h | head -2
echo
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}'

echo
echo "=========================================="
echo "DONE"
echo "=========================================="
echo ""
echo "ACTION diperlukan di Cloudflare dashboard:"
echo "  Public Hostname 'netdata.bxtohur.my.id' → update:"
echo "    URL: localhost:19999  →  localhost:61208"
echo "  (atau rename ke 'glances.bxtohur.my.id' + update Uptime Kuma monitor URL)"
echo ""
echo "Setelah update CF: https://netdata.bxtohur.my.id → Glances UI"
