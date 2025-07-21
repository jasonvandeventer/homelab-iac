# Homelab Media Stack (Terraform + Docker)

This project automates deployment and configuration of a complete self-hosted media stack using **Terraform** and **Docker**.

It deploys:

- **Plex** – Media server with GPU passthrough  
- **Sonarr** – TV show management  
- **Radarr** – Movie management  
- **Prowlarr** – Centralized indexer manager  
- **Bazarr** – Subtitle downloader  
- **SABnzbd** – Usenet downloader  
- **Nginx Proxy Manager** – SSL + reverse proxy  
- **Portainer** – Docker management UI  

…and fully integrates them into a **zero-click automation pipeline** for media downloads.

---

## ✅ Multi-Phase Deployment

To avoid long Terraform timeouts on first container startup, the setup is split into **three phases**:

1️⃣ **Phase 1 – Infrastructure**  
Terraform deploys all containers, networks, and volumes.  
This finishes quickly without waiting for Sonarr/Radarr APIs.

2️⃣ **Phase A – Fetch API Keys (automatic)**  
A lightweight script (`fetch-keys.sh`) runs automatically after containers start.  
It:

- Detects any available API keys from containers
- Updates `terraform.tfvars`
- Logs progress to `scripts/fetch-keys.log`
- **Never fails** even if some services are still initializing

3️⃣ **Phase B – Link Services (manual)**  
Once all APIs are ready, run `link-services.sh` manually to:

- Link Sonarr/Radarr → SABnzbd + Prowlarr
- Seed Prowlarr with NZBGeek and torrent trackers
- Logs results to `scripts/link-services.log`

This phased approach keeps Terraform fast, safe, and portfolio-friendly.

---

## ✅ Directory Structure

```md
scripts/
├── fetch-keys.sh        # Phase A → fetch API keys automatically
├── link-services.sh     # Phase B → run manually to link services
├── fetch-keys.log       # Logs key detection results
├── link-services.log    # Logs linking & seeding results
```

---

## ✅ Prerequisites

- Ubuntu 22.04+ or Debian-based VM (Proxmox LXC/VM works)
- Terraform 1.8+
- Docker & Docker Compose plugin installed
- Git

---

## ✅ Deployment Guide

### 1. Clone the repo

```bash
git clone https://github.com/<your-github-username>/homelab-bootstrap.git
cd homelab-bootstrap
```

### 2. Copy example variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

- Set your `nzbgeek_api_key`
- Leave Sonarr/Radarr/Prowlarr keys as `"CHANGEME"` (they’ll auto-populate later)

### 3. Deploy Phase 1 + Phase A

```bash
terraform init
terraform apply
```

- Terraform will:
  - Create Docker network/volumes
  - Deploy all containers
  - Run **Phase A (`fetch-keys.sh`)** automatically
  - Populate any API keys that are ready into `terraform.tfvars`

### 4. Wait for containers to initialize

- On first boot, Sonarr/Radarr/Prowlarr can take **2–5 minutes** for DB migrations
- Check logs:

  ```bash
  docker logs sonarr | grep "Application has finished startup"
  ```

### 5. Re-run Phase A (optional)

If some keys weren’t ready the first time:

```bash
bash scripts/fetch-keys.sh
```

Repeat until `terraform.tfvars` has **real keys for Sonarr/Radarr/Prowlarr**.

### 6. Run Phase B (linking)

Once keys are present:

```bash
bash scripts/link-services.sh
```

This will:

- Wait for APIs
- Auto-link Sonarr/Radarr → SABnzbd + Prowlarr
- Seed Prowlarr with NZBGeek and torrent trackers

---

## ✅ Terraform Outputs

After Phase 1, Terraform prints local URLs for each service:

```hcl
Outputs:

media_stack_urls = {
  "plex"      = "http://localhost:32400"
  "sonarr"    = "http://localhost:8989"
  "radarr"    = "http://localhost:7878"
  "bazarr"    = "http://localhost:6767"
  "sabnzbd"   = "http://localhost:8080"
  "prowlarr"  = "http://localhost:9696"
  "portainer" = "http://localhost:9000"
  "npm_admin" = "http://localhost:81"
}
```

---

## ✅ Why Two Phases?

On first run, Sonarr/Radarr/Prowlarr:

- Take longer to initialize (DB migrations)
- Generate their API keys only after startup completes

If Terraform tried to configure them immediately:

- It would hang for 5–10 minutes
- Often fail with `401 Unauthorized`

By splitting into **Phase A (safe key fetch)** + **Phase B (manual linking)**:

- Terraform is **fast and reliable**
- Keys populate automatically when ready
- Linking only happens once APIs are healthy

---

## ✅ Logs for Portfolio

- **Phase A log:** `scripts/fetch-keys.log`  
  Shows which services generated keys

- **Phase B log:** `scripts/link-services.log`  
  Shows APIs coming online, linking success, and Prowlarr indexer seeding

These logs provide **verifiable proof of automation** for your portfolio.

---

## ✅ Commands Recap

```bash
# Deploy containers + auto-fetch keys (Phase 1 + A)
terraform apply

# Wait for services to finish migrations...
docker logs sonarr | grep "Application has finished startup"

# Re-run Phase A until keys populate
bash scripts/fetch-keys.sh

# Run Phase B once keys are ready
bash scripts/link-services.sh
```

---

## ✅ Roadmap

- Phase 2: Add monitoring stack (Grafana + Prometheus)
- Phase 3: Add VLAN segmentation & pfSense integration
- Phase 4: K3s + GitOps migration (ArgoCD)

---

*This project demonstrates professional-grade DevOps automation: Terraform for infra, split-phase scripting for runtime config, and robust error-handling for slow-starting services.*

---

## ✅ License

MIT
