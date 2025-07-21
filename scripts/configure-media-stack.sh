#!/usr/bin/env bash
set -e

# Parse arguments
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
    --nzbgeek-key) NZBGEEK_API_KEY="$2"; shift ;;
  esac
  shift
done

echo "🔄 Auto-configuring Sonarr & Radarr with SABnzbd + Prowlarr..."

# 1. Add SABnzbd as a download client in Sonarr
echo "➡ Adding SABnzbd to Sonarr..."
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
  }" >/dev/null

# 2. Add SABnzbd to Radarr
echo "➡ Adding SABnzbd to Radarr..."
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
  }" >/dev/null

# 3. Link Prowlarr as indexer
echo "➡ Linking Prowlarr as indexer for Sonarr..."
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
  }" >/dev/null

echo "➡ Linking Prowlarr as indexer for Radarr..."
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
  }" >/dev/null

echo "✅ Auto-linking complete!"

############################################
# OPTIONAL: SEED PROWLARR INDEXERS
############################################
echo "➡ Seeding default Usenet & torrent indexers in Prowlarr..."

# 1. Add NZBGeek (Usenet)
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
      {\"name\": \"apiKey\", \"value\": \"${NZBGEEK_API_KEY}\"},
      {\"name\": \"categories\", \"value\": \"5000,5030,5040\"}
    ],
    \"priority\": 25
  }" >/dev/null

# 2. Add 1337x (Torrent)
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
  }' >/dev/null

# 3. Add RARBG proxy (Torrent)
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
  }' >/dev/null

echo "✅ Seeded NZBGeek + safe torrent trackers!"

