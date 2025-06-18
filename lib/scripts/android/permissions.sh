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
PERMISSIONS=""

# Build permissions list based on feature flags
if [ "$IS_CAMERA" = "true" ]; then
  log "Adding camera permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.CAMERA\" />
    <uses-feature android:name=\"android.hardware.camera\" android:required=\"false\" />
    <uses-feature android:name=\"android.hardware.camera.autofocus\" android:required=\"false\" />"
fi

if [ "$IS_LOCATION" = "true" ]; then
  log "Adding location permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.ACCESS_FINE_LOCATION\" />
    <uses-permission android:name=\"android.permission.ACCESS_COARSE_LOCATION\" />
    <uses-permission android:name=\"android.permission.ACCESS_BACKGROUND_LOCATION\" />"
fi

if [ "$IS_MIC" = "true" ]; then
  log "Adding microphone permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.RECORD_AUDIO\" />
    <uses-feature android:name=\"android.hardware.microphone\" android:required=\"false\" />"
fi

if [ "$IS_NOTIFICATION" = "true" ]; then
  log "Adding notification permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.POST_NOTIFICATIONS\" />
    <uses-permission android:name=\"android.permission.WAKE_LOCK\" />
    <uses-permission android:name=\"android.permission.VIBRATE\" />"
fi

if [ "$IS_CONTACT" = "true" ]; then
  log "Adding contact permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.READ_CONTACTS\" />
    <uses-permission android:name=\"android.permission.WRITE_CONTACTS\" />
    <uses-permission android:name=\"android.permission.GET_ACCOUNTS\" />"
fi

if [ "$IS_BIOMETRIC" = "true" ]; then
  log "Adding biometric permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.USE_BIOMETRIC\" />
    <uses-permission android:name=\"android.permission.USE_FINGERPRINT\" />"
fi

if [ "$IS_CALENDAR" = "true" ]; then
  log "Adding calendar permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.READ_CALENDAR\" />
    <uses-permission android:name=\"android.permission.WRITE_CALENDAR\" />"
fi

if [ "$IS_STORAGE" = "true" ]; then
  log "Adding storage permissions"
  PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.READ_EXTERNAL_STORAGE\" />
    <uses-permission android:name=\"android.permission.WRITE_EXTERNAL_STORAGE\" />
    <uses-permission android:name=\"android.permission.MANAGE_EXTERNAL_STORAGE\" />
    <uses-permission android:name=\"android.permission.READ_MEDIA_IMAGES\" />
    <uses-permission android:name=\"android.permission.READ_MEDIA_VIDEO\" />
    <uses-permission android:name=\"android.permission.READ_MEDIA_AUDIO\" />"
fi

# Add Internet permission (always needed for Flutter apps)
PERMISSIONS="$PERMISSIONS
    <uses-permission android:name=\"android.permission.INTERNET\" />"

# Update AndroidManifest.xml with permissions
if [ -f "$MANIFEST_PATH" ]; then
  log "Updating AndroidManifest.xml with permissions"
  
  # Create backup
  cp "$MANIFEST_PATH" "$MANIFEST_PATH.bak"
  
  # Add permissions after <manifest> tag
  sed -i.tmp "/<manifest/a\\
$PERMISSIONS" "$MANIFEST_PATH"
  
  rm "$MANIFEST_PATH.tmp" || true
else
  log "AndroidManifest.xml not found, skipping permissions update"
fi

log "Android permissions configuration completed successfully"
exit 0 