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
  
  # Verify keystore file was downloaded
  if [ ! -f android/app/keystore.jks ]; then
    handle_error "Keystore file was not created after download"
  fi
  
  # Check file size (should be > 1KB for a valid keystore)
  KEYSTORE_SIZE=$(stat -f%z android/app/keystore.jks 2>/dev/null || stat -c%s android/app/keystore.jks 2>/dev/null || echo "0")
  if [ "$KEYSTORE_SIZE" -lt 1024 ]; then
    log "Warning: Keystore file seems too small ($KEYSTORE_SIZE bytes). This might be an error page or invalid file."
  fi
  
  log "Verifying keystore integrity..."
  # Test keystore access
  if command -v keytool >/dev/null 2>&1; then
    log "Listing keystore contents:"
    keytool -list -v -keystore android/app/keystore.jks -storepass "$CM_KEYSTORE_PASSWORD" | head -20 || handle_error "Failed to access keystore with provided password"
    
    log "Getting certificate fingerprint for alias '$CM_KEY_ALIAS':"
    FINGERPRINT_OUTPUT=$(keytool -list -v -alias "$CM_KEY_ALIAS" -keystore android/app/keystore.jks -storepass "$CM_KEYSTORE_PASSWORD" 2>/dev/null | grep "SHA1:" || echo "")
    
    if [ -n "$FINGERPRINT_OUTPUT" ]; then
      log "📋 Certificate fingerprint for Google Play Console:"
      echo "$FINGERPRINT_OUTPUT" | while read -r line; do
        log "   $line"
      done
      log "ℹ️  Use this fingerprint in your Google Play Console app signing configuration"
    else
      log "Warning: Could not get fingerprint for alias '$CM_KEY_ALIAS'"
    fi
  else
    log "keytool not available for fingerprint verification"
  fi
  
  log "Creating keystore.properties for Gradle"
  cat > android/app/keystore.properties <<EOF
storeFile=keystore.jks
storePassword=$CM_KEYSTORE_PASSWORD
keyAlias=$CM_KEY_ALIAS
keyPassword=$CM_KEY_PASSWORD
EOF

  # Verify keystore.properties was created
  if [ ! -f android/app/keystore.properties ]; then
    handle_error "Failed to create keystore.properties file"
  fi

  log "Keystore configuration:"
  log "- Store file: android/app/keystore.jks ($(ls -lh android/app/keystore.jks | awk '{print $5}'))"
  log "- Key alias: $CM_KEY_ALIAS"
  log "- Store password: [PROTECTED]"
  log "- Key password: [PROTECTED]"
  log "- Properties file: android/app/keystore.properties"
  
  # Validate Gradle can read the keystore properties
  log "Validating keystore.properties format..."
  if grep -q "storeFile=" android/app/keystore.properties && \
     grep -q "storePassword=" android/app/keystore.properties && \
     grep -q "keyAlias=" android/app/keystore.properties && \
     grep -q "keyPassword=" android/app/keystore.properties; then
    log "✅ Keystore properties file is valid"
  else
    handle_error "Invalid keystore.properties format"
  fi
  
else
  log "No keystore URL provided; skipping keystore setup"
  log "⚠️  WARNING: Without keystore, the build will use DEBUG SIGNING"
  log "⚠️  WARNING: Debug-signed APKs cannot be uploaded to Google Play Store"
fi

log "Keystore configuration completed successfully"
exit 0 