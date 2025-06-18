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
USER_NAME=${USER_NAME:-}

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
PROFILE_TYPE=${PROFILE_TYPE:-"app-store"}
APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-}

# Email
EMAIL_SMTP_SERVER=${EMAIL_SMTP_SERVER:-}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT:-}
EMAIL_SMTP_USER=${EMAIL_SMTP_USER:-}
EMAIL_SMTP_PASS=${EMAIL_SMTP_PASS:-}
ENABLE_EMAIL_NOTIFICATIONS=${ENABLE_EMAIL_NOTIFICATIONS:-"true"}

# Export variables for email script
export ENABLE_EMAIL_NOTIFICATIONS

chmod +x ./lib/scripts/ios/*.sh || true
chmod +x ./lib/scripts/utils/*.sh || true

log "Starting iOS build for $APP_NAME"

if [ -z "$BUNDLE_ID" ] || [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ]; then
    handle_error "Missing required variables"
fi

# Generate env_config.dart for Dart use
if [ -f ./lib/scripts/utils/gen_env_config.sh ]; then
    log "Generating Dart env_config.dart from Codemagic env vars..."
    ./lib/scripts/utils/gen_env_config.sh || handle_error "Failed to generate env_config.dart"
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

# Ensure Flutter is properly configured
log "Running Flutter clean and get dependencies..."
flutter clean || handle_error "Flutter clean failed"
flutter pub get || handle_error "Flutter pub get failed"

# Create Generated.xcconfig if it doesn't exist
log "Generating Flutter iOS configuration..."
mkdir -p ios/Flutter
flutter build ios --release --no-codesign || handle_error "Flutter iOS build failed"

# Configure code signing if certificates are available
if [ -n "$CERT_CER_URL" ] && [ -n "$CERT_KEY_URL" ] && [ -n "$PROFILE_URL" ] && [ -n "$CERT_PASSWORD" ]; then
    log "Configuring iOS code signing..."
    
    # Create certificates directory
    mkdir -p certs
    
    # Download certificates and provisioning profile
    log "Downloading iOS signing certificates..."
    curl -L "$CERT_CER_URL" -o certs/cert.cer || handle_error "Failed to download certificate"
    curl -L "$CERT_KEY_URL" -o certs/cert.key || handle_error "Failed to download private key"
    curl -L "$PROFILE_URL" -o certs/profile.mobileprovision || handle_error "Failed to download provisioning profile"
    
    # Generate p12 from cer and key
    log "Generating p12 certificate..."
    openssl x509 -in certs/cert.cer -inform DER -out certs/cert.pem -outform PEM || handle_error "Failed to convert certificate"
    openssl pkcs12 -export -out certs/cert.p12 -inkey certs/cert.key -in certs/cert.pem -password pass:"$CERT_PASSWORD" || handle_error "Failed to generate p12"
    
    # Import certificate to keychain
    log "Importing certificate to keychain..."
    security create-keychain -p "" build.keychain || true
    security default-keychain -s build.keychain || handle_error "Failed to set default keychain"
    security unlock-keychain -p "" build.keychain || handle_error "Failed to unlock keychain"
    security import certs/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A || handle_error "Failed to import certificate"
    security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain || true
    
    # Install provisioning profile
    log "Installing provisioning profile..."
    PROFILE_UUID=$(grep -a -A 1 -E "UUID" certs/profile.mobileprovision | grep string | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    cp certs/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/$PROFILE_UUID.mobileprovision || handle_error "Failed to install provisioning profile"
    
    # Create ExportOptions.plist
    log "Creating export options..."
    cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${PROFILE_TYPE:-app-store}</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID}</key>
        <string>$PROFILE_UUID</string>
    </dict>
</dict>
</plist>
EOF

    log "iOS code signing configured successfully"
else
    log "No signing certificates provided, building without code signing..."
    
    # Create minimal ExportOptions.plist for development
    cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
fi

log "Building iOS app with Xcode..."
if [ -n "$CERT_CER_URL" ] && [ -n "$CERT_KEY_URL" ] && [ -n "$PROFILE_URL" ] && [ -n "$CERT_PASSWORD" ]; then
    # Build with proper signing
    xcodebuild -workspace ios/Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath build/Runner.xcarchive \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
        archive || handle_error "Archive failed"
else
    # Build without signing (development)
    xcodebuild -workspace ios/Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath build/Runner.xcarchive \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        archive || handle_error "Archive failed"
fi

log "Exporting IPA"
if [ -f ios/ExportOptions.plist ]; then
    xcodebuild -exportArchive \
        -archivePath build/Runner.xcarchive \
        -exportOptionsPlist ios/ExportOptions.plist \
        -exportPath build/ios || handle_error "Export failed"
else
    # Fallback for unsigned builds
    log "Creating unsigned IPA from archive"
    mkdir -p build/ios
    cp -r build/Runner.xcarchive/Products/Applications/Runner.app build/ios/
    cd build/ios
    zip -r Runner.ipa Runner.app/
    cd ../..
fi

./lib/scripts/utils/send_email.sh "success" "iOS build completed successfully"
log "Build completed successfully"
exit 0 