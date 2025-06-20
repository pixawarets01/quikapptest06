#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS:-}
PUSH_NOTIFY=${PUSH_NOTIFY:-"false"}

log "Starting Firebase configuration for iOS"

if [ "$PUSH_NOTIFY" = "true" ]; then
    log "🔔 Push notifications enabled"
    
    if [ -z "$FIREBASE_CONFIG_IOS" ]; then
        handle_error "FIREBASE_CONFIG_IOS is required when PUSH_NOTIFY is true"
    fi
    
    # Download and install Firebase config
    log "📥 Downloading Firebase configuration from $FIREBASE_CONFIG_IOS"
    curl -L "$FIREBASE_CONFIG_IOS" -o ios/Runner/GoogleService-Info.plist || handle_error "Failed to download Firebase config"
    mkdir -p assets
    cp ios/Runner/GoogleService-Info.plist assets/GoogleService-Info.plist || handle_error "Failed to copy GoogleService-Info.plist to assets"
    
    # Update Info.plist for push notifications
    log "📝 Configuring push notification capabilities"
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" ios/Runner/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes: string 'remote-notification'" ios/Runner/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :FirebaseAppDelegateProxyEnabled bool false" ios/Runner/Info.plist 2>/dev/null || true
    
    # Update Podfile for Firebase
    log "📦 Adding Firebase dependencies"
    if ! grep -q "pod 'Firebase/Messaging'" ios/Podfile; then
        cat >> ios/Podfile << 'EOF'

# Firebase dependencies
pod 'Firebase/Core'
pod 'Firebase/Messaging'
EOF
    fi
    
    log "✅ Firebase and push notifications configured successfully"
else
    log "⏭️ Push notifications disabled, skipping Firebase setup"
    
    # Remove Firebase config if it exists
    rm -f ios/Runner/GoogleService-Info.plist assets/GoogleService-Info.plist 2>/dev/null || true
    
    # Remove Firebase from Podfile if it exists
    if [ -f ios/Podfile ]; then
        sed -i.bak '/pod .Firebase\/Core./d' ios/Podfile
        sed -i.bak '/pod .Firebase\/Messaging./d' ios/Podfile
        rm -f ios/Podfile.bak
    fi
    
    # Remove background modes from Info.plist if they exist
    if [ -f ios/Runner/Info.plist ]; then
        /usr/libexec/PlistBuddy -c "Delete :UIBackgroundModes" ios/Runner/Info.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Delete :FirebaseAppDelegateProxyEnabled" ios/Runner/Info.plist 2>/dev/null || true
    fi
    
    log "✅ Firebase and push notifications disabled successfully"
fi

exit 0 