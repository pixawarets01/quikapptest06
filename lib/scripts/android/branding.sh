#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Branding vars
LOGO_URL=${LOGO_URL:-}
SPLASH_URL=${SPLASH_URL:-}
SPLASH_BG_URL=${SPLASH_BG_URL:-}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-}
SPLASH_TAGLINE=${SPLASH_TAGLINE:-}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-}
SPLASH_ANIMATION=${SPLASH_ANIMATION:-}
SPLASH_DURATION=${SPLASH_DURATION:-}

log "Starting branding process for $APP_NAME"

if [ -n "$LOGO_URL" ]; then
  log "Downloading app icon from $LOGO_URL"
  curl -L "$LOGO_URL" -o android/app/src/main/res/mipmap/ic_launcher.png || handle_error "Failed to download app icon"
fi

if [ -n "$SPLASH_URL" ]; then
  log "Downloading splash image from $SPLASH_URL"
  curl -L "$SPLASH_URL" -o android/app/src/main/res/drawable/splash.png || handle_error "Failed to download splash image"
fi

if [ -n "$SPLASH_BG_URL" ]; then
  log "Downloading splash background from $SPLASH_BG_URL"
  curl -L "$SPLASH_BG_URL" -o android/app/src/main/res/drawable/splash_bg.png || handle_error "Failed to download splash background"
fi

log "Branding process completed successfully"
exit 0 