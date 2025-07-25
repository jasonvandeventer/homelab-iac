#!/usr/bin/env bash
set -e

############################################################
# Logging Setup
############################################################
LOG_FILE="scripts/configure-media-stack.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting media stack auto-config: $(date) ==="

############################################################
# Parse arguments passed from Terraform
############################################################
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --sonarr-url)
    SONARR_URL="$2"
    shift
    ;;
  --sonarr-key)
    SONARR_KEY="$2"
    shift
    ;;
  --radarr-url)
    RADARR_URL="$2"
    shift
    ;;
  --radarr-key)
    RADARR_KEY="$2"
    shift
    ;;
  --sab-url)
    SAB_URL="$2"
    shift
    ;;
  --sab-key)
    SAB_KEY="$2"
    shift
    ;;
  --prowlarr-url)
    PROWLARR_URL="$2"
    shift
    ;;
  --prowlarr-key)
    PROWLARR_KEY="$2"
    shift
    ;;
  --nzbgeek-key)
    NZBGEEK_API_KEY="$2"
    shift
    ;;
  esac
  shift
done

############################################################
# Helper: wait for a config file to exist
############################################################
wait_for_config_file() {
  local container=$1
  local path=$2

  echo "⏳ Waiting for $container config at $path..."
  until docker exec "$container" test -f "$path"; do
    echo "  $container config not ready yet, retrying in 5s..."
    sleep 5
  done
  echo "✅ $container config detected."
}

############################################################
# Helper: safe fetch API key from a config file inside container
############################################################
safe_fetch_key() {
  local container=$1
  local path=$2
  local pattern=$3
  docker exec "$container" cat "$path" 2>/dev/null | grep "$pattern" | sed -n "s/.*$pattern[\">=]*\\([^\"<]*\\).*/\\1/p" || true
}

############################################################
# Helper: update terraform.tfvars in place
############################################################
update_tfvars_key() {
  local key_name=$1
  local key_value=$2
  if grep -q "$key_name" terraform.tfvars; then
    sed -i "s|$key_name.*|$key_name  = \"$key_value\"|" terraform.tfvars
  else
    echo "$key_name  = \"$key_value\"" >>terraform.tfvars
  fi
}

############################################################
# Helper: initial key fetch (non-fatal)
############################################################
fetch_or_warn() {
  local name=$1
  local container=$2
  local path=$3
  local pattern=$4
  local tfvar_key=$5
  local current_key=$6

  if [ -z "$current_key" ] || [ "$current_key" = "CHANGEME" ]; then
    NEW_KEY=$(safe_fetch_key "$container" "$path" "$pattern")
    if [ -n "$NEW_KEY" ]; then
      echo "✅ $name API key detected: $NEW_KEY"
      update_tfvars_key "$tfvar_key" "$NEW_KEY"
      echo "$NEW_KEY"
    else
      echo "⚠️ Could not fetch $name key yet (will retry during API wait)..."
      echo "$current_key"
    fi
  else
    echo "$current_key"
  fi
}

############################################################
# Helper: wait for API & auto-heal keys if 401 Unauthorized
############################################################
wait_for_api() {
  local name=$1
  local url=$2
  local container=$3
  local config_path=$4
  local pattern=$5
  local current_key=$6
  local tfvar_key_name=$7

  echo "⏳ Waiting for $name API at $url..."
  local retries=0

  while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" -H "X-Api-Key: $current_key" || true)

    if [[ "$STATUS" == "200" ]]; then
      echo "✅ $name API is ready!"
      break
    elif [[ "$STATUS" == "401" ]]; then
      echo "⚠️ $name API returned 401 Unauthorized → refreshing API key..."
      NEW_KEY=$(safe_fetch_key "$container" "$config_path" "$pattern")
      if [ -n "$NEW_KEY" ]; then
        current_key="$NEW_KEY"
        echo "✅ Updated $name API key: $current_key"
        update_tfvars_key "$tfvar_key_name" "$current_key"
      else
        echo "⚠️ $name key still not ready, retrying..."
      fi
      sleep 5
    else
      echo "  $name not ready yet (status $STATUS), retrying in 5s..."
      sleep 5
    fi

    retries=$((retries + 1))
    if [[ $retries -gt 60 ]]; then
      echo "❌ Timeout waiting for $name API!"
      exit 1
    fi
  done

  # Return the resolved key
  echo "$current_key"
}

