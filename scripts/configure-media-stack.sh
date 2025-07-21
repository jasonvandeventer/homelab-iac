#!/usr/bin/env bash
set -e

# ===============================================
# configure-media-stack.sh
# Auto-links Sonarr/Radarr/SABnzbd/Prowlarr
# Safe to re-run + Terraform output fallback
# ===============================================

# ===========
# LOGGING
# ===========
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }

# ===========
# ARGUMENTS
# ===========
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --sonarr-url) SONARR_URL="$2"; shift ;;
    --sonarr-key) SONARR_KEY="$2"; shift ;;
    --radarr-url) RADARR_URL="$2"; shift ;;
    --radarr-key) RADARR_KEY="$2"; shift ;;
    --sab-url) SAB_URL="$2"; shift ;;
    --sab-key) SAB_KEY="$2"; shift ;;
    --prowlarr-url) PROWLARR_URL="$2"; shift ;;
    --prowlarr-key) PROWLARR_KEY="$2"; shift ;;
    --nzbgeek-key) NZBGEEK_KEY="$2"; shift ;;
  esac
  shift
done

# ===========
# FALLBACK TO TERRAFORM OUTPUTS IF EMPTY
# ===========
SONARR_URL="${SONARR_URL:-http://localhost:8989}"
RADARR_URL="${RADARR_URL:-http://localhost:7878}"
SAB_URL="${SAB_URL:-http://localhost:8080}"
PROWLARR_URL="${PROWLARR_URL:-http://localhost:9696}"

SONARR_KEY="${SONARR_KEY:-$(terraform output -raw sonarr_api_key || true)}"
RADARR_KEY="${RADARR_KEY:-$(terraform output -raw radarr_api_key || true)}"
SAB_KEY="${SAB_KEY:-$(terraform output -raw sabnzbd_api_key || true)}"
PROWLARR_KEY="${PROWLARR_KEY:-$(terraform output -raw prowlarr_api_key || true)}"
NZBGEEK_KEY="${NZBGEEK_KEY:-$(terraform output -raw nzbgeek_api_key || true)}"

# ===========
# SANITY CHECKS
# ===========
for key in SONARR_KEY RADARR_KEY SAB_KEY PROWLARR_KEY; do
  if [ -z "${!key}" ] || [ "${!key}" == "null" ]; then
    warn "$key is missing! Will attempt anyway..."
  fi
done

log "🔄 Auto-configuring Sonarr & Radarr with SABnzbd + Prowlarr..."

