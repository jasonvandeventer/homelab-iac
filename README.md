# 🏠 Homelab Media Stack – Terraform Edition

This project deploys a complete **self-hosted media stack** using **Terraform + Docker provider**.

Instead of manually running `docker-compose`, this stack is **fully declarative**:

- `terraform apply` brings up the entire stack
- `terraform destroy` removes everything
- Volumes & networks are managed automatically

Perfect for **homelabs**, **Proxmox nodes**, or any Linux host running Docker.

---

## 📦 Services Included

| Service                 | Purpose                | Default Port           |
| ----------------------- | ---------------------- | ---------------------- |
| **Plex**                | Media streaming server | `32400`                |
| **Radarr**              | Movie automation       | `7878`                 |
| **Sonarr**              | TV automation          | `8989`                 |
| **Bazarr**              | Subtitle automation    | `6767`                 |
| **SABnzbd**             | Usenet downloader      | `8080`                 |
| **Portainer**           | Docker management UI   | `9000`                 |
| **Nginx Proxy Manager** | Reverse proxy + SSL    | `81` (admin), `80/443` |

All containers share **consistent paths**:

- `/data` → final media library (`movies/` + `tv/`)
- `/downloads` → temporary staging for Radarr/Sonarr
- `/config` → container-specific configs

---

## 🚀 Quick Start

**1️⃣ Clone the repo & initialize Terraform:**

```bash
git clone https://github.com/<your-username>/homelab-terraform.git
cd homelab-terraform
terraform init
```

**2️⃣ Deploy the stack:**

```bash
terraform apply
```

**3️⃣ Done!** Terraform will output quick links to all services:

```
Outputs:

media_stack_urls = {
  "plex" = "http://localhost:32400"
  "radarr" = "http://localhost:7878"
  "sonarr" = "http://localhost:8989"
  "bazarr" = "http://localhost:6767"
  "sabnzbd" = "http://localhost:8080"
  "portainer" = "http://localhost:9000"
  "npm_admin" = "http://localhost:81"
}
```

Now open your browser and start configuring.

---

## ⚙️ Customizing

This stack is **fully configurable** via `terraform.tfvars`.

Example:

```hcl
# terraform.tfvars
puid = "1001"
pgid = "1001"
tz   = "Europe/London"

ports = {
  plex       = "32400"
  radarr     = "7878"
  sonarr     = "8989"
  bazarr     = "6767"
  sabnzbd    = "8080"
  portainer  = "9000"
  npm_admin  = "81"
  npm_http   = "80"
  npm_https  = "443"
}
```

Then re-apply:

```bash
terraform apply
```

✅ No need to edit `main.tf` directly.

---

## 🗂 Volumes

Terraform automatically creates named Docker volumes:

- `plex_config` → Plex metadata
- `media_library` → Shared `/data` for movies & TV
- `downloads` → Temporary download staging
- `npm_data`, `npm_letsencrypt` → Nginx Proxy Manager configs

On Proxmox or a real homelab, you can swap these for **bind mounts** (e.g. `/mnt/media_library`).

---

## 🛠 Stack Lifecycle

```bash
terraform plan      # see what will change
terraform apply     # deploy or update containers
terraform destroy   # remove all containers, networks, and volumes
```

Terraform **tracks the state** so it only changes what’s necessary.

---

## ❓ Why Terraform Instead of docker-compose?

- **Declarative** → you define what should exist, Terraform makes it so
- **Idempotent** → `terraform apply` always converges to the same state
- **Lifecycle-aware** → `terraform destroy` cleans everything
- **Easier scaling later** → can migrate this stack to Proxmox VMs, Kubernetes, or cloud

---

## 🔒 Requirements

- Linux host (Proxmox, Ubuntu, etc.)
- Docker installed
- Terraform 1.3+

---

## 🌱 Next Phases

This is **Phase 1** of a bigger homelab automation plan:

- ✅ **Phase 1:** Docker media stack (Plex + \*arr + SABnzbd + Bazarr + NPM)
- **Phase 2:** Monitoring stack (Grafana, Prometheus, Loki)
- **Phase 3:** Infrastructure bootstrap (Proxmox VMs, Ansible)
- **Phase 4:** K3s + GitOps migration (ArgoCD, Helm)

---

## 📈 Portfolio Value

This project demonstrates:

- **Infrastructure as Code (IaC)** with Terraform
- Docker container orchestration with persistent volumes
- Declarative networking + service discovery
- Clean, reusable Terraform module design

Perfect for DevOps, SRE, or homelab enthusiasts.

---

## 📝 Credits

Built as part of a **Proxmox + Terraform homelab learning project**.

---

**Quick Commands Recap:**

```bash
terraform init
terraform apply
terraform destroy
```
