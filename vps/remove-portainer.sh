set -e

echo "=== Stop + remove portainer container + volume ==="
cd /media/armbx-storage/stacks/ops
docker compose stop portainer 2>&1 | tail -3
docker compose rm -f portainer 2>&1 | tail -3
docker volume rm ops_portainer_data 2>&1 || true

echo
echo "=== Rewrite compose.yml without portainer ==="
cat > compose.yml <<'COMPOSE'
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

  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - DOZZLE_NO_ANALYTICS=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
COMPOSE

echo
echo "=== Reconcile ==="
docker compose up -d
sleep 2
docker compose ps

echo
echo "=== Memory snapshot ==="
free -h | head -2

echo
echo "=== DONE. Portainer removed. ==="
echo "Hapus subdomain armbx.bxtohur.my.id dari Cloudflare dashboard juga."
