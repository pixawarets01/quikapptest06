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

log "Starting iOS permissions configuration"

PLIST_PATH="ios/Runner/Info.plist"

if [ ! -f "$PLIST_PATH" ]; then
  log "Info.plist not found, skipping permissions update"
  exit 0
fi

# Create backup
cp "$PLIST_PATH" "$PLIST_PATH.bak"

# Add permissions based on feature flags
if [ "$IS_CAMERA" = "true" ]; then
  log "Adding camera permissions"
  /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'This app needs access to camera to capture photos and videos.'" "$PLIST_PATH" 2>/dev/null || true
fi

if [ "$IS_LOCATION" = "true" ]; then
  log "Adding location permissions"
  /usr/libexec/PlistBuddy -c "Add :NSLocationWhenInUseUsageDescription string 'This app needs access to location when in use.'" "$PLIST_PATH" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSLocationAlwaysAndWhenInUseUsageDescription string 'This app needs access to location always and when in use.'" "$PLIST_PATH" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSLocationAlwaysUsageDescription string 'This app needs access to location always.'" "$PLIST_PATH" 2>/dev/null || true
fi

if [ "$IS_MIC" = "true" ]; then
  log "Adding microphone permissions"
  /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'This app needs access to microphone to record audio.'" "$PLIST_PATH" 2>/dev/null || true
fi

if [ "$IS_CONTACT" = "true" ]; then
  log "Adding contact permissions"
  /usr/libexec/PlistBuddy -c "Add :NSContactsUsageDescription string 'This app needs access to contacts to manage contact information.'" "$PLIST_PATH" 2>/dev/null || true
fi

if [ "$IS_BIOMETRIC" = "true" ]; then
  log "Adding biometric permissions"
  /usr/libexec/PlistBuddy -c "Add :NSFaceIDUsageDescription string 'This app uses Face ID for secure authentication.'" "$PLIST_PATH" 2>/dev/null || true
fi

if [ "$IS_CALENDAR" = "true" ]; then
  log "Adding calendar permissions"
  /usr/libexec/PlistBuddy -c "Add :NSCalendarsUsageDescription string 'This app needs access to calendar to manage events.'" "$PLIST_PATH" 2>/dev/null || true
fi

if [ "$IS_STORAGE" = "true" ]; then
  log "Adding storage permissions"
  /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'This app needs access to photo library to save and retrieve images.'" "$PLIST_PATH" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryAddUsageDescription string 'This app needs access to save photos to your photo library.'" "$PLIST_PATH" 2>/dev/null || true
fi

# Always add network permission for Flutter apps
log "Adding network permissions"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$PLIST_PATH" 2>/dev/null || true

log "iOS permissions configuration completed successfully"
exit 0 