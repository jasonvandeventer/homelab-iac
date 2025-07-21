terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

############################################
# NETWORK
############################################

# Create a custom Docker network for the media stack
resource "docker_network" "media_network" {
  name = "media-network"
}

############################################
# SHARED VOLUMES
############################################

# Shared media library for Plex, Sonarr, Radarr, Bazarr
resource "docker_volume" "media_library" {
  name = "media_library"
}

# Shared downloads for SABnzbd, Sonarr, Radarr, Bazarr
resource "docker_volume" "downloads" {
  name = "downloads"
}

############################################
# INDIVIDUAL CONFIG VOLUMES
############################################

# Bazarr config
resource "docker_volume" "bazarr_config" {
  name = "bazarr_config"
}

# Nginx Proxy Manager config
resource "docker_volume" "npm_data" {
  name = "npm_data"
}
resource "docker_volume" "npm_letsencrypt" {
  name = "npm_letsencrypt"
}

# Plex config
resource "docker_volume" "plex_config" {
  name = "plex_config"
}

# Portainer config
resource "docker_volume" "portainer_data" {
  name = "portainer_data"
}

# Prowlarr config
resource "docker_volume" "prowlarr_config" {
  name = "prowlarr_config"
}

# Radarr config
resource "docker_volume" "radarr_config" {
  name = "radarr_config"
}

# SABnzbd config
resource "docker_volume" "sabnzbd_config" {
  name = "sabnzbd_config"
}

# Sonarr config
resource "docker_volume" "sonarr_config" {
  name = "sonarr_config"
}

############################################
# CONTAINERS (ALPHABETIZED)
############################################

# Bazarr - Subtitle Management
resource "docker_container" "bazarr" {
  name    = "bazarr"
  image   = "linuxserver/bazarr:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 6767
    external = tonumber(var.ports["bazarr"])
  }

  # Dedicated config
  mounts {
    target = "/config"
    source = docker_volume.bazarr_config.name
    type   = "volume"
  }

  # Downloads shared with Sonarr/Radarr
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }

  # Media library for subtitle placement
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.tz}",
    "VERSION=docker"
  ]
}

# Nginx Proxy Manager - Reverse Proxy + SSL
resource "docker_container" "nginx_proxy_manager" {
  name    = "nginx-proxy-manager"
  image   = "jc21/nginx-proxy-manager:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 81
    external = tonumber(var.ports["npm_admin"])
  }
  ports {
    internal = 80
    external = tonumber(var.ports["npm_http"])
  }
  ports {
    internal = 443
    external = tonumber(var.ports["npm_https"])
  }

  mounts {
    target = "/data"
    source = docker_volume.npm_data.name
    type   = "volume"
  }
  mounts {
    target = "/etc/letsencrypt"
    source = docker_volume.npm_letsencrypt.name
    type   = "volume"
  }
}

# Plex - Media Server (GPU Accelerated)
resource "docker_container" "plex" {
  name    = "plex"
  image   = "linuxserver/plex:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 32400
    external = tonumber(var.ports["plex"])
  }

  # Plex config (metadata DB)
  mounts {
    target = "/config"
    source = docker_volume.plex_config.name
    type   = "volume"
  }

  # Media library for streaming
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.tz}",
    "VERSION=docker"
  ]

  # GPU passthrough
  devices {
    host_path      = "/dev/dri"
    container_path = "/dev/dri"
  }
}

# Portainer - Docker Management UI
resource "docker_container" "portainer" {
  name    = "portainer"
  image   = "portainer/portainer-ce:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 9000
    external = tonumber(var.ports["portainer"])
  }

  mounts {
    target = "/var/run/docker.sock"
    source = "/var/run/docker.sock"
    type   = "bind"
  }

  # Dedicated Portainer config volume
  mounts {
    target = "/data"
    source = docker_volume.portainer_data.name
    type   = "volume"
  }
}

# Prowlarr - Central Indexer Management
resource "docker_container" "prowlarr" {
  name    = "prowlarr"
  image   = "lscr.io/linuxserver/prowlarr:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 9696
    external = tonumber(var.ports["prowlarr"])
  }

  # Dedicated config for indexer DB
  mounts {
    target = "/config"
    source = docker_volume.prowlarr_config.name
    type   = "volume"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.tz}",
    "VERSION=docker"
  ]
}

# Radarr - Movie Management
resource "docker_container" "radarr" {
  name    = "radarr"
  image   = "linuxserver/radarr:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 7878
    external = tonumber(var.ports["radarr"])
  }

  # Dedicated config
  mounts {
    target = "/config"
    source = docker_volume.radarr_config.name
    type   = "volume"
  }

  # Downloads from SABnzbd
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }

  # Media library for movie placement
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.tz}",
    "VERSION=docker"
  ]
}

# SABnzbd - Usenet Downloader
resource "docker_container" "sabnzbd" {
  name    = "sabnzbd"
  image   = "linuxserver/sabnzbd:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 8080
    external = tonumber(var.ports["sabnzbd"])
  }

  # Dedicated config for SABnzbd
  mounts {
    target = "/config"
    source = docker_volume.sabnzbd_config.name
    type   = "volume"
  }

  # Downloads shared with Sonarr/Radarr
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.tz}",
    "VERSION=docker"
  ]
}

# Sonarr - TV Show Management
resource "docker_container" "sonarr" {
  name    = "sonarr"
  image   = "linuxserver/sonarr:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 8989
    external = tonumber(var.ports["sonarr"])
  }

  # Dedicated config
  mounts {
    target = "/config"
    source = docker_volume.sonarr_config.name
    type   = "volume"
  }

  # Downloads from SABnzbd
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }

  # Media library for TV show placement
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.tz}",
    "VERSION=docker"
  ]
}

############################################
# Phase A: Fetch API keys only (safe)
############################################
resource "null_resource" "fetch_media_keys" {
  provisioner "local-exec" {
    command = "bash scripts/fetch-keys.sh"
  }

  depends_on = [
    docker_container.sonarr,
    docker_container.radarr,
    docker_container.sabnzbd,
    docker_container.prowlarr
  ]
}

