set -e

TUNNEL_TOKEN='eyJhIjoiYjUyYzYzNWNjYjgxNTUwZmQ5NDc3MjYyMmQ3NDRjYjEiLCJ0IjoiZjc2MWYyZWUtMGViOC00YjI5LTlhYTUtYTc1MjNjNjYwODk4IiwicyI6IlpUYzVZVE0zTjJVdFlUZzVaQzAwWm1Wa0xUazRZVEl0T1dJek1EVXhZVEF5TXpKaCJ9'

echo "=========================================="
echo "FASE 4: Cloudflare Tunnel"
echo "=========================================="

echo
echo "=== 4.1 Add Cloudflare apt repo ==="
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null

echo
echo "=== 4.2 Install cloudflared ==="
sudo apt-get update 2>&1 | tail -3
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflared 2>&1 | tail -3
sudo apt-mark hold cloudflared
cloudflared --version

echo
echo "=== 4.3 Install cloudflared as systemd service with token ==="
sudo cloudflared service install "$TUNNEL_TOKEN" 2>&1 | tail -5
sleep 3
sudo systemctl status cloudflared --no-pager | head -8

echo
echo "=== 4.4 Verify tunnel connected ==="
sleep 5
sudo cloudflared tunnel info 2>&1 | head -10 || true
echo "--- journal (last 10 lines) ---"
sudo journalctl -u cloudflared -n 10 --no-pager

echo
echo "=========================================="
echo "Fase 4 DONE (local side)"
echo "=========================================="
echo ""
echo "NEXT: Add Public Hostnames di Cloudflare dashboard"
echo "  → Zero Trust → Access → Tunnels → armbx → Public Hostname tab"
echo ""
echo "Routing yang harus ditambah:"
echo "  armbx.bxtohur.my.id   → HTTP  → localhost:9000  (Portainer)"
echo "  logs.bxtohur.my.id    → HTTP  → localhost:8080  (Dozzle)"
echo "  up.bxtohur.my.id      → HTTP  → localhost:3001  (Uptime Kuma)"
echo "  netdata.bxtohur.my.id → HTTP  → localhost:19999 (Netdata)"
