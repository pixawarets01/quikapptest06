#!/bin/bash
set -euo pipefail

# CRITICAL: Force fix env_config.dart to resolve $BRANCH compilation error
# This must be done FIRST to prevent any caching issues
if [ -f "lib/scripts/utils/force_fix_env_config.sh" ]; then
    chmod +x lib/scripts/utils/force_fix_env_config.sh
    lib/scripts/utils/force_fix_env_config.sh
fi

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# CRITICAL: Force fix again after environment generation to ensure no $BRANCH patterns
if [ -f "lib/scripts/utils/force_fix_env_config.sh" ]; then
    lib/scripts/utils/force_fix_env_config.sh
fi

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

# Generate Dart environment configuration
log "⚙️ Generating Dart environment configuration..."
source "lib/scripts/utils/gen_env_config.sh"
generate_env_config

# Get Flutter dependencies
log "📦 Getting Flutter dependencies..."
flutter pub get

# Build the iOS app
log "🚀 Building iOS application (IPA)..."
flutter build ipa --release --export-options-plist=output/ios/export_options.plist

log "✅ Flutter build completed successfully."

# Find the generated IPA
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

# Final verification
log "✅ Final verification of build artifacts..."
if [ -f "output/ios/$IPA_NAME" ]; then
    log "   - IPA found at: output/ios/$IPA_NAME"
else
    log "   - ⚠️ IPA not found at expected path: output/ios/$IPA_NAME"
fi

# Process artifact URLs
log "📦 Processing artifact URLs for email notification..."
source "lib/scripts/utils/process_artifacts.sh"
artifact_urls=$(process_artifacts)
log "Artifact URLs: $artifact_urls"

# Send build success email
log "🎉 Build successful! Sending success email..."
if [ -f "lib/scripts/utils/send_ios_emails.py" ]; then
    # Use the Python script for iOS emails
    python3 lib/scripts/utils/send_ios_emails.py "build_success" --build-id "${CM_BUILD_ID:-unknown}" --artifact-urls "$artifact_urls"
elif [ -f "lib/scripts/utils/send_email.sh" ]; then
    # Fallback to shell script if Python script fails
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "iOS" "${CM_BUILD_ID:-unknown}" "Build successful" "$artifact_urls"
fi

log "✅ iOS build process completed successfully!"
exit 0 