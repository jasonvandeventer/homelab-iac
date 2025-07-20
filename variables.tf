variable "puid" {
  description = "User ID for container permissions"
  default     = "1000"
}

variable "pgid" {
  description = "Group ID for container permissions"
  default     = "1000"
}

variable "tz" {
  description = "Timezone for containers"
  default     = "America/Chicago"
}

variable "ports" {
  description = "Port mappings for services"
  type        = map(string)
  default = {
    plex      = "32400"
    radarr    = "7878"
    sonarr    = "8989"
    bazarr    = "6767"
    sabnzbd   = "8080"
    portainer = "9000"
    npm_admin = "81"
    npm_http  = "80"
    npm_https = "443"
  }
}
