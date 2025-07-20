output "media_stack_urls" {
  value = {
    plex      = "http://localhost:${var.ports["plex"]}"
    radarr    = "http://localhost:${var.ports["radarr"]}"
    sonarr    = "http://localhost:${var.ports["sonarr"]}"
    bazarr    = "http://localhost:${var.ports["bazarr"]}"
    sabnzbd   = "http://localhost:${var.ports["sabnzbd"]}"
    portainer = "http://localhost:${var.ports["portainer"]}"
    npm_admin = "http://localhost:${var.ports["npm_admin"]}"
  }
  description = "Quick links to access your media stack services"
}
