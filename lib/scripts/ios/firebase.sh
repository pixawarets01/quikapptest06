#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS:-}

log "Starting Firebase configuration for iOS"
if [ -n "$FIREBASE_CONFIG_IOS" ]; then
  log "Downloading Firebase configuration from $FIREBASE_CONFIG_IOS"
  curl -L "$FIREBASE_CONFIG_IOS" -o ios/Runner/GoogleService-Info.plist || handle_error "Failed to download Firebase config"
  mkdir -p assets
  cp ios/Runner/GoogleService-Info.plist assets/GoogleService-Info.plist || handle_error "Failed to copy GoogleService-Info.plist to assets"
else
  log "No Firebase config URL provided; skipping."
fi
log "Firebase configuration completed successfully"
exit 0 