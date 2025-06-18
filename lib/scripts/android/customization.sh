#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

PKG_NAME=${PKG_NAME:-}
APP_NAME=${APP_NAME:-}

log "Starting Android app customization"

# Update package name in build.gradle
if [ -n "$PKG_NAME" ]; then
  log "Updating package name to $PKG_NAME"
  if [ -f android/app/build.gradle ]; then
    sed -i.bak "s/applicationId .*/applicationId \"$PKG_NAME\"/" android/app/build.gradle
  fi
fi

# Update app name in AndroidManifest.xml
if [ -n "$APP_NAME" ]; then
  log "Updating app name to $APP_NAME"
  if [ -f android/app/src/main/AndroidManifest.xml ]; then
    sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml
  fi
fi

# Update app icon if logo exists in assets
if [ -f assets/images/logo.png ]; then
  log "Updating app icon from assets/images/logo.png"
  mkdir -p android/app/src/main/res/mipmap-hdpi
  mkdir -p android/app/src/main/res/mipmap-mdpi
  mkdir -p android/app/src/main/res/mipmap-xhdpi
  mkdir -p android/app/src/main/res/mipmap-xxhdpi
  mkdir -p android/app/src/main/res/mipmap-xxxhdpi
  
  # Copy logo to all density folders (you may want to resize these appropriately)
  cp assets/images/logo.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
fi

log "Android app customization completed successfully"
exit 0 