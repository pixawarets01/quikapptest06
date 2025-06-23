#!/bin/bash

# 🔐 Enhanced Code Signing Configuration for iOS
# Ensures code signing is properly enabled for all profile types

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../utils/safe_run.sh"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔐 $1"
}

# Function to configure Xcode project for code signing
configure_xcode_code_signing() {
    log "🔧 Configuring Xcode project for code signing..."
    
    local project_file="ios/Runner.xcodeproj/project.pbxproj"
    local profile_type="${PROFILE_TYPE:-app-store}"
    
    # Backup original project file
    cp "$project_file" "${project_file}.backup"
    log "✅ Project file backed up"
    
    # Determine code signing identity based on profile type
    local code_sign_identity="iPhone Distribution"
    local code_sign_style="Manual"
    
    case "$profile_type" in
        "app-store")
            code_sign_identity="iPhone Distribution"
            code_sign_style="Manual"
            ;;
        "ad-hoc")
            code_sign_identity="iPhone Distribution"
            code_sign_style="Manual"
            ;;
        "enterprise")
            code_sign_identity="iPhone Distribution"
            code_sign_style="Manual"
            ;;
        "development")
            code_sign_identity="iPhone Developer"
            code_sign_style="Automatic"
            ;;
        *)
            log "⚠️ Unknown profile type: $profile_type, using app-store defaults"
            code_sign_identity="iPhone Distribution"
            code_sign_style="Manual"
            ;;
    esac
    
    log "📋 Profile Type: $profile_type"
    log "🔑 Code Sign Identity: $code_sign_identity"
    log "🎯 Code Sign Style: $code_sign_style"
    
    # Update project.pbxproj with proper code signing settings
    # This ensures all build configurations have the correct code signing settings
    
    # Update Release configuration
    sed -i.bak \
        -e 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = '"$code_sign_style"';/g' \
        -e 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "'"$code_sign_identity"'";/g' \
        -e 's/DEVELOPMENT_TEAM = "";/DEVELOPMENT_TEAM = "'"$APPLE_TEAM_ID"'";/g' \
        -e 's/PROVISIONING_PROFILE_SPECIFIER = "";/PROVISIONING_PROFILE_SPECIFIER = "'"$(basename ios/certificates/profile.mobileprovision .mobileprovision)"'";/g' \
        "$project_file"
    
    # Update Debug configuration (for development builds)
    if [ "$profile_type" = "development" ]; then
        sed -i.bak \
            -e 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Automatic;/g' \
            -e 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";/g' \
            -e 's/DEVELOPMENT_TEAM = "";/DEVELOPMENT_TEAM = "'"$APPLE_TEAM_ID"'";/g' \
            "$project_file"
    fi
    
    # Verify changes
    if grep -q "CODE_SIGN_STYLE = $code_sign_style" "$project_file"; then
        log "✅ Code signing style updated successfully"
    else
        log "❌ Failed to update code signing style"
        return 1
    fi
    
    if grep -q "CODE_SIGN_IDENTITY.*$code_sign_identity" "$project_file"; then
        log "✅ Code signing identity updated successfully"
    else
        log "❌ Failed to update code signing identity"
        return 1
    fi
    
    log "✅ Xcode project code signing configuration completed"
}

# Function to setup keychain and certificates
setup_keychain_and_certificates() {
    log "🔑 Setting up keychain and certificates..."
    
    # Create and configure keychain
    log "🔐 Creating build keychain..."
    security create-keychain -p "" build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "" build.keychain
    security set-keychain-settings -t 3600 -u build.keychain
    
    # Set keychain search list
    security list-keychains -s build.keychain
    security show-keychain-info build.keychain
    
    # Import certificate
    log "📜 Importing certificate..."
    if [ -f "ios/certificates/cert.p12" ]; then
        if security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A; then
            log "✅ Certificate imported successfully"
        else
            log "❌ Failed to import certificate"
            return 1
        fi
    else
        log "❌ Certificate file not found: ios/certificates/cert.p12"
        return 1
    fi
    
    # Set partition list for codesigning
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
    
    # Verify certificate installation
    log "🔍 Verifying certificate installation..."
    if security find-identity -v -p codesigning build.keychain | grep -q "iPhone Distribution\|iPhone Developer"; then
        log "✅ Certificate verification successful"
    else
        log "❌ Certificate verification failed"
        return 1
    fi
    
    log "✅ Keychain and certificate setup completed"
}

# Function to install provisioning profile
install_provisioning_profile() {
    log "📱 Installing provisioning profile..."
    
    local profile_path="ios/certificates/profile.mobileprovision"
    local profile_type="${PROFILE_TYPE:-app-store}"
    
    if [ ! -f "$profile_path" ]; then
        log "❌ Provisioning profile not found: $profile_path"
        return 1
    fi
    
    # Get profile UUID
    local profile_uuid=$(security cms -D -i "$profile_path" | plutil -extract UUID raw -)
    if [ -z "$profile_uuid" ]; then
        log "❌ Failed to extract profile UUID"
        return 1
    fi
    
    log "📋 Profile UUID: $profile_uuid"
    
    # Install profile
    local profile_dest="$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.mobileprovision"
    mkdir -p "$(dirname "$profile_dest")"
    cp "$profile_path" "$profile_dest"
    
    if [ -f "$profile_dest" ]; then
        log "✅ Provisioning profile installed: $profile_dest"
    else
        log "❌ Failed to install provisioning profile"
        return 1
    fi
    
    # Verify profile installation
    if security cms -D -i "$profile_dest" >/dev/null 2>&1; then
        log "✅ Provisioning profile verification successful"
    else
        log "❌ Provisioning profile verification failed"
        return 1
    fi
    
    log "✅ Provisioning profile installation completed"
}

