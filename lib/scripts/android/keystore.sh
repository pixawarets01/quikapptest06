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
  log "Downloading keystore from $KEY_STORE_URL"
  curl -L "$KEY_STORE_URL" -o android/app/keystore.jks || handle_error "Failed to download keystore"
  
  log "Verifying keystore integrity..."
  # Test keystore access
  if command -v keytool >/dev/null 2>&1; then
    log "Listing keystore contents:"
    keytool -list -v -keystore android/app/keystore.jks -storepass "$CM_KEYSTORE_PASSWORD" | head -20 || true
    
    log "Getting certificate fingerprint for alias '$CM_KEY_ALIAS':"
    keytool -list -v -alias "$CM_KEY_ALIAS" -keystore android/app/keystore.jks -storepass "$CM_KEYSTORE_PASSWORD" | grep -A 5 -B 5 "SHA1:" || true
    
    log "Expected Google Play fingerprint: SHA1: 15:43:4B:69:09:E9:93:62:85:C1:EC:BE:F3:17:CC:BD:EC:F7:EC:5E"
    log "Current keystore fingerprint will be shown above ⬆️"
  else
    log "keytool not available for fingerprint verification"
  fi
  
  log "Creating keystore.properties"
  cat > android/app/keystore.properties <<EOF
storeFile=keystore.jks
storePassword=$CM_KEYSTORE_PASSWORD
keyAlias=$CM_KEY_ALIAS
keyPassword=$CM_KEY_PASSWORD
EOF

  log "Keystore configuration:"
  log "- Store file: android/app/keystore.jks"
  log "- Key alias: $CM_KEY_ALIAS"
  log "- Store password: [PROTECTED]"
  log "- Key password: [PROTECTED]"
  
else
  log "No keystore URL provided; skipping keystore setup"
fi

log "Keystore configuration completed successfully"
exit 0 