#!/bin/bash
set -euo pipefail

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Start build acceleration
log "🚀 Starting iOS build with acceleration..."
accelerate_build "ios"

# Error handling
trap 'handle_error $LINENO $?' ERR
handle_error() {
    local line_no=$1
    local exit_code=$2
    log "❌ Error occurred at line $line_no. Exit code: $exit_code"
    exit $exit_code
}

# Function to validate URL
validate_url() {
    local url="$1"
    local name="$2"
    
    # Check if URL is empty
    if [ -z "$url" ]; then
        log "❌ $name URL is empty"
        return 1
    fi
    
    # Check URL format
    if ! echo "$url" | grep -qE '^https?://[^[:space:]]+$'; then
        log "❌ Invalid $name URL format: $url"
        log "URL must start with http:// or https:// and contain no spaces"
        return 1
    fi
    
    # Test URL accessibility
    if ! curl --output /dev/null --silent --head --fail "$url"; then
        log "❌ Cannot access $name URL: $url"
        log "Please ensure the URL is accessible and returns a valid response"
        return 1
    fi
    
    return 0
}

# Function to download file with retries
download_file() {
    local url="$1"
    local output="$2"
    local name="$3"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        log "📥 Downloading $name (Attempt $((retry_count + 1))/$max_retries)..."
        if curl -L --fail --silent --show-error --output "$output" "$url"; then
            log "✅ $name downloaded successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log "⚠️ Failed to download $name, retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log "❌ Failed to download $name after $max_retries attempts"
    return 1
}

# Function to setup keychain
setup_keychain() {
    log "🔐 Setting up keychain..."
    
    # Create and configure keychain
    security create-keychain -p "" build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "" build.keychain
    security set-keychain-settings -t 3600 -u build.keychain

    # Create certificates directory
    mkdir -p ios/certificates

    # Handle P12 certificate
    if [ -n "${CERT_P12_URL:-}" ]; then
        log "🔍 Validating P12 certificate URL..."
        if ! validate_url "$CERT_P12_URL" "P12 certificate"; then
            return 1
        fi
        
        if ! download_file "$CERT_P12_URL" "ios/certificates/cert.p12" "P12 certificate"; then
            return 1
        fi
        
        # Import P12 certificate
        log "🔄 Importing P12 certificate..."
        if ! security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A; then
            log "❌ Failed to import P12 certificate"
            return 1
        fi
    else
        # Handle CER and KEY files
        log "🔍 Validating certificate and key URLs..."
        if ! validate_url "$CERT_CER_URL" "certificate"; then
            return 1
        fi
        if ! validate_url "$CERT_KEY_URL" "private key"; then
            return 1
        fi
        
        if ! download_file "$CERT_CER_URL" "ios/certificates/cert.cer" "certificate"; then
            return 1
        fi
        if ! download_file "$CERT_KEY_URL" "ios/certificates/cert.key" "private key"; then
            return 1
        fi

        # Use certificate handler script for proper conversion
        log "🔄 Converting certificates using certificate handler..."
        if [ -f "lib/scripts/ios/certificate_handler.sh" ]; then
            chmod +x lib/scripts/ios/certificate_handler.sh
            if ! lib/scripts/ios/certificate_handler.sh \
                "ios/certificates/cert.cer" \
                "ios/certificates/cert.key" \
                "$CERT_PASSWORD" \
                "ios/certificates/cert.p12"; then
                log "❌ Certificate handler failed"
                return 1
            fi
        else
            # Fallback to direct conversion
            log "🔄 Using fallback certificate conversion..."
        if ! openssl x509 -in ios/certificates/cert.cer -inform DER -out ios/certificates/cert.pem -outform PEM; then
            log "❌ Failed to convert certificate to PEM format"
            return 1
        fi
        if ! openssl pkcs12 -export -inkey ios/certificates/cert.key -in ios/certificates/cert.pem -out ios/certificates/cert.p12 -password pass:"$CERT_PASSWORD"; then
            log "❌ Failed to create P12 file"
            return 1
        fi

        # Import converted P12
        log "🔄 Importing converted P12 certificate..."
        if ! security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A; then
            log "❌ Failed to import converted P12 certificate"
            return 1
            fi
        fi
    fi

    # Set partition list for codesigning
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain

    log "✅ Keychain setup completed"
    return 0
}

