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

log "Starting branding process for $APP_NAME (iOS)"

# Ensure directories exist
mkdir -p ios/Runner/Assets.xcassets/AppIcon.appiconset
mkdir -p ios/Runner/Assets.xcassets/Splash.imageset
mkdir -p ios/Runner/Assets.xcassets/SplashBackground.imageset
mkdir -p assets/images

if [ -n "$LOGO_URL" ]; then
  log "Downloading app icon from $LOGO_URL"
  curl -L "$LOGO_URL" -o ios/Runner/Assets.xcassets/AppIcon.appiconset/logo.png || handle_error "Failed to download app icon"
  cp ios/Runner/Assets.xcassets/AppIcon.appiconset/logo.png assets/images/logo.png || handle_error "Failed to copy app icon to assets/images/logo.png"
fi

if [ -n "$SPLASH_URL" ]; then
  log "Downloading splash image from $SPLASH_URL"
  curl -L "$SPLASH_URL" -o assets/images/splash.png || handle_error "Failed to download splash image"
  cp assets/images/splash.png ios/Runner/Assets.xcassets/Splash.imageset/splash.png || handle_error "Failed to copy splash image to Splash.imageset"
fi

if [ -n "$SPLASH_BG_URL" ]; then
  log "Downloading splash background from $SPLASH_BG_URL"
  curl -L "$SPLASH_BG_URL" -o assets/images/splash_bg.png || handle_error "Failed to download splash background"
  cp assets/images/splash_bg.png ios/Runner/Assets.xcassets/SplashBackground.imageset/splash_bg.png || handle_error "Failed to copy splash background to SplashBackground.imageset"
fi

log "Branding process completed successfully (iOS)"
exit 0 