#!/bin/bash
# Dynamic variable loader for QuikApp workflows
set -euo pipefail

log() {
  echo "[VARS][$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 1. Try to fetch from API (requires curl and jq)
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  log "Fetching variables from API: $API_ENDPOINT"
  VARS_JSON=$(curl -s "$API_ENDPOINT")
  if [ -n "$VARS_JSON" ]; then
    # Example: export APP_ID, APP_NAME, etc. from JSON
    export APP_ID=$(echo "$VARS_JSON" | jq -r '.APP_ID // empty')
    export APP_NAME=$(echo "$VARS_JSON" | jq -r '.APP_NAME // empty')
    export PKG_NAME=$(echo "$VARS_JSON" | jq -r '.PKG_NAME // empty')
    export VERSION_NAME=$(echo "$VARS_JSON" | jq -r '.VERSION_NAME // empty')
    export VERSION_CODE=$(echo "$VARS_JSON" | jq -r '.VERSION_CODE // empty')
    export OUTPUT_DIR=$(echo "$VARS_JSON" | jq -r '.OUTPUT_DIR // empty')
    # Add more as needed
  else
    log "[WARN] API returned no data. Falling back to environment variables."
  fi
else
  log "[WARN] curl or jq not available. Falling back to environment variables."
fi 