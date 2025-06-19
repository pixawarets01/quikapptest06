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
VERSION_NAME=${VERSION_NAME:-}
VERSION_CODE=${VERSION_CODE:-}
APP_NAME=${APP_NAME:-}
ORG_NAME=${ORG_NAME:-}
WEB_URL=${WEB_URL:-}
BUNDLE_ID=${BUNDLE_ID:-}
EMAIL_ID=${EMAIL_ID:-}
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
FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS:-}

# iOS Signing
CERT_CER_URL=${CERT_CER_URL:-}
CERT_KEY_URL=${CERT_KEY_URL:-}
CERT_PASSWORD=${CERT_PASSWORD:-}
PROFILE_URL=${PROFILE_URL:-}
PROFILE_TYPE=${PROFILE_TYPE:-"app-store"}
APPLE_TEAM_ID=${APPLE_TEAM_ID:-}
APNS_KEY_ID=${APNS_KEY_ID:-}
APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL:-}
APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-}
IS_TESTFLIGHT=${IS_TESTFLIGHT:-"false"}

# Email
EMAIL_SMTP_SERVER=${EMAIL_SMTP_SERVER:-}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT:-}
EMAIL_SMTP_USER=${EMAIL_SMTP_USER:-}
EMAIL_SMTP_PASS=${EMAIL_SMTP_PASS:-}
ENABLE_EMAIL_NOTIFICATIONS=${ENABLE_EMAIL_NOTIFICATIONS:-"true"}

# Export variables for email script
export CERT_CER_URL
export CERT_KEY_URL
export PROFILE_URL
export CERT_PASSWORD
export ENABLE_EMAIL_NOTIFICATIONS

