############################################
# USER / PERMISSIONS
############################################

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

############################################
# PORT MAPPINGS (ALPHABETIZED)
############################################

variable "ports" {
  description = "Port mappings for services"
  type        = map(string)
  default = {
    bazarr    = "6767"
    npm_admin = "81"
    npm_http  = "80"
    npm_https = "443"
    plex      = "32400"
    portainer = "9000"
    prowlarr  = "9696"
    radarr    = "7878"
    sabnzbd   = "8080"
    sonarr    = "8989"
  }
}


############################################
# API Keys for Auto-Linking
############################################

variable "nzbgeek_api_key" {
  description = "API key for NZBGeek for Usenet indexing"
  type        = string
}

variable "prowlarr_api_key" {
  description = "API key for Prowlarr"
  type        = string
}

variable "radarr_api_key" {
  description = "API key for Radarr"
  type        = string
}

variable "sabnzbd_api_key" {
  description = "API key for SABnzbd"
  type        = string
}

variable "sonarr_api_key" {
  description = "API key for Sonarr"
  type        = string
}
