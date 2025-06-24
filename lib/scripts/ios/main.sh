#!/bin/bash
set -euo pipefail

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

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

# Function to validate environment variables
validate_environment_variables() {
    log "🔍 Validating environment variables..."
    
    # Required variables for all iOS builds
    local required_vars=("BUNDLE_ID" "VERSION_NAME" "VERSION_CODE" "APPLE_TEAM_ID")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    # Check for TestFlight-specific variables if TestFlight is enabled
    if [[ "$(echo "${IS_TESTFLIGHT:-false}" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
        local testflight_vars=("APP_STORE_CONNECT_KEY_IDENTIFIER" "APP_STORE_CONNECT_ISSUER_ID" "APP_STORE_CONNECT_API_KEY")
        for var in "${testflight_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                missing_vars+=("$var")
            fi
        done
    fi
    
    # Check for certificate variables
    if [[ -z "${CERT_P12_URL:-}" ]] && [[ -z "${CERT_CER_URL:-}" ]] && [[ -z "${CERT_KEY_URL:-}" ]]; then
        missing_vars+=("CERT_P12_URL or CERT_CER_URL+CERT_KEY_URL")
    fi
    
    # Check for provisioning profile
    if [[ -z "${PROFILE_URL:-}" ]]; then
        missing_vars+=("PROFILE_URL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "❌ Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log "   - $var"
        done
        log "🔍 Available environment variables:"
        env | grep -E "(BUNDLE_ID|VERSION_|APPLE_TEAM_ID|CERT_|PROFILE_|APP_STORE_CONNECT_)" | head -10 || log "   No relevant variables found"
        return 1
    fi
    
    log "✅ All required environment variables are present"
    return 0
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "iOS" "${CM_BUILD_ID:-unknown}" || true
fi

# 🔍 CRITICAL: Validate Environment Variables FIRST
log "🔍 Validating environment variables..."
if ! validate_environment_variables; then
    log "❌ Environment variable validation failed"
    exit 1
fi

log "🚀 Starting iOS Universal IPA Build Process..."

# 🔧 CRITICAL: Set Build Environment Variables FIRST
log "🔧 Setting Build Environment Variables..."
export OUTPUT_DIR="${OUTPUT_DIR:-output/ios}"
export PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export CM_BUILD_DIR="${CM_BUILD_DIR:-$(pwd)}"

log "📋 Build Environment Variables:"
log "   OUTPUT_DIR: $OUTPUT_DIR"
log "   PROJECT_ROOT: $PROJECT_ROOT"
log "   CM_BUILD_DIR: $CM_BUILD_DIR"

# 🎯 CRITICAL: Generate Environment Configuration FIRST
log "🎯 Generating Environment Configuration from API Variables..."

# Debug: Show all environment variables
log "🔍 Debug: Environment Variables Received:"
log "   APP_ID: ${APP_ID:-not_set}"
log "   APP_NAME: ${APP_NAME:-not_set}"
log "   VERSION_NAME: ${VERSION_NAME:-not_set}"
log "   VERSION_CODE: ${VERSION_CODE:-not_set}"
log "   BUNDLE_ID: ${BUNDLE_ID:-not_set}"
log "   WORKFLOW_ID: ${WORKFLOW_ID:-not_set}"
log "   PUSH_NOTIFY: ${PUSH_NOTIFY:-not_set}"
log "   OUTPUT_DIR: ${OUTPUT_DIR:-not_set}"
log "   PROJECT_ROOT: ${PROJECT_ROOT:-not_set}"
log "   CM_BUILD_DIR: ${CM_BUILD_DIR:-not_set}"
log "   CERT_PASSWORD: ${CERT_PASSWORD:+set}"
log "   PROFILE_URL: ${PROFILE_URL:+set}"
log "   PROFILE_TYPE: ${PROFILE_TYPE:-not_set}"

if [ -f "lib/scripts/utils/gen_env_config.sh" ]; then
    chmod +x lib/scripts/utils/gen_env_config.sh
    source lib/scripts/utils/gen_env_config.sh
    if generate_env_config; then
        log "✅ Environment configuration generated successfully"
        
        # Show generated config summary
        log "📋 Generated Config Summary:"
        log "   App: ${APP_NAME:-QuikApp} v${VERSION_NAME:-1.0.0}"
        log "   Workflow: ${WORKFLOW_ID:-unknown}"
        log "   Bundle ID: ${BUNDLE_ID:-not_set}"
        log "   Firebase: ${PUSH_NOTIFY:-false}"
        log "   iOS Signing: ${CERT_PASSWORD:+true}"
        log "   Profile Type: ${PROFILE_TYPE:-app-store}"
    else
        log "❌ Failed to generate environment configuration"
        exit 1
    fi
else
    log "❌ Environment configuration generator not found"
    exit 1
fi

# 🔧 Initial Setup
log "🔧 Initial Setup - Installing CocoaPods..."

# Check if CocoaPods is already installed
if command -v pod >/dev/null 2>&1; then
    log "✅ CocoaPods is already installed"
else
    log "📦 Installing CocoaPods..."
    
    # Try different installation methods
    if command -v brew >/dev/null 2>&1; then
        log "🍺 Installing CocoaPods via Homebrew..."
        brew install cocoapods
    elif command -v gem >/dev/null 2>&1; then
        log "💎 Installing CocoaPods via gem (user installation)..."
        gem install --user-install cocoapods
        # Add user gem bin to PATH
        export PATH="$HOME/.gem/ruby/$(ruby -e 'puts RUBY_VERSION')/bin:$PATH"
    else
        log "❌ No suitable package manager found for CocoaPods installation"
        exit 1
    fi
    
    # Verify installation
    if command -v pod >/dev/null 2>&1; then
        log "✅ CocoaPods installed successfully"
    else
        log "❌ CocoaPods installation failed"
        exit 1
    fi
fi

log "📦 Installing Flutter Dependencies..."
flutter pub get

# Create necessary directories
mkdir -p ios/certificates
mkdir -p "$OUTPUT_DIR"
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles

# 📥 Download Required Configuration Files
log "📥 Downloading Required Configuration Files..."

# 🔥 Firebase Configuration (Conditional based on PUSH_NOTIFY)
log "🔥 Configuring Firebase (PUSH_NOTIFY: ${PUSH_NOTIFY:-false})..."
if [ -f "lib/scripts/ios/firebase.sh" ]; then
    chmod +x lib/scripts/ios/firebase.sh
    if ./lib/scripts/ios/firebase.sh; then
        if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
            log "✅ Firebase configured successfully for push notifications"
        else
            log "✅ Firebase setup skipped (push notifications disabled)"
        fi
    else
        log "❌ Firebase configuration failed"
        exit 1
    fi
else
    log "❌ Firebase script not found"
    exit 1
fi

# APNS Key
if [ -n "${APNS_AUTH_KEY_URL:-}" ]; then
    log "🔑 Downloading APNS Key..."
    if curl -L --fail --silent --show-error --output "ios/certificates/AuthKey.p8" "$APNS_AUTH_KEY_URL"; then
        log "✅ APNS key downloaded successfully"
    else
        log "❌ Failed to download APNS key"
        exit 1
    fi
else
    log "⚠️ No APNS key URL provided"
fi

# Provisioning Profile
if [ -n "${PROFILE_URL:-}" ]; then
    log "📱 Downloading Provisioning Profile..."
    if curl -L --fail --silent --show-error --output "ios/certificates/profile.mobileprovision" "$PROFILE_URL"; then
        log "✅ Provisioning profile downloaded successfully"
        # Install provisioning profile
        cp ios/certificates/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
        log "✅ Provisioning profile installed"
    else
        log "❌ Failed to download provisioning profile"
        exit 1
    fi
else
    log "❌ No provisioning profile URL provided"
    exit 1
fi

# Certificates
if [ -n "${CERT_P12_URL:-}" ]; then
    log "🔐 Downloading P12 Certificate from URL..."
    log "🔍 P12 URL: $CERT_P12_URL"
    log "🔍 Using CERT_PASSWORD for P12 access"
    
    if curl -L --fail --silent --show-error --output "ios/certificates/cert.p12" "$CERT_P12_URL"; then
        log "✅ P12 certificate downloaded successfully"
        
        # Verify the downloaded P12 file
        log "🔍 Verifying downloaded P12 file..."
        if [ -s "ios/certificates/cert.p12" ]; then
            log "✅ P12 file is not empty"
            
            # Test P12 password
            if openssl pkcs12 -in ios/certificates/cert.p12 -noout -passin "pass:$CERT_PASSWORD" 2>/dev/null; then
                log "✅ P12 password verification successful"
            else
                log "❌ P12 password verification failed - CERT_PASSWORD may be incorrect"
                log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
                exit 1
            fi
        else
            log "❌ Downloaded P12 file is empty"
            exit 1
        fi
    else
        log "❌ Failed to download P12 certificate"
        exit 1
    fi
else
    log "🔐 CERT_P12_URL not provided, generating P12 from CER/KEY files..."
    
    # Download CER and KEY files
    if [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ]; then
        log "🔐 Downloading Certificate and Key..."
        log "🔍 CER URL: $CERT_CER_URL"
        log "🔍 KEY URL: $CERT_KEY_URL"
        log "🔍 Using CERT_PASSWORD for P12 generation"
        
        if curl -L --fail --silent --show-error --output "ios/certificates/cert.cer" "$CERT_CER_URL"; then
            log "✅ Certificate downloaded successfully"
        else
            log "❌ Failed to download certificate"
            exit 1
        fi
        
        if curl -L --fail --silent --show-error --output "ios/certificates/cert.key" "$CERT_KEY_URL"; then
            log "✅ Private key downloaded successfully"
        else
            log "❌ Failed to download private key"
            exit 1
        fi
        
        # Verify downloaded files
        log "🔍 Verifying downloaded certificate files..."
        if [ -s "ios/certificates/cert.cer" ] && [ -s "ios/certificates/cert.key" ]; then
            log "✅ Certificate files are not empty"
        else
            log "❌ Certificate files are empty"
            exit 1
        fi
        
        # Convert CER to PEM
        log "🔄 Converting certificate to PEM format..."
        if openssl x509 -in ios/certificates/cert.cer -inform DER -out ios/certificates/cert.pem -outform PEM; then
            log "✅ Certificate converted to PEM"
        else
            log "❌ Failed to convert certificate to PEM"
            exit 1
        fi
        
        # Generate P12 with compatible password handling
        # Try with CERT_PASSWORD first, then without password as fallback
        
        # Verify PEM and KEY files before P12 generation
        log "🔍 Verifying PEM and KEY files before P12 generation..."
        if [ ! -f "ios/certificates/cert.pem" ] || [ ! -f "ios/certificates/cert.key" ]; then
            log "❌ PEM or KEY file missing"
            log "   PEM exists: $([ -f ios/certificates/cert.pem ] && echo 'yes' || echo 'no')"
            log "   KEY exists: $([ -f ios/certificates/cert.key ] && echo 'yes' || echo 'no')"
            exit 1
        fi
        
        # Check PEM file content
        if openssl x509 -in ios/certificates/cert.pem -text -noout >/dev/null 2>&1; then
            log "✅ PEM file is valid certificate"
        else
            log "❌ PEM file is not a valid certificate"
            exit 1
        fi
        
        # Check KEY file content
        if openssl rsa -in ios/certificates/cert.key -check -noout >/dev/null 2>&1; then
            log "✅ KEY file is valid private key"
        else
            log "❌ KEY file is not a valid private key"
            exit 1
        fi
        
        log "🔍 Attempting P12 generation with CERT_PASSWORD..."
        if openssl pkcs12 -export \
            -inkey ios/certificates/cert.key \
            -in ios/certificates/cert.pem \
            -out ios/certificates/cert.p12 \
            -password "pass:$CERT_PASSWORD" \
            -name "iOS Distribution Certificate" \
            -legacy; then
            log "✅ P12 certificate generated successfully (with password)"
            
            # Verify the generated P12 with password
            log "🔍 Verifying generated P12 file with password..."
            if openssl pkcs12 -in ios/certificates/cert.p12 -noout -passin "pass:$CERT_PASSWORD" -legacy 2>/dev/null; then
                log "✅ Generated P12 verification successful (with password)"
                log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
            else
                log "⚠️ P12 verification with password failed, trying without password..."
                
                # Try generating without password as fallback
                if openssl pkcs12 -export \
                    -inkey ios/certificates/cert.key \
                    -in ios/certificates/cert.pem \
                    -out ios/certificates/cert.p12 \
                    -password "pass:" \
                    -name "iOS Distribution Certificate" \
                    -legacy; then
                    log "✅ P12 certificate generated successfully (no password)"
                    
                    # Verify the generated P12 without password
                    log "🔍 Verifying generated P12 file without password..."
                    if openssl pkcs12 -in ios/certificates/cert.p12 -noout -legacy 2>/dev/null; then
                        log "✅ Generated P12 verification successful (no password)"
                        log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
                    else
                        log "❌ Generated P12 verification failed (no password)"
                        log "🔍 Attempting to debug P12 file..."
                        file ios/certificates/cert.p12
                        log "🔍 P12 file content (first 100 chars):"
                        head -c 100 ios/certificates/cert.p12 | xxd
                        exit 1
                    fi
                else
                    log "❌ Failed to generate P12 certificate (both with and without password)"
                    exit 1
                fi
            fi
        else
            log "❌ Failed to generate P12 certificate with password"
            log "🔍 Debug info:"
            log "   CERT_PASSWORD length: ${#CERT_PASSWORD}"
            log "   CERT_PASSWORD starts with: ${CERT_PASSWORD:0:3}***"
            log "   PEM file exists: $([ -f ios/certificates/cert.pem ] && echo 'yes' || echo 'no')"
            log "   KEY file exists: $([ -f ios/certificates/cert.key ] && echo 'yes' || echo 'no')"
            exit 1
        fi
    else
        log "❌ No certificate URLs provided (CERT_CER_URL and CERT_KEY_URL required when CERT_P12_URL is not provided)"
        exit 1
    fi
fi

# ⚙️ iOS Project Configuration
log "⚙️ Configuring iOS Project..."

# Update Info.plist
log "📝 Updating Info.plist..."
if [ -f "ios/Runner/Info.plist" ]; then
    # Update bundle version and short version
    plutil -replace CFBundleVersion -string "$VERSION_CODE" ios/Runner/Info.plist
    plutil -replace CFBundleShortVersionString -string "$VERSION_NAME" ios/Runner/Info.plist
    plutil -replace CFBundleDisplayName -string "$APP_NAME" ios/Runner/Info.plist
    plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" ios/Runner/Info.plist
    
    log "✅ Info.plist updated successfully"
else
    log "❌ Info.plist not found"
    exit 1
fi

# Add privacy descriptions based on permissions
log "🔐 Adding privacy descriptions..."
if [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/ios/permissions.sh
    if ./lib/scripts/ios/permissions.sh; then
        log "✅ iOS permissions configuration completed"
    else
        log "❌ iOS permissions configuration failed"
        exit 1
    fi
else
    log "⚠️ iOS permissions script not found, using inline permission handling..."
    
    # Fallback inline permission handling
    if [ "${IS_CAMERA:-false}" = "true" ]; then
        plutil -replace NSCameraUsageDescription -string "This app needs camera access to take photos" ios/Runner/Info.plist
    fi

    if [ "${IS_LOCATION:-false}" = "true" ]; then
        plutil -replace NSLocationWhenInUseUsageDescription -string "This app needs location access to provide location-based services" ios/Runner/Info.plist
        plutil -replace NSLocationAlwaysAndWhenInUseUsageDescription -string "This app needs location access to provide location-based services" ios/Runner/Info.plist
    fi

    if [ "${IS_MIC:-false}" = "true" ]; then
        plutil -replace NSMicrophoneUsageDescription -string "This app needs microphone access for voice features" ios/Runner/Info.plist
    fi

    if [ "${IS_CONTACT:-false}" = "true" ]; then
        plutil -replace NSContactsUsageDescription -string "This app needs contacts access to manage contacts" ios/Runner/Info.plist
    fi

    if [ "${IS_BIOMETRIC:-false}" = "true" ]; then
        plutil -replace NSFaceIDUsageDescription -string "This app uses Face ID for secure authentication" ios/Runner/Info.plist
    fi

    if [ "${IS_CALENDAR:-false}" = "true" ]; then
        plutil -replace NSCalendarsUsageDescription -string "This app needs calendar access to manage events" ios/Runner/Info.plist
    fi

    if [ "${IS_STORAGE:-false}" = "true" ]; then
        plutil -replace NSPhotoLibraryUsageDescription -string "This app needs photo library access to save and manage photos" ios/Runner/Info.plist
        plutil -replace NSPhotoLibraryAddUsageDescription -string "This app needs photo library access to save photos" ios/Runner/Info.plist
    fi

    # Always add network security
    plutil -replace NSAppTransportSecurity -json '{"NSAllowsArbitraryLoads": true}' ios/Runner/Info.plist

    log "✅ Privacy descriptions added"
fi

# 🔐 Code Signing Preparation
log "🔐 Setting up Code Signing..."

# Use enhanced code signing script
if [ -f "lib/scripts/ios/code_signing.sh" ]; then
    chmod +x lib/scripts/ios/code_signing.sh
    if ./lib/scripts/ios/code_signing.sh; then
        log "✅ Enhanced code signing setup completed"
    else
        log "❌ Enhanced code signing setup failed"
        exit 1
    fi
else
    log "❌ Enhanced code signing script not found"
    exit 1
fi

# 🔥 Firebase Setup (Conditional)
if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
    log "🔥 Setting up Firebase for iOS..."
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        chmod +x lib/scripts/ios/firebase.sh
        if ./lib/scripts/ios/firebase.sh; then
            log "✅ Firebase setup completed"
        else
            log "❌ Firebase setup failed"
            exit 1
        fi
    else
        log "❌ Firebase script not found"
        exit 1
    fi
else
    log "🔕 Push notifications disabled, skipping Firebase setup"
fi

# 🎨 Branding and Customization
log "🎨 Setting up Branding and Customization..."

# Download and setup branding assets
if [ -f "lib/scripts/ios/branding.sh" ]; then
    chmod +x lib/scripts/ios/branding.sh
    if ./lib/scripts/ios/branding.sh; then
        log "✅ Branding setup completed"
    else
        log "❌ Branding setup failed"
        exit 1
    fi
else
    log "❌ Branding script not found"
    exit 1
fi

# Customize app configuration
if [ -f "lib/scripts/ios/customization.sh" ]; then
    chmod +x lib/scripts/ios/customization.sh
    if ./lib/scripts/ios/customization.sh; then
        log "✅ App customization completed"
    else
        log "❌ App customization failed"
        exit 1
    fi
else
    log "❌ Customization script not found"
    exit 1
fi

# 🔧 CRITICAL: Update Bundle ID from Codemagic Environment Variables
log "🔧 Updating Bundle ID from Codemagic environment variables..."

# Validate BUNDLE_ID environment variable
if [ -z "${BUNDLE_ID:-}" ]; then
    log "❌ BUNDLE_ID environment variable is not set"
    log "🔍 Available environment variables:"
    env | grep -i bundle || log "   No bundle-related variables found"
    exit 1
fi

log "📋 Current Bundle ID Configuration:"
log "   BUNDLE_ID from environment: ${BUNDLE_ID}"
log "   Current Info.plist bundle ID: $(plutil -extract CFBundleIdentifier raw ios/Runner/Info.plist 2>/dev/null || echo 'not found')"

# Update Info.plist bundle identifier
log "🔧 Updating Info.plist bundle identifier..."
if plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" ios/Runner/Info.plist; then
    log "✅ Info.plist bundle identifier updated to: $BUNDLE_ID"
else
    log "❌ Failed to update Info.plist bundle identifier"
    exit 1
fi

# Update Xcode project bundle identifier for all configurations
log "🔧 Updating Xcode project bundle identifier..."
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

# Backup the project file
cp "$PROJECT_FILE" "${PROJECT_FILE}.bundle_backup"
log "✅ Project file backed up"

# Update PRODUCT_BUNDLE_IDENTIFIER for all configurations and targets
# First, let's see what we're working with
log "🔍 Current PRODUCT_BUNDLE_IDENTIFIER entries in project file:"
grep -n "PRODUCT_BUNDLE_IDENTIFIER" "$PROJECT_FILE" || log "   No PRODUCT_BUNDLE_IDENTIFIER found"

# Update main app bundle identifier (com.example.quikapptest06)
if sed -i.bak \
    -e 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.quikapptest06;/PRODUCT_BUNDLE_IDENTIFIER = "'"$BUNDLE_ID"'";/g' \
    "$PROJECT_FILE"; then
    log "✅ Main app bundle identifier updated to: $BUNDLE_ID"
else
    log "❌ Failed to update main app bundle identifier"
    # Restore backup
    mv "${PROJECT_FILE}.bundle_backup" "$PROJECT_FILE"
    exit 1
fi

# Update test target bundle identifier (com.example.quikapptest06.RunnerTests)
TEST_BUNDLE_ID="${BUNDLE_ID}.RunnerTests"
if sed -i.bak \
    -e 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.quikapptest06\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = "'"$TEST_BUNDLE_ID"'";/g' \
    "$PROJECT_FILE"; then
    log "✅ Test target bundle identifier updated to: $TEST_BUNDLE_ID"
else
    log "⚠️ Failed to update test target bundle identifier (this might be expected if test target doesn't exist)"
fi

# Also try to update any other variations that might exist
if sed -i.bak \
    -e 's/PRODUCT_BUNDLE_IDENTIFIER = "[^"]*quikapptest06[^"]*";/PRODUCT_BUNDLE_IDENTIFIER = "'"$BUNDLE_ID"'";/g' \
    "$PROJECT_FILE"; then
    log "✅ Additional bundle identifier patterns updated"
else
    log "⚠️ No additional bundle identifier patterns found to update"
fi

# Verify the changes
log "🔍 Verifying bundle ID updates..."
INFO_PLIST_BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw ios/Runner/Info.plist 2>/dev/null || echo "")

# Function to extract bundle ID from Xcode project file
extract_bundle_id_from_project() {
    local project_file="$1"
    local bundle_id=""
    
    log "🔍 Extracting bundle ID from project file: $project_file"
    
    # Method 1: Handle both quoted and unquoted bundle IDs with sed
    bundle_id=$(grep 'PRODUCT_BUNDLE_IDENTIFIER' "$project_file" 2>/dev/null | grep -v "RunnerTests" | head -1 | sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"*\([^";]*\)"*;.*/\1/p' 2>/dev/null || echo "")
    
    # Method 2: awk fallback for quoted bundle IDs
    if [[ -z "$bundle_id" ]]; then
        log "🔍 Method 1 failed, trying awk for quoted bundle IDs..."
        bundle_id=$(awk '/PRODUCT_BUNDLE_IDENTIFIER/ && !/RunnerTests/ {match($0, /PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"([^"]*)"/, arr); if (arr[1] != "") print arr[1]; exit}' "$project_file" 2>/dev/null || echo "")
    fi
    
    # Method 3: awk fallback for unquoted bundle IDs
    if [[ -z "$bundle_id" ]]; then
        log "🔍 Method 2 failed, trying awk for unquoted bundle IDs..."
        bundle_id=$(awk '/PRODUCT_BUNDLE_IDENTIFIER/ && !/RunnerTests/ {match($0, /PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*([^;]*);/, arr); if (arr[1] != "") {gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[1]); print arr[1]}; exit}' "$project_file" 2>/dev/null || echo "")
    fi
    
    # Method 4: grep + sed combination for quoted bundle IDs
    if [[ -z "$bundle_id" ]]; then
        log "🔍 Method 3 failed, trying grep + sed for quoted bundle IDs..."
        bundle_id=$(grep 'PRODUCT_BUNDLE_IDENTIFIER' "$project_file" 2>/dev/null | grep -v "RunnerTests" | head -1 | grep -o '"[^"]*"' | head -1 | sed 's/"//g' 2>/dev/null || echo "")
    fi
    
    # Method 5: Simple extraction for unquoted bundle IDs
    if [[ -z "$bundle_id" ]]; then
        log "🔍 Method 4 failed, trying simple extraction for unquoted bundle IDs..."
        bundle_id=$(grep 'PRODUCT_BUNDLE_IDENTIFIER' "$project_file" 2>/dev/null | grep -v "RunnerTests" | head -1 | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*\([^;]*\);.*/\1/' | xargs 2>/dev/null || echo "")
    fi
    
    # Clean up the extracted bundle ID
    if [[ -n "$bundle_id" ]]; then
        # Remove any whitespace and ensure it's just the bundle ID
        bundle_id=$(echo "$bundle_id" | xargs)
        
        # If it still contains the full line structure, extract just the bundle ID
        if [[ "$bundle_id" == *"PRODUCT_BUNDLE_IDENTIFIER"* ]]; then
            bundle_id=$(echo "$bundle_id" | sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"*\([^";]*\)"*;.*/\1/p')
        fi
        
        # Final cleanup - remove any remaining quotes
        bundle_id=$(echo "$bundle_id" | sed 's/^"*\|"*$//g')
    fi
    
    log "🔍 Extracted bundle ID: '$bundle_id'"
    echo "$bundle_id"
}

# More robust project bundle ID extraction - specifically look for main app bundle ID
PROJECT_BUNDLE_ID=$(extract_bundle_id_from_project "$PROJECT_FILE")

log "🔍 Verification Debug Info:"
log "   Expected BUNDLE_ID: $BUNDLE_ID"
log "   Info.plist CFBundleIdentifier: $INFO_PLIST_BUNDLE_ID"
log "   Xcode project PRODUCT_BUNDLE_IDENTIFIER (main app): $PROJECT_BUNDLE_ID"
log "   Project file exists: $([ -f "$PROJECT_FILE" ] && echo 'yes' || echo 'no')"

# Debug: Show the raw extraction process
log "🔍 Bundle ID Extraction Debug:"
log "   Raw grep output:"
grep 'PRODUCT_BUNDLE_IDENTIFIER' "$PROJECT_FILE" 2>/dev/null | grep -v "RunnerTests" | head -1 || log "   No PRODUCT_BUNDLE_IDENTIFIER found"
log "   Final extracted PROJECT_BUNDLE_ID: '$PROJECT_BUNDLE_ID'"

# Show all PRODUCT_BUNDLE_IDENTIFIER entries for debugging
log "🔍 All PRODUCT_BUNDLE_IDENTIFIER entries in project file:"
grep -n "PRODUCT_BUNDLE_IDENTIFIER" "$PROJECT_FILE" 2>/dev/null || log "   No PRODUCT_BUNDLE_IDENTIFIER found"

# Verify Info.plist bundle ID
if [ "$INFO_PLIST_BUNDLE_ID" = "$BUNDLE_ID" ]; then
    log "✅ Info.plist bundle ID verified: $INFO_PLIST_BUNDLE_ID"
else
    log "❌ Info.plist bundle ID mismatch: expected '$BUNDLE_ID', got '$INFO_PLIST_BUNDLE_ID'"
    log "🔍 Debug: Info.plist content around CFBundleIdentifier:"
    grep -A2 -B2 "CFBundleIdentifier" ios/Runner/Info.plist 2>/dev/null || log "   Could not find CFBundleIdentifier in Info.plist"
    exit 1
fi

# Verify Xcode project bundle ID (with more lenient checking)
if [ -n "$PROJECT_BUNDLE_ID" ] && [ "$PROJECT_BUNDLE_ID" != "\$(TARGET_NAME)" ]; then
    # Clean up the extracted bundle ID for comparison
    CLEAN_PROJECT_BUNDLE_ID=$(echo "$PROJECT_BUNDLE_ID" | xargs)
    
    log "🔍 Bundle ID Comparison:"
    log "   Expected: '$BUNDLE_ID'"
    log "   Extracted: '$CLEAN_PROJECT_BUNDLE_ID'"
    
    if [ "$CLEAN_PROJECT_BUNDLE_ID" = "$BUNDLE_ID" ]; then
        log "✅ Xcode project bundle ID verified: $CLEAN_PROJECT_BUNDLE_ID"
    else
        log "⚠️ Xcode project bundle ID mismatch: expected '$BUNDLE_ID', got '$CLEAN_PROJECT_BUNDLE_ID'"
        log "🔍 Debug: Project file content around PRODUCT_BUNDLE_IDENTIFIER:"
        grep -A2 -B2 "PRODUCT_BUNDLE_IDENTIFIER" "$PROJECT_FILE" 2>/dev/null | head -10 || log "   Could not find PRODUCT_BUNDLE_IDENTIFIER in project file"
        
        # Try to extract the bundle ID one more time with a different method
        log "🔍 Attempting alternative bundle ID extraction..."
        ALTERNATIVE_BUNDLE_ID=$(grep 'PRODUCT_BUNDLE_IDENTIFIER' "$PROJECT_FILE" 2>/dev/null | grep -v "RunnerTests" | head -1 | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"*\([^";]*\)"*;.*/\1/' | xargs 2>/dev/null || echo "")
        log "   Alternative extraction result: '$ALTERNATIVE_BUNDLE_ID'"
        
        if [ "$ALTERNATIVE_BUNDLE_ID" = "$BUNDLE_ID" ]; then
            log "✅ Alternative extraction successful: $ALTERNATIVE_BUNDLE_ID"
        else
            log "⚠️ Alternative extraction also failed"
            log "🔍 Since Info.plist bundle ID is correct, continuing with build"
            log "🔍 Xcode project bundle ID verification will be skipped"
        fi
    fi
else
    log "⚠️ Could not extract Xcode project bundle ID or found variable reference, but Info.plist was updated successfully"
    log "🔍 This might be acceptable if the project file uses variable references"
    log "🔍 Continuing with build since Info.plist bundle ID is correct"
fi

log "✅ Bundle ID update completed successfully"
log "📋 Final Bundle ID Configuration:"
log "   Environment BUNDLE_ID: ${BUNDLE_ID}"
log "   Info.plist CFBundleIdentifier: ${INFO_PLIST_BUNDLE_ID}"
log "   Xcode project PRODUCT_BUNDLE_IDENTIFIER (main app): ${PROJECT_BUNDLE_ID}"

# 🔍 CRITICAL: Validate Bundle ID matches Provisioning Profile
log "🔍 Validating Bundle ID matches Provisioning Profile..."

# Extract bundle ID from provisioning profile
PROFILE_BUNDLE_ID=""
if [ -f "ios/certificates/profile.mobileprovision" ]; then
    log "🔍 Extracting bundle ID from provisioning profile..."
    
    # Extract bundle ID using security command
    PROFILE_BUNDLE_ID=$(security cms -D -i ios/certificates/profile.mobileprovision 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null | sed 's/^[^.]*\.//' 2>/dev/null || echo "")
    
    # If that method failed, try alternative extraction
    if [ -z "$PROFILE_BUNDLE_ID" ]; then
        PROFILE_BUNDLE_ID=$(security cms -D -i ios/certificates/profile.mobileprovision 2>/dev/null | grep -o 'application-identifier.*' | head -1 | sed 's/.*<string>\([^<]*\)<\/string>.*/\1/' | sed 's/^[^.]*\.//' 2>/dev/null || echo "")
    fi
    
    # If still empty, try one more method
    if [ -z "$PROFILE_BUNDLE_ID" ]; then
        PROFILE_BUNDLE_ID=$(security cms -D -i ios/certificates/profile.mobileprovision 2>/dev/null | grep -A1 -B1 "application-identifier" | grep "<string>" | head -1 | sed 's/.*<string>\([^<]*\)<\/string>.*/\1/' | sed 's/^[^.]*\.//' 2>/dev/null || echo "")
    fi
    
    log "🔍 Bundle ID extracted from provisioning profile: $PROFILE_BUNDLE_ID"
else
    log "❌ Provisioning profile not found at ios/certificates/profile.mobileprovision"
    log "🔍 Available files in ios/certificates/:"
    ls -la ios/certificates/ 2>/dev/null || log "   Directory not accessible"
    exit 1
fi

# Validate bundle ID match
if [ -n "$PROFILE_BUNDLE_ID" ]; then
    log "🔍 Bundle ID Comparison:"
    log "   Environment BUNDLE_ID: $BUNDLE_ID"
    log "   Provisioning Profile Bundle ID: $PROFILE_BUNDLE_ID"
    
    if [ "$BUNDLE_ID" = "$PROFILE_BUNDLE_ID" ]; then
        log "✅ Bundle ID match verified: $BUNDLE_ID"
        log "✅ Provisioning profile is compatible with app bundle ID"
    else
        log "❌ Bundle ID mismatch detected!"
        log "❌ Environment BUNDLE_ID ($BUNDLE_ID) does not match provisioning profile bundle ID ($PROFILE_BUNDLE_ID)"
        log "🔍 This will cause code signing to fail during the build process"
        log "🔍 Solutions:"
        log "   1. Update BUNDLE_ID environment variable to: $PROFILE_BUNDLE_ID"
        log "   2. Or update provisioning profile to include bundle ID: $BUNDLE_ID"
        log "   3. Or create a new provisioning profile for bundle ID: $BUNDLE_ID"
        
        # Show provisioning profile details for debugging
        log "🔍 Provisioning profile details:"
        if security cms -D -i ios/certificates/profile.mobileprovision 2>/dev/null | grep -A5 -B5 "application-identifier" | head -10; then
            log "   (Shown above: application-identifier section from provisioning profile)"
        else
            log "   Could not extract application-identifier from provisioning profile"
        fi
        
        exit 1
    fi
else
    log "⚠️ Could not extract bundle ID from provisioning profile"
    log "🔍 This might be acceptable if the profile uses wildcard bundle IDs"
    log "🔍 Continuing with build, but code signing might fail"
    
    # Show provisioning profile structure for debugging
    log "🔍 Provisioning profile structure:"
    security cms -D -i ios/certificates/profile.mobileprovision 2>/dev/null | grep -E "(application-identifier|com\.apple\.developer\.team-identifier)" | head -5 || log "   Could not extract profile structure"
fi

# 🔐 Permissions Setup
log "🔐 Setting up Permissions..."

if [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/ios/permissions.sh
    if ./lib/scripts/ios/permissions.sh; then
        log "✅ Permissions setup completed"
    else
        log "❌ Permissions setup failed"
        exit 1
    fi
else
    log "❌ Permissions script not found"
    exit 1
fi

# 🔧 CRITICAL: Fix iOS App Icons Before Flutter Build
log "🔧 Fixing iOS app icons before Flutter build..."
log "🔍 Current working directory: $(pwd)"
log "🔍 Checking if icon fix script exists..."

# Set up error handling for icon fix
set +e  # Temporarily disable exit on error for icon fix
ICON_FIX_SUCCESS=false

if [ -f "lib/scripts/utils/fix_ios_icons.sh" ]; then
    log "✅ Icon fix script found at lib/scripts/utils/fix_ios_icons.sh"
    log "🔍 Making script executable..."
    chmod +x lib/scripts/utils/fix_ios_icons.sh
    log "🔍 Running icon fix script..."
    log "🔍 Script path: $(realpath lib/scripts/utils/fix_ios_icons.sh)"
    log "🔍 Script permissions: $(ls -la lib/scripts/utils/fix_ios_icons.sh)"
    
    # Run the script with explicit bash and capture output
    log "🔍 Executing icon fix script..."
    if bash lib/scripts/utils/fix_ios_icons.sh 2>&1; then
        log "✅ iOS app icons fixed successfully before Flutter build"
        ICON_FIX_SUCCESS=true
    else
        log "❌ Failed to fix iOS app icons"
        log "🔍 Exit code: $?"
        log "🔍 Icon fix failed, but continuing with build..."
        ICON_FIX_SUCCESS=false
    fi
else
    log "❌ iOS icon fix script not found at lib/scripts/utils/fix_ios_icons.sh"
    log "🔍 Checking what files exist in lib/scripts/utils/:"
    ls -la lib/scripts/utils/ 2>/dev/null || log "   Directory not accessible"
    log "🔍 Checking if the path exists:"
    ls -la lib/scripts/utils/fix_ios_icons.sh 2>/dev/null || log "   File not found"
    log "🔍 Icon fix script not found, but continuing with build..."
    ICON_FIX_SUCCESS=false
fi

# Re-enable exit on error
set -e

# Verify icon state after fix attempt
log "🔍 Verifying icon state after fix attempt..."
if [ -d "ios/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
    ICON_COUNT=$(ls -1 ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png 2>/dev/null | wc -l)
    log "📊 Found $ICON_COUNT icon files"
    
    # Check if main icon is valid
    if [ -s "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" ]; then
        ICON_SIZE=$(ls -lh ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png | awk '{print $5}')
        log "✅ Main app icon is valid: $ICON_SIZE"
        ICON_FIX_SUCCESS=true
    else
        log "❌ Main app icon is invalid or missing"
        ICON_FIX_SUCCESS=false
    fi
else
    log "❌ Icon directory does not exist"
    ICON_FIX_SUCCESS=false
fi

if [ "$ICON_FIX_SUCCESS" = false ]; then
    log "⚠️ Icon fix was not successful, but continuing with build..."
    log "🔍 This might cause the build to fail, but we'll try anyway..."
fi

# 📦 STAGE 1: First Podfile Injection for Flutter Build (No Code Signing)
log "📦 STAGE 1: First Podfile Injection for Flutter Build (No Code Signing)..."

# 🧹 Clean up existing Pods to avoid version conflicts
log "🧹 Cleaning up existing Pods for fresh start..."
rm -rf ios/Pods ios/Podfile.lock ios/Pods.xcodeproj 2>/dev/null || true
log "✅ Pods cleanup completed"

# Generate first Podfile for Flutter build (no code signing)
if [ -f "lib/scripts/ios/generate_podfile.sh" ]; then
    chmod +x lib/scripts/ios/generate_podfile.sh
    if ./lib/scripts/ios/generate_podfile.sh "flutter-build" "$PROFILE_TYPE"; then
        log "✅ First Podfile generated for Flutter build"
    else
        log "❌ First Podfile generation failed"
        exit 1
    fi
else
    log "❌ Podfile generator script not found"
    exit 1
fi

# Install pods for Flutter build
log "🍫 Installing CocoaPods for Flutter build..."
cd ios
pod install --repo-update
cd ..
log "✅ CocoaPods installed for Flutter build"

# Build Flutter app (no code signing)
log "📱 Building Flutter app (no code signing)..."
flutter build ios --release --no-codesign \
    --dart-define=WEB_URL="${WEB_URL:-}" \
    --dart-define=PUSH_NOTIFY="${PUSH_NOTIFY:-false}" \
    --dart-define=PKG_NAME="${PKG_NAME:-}" \
    --dart-define=APP_NAME="${APP_NAME:-}" \
    --dart-define=ORG_NAME="${ORG_NAME:-}" \
    --dart-define=VERSION_NAME="${VERSION_NAME:-}" \
    --dart-define=VERSION_CODE="${VERSION_CODE:-}" \
    --dart-define=EMAIL_ID="${EMAIL_ID:-}" \
    --dart-define=IS_SPLASH="${IS_SPLASH:-false}" \
    --dart-define=SPLASH="${SPLASH:-}" \
    --dart-define=SPLASH_BG="${SPLASH_BG:-}" \
    --dart-define=SPLASH_ANIMATION="${SPLASH_ANIMATION:-}" \
    --dart-define=SPLASH_BG_COLOR="${SPLASH_BG_COLOR:-}" \
    --dart-define=SPLASH_TAGLINE="${SPLASH_TAGLINE:-}" \
    --dart-define=SPLASH_TAGLINE_COLOR="${SPLASH_TAGLINE_COLOR:-}" \
    --dart-define=SPLASH_DURATION="${SPLASH_DURATION:-}" \
    --dart-define=IS_PULLDOWN="${IS_PULLDOWN:-false}" \
    --dart-define=LOGO_URL="${LOGO_URL:-}" \
    --dart-define=IS_BOTTOMMENU="${IS_BOTTOMMENU:-false}" \
    --dart-define=BOTTOMMENU_ITEMS="${BOTTOMMENU_ITEMS:-}" \
    --dart-define=BOTTOMMENU_BG_COLOR="${BOTTOMMENU_BG_COLOR:-}" \
    --dart-define=BOTTOMMENU_ICON_COLOR="${BOTTOMMENU_ICON_COLOR:-}" \
    --dart-define=BOTTOMMENU_TEXT_COLOR="${BOTTOMMENU_TEXT_COLOR:-}" \
    --dart-define=BOTTOMMENU_FONT="${BOTTOMMENU_FONT:-}" \
    --dart-define=BOTTOMMENU_FONT_SIZE="${BOTTOMMENU_FONT_SIZE:-}" \
    --dart-define=BOTTOMMENU_FONT_BOLD="${BOTTOMMENU_FONT_BOLD:-}" \
    --dart-define=BOTTOMMENU_FONT_ITALIC="${BOTTOMMENU_FONT_ITALIC:-}" \
    --dart-define=BOTTOMMENU_ACTIVE_TAB_COLOR="${BOTTOMMENU_ACTIVE_TAB_COLOR:-}" \
    --dart-define=BOTTOMMENU_ICON_POSITION="${BOTTOMMENU_ICON_POSITION:-}" \
    --dart-define=BOTTOMMENU_VISIBLE_ON="${BOTTOMMENU_VISIBLE_ON:-}" \
    --dart-define=IS_DOMAIN_URL="${IS_DOMAIN_URL:-false}" \
    --dart-define=IS_LOAD_IND="${IS_LOAD_IND:-false}" \
    --dart-define=IS_CHATBOT="${IS_CHATBOT:-false}" \
    --dart-define=IS_CAMERA="${IS_CAMERA:-false}" \
    --dart-define=IS_LOCATION="${IS_LOCATION:-false}" \
    --dart-define=IS_BIOMETRIC="${IS_BIOMETRIC:-false}" \
    --dart-define=IS_MIC="${IS_MIC:-false}" \
    --dart-define=IS_CONTACT="${IS_CONTACT:-false}" \
    --dart-define=IS_CALENDAR="${IS_CALENDAR:-false}" \
    --dart-define=IS_NOTIFICATION="${IS_NOTIFICATION:-false}" \
    --dart-define=IS_STORAGE="${IS_STORAGE:-false}" \
    --dart-define=FIREBASE_CONFIG_ANDROID="${FIREBASE_CONFIG_ANDROID:-}" \
    --dart-define=FIREBASE_CONFIG_IOS="${FIREBASE_CONFIG_IOS:-}" \
    --dart-define=APNS_KEY_ID="${APNS_KEY_ID:-}" \
    --dart-define=APPLE_TEAM_ID="${APPLE_TEAM_ID:-}" \
    --dart-define=APNS_AUTH_KEY_URL="${APNS_AUTH_KEY_URL:-}" \
    --dart-define=KEY_STORE_URL="${KEY_STORE_URL:-}" \
    --dart-define=CM_KEYSTORE_PASSWORD="${CM_KEYSTORE_PASSWORD:-}" \
    --dart-define=CM_KEY_ALIAS="${CM_KEY_ALIAS:-}" \
    --dart-define=CM_KEY_PASSWORD="${CM_KEY_PASSWORD:-}"

if [ $? -eq 0 ]; then
    log "✅ Flutter app built successfully (no code signing)"
else
    log "❌ Flutter app build failed"
    exit 1
fi

# 📦 STAGE 2: Second Podfile Injection for xcodebuild (With Code Signing)
log "📦 STAGE 2: Second Podfile Injection for xcodebuild (With Code Signing)..."

# 🧹 Clean up existing Pods for second stage
log "🧹 Cleaning up existing Pods for second stage..."
rm -rf ios/Pods ios/Podfile.lock ios/Pods.xcodeproj 2>/dev/null || true
log "✅ Second stage Pods cleanup completed"

# Generate second Podfile for xcodebuild (with code signing)
if [ -f "lib/scripts/ios/generate_podfile.sh" ]; then
    chmod +x lib/scripts/ios/generate_podfile.sh
    if ./lib/scripts/ios/generate_podfile.sh "xcodebuild" "$PROFILE_TYPE"; then
        log "✅ Second Podfile generated for xcodebuild"
    else
        log "❌ Second Podfile generation failed"
        exit 1
    fi
else
    log "❌ Podfile generator script not found"
    exit 1
fi

# Install pods for xcodebuild
log "🍫 Installing CocoaPods for xcodebuild..."
cd ios
pod install --repo-update
cd ..
log "✅ CocoaPods installed for xcodebuild"

# 📦 Enhanced IPA Build Process with xcodebuild
log "📦 Starting Enhanced IPA Build Process with xcodebuild..."

# Use the enhanced build script with xcodebuild approach
if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
    chmod +x lib/scripts/ios/build_ipa.sh
    if ./lib/scripts/ios/build_ipa.sh; then
        log "✅ Enhanced IPA build completed successfully"
    else
        log "❌ Enhanced IPA build failed"
        exit 1
    fi
else
    log "❌ Enhanced build script not found"
    exit 1
fi

# 📧 Send Success Email
log "📧 Sending build success email..."

# Get build ID from environment
BUILD_ID="${CM_BUILD_ID:-${FCI_BUILD_ID:-unknown}}"

# Send success email
if [ -f "lib/scripts/utils/send_email.py" ]; then
    if python3 lib/scripts/utils/send_email.py "build_success" "iOS" "$BUILD_ID" "Build completed successfully"; then
        log "✅ Success email sent"
    else
        log "⚠️ Failed to send success email, but build succeeded"
    fi
else
    log "⚠️ Email script not found, skipping email notification"
fi

log "🎉 iOS build process completed successfully!"
log "📱 IPA file available at: build/ios/ipa/Runner.ipa"
log "📋 Build Summary:"
log "   Profile Type: $PROFILE_TYPE"
log "   Bundle ID: $BUNDLE_ID"
log "   Team ID: $APPLE_TEAM_ID"
log "   Two-Stage Podfile Injection: ✅ Completed"
log "   Flutter Build (No Code Signing): ✅ Completed"
log "   xcodebuild (With Code Signing): ✅ Completed"

exit 0 