#!/bin/bash
set -euo pipefail

# Source environment variables
source lib/scripts/utils/gen_env_config.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

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

        # Convert certificates to p12
        log "🔄 Converting certificates to p12..."
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
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$(basename ios/certificates/profile.mobileprovision .mobileprovision)</string>
    </dict>
    <key>compileBitcode</key>
    <$compile_bitcode/>
    <key>uploadBitcode</key>
    <$upload_bitcode/>
    <key>uploadSymbols</key>
    <$upload_symbols/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>$thinning</string>
EOF

    # Add distribution specific options
    if [ "$method" = "ad-hoc" ]; then
        cat >> ios/ExportOptions.plist << EOF
    <key>manifest</key>
    <dict>
        <key>appURL</key>
        <string>${INSTALL_URL:-}</string>
        <key>displayImageURL</key>
        <string>${DISPLAY_IMAGE_URL:-}</string>
        <key>fullSizeImageURL</key>
        <string>${FULL_SIZE_IMAGE_URL:-}</string>
    </dict>
EOF
    fi

    # Close the plist
    cat >> ios/ExportOptions.plist << EOF
</dict>
</plist>
EOF

    log "✅ Provisioning profile setup completed"
}

# Function to setup Podfile
setup_podfile() {
    log "📦 Setting up Podfile..."
    
    cat > ios/Podfile << 'EOF'
platform :ios, '13.0'
use_frameworks!

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
EOF

    log "✅ Podfile setup completed"
}

# Function to send error notification email
send_error_notification() {
    local error_type="$1"
    local details="$2"

    if command -v python3 >/dev/null 2>&1; then
        if [ -f "lib/scripts/utils/send_ios_emails.py" ]; then
            chmod +x lib/scripts/utils/send_ios_emails.py
            python3 lib/scripts/utils/send_ios_emails.py "$error_type" "$details" || true
        else
            log "⚠️ iOS email script not found, falling back to generic email"
            if [ -f "lib/scripts/utils/send_email.sh" ]; then
                chmod +x lib/scripts/utils/send_email.sh
                lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "$details" || true
            fi
        fi
    else
        log "⚠️ Python not found, falling back to generic email"
        if [ -f "lib/scripts/utils/send_email.sh" ]; then
            chmod +x lib/scripts/utils/send_email.sh
            lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "$details" || true
        fi
    fi
}

# Function to validate certificates
validate_certificates() {
    log "🔍 Validating certificates..."
    
    local cert_error=""
    local has_p12=false
    local has_cer_key=false
    
    # Check P12 certificate
    if [ -n "${CERT_P12_URL:-}" ]; then
        if validate_url "$CERT_P12_URL" "P12 certificate"; then
            has_p12=true
        else
            cert_error="Invalid P12 certificate URL: $CERT_P12_URL"
        fi
    fi
    
    # Check CER and KEY if P12 is not valid
    if [ "$has_p12" = "false" ]; then
        log "⚠️ P12 certificate not available, checking CER and KEY..."
        
        if [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ]; then
            if validate_url "$CERT_CER_URL" "certificate" && validate_url "$CERT_KEY_URL" "private key"; then
                has_cer_key=true
            else
                cert_error="${cert_error:+$cert_error\n}Invalid certificate URLs:\nCER: $CERT_CER_URL\nKEY: $CERT_KEY_URL"
            fi
        else
            cert_error="${cert_error:+$cert_error\n}Missing certificate files. Provide either P12 or both CER and KEY."
        fi
    fi
    
    # Send error notification if no valid certificates
    if [ "$has_p12" = "false" ] && [ "$has_cer_key" = "false" ]; then
        log "❌ No valid certificates available"
        send_error_notification "certificates" "$cert_error"
        return 1
    fi
    
    log "✅ Certificate validation completed"
    return 0
}

