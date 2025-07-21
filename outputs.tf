############################################
# MEDIA STACK URLs
############################################

output "media_stack_urls" {
  description = "Quick links to access your media stack services"
  value = {
    bazarr    = "http://localhost:${var.ports["bazarr"]}"
    npm_admin = "http://localhost:${var.ports["npm_admin"]}"
    plex      = "http://localhost:${var.ports["plex"]}"
    portainer = "http://localhost:${var.ports["portainer"]}"
    prowlarr  = "http://localhost:${var.ports["prowlarr"]}"
    radarr    = "http://localhost:${var.ports["radarr"]}"
    sabnzbd   = "http://localhost:${var.ports["sabnzbd"]}"
    sonarr    = "http://localhost:${var.ports["sonarr"]}"
  }
}