# Function to setup provisioning
setup_provisioning() {
    log "📱 Setting up provisioning profile..."
    
    # Install provisioning profile
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    cp ios/certificates/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
    
    # Determine distribution method from profile type
    local method="${PROFILE_TYPE:-app-store}"
    local thinning="${THINNING:-none}"
    local strip_bitcode="true"
    local upload_bitcode="false"
    local upload_symbols="true"
    local compile_bitcode="false"
    
    # Set specific options based on distribution method
    if [ "$method" = "ad-hoc" ]; then
        strip_bitcode="true"
        upload_bitcode="false"
        upload_symbols="false"
        compile_bitcode="false"
        
        # For ad-hoc, we can enable device specific builds
        if [ "${ENABLE_DEVICE_SPECIFIC_BUILDS:-false}" = "true" ]; then
            thinning="thin-for-all-variants"
        fi
    fi
    
    # Create export options plist
    cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$method</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$(basename ios/certificates/profile.mobileprovision .mobileprovision)</string>
    </dict>
    <key>stripBitcode</key>
    <$strip_bitcode/>
    <key>uploadBitcode</key>
    <$upload_bitcode/>
    <key>uploadSymbols</key>
    <$upload_symbols/>
    <key>compileBitcode</key>
    <$compile_bitcode/>
    <key>thinning</key>
    <string>$thinning</string>
</dict>
</plist>
EOF

    log "✅ Provisioning profile setup completed"
    return 0
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "iOS" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/ios

# Enhanced asset download with parallel processing
log "📥 Starting enhanced asset download..."
if [ -f "lib/scripts/ios/branding.sh" ]; then
    chmod +x lib/scripts/ios/branding.sh
    if lib/scripts/ios/branding.sh; then
        log "✅ iOS branding completed with acceleration"
        
        # Validate required assets after branding
        log "🔍 Validating iOS assets..."
        required_assets=("assets/images/logo.png" "assets/images/splash.png")
        for asset in "${required_assets[@]}"; do
            if [ -f "$asset" ] && [ -s "$asset" ]; then
                log "✅ $asset exists and has content"
            else
                log "❌ $asset is missing or empty after branding"
                exit 1
            fi
        done
        log "✅ All iOS assets validated"
    else
        log "❌ iOS branding failed"
        exit 1
    fi
else
    log "⚠️ iOS branding script not found, skipping..."
fi

# Download custom icons for bottom menu
log "🎨 Downloading custom icons for bottom menu..."
if [ "${IS_BOTTOMMENU:-false}" = "true" ]; then
    if [ -f "lib/scripts/utils/download_custom_icons.sh" ]; then
        chmod +x lib/scripts/utils/download_custom_icons.sh
        if lib/scripts/utils/download_custom_icons.sh; then
            log "✅ Custom icons download completed"
            
            # Validate custom icons if BOTTOMMENU_ITEMS contains custom icons
            if [ -n "${BOTTOMMENU_ITEMS:-}" ]; then
                log "🔍 Validating custom icons..."
                if [ -d "assets/icons" ] && [ "$(ls -A assets/icons 2>/dev/null)" ]; then
                    log "✅ Custom icons found in assets/icons/"
                    ls -la assets/icons/ | while read -r line; do
                        log "   $line"
                    done
                else
                    log "ℹ️ No custom icons found (using preset icons only)"
                fi
            fi
        else
            log "❌ Custom icons download failed"
            exit 1
        fi
    else
        log "⚠️ Custom icons download script not found, skipping..."
    fi
else
    log "ℹ️ Bottom menu disabled (IS_BOTTOMMENU=false), skipping custom icons download"
fi

# Run customization with acceleration
log "⚙️ Running iOS customization with acceleration..."
if [ -f "lib/scripts/ios/customization.sh" ]; then
    chmod +x lib/scripts/ios/customization.sh
    if lib/scripts/ios/customization.sh; then
        log "✅ iOS customization completed"
    else
        log "❌ iOS customization failed"
        exit 1
    fi
else
    log "⚠️ iOS customization script not found, skipping..."
fi

# Run permissions with acceleration
log "🔒 Running iOS permissions with acceleration..."
if [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/ios/permissions.sh
    if lib/scripts/ios/permissions.sh; then
        log "✅ iOS permissions configured"
    else
        log "❌ iOS permissions configuration failed"
        exit 1
    fi
else
    log "⚠️ iOS permissions script not found, skipping..."
fi

# Run Firebase with acceleration
log "🔥 Running iOS Firebase with acceleration..."
if [ -f "lib/scripts/ios/firebase.sh" ]; then
    chmod +x lib/scripts/ios/firebase.sh
    if lib/scripts/ios/firebase.sh; then
        log "✅ iOS Firebase configuration completed"
    else
        log "❌ iOS Firebase configuration failed"
        exit 1
    fi
else
    log "⚠️ iOS Firebase script not found, skipping..."
fi

# Setup certificates and provisioning with acceleration
log "🔐 Setting up certificates and provisioning with acceleration..."

# Download provisioning profile
log "📥 Downloading provisioning profile..."
if ! validate_url "$PROFILE_URL" "provisioning profile"; then
    log "❌ Invalid provisioning profile URL"
    exit 1
fi

if ! download_file "$PROFILE_URL" "ios/certificates/profile.mobileprovision" "provisioning profile"; then
    log "❌ Failed to download provisioning profile"
    exit 1
fi

# Setup keychain and certificates
if ! setup_keychain; then
    log "❌ Keychain setup failed"
    exit 1
fi

# Setup provisioning
if ! setup_provisioning; then
    log "❌ Provisioning setup failed"
    exit 1
fi

# Enhanced iOS build with acceleration
log "📱 Starting enhanced iOS build..."

# Configure JVM options for CocoaPods and Xcode
log "🔧 Configuring JVM options..."
export JAVA_TOOL_OPTIONS="-Xmx2048m -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError"

# Configure CocoaPods environment
log "🔧 Configuring CocoaPods environment..."
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Pre-install CocoaPods dependencies
log "📦 Pre-installing CocoaPods dependencies..."
cd ios

# Clean CocoaPods cache if needed
if [ "${CLEAN_PODS_CACHE:-false}" = "true" ]; then
    log "🧹 Cleaning CocoaPods cache..."
    rm -rf "${HOME}/Library/Caches/CocoaPods"
    rm -rf "Pods/"
    rm -f "Podfile.lock"
fi

# Install pods with optimized settings
if [ "${COCOAPODS_FAST_INSTALL:-true}" = "true" ]; then
    log "📦 Fast installing pods with repo update..."
    if ! pod install --repo-update --verbose; then
        log "⚠️ Fast pod install failed, trying regular install..."
        if ! pod install --verbose; then
            log "❌ Pod installation failed"
            exit 1
        fi
    fi
else
    log "📦 Regular pod installation..."
    if ! pod install --verbose; then
        log "❌ Pod installation failed"
        exit 1
    fi
fi

cd ..

# Clean Flutter build cache first
log "🧹 Cleaning Flutter build cache..."
flutter clean

# Build iOS app with optimizations
log "🔨 Building iOS app with optimizations..."
if flutter build ios --release --no-codesign \
    --dart-define=ENABLE_BITCODE=NO \
    --dart-define=STRIP_STYLE=non-global; then
    log "✅ iOS build completed successfully"
else
    log "❌ iOS build failed"
    exit 1
fi

# Archive and export IPA with optimizations
log "📦 Archiving and exporting IPA with optimizations..."
cd ios

# Create archive with optimized settings
log "📦 Creating archive..."
if xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath build/Runner.xcarchive \
    -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates \
    ENABLE_BITCODE=NO \
    STRIP_STYLE=non-global \
    COMPILER_INDEX_STORE_ENABLE=NO \
    archive; then
    log "✅ Archive created successfully"
else
    log "❌ Archive creation failed"
    exit 1
fi

# Export IPA with optimized settings
log "📦 Exporting IPA..."
if xcodebuild -exportArchive \
    -archivePath build/Runner.xcarchive \
    -exportPath build/ios/ipa \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates \
    ENABLE_BITCODE=NO \
    STRIP_STYLE=non-global \
    COMPILER_INDEX_STORE_ENABLE=NO; then
    log "✅ IPA exported successfully"
else
    log "❌ IPA export failed"
    exit 1
fi

cd ..

# Copy artifacts to output directory
log "📁 Copying artifacts to output directory..."
cp ios/build/ios/ipa/*.ipa output/ios/ 2>/dev/null || true
log "✅ iOS artifacts copied to output/ios/"

# Verify artifacts
log "🔍 Verifying artifacts..."
if [ -f "output/ios/Runner.ipa" ]; then
    IPA_SIZE=$(du -h output/ios/Runner.ipa | cut -f1)
    log "✅ IPA created successfully (Size: $IPA_SIZE)"
else
    log "❌ IPA not found in output directory"
    exit 1
fi

# Send build success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    # Pass platform and build ID for individual artifact URL generation
    lib/scripts/utils/send_email.sh "build_success" "iOS" "${CM_BUILD_ID:-unknown}" || true
fi

log "🎉 iOS build completed successfully with acceleration!"
log "📊 Build artifacts available in output/ios/"

exit 0 