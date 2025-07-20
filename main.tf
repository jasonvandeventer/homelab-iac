terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

# Create a custom Docker network
resource "docker_network" "media_network" {
  name = "media-network"
}

# Create persistent volumes
resource "docker_volume" "plex_config" {
  name = "plex_config"
}

resource "docker_volume" "media_library" {
  name = "media_library"
}

resource "docker_volume" "downloads" {
  name = "downloads"
}

# Deploy Plex container
resource "docker_container" "plex" {
  name    = "plex"
  image   = "linuxserver/plex:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 32400
    external = 32400
  }

  # Bind persistent volumes
  mounts {
    target = "/config"
    source = docker_volume.plex_config.name
    type   = "volume"
  }
  # Media library
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  # Environment variables (configurable later)
  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=America/Chicago",
    "VERSION=docker"
  ]

  devices {
    host_path      = "/dev/dri"
    container_path = "/dev/dri"
  }
}

# Radarr = Movie Management
resource "docker_container" "radarr" {
  name    = "radarr"
  image   = "linuxserver/radarr:latest"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.media_network.name
  }

  ports {
    internal = 7878
    external = 7878
  }

  mounts {
    target = "/config"
    source = docker_volume.downloads.name
    type   = "volume"
  }
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=America/Chicago"
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
    external = 8989
  }

  mounts {
    target = "/config"
    source = docker_volume.downloads.name
    type   = "volume"
  }
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=America/Chicago"
  ]
}

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
    external = 6767
  }

  mounts {
    target = "/config"
    source = docker_volume.downloads.name
    type   = "volume"
  }
  mounts {
    target = "/data"
    source = docker_volume.media_library.name
    type   = "volume"
  }

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=America/Chicago"
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
    external = 8080
  }

  mounts {
    target = "/config"
    source = docker_volume.downloads.name
    type   = "volume"
  }
  mounts {
    target = "/downloads"
    source = docker_volume.downloads.name
    type   = "volume"
  }

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=America/Chicago"
  ]
}
