# 🏠 Homelab Bootstrap – **Phase 1.5**

> **Now with Prowlarr + Auto-Linking + Pre-Seeded Indexers**
>
> Deploy Plex, SABnzbd, Sonarr, Radarr, Bazarr, Portainer, Nginx Proxy Manager, and Prowlarr **with one Terraform apply**.
>
> ✅ **Single-command deployment**  
> ✅ **GPU-accelerated Plex streaming**  
> ✅ **Persistent volumes for all configs**  
> ✅ **Automatic Sonarr/Radarr → SABnzbd + Prowlarr linking**  
> ✅ **Prowlarr pre-seeded with NZBGeek + safe torrent indexers**

---

## 📂 Repo Structure

```
homelab-bootstrap/
├── main.tf                      # Terraform config for media stack
├── variables.tf                 # API keys, ports, user config
├── outputs.tf                   # Quick access URLs
├── terraform.tfvars             # Your personal API keys + TZ
├── scripts/
│   └── configure-media-stack.sh # Auto-links Sonarr/Radarr to SABnzbd + Prowlarr + seeds indexers
└── volumes.tf                   # (Optional) extra volume definitions
```

---

## 🖥️ Phase 1.5 Services

| Service                 | Purpose                          | Default Port   |
| ----------------------- | -------------------------------- | -------------- |
| **Bazarr**              | Subtitle management              | `6767`         |
| **Nginx Proxy Manager** | Reverse proxy & SSL              | `81`, `80/443` |
| **Plex**                | GPU-accelerated media server     | `32400`        |
| **Portainer**           | Docker management UI             | `9000`         |
| **Prowlarr**            | Unified Usenet + torrent indexer | `9696`         |
| **Radarr**              | Movie management                 | `7878`         |
| **SABnzbd**             | Usenet downloader                | `8080`         |
| **Sonarr**              | TV show management               | `8989`         |

All configs now live in **dedicated volumes**, ensuring persistence across upgrades:

- `/var/lib/docker/volumes/bazarr_config`
- `/var/lib/docker/volumes/radarr_config`
- `/var/lib/docker/volumes/sonarr_config`
- `/var/lib/docker/volumes/sabnzbd_config`
- `/var/lib/docker/volumes/prowlarr_config`
- `/var/lib/docker/volumes/plex_config`

Shared media paths:

- `downloads` → SABnzbd, Sonarr, Radarr, Bazarr
- `media_library` → Plex library

---

## 🚀 Quick Start

1️⃣ **Configure your API keys**  
Create `terraform.tfvars` with your real keys:

```hcl
sabnzbd_api_key  = "YOUR_SABNZBD_KEY"
sonarr_api_key   = "YOUR_SONARR_KEY"
radarr_api_key   = "YOUR_RADARR_KEY"
prowlarr_api_key = "YOUR_PROWLARR_KEY"
nzbgeek_api_key  = "YOUR_NZBGEEK_KEY"
```

2️⃣ **Deploy the stack**

```bash
terraform init
terraform apply
```

3️⃣ **Wait for auto-linking to complete**  
Terraform will run `scripts/configure-media-stack.sh` to:

- Link SABnzbd → Sonarr + Radarr
- Link Prowlarr → Sonarr + Radarr
- Pre-seed Prowlarr with **NZBGeek + 1337x + RARBG mirror**

4️⃣ **Access your services**  
After apply completes:

```bash
terraform output media_stack_urls
```

---

## ♻️ What’s New in Phase 1.5?

✅ **Dedicated config volumes for every container** (no mixed data)  
✅ **Prowlarr container added**  
✅ **Auto-linking script** for Sonarr + Radarr + SABnzbd + Prowlarr  
✅ **Pre-seeded Prowlarr** with NZBGeek + safe torrent trackers  
✅ **Instant usable stack** → Sonarr/Radarr immediately have download client + indexers configured

---

## 🔄 Post-Deploy Behavior

- Updating containers with `terraform apply` **does not reset API keys** (persisted in `/config` volumes).
- Adding more indexers later? Just run:
  ```bash
  bash scripts/configure-media-stack.sh     --sonarr-url "http://localhost:8989"     --sonarr-key "$SONARR_KEY"     --radarr-url "http://localhost:7878"     --radarr-key "$RADARR_KEY"     --sab-url "http://localhost:8080"     --sab-key "$SAB_KEY"     --prowlarr-url "http://localhost:9696"     --prowlarr-key "$PROWLARR_KEY"     --nzbgeek-key "$NZBGEEK_KEY"
  ```

---

## 📈 Portfolio Value

This now demonstrates:

- **Infrastructure as Code** (Terraform-managed Docker stack)
- **Persistent volume strategy**
- **Automated service integration via APIs**
- **Unified indexer (Prowlarr) auto-seeded with providers**
- **Truly one-command media stack deploy**

---

## ✅ Quick URLs

After `terraform apply`, view all services:

```bash
terraform output media_stack_urls
```

Example:

- Plex → `http://localhost:32400`
- Sonarr → `http://localhost:8989`
- Radarr → `http://localhost:7878`
- Bazarr → `http://localhost:6767`
- SABnzbd → `http://localhost:8080`
- Portainer → `http://localhost:9000`
- Nginx Proxy Manager → `http://localhost:81`
- Prowlarr → `http://localhost:9696`

---

### ✅ Phase 1.5 Highlights

**Before:**

- Containers deployed, but Sonarr/Radarr setup was manual
- No indexers → needed to log into Prowlarr and add them

**Now:**

- **Zero-click setup** → after Terraform apply, Sonarr & Radarr already know SABnzbd + Prowlarr
- **Baseline providers** (NZBGeek + torrents) already usable
- Fully persistent → upgrades won’t break configuration

---

## 🛠 Next Phases

Phase 2.0 will add:

- **Homarr Dashboard** (Phase 2.6)
- **Monitoring & security stack (Prometheus, Grafana, CrowdSec)**
- Optional **Pi-hole/qBittorrent + VLAN work**

---

## ✅ Commit & Push

After testing:

```bash
git add .
git commit -m "feat: Phase 1.5 – Added Prowlarr + auto-linking & seeded indexers"
git push origin main
```
