# ArmBX OS

**Headless Armbian-based OS khusus Amlogic STB** (S905X / aml-s9xx-box family) — dibangun di atas Armbian community build (Debian 13 trixie, kernel 6.18.49-meson64).

Dirancang untuk STB bekas dengan **eMMC corrupt**: boot dari SD card via u-boot bypass. Cocok dijadikan mini home-VPS, Docker host, atau IoT gateway dengan budget minimal.

## ✨ Fitur

- 🪶 **Headless** — tanpa X11/desktop stack, konsumsi RAM minimal
- 🔧 **`bx-menu`** — TUI toolkit untuk WiFi, USB storage, Tailscale, info jaringan, install ke eMMC, legacy tools (MusMenu dari Pak Mustofa)
- 📶 **WiFi Setup Wizard** — otomatis muncul saat login pertama lokal (TV + keyboard), scan + connect
- 💾 **USB Auto-mount** — colok USB → otomatis mount di `/media/<label>` dengan ownership `bx`
- 🔐 **Hardened SSH** — key-only (opsional), `PermitRootLogin no`, LLMNR off, UFW-ready
- 🔄 **First-boot auto-setup** — regen SSH host keys, expand partisi ke seluruh SD, pin critical packages
- 📊 **Dynamic banner** — `/etc/issue` menampilkan logo ArmBX + IP + perintah SSH
- 🛡️ **Kernel pinned** (`apt-mark hold`) — mencegah brick dari upgrade kernel yang tidak kompatibel dengan STB

## 🚀 Flash

1. **Download** image terbaru dari [Releases](../../releases).
2. **Verifikasi SHA256**:
   ```
   sha256sum -c armbx-os-1.0.img.xz.sha256
   ```
3. **Flash** ke SD card ≥ 4GB pakai [Balena Etcher](https://etcher.balena.io/) (auto-decompress `.xz`) atau Rufus.
4. **Masukkan SD ke STB**, nyalakan.

## 🎬 First boot flow

1. ~30 detik: banner ArmBX + `armbx login:` di layar TV
2. Login: `bx` / `armbx` → sistem paksa ganti password
3. **Wizard WiFi otomatis muncul** → scan + pilih SSID + password → connect
4. Setelah connect: tampil IP + perintah `ssh bx@<IP>`
5. Partisi root auto-expand ke seluruh ukuran SD
6. SSH host keys di-regenerate otomatis

## 🖥️ Target hardware

- STB Amlogic S905X / S905W (p212 DTB)
- Boot dari SD; eMMC tidak disentuh (aman untuk STB dengan eMMC corrupt)
- Minimal 1GB RAM (tested di 1.88GB)

Compatible dengan STB:
- B860H v1 / v2.1 (via Oprek B860H di bx-menu)
- HG680P (via wifi-hg680p script)
- STB Amlogic generic yang bisa boot dari SD

## 🏗️ Build from source

Butuh WSL (Ubuntu) + Windows PowerShell + Admin.

```bash
# 1. Image existing SD STB (yang sudah di-customize) ke .img
powershell.exe -File build/image-full.ps1  # (as admin)

# 2. Patch + shrink + compress
wsl -u root bash build/build-image.sh
```

Lihat `build/` untuk detail script.

## 📦 VPS-ify

Scripts optional untuk setup STB jadi mini-VPS:

- `vps/01-security.sh` — UFW, fail2ban, unattended-upgrades, swap tuning
- `vps/02a-docker-install.sh` — Docker + compose plugin
- `vps/02b-docker-move-to-usb.sh` — Move `/var/lib/docker` ke USB ext4 (overlay2 driver)
- `vps/03-monitoring-netdata-kuma.sh` — Netdata + Uptime Kuma (atau)
- `vps/04-switch-to-gatus.sh` — Gatus (lightweight, ~150MB lebih hemat dari Uptime Kuma)
- `vps/05-cloudflare-tunnel.sh` — Public access via Cloudflare Tunnel (no port forwarding)

Panduan deployment service baru: [DEPLOYMENT.md](DEPLOYMENT.md)

## 🔐 Security defaults

- `PermitRootLogin no`
- Password auth: on (switch to key-only setelah first login)
- LLMNR off
- Hanya SSH listening (plus 80/443 bila UFW setup di-run)
- Sudo butuh password

## 🙏 Credits

- Base: [Armbian community](https://github.com/armbian/community)
- Original STB installer scripts & MusMenu: **Pak Mustofa**
- u-boot bypass tooling: komunitas Armbian/Amlogic
- Build & rebrand: Rizal / Bxtohur

## 📜 Lisensi

MIT. Lihat [LICENSE](LICENSE).

ArmBX OS adalah redistribusi dengan modifikasi dari Armbian (GPL-2.0) — komponen upstream mengikuti lisensi masing-masing.
