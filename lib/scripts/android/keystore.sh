#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

KEY_STORE_URL=${KEY_STORE_URL:-}
CM_KEYSTORE_PASSWORD=${CM_KEYSTORE_PASSWORD:-}
CM_KEY_ALIAS=${CM_KEY_ALIAS:-}
CM_KEY_PASSWORD=${CM_KEY_PASSWORD:-}

log "Starting keystore configuration"
if [ -n "$KEY_STORE_URL" ]; then
  log "Creating keystore.properties"
  cat > android/app/keystore.properties <<EOF
storeFile=keystore.jks
storePassword=$CM_KEYSTORE_PASSWORD
keyAlias=$CM_KEY_ALIAS
keyPassword=$CM_KEY_PASSWORD
EOF
  log "Downloading keystore from $KEY_STORE_URL"
  curl -L "$KEY_STORE_URL" -o android/app/keystore.jks || handle_error "Failed to download keystore"
else
  log "No keystore URL provided; skipping."
fi
log "Keystore configuration completed successfully"
exit 0 