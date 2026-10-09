# 🚀 ArmBX STB VPS — Panduan Deployment

Guide praktis untuk deploy service ke STB (ArmBX OS) kamu.

---

## 📍 Info VPS

| Item | Value |
|---|---|
| **OS** | ArmBX OS 1.0 (based on Armbian/Debian trixie) |
| **Hostname** | `armbx` |
| **Hardware** | Amlogic S905X STB, 1.88 GB RAM, aarch64 |
| **User** | `bx` (sudo, docker group) |
| **Domain** | `bxtohur.my.id` (via Cloudflare Tunnel) |
| **Storage path untuk stacks** | `/media/armbx-storage/stacks/` (USB 128GB ext4) |

### Akses

```bash
# Dari laptop (hosts entry sudah di-set)
ssh bx@bx                          # local LAN
ssh bx@armbx                       # Tailscale (dari manapun)
ssh bx@100.107.240.20              # Tailscale IP langsung
```

Semua pakai SSH key (`~/.ssh/id_ed25519`). No password prompt.

---

## 🏗️ Pattern: Deploy service baru

**Template folder layout:**

```
/media/armbx-storage/stacks/
├── ops/              ← Dozzle + Watchtower (ada)
├── monitoring/       ← Netdata + Uptime Kuma (ada)
├── <new-service>/
│   ├── compose.yml
│   └── data/         ← volume data kalau pakai bind mount
```

### Step 1 — SSH ke STB

```bash
ssh bx@armbx
```

### Step 2 — Bikin folder stack

```bash
cd /media/armbx-storage/stacks
mkdir myapp && cd myapp
```

### Step 3 — Tulis compose.yml

**Template minimal:**

```yaml
services:
  myapp:
    image: nama/image:tag
    container_name: myapp
    restart: unless-stopped
    ports:
      - "127.0.0.1:<PORT>:<INTERNAL_PORT>"   # bind localhost!
    environment:
      - KEY=value
    volumes:
      - ./data:/path/di/container
```

**Catatan penting:**
- **Selalu bind ke `127.0.0.1`**, bukan `0.0.0.0`. Public access via Cloudflare Tunnel, bukan via port terbuka.
- Pakai `restart: unless-stopped` biar auto-start setelah reboot.
- Tag `latest` → Watchtower akan auto-update daily. Kalau mau pinned version, pakai tag spesifik.

### Step 4 — Deploy

```bash
docker compose up -d
docker compose logs -f    # verify startup, Ctrl+C untuk keluar
```

### Step 5 — Expose publicly (Cloudflare Tunnel)

1. Buka https://one.dash.cloudflare.com/
2. **Networks → Tunnels → `armbx` → Public Hostname → Add**
3. Isi:
   - Subdomain: `myapp` (atau whatever)
   - Domain: `bxtohur.my.id`
   - Type: `HTTP`
   - URL: `localhost:<PORT>`
4. (Optional) **Access tab → Add application** → policy email allow → protect dari publik

~30 detik DNS propagate → `https://myapp.bxtohur.my.id` ready.

### Step 6 — Monitor di Uptime Kuma

1. Buka https://up.bxtohur.my.id
2. **Add New Monitor**:
   - Type: HTTP(s)
   - URL: `https://myapp.bxtohur.my.id`
   - Interval: 60s
   - Notifications: centang Telegram Alert
3. Save

### Step 7 — Dokumentasi (optional)

Tulis `README.md` di folder stack kamu biar inget settingan env, port, dsb.

---

## 📋 Common tasks

### Lihat semua container running

```bash
docker ps
# atau via web: https://logs.bxtohur.my.id
```

### Restart service

```bash
cd /media/armbx-storage/stacks/myapp
docker compose restart
```

### Update service (manual, selain Watchtower)

```bash
cd /media/armbx-storage/stacks/myapp
docker compose pull && docker compose up -d
```

### Stop + remove service

```bash
cd /media/armbx-storage/stacks/myapp
docker compose down          # keep volumes
docker compose down -v       # DELETE volumes juga
```

Jangan lupa hapus Public Hostname di Cloudflare dashboard + monitor di Uptime Kuma.

### Lihat logs real-time

```bash
# CLI
docker logs -f myapp

# Web
https://logs.bxtohur.my.id
```

### Resource check

```bash
free -h              # RAM
df -h /              # disk root
df -h /media/armbx-storage  # disk USB (docker data)
docker system df     # Docker space usage
```

Browser: `https://netdata.bxtohur.my.id` for live graphs.

### Clean up Docker space

```bash
docker system prune              # remove stopped containers + unused networks
docker image prune -a            # remove unused images
docker volume prune              # remove unused volumes (CAREFUL)
```

