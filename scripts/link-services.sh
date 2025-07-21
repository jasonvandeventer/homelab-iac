#!/usr/bin/env bash
set -e

LOG_FILE="scripts/link-services.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Phase B: Linking services $(date) ==="

SONARR_URL="http://localhost:8989"
RADARR_URL="http://localhost:7878"
SAB_URL="http://localhost:8080"
PROWLARR_URL="http://localhost:9696"

SONARR_KEY=$(grep sonarr_api_key terraform.tfvars | awk '{print $3}' | tr -d '"')
RADARR_KEY=$(grep radarr_api_key terraform.tfvars | awk '{print $3}' | tr -d '"')
PROWLARR_KEY=$(grep prowlarr_api_key terraform.tfvars | awk '{print $3}' | tr -d '"')
SAB_KEY=$(grep sabnzbd_api_key terraform.tfvars | awk '{print $3}' | tr -d '"')

wait_for_api() {
    local name=$1 url=$2 key=$3
    echo "⏳ Waiting for $name API at $url..."
    retries=0
    while true; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" -H "X-Api-Key: $key" || true)
        if [[ "$STATUS" == "200" ]]; then
            echo "✅ $name API ready!"
            break
        fi
        retries=$((retries + 1))
        if [[ $retries -gt 180 ]]; then
            echo "❌ Timeout waiting for $name API"
            exit 1
        fi
        sleep 5
    done
}

wait_for_api "Sonarr" "$SONARR_URL/api/v3/system/status" "$SONARR_KEY"
wait_for_api "Radarr" "$RADARR_URL/api/v3/system/status" "$RADARR_KEY"
wait_for_api "Prowlarr" "$PROWLARR_URL/api/v1/system/status" "$PROWLARR_KEY"

echo "🔧 Linking Sonarr/Radarr → SABnzbd & Prowlarr..."

# Link SABnzbd to Sonarr
curl -s -X POST "$SONARR_URL/api/v3/downloadclient" -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" --data "{
  \"name\": \"SABnzbd\",
  \"enable\": true,
  \"protocol\": \"usenet\",
  \"priority\": 1,
  \"configContract\": \"SabnzbdSettings\",
  \"implementation\": \"Sabnzbd\",
  \"fields\": [
    {\"name\": \"apiKey\", \"value\": \"$SAB_KEY\"},
    {\"name\": \"host\", \"value\": \"$SAB_URL\"},
    {\"name\": \"port\", \"value\": 8080},
    {\"name\": \"useSsl\", \"value\": false},
    {\"name\": \"tvCategory\", \"value\": \"tv\"}
  ]
}" >/dev/null

# Link SABnzbd to Radarr
curl -s -X POST "$RADARR_URL/api/v3/downloadclient" -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" --data "{
  \"name\": \"SABnzbd\",
  \"enable\": true,
  \"protocol\": \"usenet\",
  \"priority\": 1,
  \"configContract\": \"SabnzbdSettings\",
  \"implementation\": \"Sabnzbd\",
  \"fields\": [
    {\"name\": \"apiKey\", \"value\": \"$SAB_KEY\"},
    {\"name\": \"host\", \"value\": \"$SAB_URL\"},
    {\"name\": \"port\", \"value\": 8080},
    {\"name\": \"useSsl\", \"value\": false},
    {\"name\": \"movieCategory\", \"value\": \"movies\"}
  ]
}" >/dev/null

# Link Prowlarr as indexer for Sonarr & Radarr
for target in sonarr radarr; do
    TARGET_URL_VAR="${target^^}_URL"
    TARGET_KEY_VAR="${target^^}_KEY"
    curl -s -X POST "${!TARGET_URL_VAR}/api/v3/indexer" \
        -H "X-Api-Key: ${!TARGET_KEY_VAR}" \
        -H "Content-Type: application/json" \
        --data "{
      \"name\": \"Prowlarr\",
      \"enable\": true,
      \"protocol\": \"usenet\",
      \"priority\": 1,
      \"configContract\": \"ProwlarrSettings\",
      \"implementation\": \"Prowlarr\",
      \"fields\": [
        {\"name\": \"apiKey\", \"value\": \"$PROWLARR_KEY\"},
        {\"name\": \"host\", \"value\": \"$PROWLARR_URL\"},
        {\"name\": \"port\", \"value\": 9696},
        {\"name\": \"useSsl\", \"value\": false}
      ]
    }" >/dev/null
done

echo "✅ Linked download clients and indexers!"

# Seed indexers in Prowlarr
echo "📡 Seeding indexers in Prowlarr..."
curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
    -H "X-Api-Key: $PROWLARR_KEY" \
    -H "Content-Type: application/json" \
    --data "{
    \"name\": \"NZBGeek\",
    \"enabled\": true,
    \"protocol\": 1,
    \"implementation\": \"Newznab\",
    \"configContract\": \"NewznabSettings\",
    \"fields\": [
      {\"name\": \"baseUrl\", \"value\": \"https://api.nzbgeek.info\"},
      {\"name\": \"apiKey\", \"value\": \"$(grep nzbgeek_api_key terraform.tfvars | awk '{print $3}' | tr -d '\"')\"},
      {\"name\": \"categories\", \"value\": \"5000,5030,5040\"}
    ],
    \"priority\": 25
  }" >/dev/null

echo "✅ Phase B complete $(date)"