# Function to generate enhanced ExportOptions.plist
generate_export_options() {
    log "📦 Generating enhanced ExportOptions.plist..."
    
    local profile_type="${PROFILE_TYPE:-app-store}"
    local method="$profile_type"
    
    # Determine export options based on profile type
    local upload_symbols="true"
    local upload_bitcode="false"
    local compile_bitcode="false"
    local thinning="<none>"
    local destination="export"
    
    case "$profile_type" in
        "app-store")
            upload_symbols="true"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="<none>"
            destination="upload"
            ;;
        "ad-hoc")
            upload_symbols="false"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="<none>"
            destination="export"
            ;;
        "enterprise")
            upload_symbols="false"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="<none>"
            destination="export"
            ;;
        "development")
            upload_symbols="false"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="<none>"
            destination="export"
            ;;
    esac
    
    # Get profile UUID for provisioning profiles section
    local profile_uuid=""
    if [ -f "ios/certificates/profile.mobileprovision" ]; then
        profile_uuid=$(security cms -D -i "ios/certificates/profile.mobileprovision" | plutil -extract UUID raw -)
    fi
    
    # Create enhanced ExportOptions.plist
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
    <key>uploadSymbols</key>
    <$upload_symbols/>
    <key>uploadBitcode</key>
    <$upload_bitcode/>
    <key>compileBitcode</key>
    <$compile_bitcode/>
    <key>thinning</key>
    <string>$thinning</string>
    <key>destination</key>
    <string>$destination</string>
EOF
    
    # Add TestFlight specific options
    if [ "${IS_TESTFLIGHT:-false}" = "true" ] && [ "$method" = "app-store" ]; then
        cat >> ios/ExportOptions.plist << EOF
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>uploadBitcode</key>
    <false/>
EOF
    fi
    
    # Add Ad-Hoc specific options
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
    
    cat >> ios/ExportOptions.plist << EOF
</dict>
</plist>
EOF
    
    log "✅ ExportOptions.plist generated for $profile_type"
    log "📋 Export method: $method"
    log "📦 Destination: $destination"
    log "🔧 Thinning: $thinning"
}

# Function to verify code signing setup
verify_code_signing_setup() {
    log "🔍 Verifying code signing setup..."
    
    local profile_type="${PROFILE_TYPE:-app-store}"
    local verification_passed=true
    
    # Check keychain
    if ! security list-keychains | grep -q "build.keychain"; then
        log "❌ Build keychain not found"
        verification_passed=false
    fi
    
    # Check certificate
    if ! security find-identity -v -p codesigning build.keychain | grep -q "iPhone Distribution\|iPhone Developer"; then
        log "❌ Code signing certificate not found"
        verification_passed=false
    fi
    
    # Check provisioning profile
    if [ ! -f "ios/certificates/profile.mobileprovision" ]; then
        log "❌ Provisioning profile not found"
        verification_passed=false
    fi
    
    # Check ExportOptions.plist
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log "❌ ExportOptions.plist not found"
        verification_passed=false
    fi
    
    # Check Xcode project configuration
    if ! grep -q "CODE_SIGN_STYLE" ios/Runner.xcodeproj/project.pbxproj; then
        log "❌ Code signing not configured in Xcode project"
        verification_passed=false
    fi
    
    if [ "$verification_passed" = true ]; then
        log "✅ Code signing setup verification passed"
        return 0
    else
        log "❌ Code signing setup verification failed"
        return 1
    fi
}

# Main execution
main() {
    log "🚀 Starting enhanced code signing configuration..."
    
    # Validate required environment variables
    if [ -z "${CERT_PASSWORD:-}" ]; then
        log "❌ CERT_PASSWORD is required"
        exit 1
    fi
    
    if [ -z "${APPLE_TEAM_ID:-}" ]; then
        log "❌ APPLE_TEAM_ID is required"
        exit 1
    fi
    
    if [ -z "${BUNDLE_ID:-}" ]; then
        log "❌ BUNDLE_ID is required"
        exit 1
    fi
    
    if [ -z "${PROFILE_TYPE:-}" ]; then
        log "⚠️ PROFILE_TYPE not set, defaulting to app-store"
        export PROFILE_TYPE="app-store"
    fi
    
    log "📋 Code Signing Configuration:"
    log "   Profile Type: ${PROFILE_TYPE}"
    log "   Team ID: ${APPLE_TEAM_ID}"
    log "   Bundle ID: ${BUNDLE_ID}"
    
    # Execute code signing setup steps
    configure_xcode_code_signing
    setup_keychain_and_certificates
    install_provisioning_profile
    generate_export_options
    verify_code_signing_setup
    
    log "✅ Enhanced code signing configuration completed successfully!"
}

# Run main function
main "$@" 