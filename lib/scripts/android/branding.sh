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

# Ensure directories exist
mkdir -p android/app/src/main/res/mipmap
mkdir -p android/app/src/main/res/drawable
mkdir -p assets/images


if [ -z "$LOGO_URL" ]; then
  echo "LOGO_URL is empty or null."
  # Your commands here if LOGO_URL is empty
  curl -L "${WEB_URL}/favicon.ico" -o assets/images/logo.png || handle_error "Failed to download favicon for ${WEB_URL}"
else
  echo "LOGO_URL has a value: $LOGO_URL"
  # Your commands here if LOGO_URL has a value
  log "Downloading app icon from $LOGO_URL"
    curl -L "$LOGO_URL" -o android/app/src/main/res/mipmap/ic_launcher.png || handle_error "Failed to download app icon"
    curl -L "$LOGO_URL" -o assets/images/logo.png || handle_error "Failed to download app icon"
fi

#if [ -n "$LOGO_URL" ]; then
#  log "Downloading app icon from $LOGO_URL"
#  curl -L "$LOGO_URL" -o android/app/src/main/res/mipmap/ic_launcher.png || handle_error "Failed to download app icon"
#  curl -L "$LOGO_URL" -o assets/images/logo.png || handle_error "Failed to download app icon"
##  cp android/app/src/main/res/mipmap/ic_launcher.png assets/images/logo.png || handle_error "Failed to copy app icon to assets/images/logo.png"
#fi

if [ -n "$SPLASH_URL" ]; then
  log "Downloading splash image from $SPLASH_URL"
  curl -L "$SPLASH_URL" -o assets/images/splash.png || handle_error "Failed to download splash image"
  cp assets/images/splash.png android/app/src/main/res/drawable/splash.png || handle_error "Failed to copy splash image to drawable"
else
  log "Use Logo as splash image"
  cp assets/images/logo.png assets/images/splash.png || handle_error "Failed to download splash image from Logo"
fi

if [ -n "$SPLASH_BG_URL" ]; then
  log "Downloading splash background from $SPLASH_BG_URL"
  curl -L "$SPLASH_BG_URL" -o assets/images/splash_bg.png || handle_error "Failed to download splash background"
  cp assets/images/splash_bg.png android/app/src/main/res/drawable/splash_bg.png || handle_error "Failed to copy splash background to drawable"
fi

log "Branding process completed successfully"
exit 0 