# Homelab Media Stack - Terraform Edition

This project replaces the original **bash + docker-compose** deployment with **Terraform Infrastructure as Code**.

## What It Does

✅ Creates a Docker network
✅ Creates persistent volumes
✅ Deploys Plex (Phase 1)
✅ Later adds Radarr, Sonarr, Bazarr, SABnzbd, Portainer, Nginx Proxy Manager

## Goals

- Learn Terraform Docker provider
- Make the media stack **declarative**
- Push to GitHub for portfolio
- Deploy locally, then on Proxmox host

---

## Quick Start

```bash
terraform init
terraform plan
terraform apply
```
