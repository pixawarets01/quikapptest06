#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

FIREBASE_CONFIG_ANDROID=${FIREBASE_CONFIG_ANDROID:-}

log "Starting Firebase configuration"
if [ -n "$FIREBASE_CONFIG_ANDROID" ]; then
  log "Downloading Firebase configuration from $FIREBASE_CONFIG_ANDROID"
  curl -L "$FIREBASE_CONFIG_ANDROID" -o android/app/google-services.json || handle_error "Failed to download Firebase config"
else
  log "No Firebase config URL provided; skipping."
fi
log "Firebase configuration completed successfully"
exit 0 