############################################################
# Step 1: Wait for all config files to exist
############################################################
wait_for_config_file "sonarr" "/config/config.xml"
wait_for_config_file "radarr" "/config/config.xml"
wait_for_config_file "prowlarr" "/config/config.xml"
wait_for_config_file "sabnzbd" "/config/sabnzbd.ini"

############################################################
# Step 2: Safe initial auto-fetch API keys (non-fatal)
############################################################
SONARR_KEY=$(fetch_or_warn "Sonarr" "sonarr" "/config/config.xml" "ApiKey" "sonarr_api_key" "$SONARR_KEY")
RADARR_KEY=$(fetch_or_warn "Radarr" "radarr" "/config/config.xml" "ApiKey" "radarr_api_key" "$RADARR_KEY")
PROWLARR_KEY=$(fetch_or_warn "Prowlarr" "prowlarr" "/config/config.xml" "ApiKey" "prowlarr_api_key" "$PROWLARR_KEY")

# SABnzbd key is in sabnzbd.ini
if [ -z "$SAB_KEY" ] || [ "$SAB_KEY" = "CHANGEME" ]; then
  NEW_KEY=$(docker exec sabnzbd grep "api_key" /config/sabnzbd.ini 2>/dev/null | cut -d' ' -f3 || true)
  if [ -n "$NEW_KEY" ]; then
    SAB_KEY="$NEW_KEY"
    echo "✅ SABnzbd API key detected: $SAB_KEY"
    update_tfvars_key "sabnzbd_api_key" "$SAB_KEY"
  else
    echo "⚠️ Could not fetch SABnzbd key yet (will retry during API wait)..."
  fi
fi

############################################################
# Step 3: Wait for APIs (auto-heal keys if needed)
############################################################
SONARR_KEY=$(
  wait_for_api \
    "Sonarr" \
    "${SONARR_URL}/api/v3/system/status" \
    "sonarr" \
    "/config/config.xml" \
    "ApiKey" \
    "$SONARR_KEY" \
    "sonarr_api_key"
)

RADARR_KEY=$(
  wait_for_api \
    "Radarr" \
    "${RADARR_URL}/api/v3/system/status" \
    "radarr" \
    "/config/config.xml" \
    "ApiKey" \
    "$RADARR_KEY" \
    "radarr_api_key"
)

PROWLARR_KEY=$(
  wait_for_api \
    "Prowlarr" \
    "${PROWLARR_URL}/api/v1/system/status" \
    "prowlarr" \
    "/config/config.xml" \
    "ApiKey" \
    "$PROWLARR_KEY" \
    "prowlarr_api_key"
)

############################################################
# Step 4: Auto-configure Sonarr & Radarr with SABnzbd + Prowlarr
############################################################
echo "🔄 Auto-configuring Sonarr & Radarr with SABnzbd + Prowlarr..."

# Add SABnzbd to Sonarr
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
      {\"name\": \"tvCategory\", \"value\": \"tv\"}
    ]
  }" >/dev/null

# Add SABnzbd to Radarr
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
      {\"name\": \"movieCategory\", \"value\": \"movies\"}
    ]
  }" >/dev/null

# Link Prowlarr to Sonarr
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

# Link Prowlarr to Radarr
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

echo "✅ Sonarr & Radarr linked with SABnzbd + Prowlarr!"

############################################################
# Step 5: Seed Prowlarr with NZBGeek + Torrent Indexers
############################################################
echo "➡ Seeding default Usenet & torrent indexers in Prowlarr..."

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
      {\"name\": \"apiKey\", \"value\": \"${NZBGEEK_API_KEY}\"},
      {\"name\": \"categories\", \"value\": \"5000,5030,5040\"}
    ],
    \"priority\": 25
  }" >/dev/null

# 1337x
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
  }' >/dev/null

echo "✅ Seeded NZBGeek + safe torrent trackers!"
echo "=== Auto-config completed at $(date) ==="
