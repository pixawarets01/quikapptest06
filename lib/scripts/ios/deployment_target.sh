#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "Updating iOS deployment target to 13.0 for Firebase compatibility..."

# Update Xcode project file
if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
    log "Updating Xcode project deployment target..."
    sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9][0-9]*\.[0-9]/IPHONEOS_DEPLOYMENT_TARGET = 13.0/g' ios/Runner.xcodeproj/project.pbxproj
    log "Xcode project updated"
else
    log "Warning: Xcode project file not found"
fi

# Update Podfile
if [ -f ios/Podfile ]; then
    log "Ensuring Podfile has correct platform..."
    if grep -q "platform :ios" ios/Podfile; then
        sed -i.bak 's/platform :ios, .*/platform :ios, '\''13.0'\''/g' ios/Podfile
    else
        # Add platform line if it doesn't exist
        sed -i.bak '1i\
platform :ios, '\''13.0'\''
' ios/Podfile
    fi
    log "Podfile updated"
else
    log "Warning: Podfile not found"
fi

# Update AppFrameworkInfo.plist
if [ -f ios/Flutter/AppFrameworkInfo.plist ]; then
    log "Updating AppFrameworkInfo.plist..."
    sed -i.bak 's/<string>[0-9][0-9]*\.0<\/string>/<string>13.0<\/string>/g' ios/Flutter/AppFrameworkInfo.plist
    log "AppFrameworkInfo.plist updated"
else
    log "Warning: AppFrameworkInfo.plist not found"
fi

# Clean up backup files
rm -f ios/Runner.xcodeproj/project.pbxproj.bak || true
rm -f ios/Podfile.bak || true
rm -f ios/Flutter/AppFrameworkInfo.plist.bak || true

log "iOS deployment target update completed" 