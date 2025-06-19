#!/bin/bash
set -euo pipefail

# Source environment variables
source lib/scripts/utils/gen_env_config.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Error handling with email notification
trap 'handle_error $LINENO $?' ERR

handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Send build failed email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit $exit_code
}

log "🚀 Starting iOS build process..."

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "iOS" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p ios/certificates
mkdir -p output/ios

# Step 1: Download certificate files (unencrypted)
log "📥 Downloading certificate files (unencrypted)..."

if [ -n "${CERT_CER_URL:-}" ]; then
    log "Downloading certificate from: $CERT_CER_URL"
    if curl -L -o ios/certificates/cert.cer "$CERT_CER_URL"; then
        log "✅ Certificate downloaded successfully"
    else
        log "❌ Failed to download certificate"
        exit 1
    fi
else
    log "❌ CERT_CER_URL is required for iOS signing"
    exit 1
fi

if [ -n "${CERT_KEY_URL:-}" ]; then
    log "Downloading private key from: $CERT_KEY_URL"
    if curl -L -o ios/certificates/cert.key "$CERT_KEY_URL"; then
        log "✅ Private key downloaded successfully"
    else
        log "❌ Failed to download private key"
        exit 1
    fi
else
    log "❌ CERT_KEY_URL is required for iOS signing"
    exit 1
fi

if [ -n "${PROFILE_URL:-}" ]; then
    log "Downloading provisioning profile from: $PROFILE_URL"
    if curl -L -o ios/certificates/profile.mobileprovision "$PROFILE_URL"; then
        log "✅ Provisioning profile downloaded successfully"
    else
        log "❌ Failed to download provisioning profile"
        exit 1
    fi
else
    log "❌ PROFILE_URL is required for iOS signing"
    exit 1
fi

# Step 2: Validate required variables
log "🔍 Validating required variables..."

