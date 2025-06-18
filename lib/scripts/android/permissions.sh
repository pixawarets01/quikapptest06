#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Permission flags
IS_CAMERA=${IS_CAMERA:-"false"}
IS_LOCATION=${IS_LOCATION:-"false"}
IS_MIC=${IS_MIC:-"false"}
IS_NOTIFICATION=${IS_NOTIFICATION:-"false"}
IS_CONTACT=${IS_CONTACT:-"false"}
IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
IS_CALENDAR=${IS_CALENDAR:-"false"}
IS_STORAGE=${IS_STORAGE:-"false"}

log "Starting Android permissions configuration"

MANIFEST_PATH="android/app/src/main/AndroidManifest.xml"

if [ -f "$MANIFEST_PATH" ]; then
  log "Updating AndroidManifest.xml with permissions"
  
  # Create backup
  cp "$MANIFEST_PATH" "$MANIFEST_PATH.bak"
  
  # Create new manifest with permissions
  cat > "$MANIFEST_PATH" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
EOF

  # Add permissions based on flags
  if [ "$IS_CAMERA" = "true" ]; then
    log "Adding camera permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
EOF
  fi

  if [ "$IS_LOCATION" = "true" ]; then
    log "Adding location permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
EOF
  fi

  if [ "$IS_MIC" = "true" ]; then
    log "Adding microphone permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-feature android:name="android.hardware.microphone" android:required="false" />
EOF
  fi

  if [ "$IS_NOTIFICATION" = "true" ]; then
    log "Adding notification permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />
EOF
  fi

  if [ "$IS_CONTACT" = "true" ]; then
    log "Adding contact permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.READ_CONTACTS" />
    <uses-permission android:name="android.permission.WRITE_CONTACTS" />
    <uses-permission android:name="android.permission.GET_ACCOUNTS" />
EOF
  fi

  if [ "$IS_BIOMETRIC" = "true" ]; then
    log "Adding biometric permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />
EOF
  fi

  if [ "$IS_CALENDAR" = "true" ]; then
    log "Adding calendar permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />
EOF
  fi

  if [ "$IS_STORAGE" = "true" ]; then
    log "Adding storage permissions"
    cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
EOF
  fi

  # Add Internet permission (always needed for Flutter apps)
  cat >> "$MANIFEST_PATH" << 'EOF'
    <uses-permission android:name="android.permission.INTERNET" />
EOF

  # Read the rest of the original manifest and append it
  awk '/<manifest/,/<\/manifest>/ { if ($0 ~ /<manifest/) next; print }' "$MANIFEST_PATH.bak" >> "$MANIFEST_PATH"

  # Clean up backup
  rm "$MANIFEST_PATH.bak" || true
else
  log "AndroidManifest.xml not found, skipping permissions update"
fi

log "Android permissions configuration completed successfully"
exit 0 