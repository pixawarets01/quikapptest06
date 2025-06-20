#!/bin/bash
set -euo pipefail

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Early required variable validation for iOS builds
log "🔍 Validating required variables for iOS build..."
REQUIRED_VARS=("BUNDLE_ID" "APPLE_TEAM_ID" "PROFILE_URL" "CERT_PASSWORD" "PROFILE_TYPE")
CERT_OK=false

# Check for certificate variables
if [ -n "${CERT_P12_URL:-}" ]; then
    REQUIRED_VARS+=("CERT_P12_URL")
    CERT_OK=true
    log "✅ P12 certificate URL provided"
elif [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ]; then
    REQUIRED_VARS+=("CERT_CER_URL" "CERT_KEY_URL")
    CERT_OK=true
    log "✅ CER and KEY certificate URLs provided"
else
    log "❌ No valid certificate variables provided"
    log "   Required: CERT_P12_URL OR (CERT_CER_URL AND CERT_KEY_URL)"
fi

# Validate all required variables
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        log "❌ Required variable $var is missing!"
        log "   This will cause the build to fail. Please check your Codemagic environment variables."
        
        # Send failure email
        if [ -f "lib/scripts/utils/send_email.sh" ]; then
            chmod +x lib/scripts/utils/send_email.sh
            lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Missing required variable: $var" || true
        fi
        exit 1
    else
        log "✅ $var is set"
    fi
done

if [ "$CERT_OK" = false ]; then
    log "❌ No valid certificate configuration found!"
    log "   Please provide either:"
    log "   - CERT_P12_URL (for P12 certificate)"
    log "   - CERT_CER_URL AND CERT_KEY_URL (for CER/KEY certificates)"
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "No valid certificate variables provided" || true
    fi
    exit 1
fi

log "✅ All required variables validated successfully"

# Determine iOS workflow type
WORKFLOW_TYPE=""
if [[ "${WORKFLOW_ID:-}" == "ios-appstore" ]]; then
    WORKFLOW_TYPE="app-store"
    log "🍎 iOS App Store Build Workflow Detected"
elif [[ "${WORKFLOW_ID:-}" == "ios-adhoc" ]]; then
    WORKFLOW_TYPE="ad-hoc"
    log "🍎 iOS Ad Hoc Build Workflow Detected"
else
    # Fallback to app-store for backward compatibility
    WORKFLOW_TYPE="${PROFILE_TYPE:-app-store}"
    log "🍎 iOS Build Workflow: $WORKFLOW_TYPE (from PROFILE_TYPE)"
fi

# Override PROFILE_TYPE with workflow-specific value
export PROFILE_TYPE="$WORKFLOW_TYPE"
log "📋 Using Profile Type: $PROFILE_TYPE"

# Start build acceleration
log "🚀 Starting iOS build with acceleration..."
accelerate_build "ios"

# Error handling
trap 'handle_error $LINENO $?' ERR
handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
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

# Create a list of safe environment variables to pass to Flutter
log "🔧 Preparing environment variables for Flutter..."
ENV_ARGS=""

# Define a list of safe variables that can be passed to Flutter
SAFE_VARS=(
    "APP_ID" "WORKFLOW_ID" "BRANCH" "VERSION_NAME" "VERSION_CODE" 
    "APP_NAME" "ORG_NAME" "WEB_URL" "BUNDLE_ID" "EMAIL_ID" "USER_NAME"
    "PUSH_NOTIFY" "IS_CHATBOT" "IS_DOMAIN_URL" "IS_SPLASH" "IS_PULLDOWN"
    "IS_BOTTOMMENU" "IS_LOAD_IND" "IS_CAMERA" "IS_LOCATION" "IS_MIC"
    "IS_NOTIFICATION" "IS_CONTACT" "IS_BIOMETRIC" "IS_CALENDAR" "IS_STORAGE"
    "LOGO_URL" "SPLASH_URL" "SPLASH_BG_URL" "SPLASH_BG_COLOR" "SPLASH_TAGLINE" 
    "SPLASH_TAGLINE_COLOR" "SPLASH_ANIMATION" "SPLASH_DURATION" "BOTTOMMENU_FONT" 
    "BOTTOMMENU_FONT_SIZE" "BOTTOMMENU_FONT_BOLD" "BOTTOMMENU_FONT_ITALIC" 
    "BOTTOMMENU_BG_COLOR" "BOTTOMMENU_TEXT_COLOR" "BOTTOMMENU_ICON_COLOR" 
    "BOTTOMMENU_ACTIVE_TAB_COLOR" "BOTTOMMENU_ICON_POSITION"
    "FIREBASE_CONFIG_ANDROID" "FIREBASE_CONFIG_IOS"
    "ENABLE_EMAIL_NOTIFICATIONS" "EMAIL_SMTP_SERVER" "EMAIL_SMTP_PORT"
    "EMAIL_SMTP_USER" "CM_BUILD_ID" "CM_WORKFLOW_NAME" "CM_BRANCH"
    "FCI_BUILD_ID" "FCI_WORKFLOW_NAME" "FCI_BRANCH" "CONTINUOUS_INTEGRATION"
    "CI" "BUILD_NUMBER" "PROJECT_BUILD_NUMBER"
)