chmod +x ./lib/scripts/ios/*.sh || true
chmod +x ./lib/scripts/utils/*.sh || true

log "Starting iOS build for $APP_NAME"
log "Bundle ID: $BUNDLE_ID"
log "Version: $VERSION_NAME ($VERSION_CODE)"

if [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ] || [ -z "$APP_NAME" ] || [ -z "$BUNDLE_ID" ]; then
    handle_error "Required variables are missing"
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
if [ "$PUSH_NOTIFY" = "true" ] && [ -f ./lib/scripts/ios/firebase.sh ]; then
    log "Running Firebase script..."
    ./lib/scripts/ios/firebase.sh || handle_error "Firebase script failed"
fi

# Deployment target update
if [ -f ./lib/scripts/ios/deployment_target.sh ]; then
    log "Updating iOS deployment target to 13.0 for Firebase compatibility..."
    ./lib/scripts/ios/deployment_target.sh || handle_error "Deployment target update failed"
fi

# iOS Code Signing Setup
SIGNING_CONFIGURED="false"
P12_FILE=""
MOBILEPROVISION_FILE=""
TEAM_ID=""
PROVISIONING_PROFILE_UUID=""

if [ -n "$CERT_CER_URL" ] && [ -n "$CERT_KEY_URL" ] && [ -n "$CERT_PASSWORD" ] && [ -n "$PROFILE_URL" ]; then
    log "🔐 Setting up iOS code signing..."
    log "Certificate URL: $CERT_CER_URL"
    log "Key URL: $CERT_KEY_URL"
    log "Profile URL: $PROFILE_URL"
    log "Password configured: $([ -n "$CERT_PASSWORD" ] && echo "Yes (length: ${#CERT_PASSWORD})" || echo "No")"
    
    # Create certificates directory
    mkdir -p ios/certificates
    
    # Download certificate and key files
    log "Downloading certificate files..."
    curl -L "$CERT_CER_URL" -o ios/certificates/cert.cer || handle_error "Failed to download certificate"
    curl -L "$CERT_KEY_URL" -o ios/certificates/cert.key || handle_error "Failed to download private key"
    curl -L "$PROFILE_URL" -o ios/certificates/profile.mobileprovision || handle_error "Failed to download provisioning profile"
    
    # Verify files were downloaded and check their content
    if [ ! -f ios/certificates/cert.cer ] || [ ! -f ios/certificates/cert.key ] || [ ! -f ios/certificates/profile.mobileprovision ]; then
        handle_error "One or more certificate files failed to download"
    fi
    
    # Check file sizes and basic content
    log "Verifying downloaded files..."
    CER_SIZE=$(stat -f%z ios/certificates/cert.cer 2>/dev/null || stat -c%s ios/certificates/cert.cer 2>/dev/null || echo "0")
    KEY_SIZE=$(stat -f%z ios/certificates/cert.key 2>/dev/null || stat -c%s ios/certificates/cert.key 2>/dev/null || echo "0")
    PROFILE_SIZE=$(stat -f%z ios/certificates/profile.mobileprovision 2>/dev/null || stat -c%s ios/certificates/profile.mobileprovision 2>/dev/null || echo "0")
    
    log "Certificate size: ${CER_SIZE} bytes"
    log "Private key size: ${KEY_SIZE} bytes"
    log "Provisioning profile size: ${PROFILE_SIZE} bytes"
    
    if [ "$CER_SIZE" -lt 100 ] || [ "$KEY_SIZE" -lt 100 ] || [ "$PROFILE_SIZE" -lt 100 ]; then
        log "Warning: One or more files seem too small - they might be error pages or invalid files"
        log "Certificate content preview: $(head -2 ios/certificates/cert.cer)"
        log "Key content preview: $(head -2 ios/certificates/cert.key)"
    fi
    
    # Use advanced certificate handler for P12 generation and keychain import
    log "Processing certificates with advanced handler..."
    P12_FILE="ios/certificates/cert.p12"
    
    # Make certificate handler executable
    chmod +x ./lib/scripts/ios/certificate_handler.sh || handle_error "Failed to make certificate handler executable"
    
    # Call the certificate handler
    if ./lib/scripts/ios/certificate_handler.sh ios/certificates/cert.cer ios/certificates/cert.key "$CERT_PASSWORD" "$P12_FILE"; then
        log "✅ Certificate processing and keychain import completed successfully"
    else
        handle_error "Certificate processing failed - check certificate files and CERT_PASSWORD"
    fi
    
    # Install provisioning profile
    log "Installing provisioning profile..."
    MOBILEPROVISION_FILE="ios/certificates/profile.mobileprovision"
    
    # Extract provisioning profile UUID and Team ID
    PROVISIONING_PROFILE_UUID=$(security cms -D -i "$MOBILEPROVISION_FILE" | plutil -extract UUID xml1 -o - - | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
    TEAM_ID=$(security cms -D -i "$MOBILEPROVISION_FILE" | plutil -extract TeamIdentifier.0 xml1 -o - - | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
    
    if [ -z "$PROVISIONING_PROFILE_UUID" ] || [ -z "$TEAM_ID" ]; then
        handle_error "Failed to extract provisioning profile UUID or Team ID"
    fi
    
    log "Provisioning Profile UUID: $PROVISIONING_PROFILE_UUID"
    log "Team ID: $TEAM_ID"
    
    # Install provisioning profile
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    cp "$MOBILEPROVISION_FILE" ~/Library/MobileDevice/Provisioning\ Profiles/"$PROVISIONING_PROFILE_UUID.mobileprovision"
    
    SIGNING_CONFIGURED="true"
    log "✅ iOS code signing setup completed"
else
    log "⚠️  No iOS signing configuration provided - building unsigned IPA"
fi

# Clean and prepare for build
log "Cleaning iOS build cache..."
flutter clean
rm -rf ios/Pods ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Update Podfile with Firebase compatibility and Swift compiler fix
log "Updating Podfile for Firebase compatibility..."
cat > ios/Podfile << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Flutter-Generated.xcconfig, then run \"flutter pub get\""
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Set minimum deployment target
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      
      # Fix Firebase Swift compiler issues
      if target.name == 'FirebaseCoreInternal'
        config.build_settings['OTHER_SWIFT_FLAGS'] = '$(inherited) -enable-experimental-feature AccessLevelOnImport'
      end
      
      # Additional Firebase compatibility fixes
      if target.name.start_with?('Firebase')
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end
end
EOF

# Generate Flutter iOS configuration
log "Generating Flutter iOS configuration..."
flutter pub get
flutter build ios --config-only --no-codesign

# Run pod install
log "Installing CocoaPods dependencies..."
cd ios
pod install --repo-update
cd ..

# Create entitlements file if needed
if [ "$SIGNING_CONFIGURED" = "true" ]; then
    log "Creating entitlements file..."
    cat > ios/Runner/Runner.entitlements << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>$TEAM_ID.$BUNDLE_ID</string>
    <key>keychain-access-groups</key>
    <array>
        <string>$TEAM_ID.$BUNDLE_ID</string>
    </array>
EOF

    if [ "$PUSH_NOTIFY" = "true" ]; then
        cat >> ios/Runner/Runner.entitlements << EOF
    <key>aps-environment</key>
    <string>production</string>
EOF
    fi

    cat >> ios/Runner/Runner.entitlements << EOF
</dict>
</plist>
EOF

    # Create export options plist
    log "Creating export options..."
    cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$PROFILE_TYPE</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$PROVISIONING_PROFILE_UUID</string>
    </dict>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
fi

# Build with xcodebuild
log "Building iOS app with xcodebuild..."
cd ios

if [ "$SIGNING_CONFIGURED" = "true" ]; then
    log "Building signed IPA..."
    
    # Build archive
    xcodebuild -workspace Runner.xcworkspace \
               -scheme Runner \
               -configuration Release \
               -destination generic/platform=iOS \
               -archivePath Runner.xcarchive \
               -allowProvisioningUpdates \
               DEVELOPMENT_TEAM="$TEAM_ID" \
               PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_UUID" \
               CODE_SIGN_IDENTITY="iPhone Distribution" \
               CODE_SIGN_ENTITLEMENTS="Runner/Runner.entitlements" \
               archive || handle_error "Failed to build iOS archive"
    
    # Export IPA
    xcodebuild -exportArchive \
               -archivePath Runner.xcarchive \
               -exportPath ../output/ios \
               -exportOptionsPlist ExportOptions.plist || handle_error "Failed to export IPA"
    
    log "✅ Signed IPA created successfully"
else
    log "Building unsigned IPA..."
    
    # Build archive without signing
    xcodebuild -workspace Runner.xcworkspace \
               -scheme Runner \
               -configuration Release \
               -destination generic/platform=iOS \
               -archivePath Runner.xcarchive \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO \
               archive || handle_error "Failed to build iOS archive"
    
    # Create basic export options for unsigned build
    cat > ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF
    
    # Export unsigned IPA
    xcodebuild -exportArchive \
               -archivePath Runner.xcarchive \
               -exportPath ../output/ios \
               -exportOptionsPlist ExportOptions.plist || handle_error "Failed to export unsigned IPA"
    
    log "✅ Unsigned IPA created successfully"
fi

cd ..

# Create output directory and verify IPA
mkdir -p output/ios
if [ -f ios/Runner.xcarchive ]; then
    log "iOS build completed successfully"
    if [ -d "output/ios" ] && [ "$(ls -A output/ios/*.ipa 2>/dev/null)" ]; then
        log "IPA file created: $(ls output/ios/*.ipa)"
    else
        log "Warning: IPA file not found in expected location"
        find ios -name "*.ipa" -exec mv {} output/ios/ \; || true
    fi
else
    handle_error "iOS archive not created"
fi

# Send success email
./lib/scripts/utils/send_email.sh "success" "iOS build completed successfully"
log "iOS build completed successfully"
exit 0 