#!/usr/bin/env bash
set +e # Never fail

LOG_FILE="scripts/fetch-keys.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Phase A: Fetching API keys $(date) ==="

safe_fetch_key() {
    local container=$1 path=$2 pattern=$3
    docker exec "$container" cat "$path" 2>/dev/null | grep "$pattern" | sed -n "s/.*$pattern[\">=]*\\([^\"<]*\\).*/\\1/p" || true
}

update_tfvars_key() {
    local key_name=$1 key_value=$2
    if grep -q "$key_name" terraform.tfvars; then
        sed -i "s|$key_name.*|$key_name  = \"$key_value\"|" terraform.tfvars
    else
        echo "$key_name  = \"$key_value\"" >>terraform.tfvars
    fi
}

fetch_and_write() {
    local name=$1 container=$2 config=$3 pattern=$4 tfvar_key=$5
    echo "🔍 Checking $name for API key..."
    KEY=$(safe_fetch_key "$container" "$config" "$pattern")
    if [ -n "$KEY" ]; then
        echo "✅ $name key detected: $KEY"
        update_tfvars_key "$tfvar_key" "$KEY"
    else
        echo "⚠️ $name key not ready yet (will populate later)"
    fi
}

fetch_and_write "Sonarr" "sonarr" "/config/config.xml" "ApiKey" "sonarr_api_key"
fetch_and_write "Radarr" "radarr" "/config/config.xml" "ApiKey" "radarr_api_key"
fetch_and_write "Prowlarr" "prowlarr" "/config/config.xml" "ApiKey" "prowlarr_api_key"

SAB_KEY=$(docker exec sabnzbd grep "api_key" /config/sabnzbd.ini 2>/dev/null | cut -d' ' -f3 || true)
if [ -n "$SAB_KEY" ]; then
    echo "✅ SABnzbd key detected: $SAB_KEY"
    update_tfvars_key "sabnzbd_api_key" "$SAB_KEY"
else
    echo "⚠️ SABnzbd key not ready yet"
fi

echo "=== Phase A complete $(date) ==="
exit 0