# Only pass safe variables to Flutter
for var_name in "${SAFE_VARS[@]}"; do
    if [ -n "${!var_name:-}" ]; then
        # Escape the value to handle special characters
        var_value="${!var_name}"
        # Remove any newlines or problematic characters
        var_value=$(echo "$var_value" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        
        # Special handling for APP_NAME to properly escape spaces
        if [ "$var_name" = "APP_NAME" ]; then
            var_value=$(printf '%q' "$var_value")
        fi
        
        ENV_ARGS="$ENV_ARGS --dart-define=$var_name=$var_value"
    fi
done

# Add essential build arguments
ENV_ARGS="$ENV_ARGS --dart-define=FLUTTER_BUILD_NAME=$VERSION_NAME"
ENV_ARGS="$ENV_ARGS --dart-define=FLUTTER_BUILD_NUMBER=$VERSION_CODE"

log "📋 Prepared $ENV_ARGS environment variables for Flutter build"

# Build iOS app with optimizations
log "🔨 Building iOS app with optimizations..."

if flutter build ios --release --no-codesign \
    --dart-define=ENABLE_BITCODE=NO \
    --dart-define=STRIP_STYLE=non-global \
    $ENV_ARGS; then
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
mkdir -p output/ios

# Find and copy the IPA file with multiple detection methods
log "📦 Locating and copying IPA file..."
IPA_FOUND=false
IPA_NAME=""

# Look for IPA in common locations
IPA_LOCATIONS=(
    "ios/build/ios/ipa/*.ipa"
    "ios/build/Runner.xcarchive/Products/Applications/*.ipa"
    "ios/build/archive/*.ipa"
    "build/ios/ipa/*.ipa"
    "build/ios/archive/Runner.xcarchive/Products/Applications/*.ipa"
)

for pattern in "${IPA_LOCATIONS[@]}"; do
    for ipa_file in $pattern; do
        if [ -f "$ipa_file" ]; then
            IPA_NAME=$(basename "$ipa_file")
            cp "$ipa_file" "output/ios/$IPA_NAME"
            log "✅ IPA found and copied: $ipa_file → output/ios/$IPA_NAME"
            IPA_FOUND=true
            break 2
        fi
    done
done

# If no IPA found with patterns, try find command
if [ "$IPA_FOUND" = false ]; then
    log "🔍 Searching for IPA files using find command..."
    FOUND_IPAS=$(find . -name "*.ipa" -type f 2>/dev/null | head -5)
    
    if [ -n "$FOUND_IPAS" ]; then
        log "📋 Found IPA files:"
        echo "$FOUND_IPAS" | while read -r ipa_file; do
            log "   - $ipa_file"
        done
        
        # Use the first IPA found
        FIRST_IPA=$(echo "$FOUND_IPAS" | head -1)
        IPA_NAME=$(basename "$FIRST_IPA")
        cp "$FIRST_IPA" "output/ios/$IPA_NAME"
        log "✅ IPA copied from find: $FIRST_IPA → output/ios/$IPA_NAME"
        IPA_FOUND=true
    fi
fi

# Verify IPA was created and copied
if [ "$IPA_FOUND" = false ]; then
    log "❌ No IPA file found after build!"
    log "   Searched locations:"
    for pattern in "${IPA_LOCATIONS[@]}"; do
        log "   - $pattern"
    done
    
    # List build directory contents for debugging
    log "🔍 Build directory contents:"
    find . -name "*.ipa" -type f 2>/dev/null || log "   No IPA files found in project"
    
    # Check if archive was created
    if [ -d "ios/build/Runner.xcarchive" ]; then
        log "✅ Archive exists at ios/build/Runner.xcarchive"
        log "🔍 Archive contents:"
        ls -la ios/build/Runner.xcarchive/Products/Applications/ 2>/dev/null || log "   No Applications directory in archive"
    else
        log "❌ Archive not found at ios/build/Runner.xcarchive"
    fi
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "No IPA file generated after build" || true
    fi
    exit 1
fi

# Verify the copied IPA file
if [ -f "output/ios/$IPA_NAME" ]; then
    IPA_SIZE=$(stat -f%z "output/ios/$IPA_NAME" 2>/dev/null || stat -c%s "output/ios/$IPA_NAME" 2>/dev/null || echo "unknown")
    log "✅ IPA verification successful:"
    log "   File: output/ios/$IPA_NAME"
    log "   Size: $IPA_SIZE bytes"
    
    # Additional verification - check if it's a valid ZIP/IPA
    if file "output/ios/$IPA_NAME" | grep -q "Zip archive"; then
        log "✅ IPA file format verified (ZIP archive)"
    else
        log "⚠️ IPA file format verification failed - may not be a valid ZIP archive"
    fi
else
    log "❌ IPA file verification failed!"
    log "   Expected: output/ios/$IPA_NAME"
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "IPA file verification failed" || true
    fi
    exit 1
fi

# List output directory contents
log "📋 Output directory contents:"
ls -la output/ios/ || log "   No files in output/ios/"

log "🎉 iOS build completed successfully!"

# Send success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "iOS" "${CM_BUILD_ID:-unknown}" "IPA: $IPA_NAME" || true
fi

exit 0 