---

## 🧰 Shortcut commands di STB

```bash
bx-menu              # TUI toolkit: WiFi, USB, network info, dsb
bx-menu              # dari TV console juga bisa
armbx-wifi-setup     # setup WiFi interaktif
tailscale status     # cek koneksi tailnet
```

---

## 🔐 Security

**Service yang sedang jalan secure by default:**
- UFW allow hanya: SSH (22), HTTP (80), HTTPS (443), LAN, Tailscale
- fail2ban: SSH brute-force protection (ban 1 jam setelah 5x fail)
- unattended-upgrades: auto security patches (kernel + docker + ssh di-skip)

**Jangan buka port public tanpa reverse proxy / Cloudflare Tunnel.** Ports yang diperlukan di-tunnel-kan via Cloudflared.

**Rekomendasi tambahan:**
- Service dengan data sensitive (Dozzle, Netdata) → tambah **Cloudflare Access** policy di CF dashboard.
- Rotate SSH key laptop secara berkala.
- Simpan backup `/media/armbx-storage/stacks/*/compose.yml` di git repo (jangan commit `.env` berisi secret).

---

## 💾 Backup

Data penting ada di:
- `/media/armbx-storage/stacks/*/data` — konfigurasi tiap service
- Docker volumes (di `/media/armbx-storage/docker/volumes/`)
- `/etc/docker/daemon.json` — docker config
- `/home/bx/` — home directory

**Simple backup to another USB:**

```bash
tar czf /tmp/armbx-backup-$(date +%Y%m%d).tar.gz \
    /media/armbx-storage/stacks \
    /media/armbx-storage/docker/volumes \
    /etc/docker/daemon.json \
    /home/bx/.ssh \
    /etc/wireguard 2>/dev/null

# transfer ke laptop
scp bx@armbx:/tmp/armbx-backup-*.tar.gz C:/Backups/
```

**Automated backup (future):** install `restic` ke Backblaze B2 / S3.

---

## 🧯 Troubleshooting

### STB tidak responsive

Dari laptop:
```bash
ping bx                # LAN ping
ping armbx             # Tailscale ping
```

Kalau LAN ping gagal: STB mati / listrik off. Kalau LAN OK tapi SSH refuse: service SSH down (butuh TV console).

### Service tidak accessible dari internet

Urutan check:
1. Container running? → `docker ps | grep <name>`
2. Localhost accessible? → `curl -I http://localhost:<port>`
3. Cloudflared running? → `systemctl status cloudflared`
4. Public Hostname sudah di-add di CF dashboard?
5. DNS resolve? → `nslookup myapp.bxtohur.my.id`

### Docker gagal start

Kalau USB `armbx-storage` cabut, docker gagal start (karena `RequiresMountsFor`). Colok balik USB → `sudo systemctl start docker`.

### Memory tinggi

```bash
docker stats                    # per-container memory
free -h                         # overall
```

Kalau over 1.5G, cek apakah Netdata atau service lain memory-leak. Restart yang bermasalah: `docker restart <name>`.

### Reboot bersih

```bash
sudo reboot
```

Semua container auto-restart. Tailscale auto-reconnect. Cloudflared auto-reconnect. ~30 detik service lengkap online.

### Force stop semua + reboot

```bash
docker compose -f /media/armbx-storage/stacks/*/compose.yml down 2>/dev/null
sudo reboot
```

---

## 📚 Reference

| Service | URL internal | URL public | Fungsi |
|---|---|---|---|
| Dozzle | http://127.0.0.1:8080 | https://logs.bxtohur.my.id | Container logs browser |
| Netdata | http://127.0.0.1:19999 | https://netdata.bxtohur.my.id | Host metrics |
| Uptime Kuma | http://127.0.0.1:3001 | https://up.bxtohur.my.id | Monitoring + alerts |

Config files:
- Docker daemon: `/etc/docker/daemon.json`
- Cloudflared: `/etc/cloudflared/*.yml` (managed by `cloudflared service install`)
- fail2ban: `/etc/fail2ban/jail.local`
- UFW: `sudo ufw status verbose`
- Netplan: `/etc/netplan/*.yaml`
- NM: `/etc/NetworkManager/system-connections/`

Logs:
- firstboot: `/var/log/armbx-firstboot.log`
- cloudflared: `sudo journalctl -u cloudflared -f`
- fail2ban: `sudo journalctl -u fail2ban -n 50`
- docker: `/media/armbx-storage/docker/containers/<id>/`

---

**Last updated:** 2026-10-10 — ArmBX OS 1.0 v1.5.2
