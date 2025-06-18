#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

BUNDLE_ID=${BUNDLE_ID:-}
APP_NAME=${APP_NAME:-}

log "Starting iOS app customization"

# Update bundle ID in Info.plist
if [ -n "$BUNDLE_ID" ]; then
  log "Updating bundle ID to $BUNDLE_ID"
  if [ -f ios/Runner/Info.plist ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist || true
  fi
fi

# Update app name in Info.plist
if [ -n "$APP_NAME" ]; then
  log "Updating app name to $APP_NAME"
  if [ -f ios/Runner/Info.plist ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" ios/Runner/Info.plist || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" ios/Runner/Info.plist || true
  fi
fi

# Update app icon if logo exists in assets
if [ -f assets/images/logo.png ]; then
  log "Updating app icon from assets/images/logo.png"
  mkdir -p ios/Runner/Assets.xcassets/AppIcon.appiconset
  
  # Copy logo to AppIcon (you may want to resize these appropriately)
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
  cp assets/images/logo.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
fi

log "iOS app customization completed successfully"
exit 0 