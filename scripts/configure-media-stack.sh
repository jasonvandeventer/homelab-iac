#!/usr/bin/env bash
set -e

# ===============================================
# configure-media-stack.sh
# Auto-links Sonarr/Radarr/SABnzbd/Prowlarr
# Safe to re-run + Terraform output + auto-fetch keys
# ===============================================

# ===========
# LOGGING COLORS
# ===========
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }

# ===========
# LOG FILE SETUP
# ===========
LOG_FILE="scripts/configure-media-stack.log"
mkdir -p scripts
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Starting media stack auto-config: $(date) ==="

# ===========
# ARGUMENTS FROM TERRAFORM
# ===========
while [[ $# -gt 0 ]]; do
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
NZBGEEK_API_KEY="${NZBGEEK_API_KEY:-$(terraform output -raw nzbgeek_api_key || true)}"

# ===========
# HELPERS
# ===========

wait_for_config_file() {
	local container=$1
	local path=$2
	log "⏳ Waiting for $container config at $path..."
	until docker exec "$container" test -f "$path"; do
		echo "  $container config not ready yet, retrying in 5s..."
		sleep 5
	done
	ok "$container config detected."
}

fetch_api_key() {
	local container=$1
	local config_path=$2
	local pattern=$3
	log "🔍 Fetching API key for $container..."
	docker exec "$container" cat "$config_path" | grep "$pattern" | sed -n "s/.*$pattern[\">=]*\\([^\"<]*\\).*/\\1/p"
}

update_tfvars_key() {
	local key_name=$1
	local key_value=$2
	if grep -q "$key_name" terraform.tfvars; then
		sed -i "s|$key_name.*|$key_name  = \"$key_value\"|" terraform.tfvars
	else
		echo "$key_name  = \"$key_value\"" >>terraform.tfvars
	fi
}

wait_for_api() {
  local name=$1
  local url=$2
  local container=$3
  local config_path=$4
  local pattern=$5
  local key_var_name=$6

  echo "⏳ Waiting for $name API at $url..."
  local retries=0

  while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" -H "X-Api-Key: ${!key_var_name}" || true)

    if [[ "$STATUS" == "200" ]]; then
      echo "✅ $name API is ready!"
      break
    elif [[ "$STATUS" == "401" ]]; then
      echo "⚠️ $name API returned 401 Unauthorized → refreshing API key..."
      NEW_KEY=$(docker exec "$container" cat "$config_path" | grep "$pattern" | sed -n "s/.*$pattern[\">=]*\\([^\"<]*\\).*/\\1/p")
      echo "✅ New $name API key detected: $NEW_KEY"

      # Update tfvars + key var
      update_tfvars_key "${key_var_name,,}" "$NEW_KEY"
      eval "$key_var_name=\"$NEW_KEY\""

      echo "🔄 Retrying $name API with updated key..."
      sleep 3
    else
      echo "  $name not ready yet (status $STATUS), retrying in 5s..."
      sleep 5
    fi

    retries=$((retries+1))
    if [[ $retries -gt 60 ]]; then
      echo "❌ Timeout waiting for $name API!"
      exit 1
    fi
  done
}


# ===========
# STEP 1: WAIT FOR CONFIG FILES
# ===========
wait_for_config_file "sonarr" "/config/config.xml"
wait_for_config_file "radarr" "/config/config.xml"
wait_for_config_file "prowlarr" "/config/config.xml"
wait_for_config_file "sabnzbd" "/config/sabnzbd.ini"

# ===========
# STEP 2: AUTO-FETCH API KEYS IF EMPTY/PLACEHOLDER
# ===========
if [ -z "$SONARR_KEY" ] || [ "$SONARR_KEY" = "CHANGEME" ]; then
	SONARR_KEY=$(fetch_api_key "sonarr" "/config/config.xml" "ApiKey")
	ok "Sonarr API key detected: $SONARR_KEY"
	update_tfvars_key "sonarr_api_key" "$SONARR_KEY"
fi

if [ -z "$RADARR_KEY" ] || [ "$RADARR_KEY" = "CHANGEME" ]; then
	RADARR_KEY=$(fetch_api_key "radarr" "/config/config.xml" "ApiKey")
	ok "Radarr API key detected: $RADARR_KEY"
	update_tfvars_key "radarr_api_key" "$RADARR_KEY"
fi

if [ -z "$PROWLARR_KEY" ] || [ "$PROWLARR_KEY" = "CHANGEME" ]; then
	PROWLARR_KEY=$(fetch_api_key "prowlarr" "/config/config.xml" "ApiKey")
	ok "Prowlarr API key detected: $PROWLARR_KEY"
	update_tfvars_key "prowlarr_api_key" "$PROWLARR_KEY"
fi

if [ -z "$SAB_KEY" ] || [ "$SAB_KEY" = "CHANGEME" ]; then
	SAB_KEY=$(docker exec sabnzbd grep "api_key" /config/sabnzbd.ini | cut -d' ' -f3)
	ok "SABnzbd API key detected: $SAB_KEY"
	update_tfvars_key "sabnzbd_api_key" "$SAB_KEY"
fi

# ===========
# STEP 3: WAIT FOR APIS TO RESPOND
# ===========
wait_for_api "Sonarr" "${SONARR_URL}/api/v3/system/status" "$SONARR_KEY"
wait_for_api "Radarr" "${RADARR_URL}/api/v3/system/status" "$RADARR_KEY"
wait_for_api "Prowlarr" "${PROWLARR_URL}/api/v1/system/status" "$PROWLARR_KEY"

# ===========
# STEP 4: AUTO-CONFIGURE SONARR & RADARR WITH SABNZBD + PROWLARR
# ===========
log "🔄 Auto-configuring Sonarr & Radarr with SABnzbd + Prowlarr..."

for app in Sonarr Radarr; do
	URL_VAR="${app^^}_URL"
	KEY_VAR="${app^^}_KEY"
	log "➡ Adding SABnzbd to $app..."
	curl -s -X POST "${!URL_VAR}/api/v3/downloadclient" \
		-H "X-Api-Key: ${!KEY_VAR}" \
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
        {\"name\": \"${app,,}Category\", \"value\": \"${app,,}\"}
      ]
    }" >/dev/null && ok "$app linked to SABnzbd"

	log "➡ Linking Prowlarr as indexer for $app..."
	curl -s -X POST "${!URL_VAR}/api/v3/indexer" \
		-H "X-Api-Key: ${!KEY_VAR}" \
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
    }" >/dev/null && ok "$app linked to Prowlarr"
done

# ===========
# STEP 5: SEED PROWLARR INDEXERS
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
      {\"name\": \"apiKey\", \"value\": \"${NZBGEEK_API_KEY}\"},
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
echo "=== Auto-config completed at $(date) ==="
