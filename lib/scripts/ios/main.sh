#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() {
  log "ERROR: $1"
  ./lib/scripts/utils/send_email.sh "failure" "iOS build failed: $1"
  exit 1
}
trap 'handle_error "Error occurred at line $LINENO"' ERR

# App Metadata
APP_ID=${APP_ID:-}
WORKFLOW_ID=${WORKFLOW_ID:-}
BRANCH=${BRANCH:-}
VERSION_NAME=${VERSION_NAME:-}
VERSION_CODE=${VERSION_CODE:-}
APP_NAME=${APP_NAME:-}
ORG_NAME=${ORG_NAME:-}
WEB_URL=${WEB_URL:-}
EMAIL_ID=${EMAIL_ID:-}
BUNDLE_ID=${BUNDLE_ID:-}

# Feature Flags
PUSH_NOTIFY=${PUSH_NOTIFY:-"false"}
IS_CHATBOT=${IS_CHATBOT:-"false"}
IS_DOMAIN_URL=${IS_DOMAIN_URL:-"false"}
IS_SPLASH=${IS_SPLASH:-"false"}
IS_PULLDOWN=${IS_PULLDOWN:-"false"}
IS_BOTTOMMENU=${IS_BOTTOMMENU:-"false"}
IS_LOAD_IND=${IS_LOAD_IND:-"false"}
IS_CAMERA=${IS_CAMERA:-"false"}
IS_LOCATION=${IS_LOCATION:-"false"}
IS_MIC=${IS_MIC:-"false"}
IS_NOTIFICATION=${IS_NOTIFICATION:-"false"}
IS_CONTACT=${IS_CONTACT:-"false"}
IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
IS_CALENDAR=${IS_CALENDAR:-"false"}
IS_STORAGE=${IS_STORAGE:-"false"}

# Branding
LOGO_URL=${LOGO_URL:-}
SPLASH_URL=${SPLASH_URL:-}
SPLASH_BG_URL=${SPLASH_BG_URL:-}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-}
SPLASH_TAGLINE=${SPLASH_TAGLINE:-}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-}
SPLASH_ANIMATION=${SPLASH_ANIMATION:-}
SPLASH_DURATION=${SPLASH_DURATION:-}

# Bottom Menu
BOTTOMMENU_ITEMS=${BOTTOMMENU_ITEMS:-}
BOTTOMMENU_BG_COLOR=${BOTTOMMENU_BG_COLOR:-}
BOTTOMMENU_ICON_COLOR=${BOTTOMMENU_ICON_COLOR:-}
BOTTOMMENU_TEXT_COLOR=${BOTTOMMENU_TEXT_COLOR:-}
BOTTOMMENU_FONT=${BOTTOMMENU_FONT:-}
BOTTOMMENU_FONT_SIZE=${BOTTOMMENU_FONT_SIZE:-}
BOTTOMMENU_FONT_BOLD=${BOTTOMMENU_FONT_BOLD:-}
BOTTOMMENU_FONT_ITALIC=${BOTTOMMENU_FONT_ITALIC:-}
BOTTOMMENU_ACTIVE_TAB_COLOR=${BOTTOMMENU_ACTIVE_TAB_COLOR:-}
BOTTOMMENU_ICON_POSITION=${BOTTOMMENU_ICON_POSITION:-}
BOTTOMMENU_VISIBLE_ON=${BOTTOMMENU_VISIBLE_ON:-}

# Firebase
echo "[INFO] Loading Firebase config..."
FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS:-}

# iOS Signing
APPLE_TEAM_ID=${APPLE_TEAM_ID:-}
APNS_KEY_ID=${APNS_KEY_ID:-}
APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL:-}
CERT_PASSWORD=${CERT_PASSWORD:-}
PROFILE_URL=${PROFILE_URL:-}
CERT_CER_URL=${CERT_CER_URL:-}
CERT_KEY_URL=${CERT_KEY_URL:-}
APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-}

chmod +x ./lib/scripts/ios/*.sh || true
chmod +x ./lib/scripts/utils/*.sh || true

log "Starting iOS build for $APP_NAME"

if [ -z "$BUNDLE_ID" ] || [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ]; then
    handle_error "Missing required variables"
fi

# Branding
if [ -f ./lib/scripts/ios/branding.sh ]; then
    log "Running branding script..."
    ./lib/scripts/ios/branding.sh || handle_error "Branding script failed"
fi

# Customization (after branding)
if [ -f ./lib/scripts/ios/customization.sh ]; then
    log "Running customization script..."
    ./lib/scripts/ios/customization.sh || handle_error "Customization script failed"
fi

# Permissions (after customization)
if [ -f ./lib/scripts/ios/permissions.sh ]; then
    log "Running permissions script..."
    ./lib/scripts/ios/permissions.sh || handle_error "Permissions script failed"
fi

# Firebase
if [ -n "$FIREBASE_CONFIG_IOS" ] && [ -f ./lib/scripts/ios/firebase.sh ]; then
    log "Running Firebase script..."
    ./lib/scripts/ios/firebase.sh || handle_error "Firebase script failed"
    if [ -f ios/Runner/GoogleService-Info.plist ]; then
        mkdir -p assets
        cp ios/Runner/GoogleService-Info.plist assets/GoogleService-Info.plist || handle_error "Failed to copy GoogleService-Info.plist to assets"
    fi
fi

# Signing
if [ -f ./lib/scripts/ios/signing.sh ]; then
    log "Running signing script..."
    ./lib/scripts/ios/signing.sh || handle_error "Signing script failed"
fi

log "Building iOS app"
xcodebuild -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath build/Runner.xcarchive \
    archive || handle_error "Archive failed"

log "Exporting IPA"
xcodebuild -exportArchive \
    -archivePath build/Runner.xcarchive \
    -exportOptionsPlist ios/ExportOptions.plist \
    -exportPath build/ios || handle_error "Export failed"

./lib/scripts/utils/send_email.sh "success" "iOS build completed successfully"
log "Build completed successfully"
exit 0 