required_vars=(
    "CERT_PASSWORD"
    "APPLE_TEAM_ID"
    "APNS_KEY_ID"
    "APNS_AUTH_KEY_URL"
    "APP_STORE_CONNECT_KEY_IDENTIFIER"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        log "❌ Required variable $var is missing"
        exit 1
    fi
done

# Step 3: Process certificates and create P12
log "🔐 Processing certificates and creating P12 file..."
if [ -f "lib/scripts/ios/certificate_handler.sh" ]; then
    chmod +x lib/scripts/ios/certificate_handler.sh
    if lib/scripts/ios/certificate_handler.sh \
        "ios/certificates/cert.cer" \
        "ios/certificates/cert.key" \
        "$CERT_PASSWORD" \
        "ios/certificates/cert.p12"; then
        log "✅ Certificate processing completed"
    else
        log "❌ Certificate processing failed"
        exit 1
    fi
else
    log "❌ Certificate handler script not found"
    exit 1
fi

# Step 4: Install provisioning profile
log "📱 Installing provisioning profile..."
if [ -f "ios/certificates/profile.mobileprovision" ]; then
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
    cp ios/certificates/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
    log "✅ Provisioning profile installed"
else
    log "❌ Provisioning profile not found"
    exit 1
fi

# Step 5: Download APNS auth key
log "🔑 Downloading APNS auth key..."
if [ -n "${APNS_AUTH_KEY_URL:-}" ]; then
    if curl -L -o ios/certificates/AuthKey_${APNS_KEY_ID}.p8 "$APNS_AUTH_KEY_URL"; then
        log "✅ APNS auth key downloaded"
    else
        log "❌ Failed to download APNS auth key"
        exit 1
    fi
else
    log "❌ APNS_AUTH_KEY_URL is required"
    exit 1
fi

# Step 6: Run branding script
log "🎨 Running branding script..."
if [ -f "lib/scripts/ios/branding.sh" ]; then
    chmod +x lib/scripts/ios/branding.sh
    if lib/scripts/ios/branding.sh; then
        log "✅ Branding completed"
    else
        log "❌ Branding failed"
        exit 1
    fi
else
    log "⚠️  Branding script not found, skipping..."
fi

# Step 7: Run customization script
log "⚙️  Running customization script..."
if [ -f "lib/scripts/ios/customization.sh" ]; then
    chmod +x lib/scripts/ios/customization.sh
    if lib/scripts/ios/customization.sh; then
        log "✅ Customization completed"
    else
        log "❌ Customization failed"
        exit 1
    fi
else
    log "⚠️  Customization script not found, skipping..."
fi

# Step 8: Run permissions script
log "🔒 Running permissions script..."
if [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/ios/permissions.sh
    if lib/scripts/ios/permissions.sh; then
        log "✅ Permissions configured"
    else
        log "❌ Permissions configuration failed"
        exit 1
    fi
else
    log "⚠️  Permissions script not found, skipping..."
fi

# Step 9: Run deployment target script
log "📱 Setting deployment target..."
if [ -f "lib/scripts/ios/deployment_target.sh" ]; then
    chmod +x lib/scripts/ios/deployment_target.sh
    if lib/scripts/ios/deployment_target.sh; then
        log "✅ Deployment target set"
    else
        log "❌ Deployment target setting failed"
        exit 1
    fi
else
    log "⚠️  Deployment target script not found, skipping..."
fi

# Step 10: Run Firebase script
log "🔥 Running Firebase script..."
if [ -f "lib/scripts/ios/firebase.sh" ]; then
    chmod +x lib/scripts/ios/firebase.sh
    if lib/scripts/ios/firebase.sh; then
        log "✅ Firebase configuration completed"
    else
        log "❌ Firebase configuration failed"
        exit 1
    fi
else
    log "⚠️  Firebase script not found, skipping..."
fi

# Step 11: Update Podfile for Firebase compatibility
log "📦 Updating Podfile for Firebase compatibility..."
if [ -f "ios/Podfile" ]; then
    # Add Firebase compatibility settings
    cat >> ios/Podfile << 'EOF'

# Firebase compatibility settings
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
EOF
    log "✅ Podfile updated"
else
    log "❌ Podfile not found"
    exit 1
fi

# Step 12: Flutter setup (CRITICAL - must come before pod install)
log "📦 Setting up Flutter dependencies..."
if flutter doctor; then
    log "✅ Flutter doctor check completed"
else
    log "⚠️  Flutter doctor had warnings (continuing anyway)"
fi

log "📦 Running flutter pub get..."
if flutter pub get; then
    log "✅ Flutter dependencies installed"
else
    log "❌ Failed to install Flutter dependencies"
    exit 1
fi

log "📦 Running flutter precache --ios..."
if flutter precache --ios; then
    log "✅ Flutter iOS artifacts cached"
else
    log "⚠️  Flutter precache had warnings (continuing anyway)"
fi

# Step 13: Install pods (now that Flutter dependencies are ready)
log "📦 Installing CocoaPods dependencies..."
cd ios
if pod install --repo-update; then
    log "✅ CocoaPods dependencies installed"
else
    log "❌ CocoaPods installation failed"
    exit 1
fi
cd ..

# Step 14: Build and export IPA
log "🏗️  Building iOS app..."

# Determine if we should build signed or unsigned
BUILD_SIGNED=true
if ! security find-identity -v -p codesigning build.keychain 2>/dev/null | grep -q "iPhone Distribution"; then
    log "⚠️  No valid signing identity found, attempting unsigned build"
    BUILD_SIGNED=false
fi

# Create export options plist
cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${PROFILE_TYPE:-app-store}</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$(basename ios/certificates/profile.mobileprovision .mobileprovision)</string>
    </dict>
    <key>compileBitcode</key>
    <false/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

# Build the app
cd ios
if [ "$BUILD_SIGNED" = true ]; then
    log "Building with code signing..."
    if xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive; then
        log "✅ Archive created successfully"
        
        if xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build/ -exportOptionsPlist ExportOptions.plist; then
            log "✅ IPA exported successfully"
            cp build/Runner.ipa ../output/ios/
        else
            log "❌ IPA export failed"
            exit 1
        fi
    else
        log "❌ Archive creation failed"
        exit 1
    fi
else
    log "Building without code signing..."
    if flutter build ios --release --no-codesign; then
        log "✅ Unsigned build completed"
        # Create a simple IPA structure for unsigned build
        mkdir -p Payload/Runner.app
        cp -r build/ios/Release-iphoneos/Runner.app Payload/
        zip -r ../output/ios/Runner-unsigned.ipa Payload/
        rm -rf Payload
    else
        log "❌ Unsigned build failed"
        exit 1
    fi
fi
cd ..

# Step 15: Generate environment config
log "⚙️  Generating environment configuration..."
if [ -f "lib/scripts/utils/gen_env_config.sh" ]; then
    chmod +x lib/scripts/utils/gen_env_config.sh
    if lib/scripts/utils/gen_env_config.sh; then
        log "✅ Environment configuration generated"
    else
        log "❌ Environment configuration generation failed"
        exit 1
    fi
else
    log "⚠️  Environment config script not found, skipping..."
fi

# Step 16: Send build success email
log "📧 Sending build success notification..."
ARTIFACTS_URL="https://codemagic.io/builds/${CM_BUILD_ID:-unknown}/artifacts"
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    lib/scripts/utils/send_email.sh "build_success" "iOS" "${CM_BUILD_ID:-unknown}" "$ARTIFACTS_URL" || true
fi

log "🎉 iOS build process completed successfully!"
log "📱 IPA file location: output/ios/"

exit 0 