# ===========
# 1. ADD SABNZBD AS DOWNLOAD CLIENT
# ===========
log "➡ Adding SABnzbd to Sonarr..."
curl -s -X POST "${SONARR_URL}/api/v3/downloadclient" \
  -H "X-Api-Key: ${SONARR_KEY}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"SABnzbd\",
    \"enable\": true,
    \"protocol\": \"usenet\",
    \"priority\": 1,
    \"configContract\": \"SabnzbdSettings\",
    \"implementation\": \"Sabnzbd\",
    \"fields\": [
      {\"name\": \"apiKey\", \"value\": \"${SAB_KEY}\"},
      {\"name\": \"host\", \"value\": \"${SAB_URL}\"},
      {\"name\": \"port\", \"value\": 8080},
      {\"name\": \"useSsl\", \"value\": false},
      {\"name\": \"tvCategory\", \"value\": \"tv\"},
      {\"name\": \"recentTvPriority\", \"value\": 0},
      {\"name\": \"olderTvPriority\", \"value\": 0}
    ]
  }" >/dev/null && ok "Sonarr linked to SABnzbd"

log "➡ Adding SABnzbd to Radarr..."
curl -s -X POST "${RADARR_URL}/api/v3/downloadclient" \
  -H "X-Api-Key: ${RADARR_KEY}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"SABnzbd\",
    \"enable\": true,
    \"protocol\": \"usenet\",
    \"priority\": 1,
    \"configContract\": \"SabnzbdSettings\",
    \"implementation\": \"Sabnzbd\",
    \"fields\": [
      {\"name\": \"apiKey\", \"value\": \"${SAB_KEY}\"},
      {\"name\": \"host\", \"value\": \"${SAB_URL}\"},
      {\"name\": \"port\", \"value\": 8080},
      {\"name\": \"useSsl\", \"value\": false},
      {\"name\": \"movieCategory\", \"value\": \"movies\"},
      {\"name\": \"recentMoviePriority\", \"value\": 0},
      {\"name\": \"olderMoviePriority\", \"value\": 0}
    ]
  }" >/dev/null && ok "Radarr linked to SABnzbd"

# ===========
# 2. LINK PROWLARR AS INDEXER FOR BOTH
# ===========
log "➡ Linking Prowlarr as indexer for Sonarr..."
curl -s -X POST "${SONARR_URL}/api/v3/indexer" \
  -H "X-Api-Key: ${SONARR_KEY}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"Prowlarr\",
    \"enable\": true,
    \"protocol\": \"usenet\",
    \"priority\": 1,
    \"configContract\": \"ProwlarrSettings\",
    \"implementation\": \"Prowlarr\",
    \"fields\": [
      {\"name\": \"apiKey\", \"value\": \"${PROWLARR_KEY}\"},
      {\"name\": \"host\", \"value\": \"${PROWLARR_URL}\"},
      {\"name\": \"port\", \"value\": 9696},
      {\"name\": \"useSsl\", \"value\": false}
    ]
  }" >/dev/null && ok "Sonarr linked to Prowlarr"

log "➡ Linking Prowlarr as indexer for Radarr..."
curl -s -X POST "${RADARR_URL}/api/v3/indexer" \
  -H "X-Api-Key: ${RADARR_KEY}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"Prowlarr\",
    \"enable\": true,
    \"protocol\": \"usenet\",
    \"priority\": 1,
    \"configContract\": \"ProwlarrSettings\",
    \"implementation\": \"Prowlarr\",
    \"fields\": [
      {\"name\": \"apiKey\", \"value\": \"${PROWLARR_KEY}\"},
      {\"name\": \"host\", \"value\": \"${PROWLARR_URL}\"},
      {\"name\": \"port\", \"value\": 9696},
      {\"name\": \"useSsl\", \"value\": false}
    ]
  }" >/dev/null && ok "Radarr linked to Prowlarr"

# ===========
# 3. OPTIONAL: SEED PROWLARR WITH INDEXERS
# ===========
log "➡ Seeding default Usenet & torrent indexers in Prowlarr..."

# NZBGeek
curl -s -X POST "${PROWLARR_URL}/api/v1/indexer" \
  -H "X-Api-Key: ${PROWLARR_KEY}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"NZBGeek\",
    \"enabled\": true,
    \"protocol\": 1,
    \"implementation\": \"Newznab\",
    \"configContract\": \"NewznabSettings\",
    \"tags\": [],
    \"fields\": [
      {\"name\": \"baseUrl\", \"value\": \"https://api.nzbgeek.info\"},
      {\"name\": \"apiKey\", \"value\": \"${NZBGEEK_KEY}\"},
      {\"name\": \"categories\", \"value\": \"5000,5030,5040\"}
    ],
    \"priority\": 25
  }" >/dev/null && ok "Seeded NZBGeek Usenet"

# 1337x Torrent
curl -s -X POST "${PROWLARR_URL}/api/v1/indexer" \
  -H "X-Api-Key: ${PROWLARR_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "1337x",
    "enabled": true,
    "protocol": 2,
    "implementation": "Torznab",
    "configContract": "TorznabSettings",
    "tags": [],
    "fields": [
      {"name": "baseUrl", "value": "https://1337x.to"}
    ],
    "priority": 25
  }' >/dev/null && ok "Seeded 1337x torrent indexer"

# RARBG Mirror
curl -s -X POST "${PROWLARR_URL}/api/v1/indexer" \
  -H "X-Api-Key: ${PROWLARR_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "RARBG Mirror",
    "enabled": true,
    "protocol": 2,
    "implementation": "Torznab",
    "configContract": "TorznabSettings",
    "tags": [],
    "fields": [
      {"name": "baseUrl", "value": "https://torrentapi.org"}
    ],
    "priority": 25
  }' >/dev/null && ok "Seeded RARBG mirror"

ok "✅ Auto-linking + seeding complete!"