# Function to validate provisioning profile
validate_provisioning_profile() {
    log "🔍 Validating provisioning profile..."
    
    if [ -z "${PROFILE_URL:-}" ]; then
        local error_msg="Provisioning profile URL is required"
        log "❌ $error_msg"
        send_error_notification "provisioning" "$error_msg"
        return 1
    fi
    
    if ! validate_url "$PROFILE_URL" "provisioning profile"; then
        local error_msg="Invalid provisioning profile URL: $PROFILE_URL"
        log "❌ $error_msg"
        send_error_notification "provisioning" "$error_msg"
        return 1
    fi
    
    # Download and verify profile
    if ! download_file "$PROFILE_URL" "ios/certificates/profile.mobileprovision" "provisioning profile"; then
        local error_msg="Failed to download provisioning profile"
        log "❌ $error_msg"
        send_error_notification "provisioning" "$error_msg"
        return 1
    fi
    
    # Verify profile content
    if ! security cms -D -i ios/certificates/profile.mobileprovision > /dev/null 2>&1; then
        local error_msg="Invalid provisioning profile format"
        log "❌ $error_msg"
        send_error_notification "provisioning" "$error_msg"
        return 1
    fi
    
    log "✅ Provisioning profile validation completed"
    return 0
}

# Function to validate required variables
validate_variables() {
    log "🔍 Validating required variables..."
    
    # Validate certificates first
    if ! validate_certificates; then
        return 1
    fi
    
    # Validate provisioning profile
    if ! validate_provisioning_profile; then
        return 1
    fi
    
    # Check other required variables
    local required_vars=(
        "CERT_PASSWORD"
        "APPLE_TEAM_ID"
        "BUNDLE_ID"
        "PROFILE_TYPE"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log "❌ Required variable $var is missing"
            return 1
        fi
    done
    
    # Validate profile type
    if [ "$PROFILE_TYPE" != "app-store" ] && [ "$PROFILE_TYPE" != "ad-hoc" ]; then
        log "❌ PROFILE_TYPE must be either 'app-store' or 'ad-hoc'"
        return 1
    fi
    
    log "✅ Variable validation completed"
    return 0
}

# Main build process
main() {
    log "🚀 Starting iOS build process..."

    # Validate required variables
    validate_variables

    # Create necessary directories
    mkdir -p ios/certificates
    mkdir -p output/ios

    # Setup certificates and signing
    setup_keychain
    setup_provisioning

    # Flutter setup
    log "📦 Setting up Flutter..."
    flutter clean
    flutter pub get

    # Setup and install pods
    setup_podfile
    cd ios
    pod install --repo-update
    cd ..

    # Build IPA
    log "🏗️ Building IPA..."
    cd ios
    
    # Archive
    xcodebuild -workspace Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath build/Runner.xcarchive \
        archive | xcpretty

    # Export IPA
    xcodebuild -exportArchive \
        -archivePath build/Runner.xcarchive \
        -exportOptionsPlist ExportOptions.plist \
        -exportPath build/ios/ipa | xcpretty

    # Copy IPA to output directory
    mkdir -p ../output/ios
    cp build/ios/ipa/Runner.ipa ../output/ios/
    
    # Generate manifest for ad-hoc distribution if needed
    if [ "$PROFILE_TYPE" = "ad-hoc" ] && [ -n "${INSTALL_URL:-}" ]; then
        log "📝 Generating manifest for OTA installation..."
        cat > ../output/ios/manifest.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>$INSTALL_URL</string>
                </dict>
                <dict>
                    <key>kind</key>
                    <string>display-image</string>
                    <key>url</key>
                    <string>${DISPLAY_IMAGE_URL:-}</string>
                </dict>
                <dict>
                    <key>kind</key>
                    <string>full-size-image</string>
                    <key>url</key>
                    <string>${FULL_SIZE_IMAGE_URL:-}</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>$BUNDLE_ID</string>
                <key>bundle-version</key>
                <string>${VERSION_NAME:-1.0.0}</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>${APP_NAME:-$BUNDLE_ID}</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF
        log "✅ Manifest file generated at output/ios/manifest.plist"
    fi
    
    cd ..

    log "✅ Build completed successfully!"
    log "📱 IPA file location: output/ios/Runner.ipa"
    
    # Upload to TestFlight if enabled and this is an app-store build
    if [ "$PROFILE_TYPE" = "app-store" ]; then
        if [ -f "lib/scripts/ios/testflight_upload.sh" ]; then
            log "🚀 Checking TestFlight upload..."
            chmod +x lib/scripts/ios/testflight_upload.sh
            if ./lib/scripts/ios/testflight_upload.sh; then
                log "✅ TestFlight upload completed"
            else
                log "⚠️ TestFlight upload failed (non-critical)"
            fi
        else
            log "⚠️ TestFlight upload script not found"
        fi
    fi
    
    exit 0
}

# Run the build process
main

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