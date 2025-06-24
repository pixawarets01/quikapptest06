#!/bin/bash

# 🚀 Enhanced IPA Build Script for iOS
# Ensures consistent IPA generation between local and Codemagic environments

set -euo pipefail

# Source common functions
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../utils/safe_run.sh"

# Enhanced logging with timestamps
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🚀 $1"; }
error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1" >&2; }
success() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1"; }
warning() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️ $1"; }

# Error handling
handle_error() {
    error "Build failed: $1"
    error "Build attempt failed at line $LINENO"
    exit 1
}

trap 'handle_error "Unexpected error occurred"' ERR

# Environment variables
BUNDLE_ID=${BUNDLE_ID:-}
VERSION_NAME=${VERSION_NAME:-}
VERSION_CODE=${VERSION_CODE:-}
PROFILE_TYPE=${PROFILE_TYPE:-"app-store"}
BUILD_MODE=${BUILD_MODE:-"release"}
OUTPUT_DIR=${OUTPUT_DIR:-"output/ios"}
EXPORT_OPTIONS_PLIST="ios/ExportOptions.plist"
APPLE_TEAM_ID=${APPLE_TEAM_ID:-}

# Function to validate build environment
validate_build_environment() {
    log "🔍 Validating build environment..."
    
    # Check required variables
    if [ -z "$BUNDLE_ID" ]; then
        error "BUNDLE_ID is required"
        exit 1
    fi
    
    if [ -z "$VERSION_NAME" ]; then
        error "VERSION_NAME is required"
        exit 1
    fi
    
    if [ -z "$VERSION_CODE" ]; then
        error "VERSION_CODE is required"
        exit 1
    fi
    
    if [ -z "$APPLE_TEAM_ID" ]; then
        error "APPLE_TEAM_ID is required"
        exit 1
    fi
    
    # Check required files
    if [ ! -f "ios/Runner/Info.plist" ]; then
        error "Info.plist not found"
        exit 1
    fi
    
    # ExportOptions.plist will be generated if missing, so don't fail here
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log "⚠️ ExportOptions.plist not found (will be generated later)"
    fi
    
    if [ ! -f "ios/Podfile" ]; then
        error "Podfile not found"
        exit 1
    fi
    
    # Check Flutter environment
    if ! command -v flutter &> /dev/null; then
        error "Flutter not found in PATH"
        exit 1
    fi
    
    # Check Xcode environment
    if ! command -v xcodebuild &> /dev/null; then
        error "Xcode not found in PATH"
        exit 1
    fi
    
    log "✅ Build environment validation passed"
}

# Function to clean build environment
clean_build_environment() {
    log "🧹 Cleaning build environment..."
    
    # Clean Flutter
    log "📦 Cleaning Flutter build cache..."
    flutter clean
    
    # Clean iOS build
    log "📱 Cleaning iOS build cache..."
    rm -rf ios/build/ 2>/dev/null || true
    rm -rf ios/Pods/ 2>/dev/null || true
    rm -rf ios/.symlinks/ 2>/dev/null || true
    rm -rf ios/Flutter/Flutter.framework 2>/dev/null || true
    rm -rf ios/Flutter/Flutter.podspec 2>/dev/null || true
    
    # Clean derived data (if in CI)
    if [ "${CI:-false}" = "true" ]; then
        log "🗑️ Cleaning Xcode derived data..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/ 2>/dev/null || true
    fi
    
    log "✅ Build environment cleaned"
}

# Function to install iOS dependencies
install_ios_dependencies() {
    log "📦 Installing iOS dependencies..."
    
    # Ensure Flutter dependencies are up to date
    log "📦 Updating Flutter dependencies..."
    if flutter pub get; then
        log "✅ Flutter dependencies updated"
    else
        handle_error "Failed to update Flutter dependencies"
    fi
    
    # Navigate to iOS directory
    cd ios
    
    # Clean any existing pods
    log "🧹 Cleaning existing pods..."
    rm -rf Pods/ 2>/dev/null || true
    rm -rf Podfile.lock 2>/dev/null || true
    
    # Install CocoaPods dependencies
    log "🍫 Installing CocoaPods dependencies..."
    if pod install --repo-update; then
        log "✅ CocoaPods dependencies installed successfully"
    else
        log "❌ Pod install failed, trying with verbose output..."
        if pod install --repo-update --verbose; then
            log "✅ CocoaPods dependencies installed successfully (with verbose)"
        else
            handle_error "Failed to install CocoaPods dependencies"
        fi
    fi
    
    # Return to project root
    cd ..
    
    log "✅ iOS dependencies installed"
}

# Function to verify code signing setup
verify_code_signing_setup() {
    log "🔐 Verifying code signing setup..."
    
    # Check keychain
    if ! security list-keychains | grep -q "build.keychain"; then
        error "Build keychain not found"
    fi
    
    # Check certificate
    if ! security find-identity -v -p codesigning build.keychain | grep -q "iPhone Distribution\|iPhone Developer\|iOS Distribution Certificate\|Apple Distribution"; then
        error "Code signing certificate not found"
    fi
    
    # Check provisioning profile
    if [ ! -f "ios/certificates/profile.mobileprovision" ]; then
        error "Provisioning profile not found"
    fi
    
    # Check ExportOptions.plist - generate if missing
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log "⚠️ ExportOptions.plist not found, generating it..."
        
        # Check if we have the required environment variables
        if [ -z "${APPLE_TEAM_ID:-}" ] || [ -z "${BUNDLE_ID:-}" ] || [ -z "${PROFILE_TYPE:-}" ]; then
            log "❌ Missing required environment variables for ExportOptions.plist generation"
            log "   APPLE_TEAM_ID: ${APPLE_TEAM_ID:-not_set}"
            log "   BUNDLE_ID: ${BUNDLE_ID:-not_set}"
            log "   PROFILE_TYPE: ${PROFILE_TYPE:-not_set}"
            handle_error "Cannot generate ExportOptions.plist without required environment variables"
        fi
        
        # Generate ExportOptions.plist
        generate_export_options
    fi
    
    # Verify ExportOptions.plist content - check for method value
    log "🔍 Checking ExportOptions.plist method..."
    
    # Use a more reliable method to extract the method value
    local METHOD_VALUE=""
    if command -v plutil >/dev/null 2>&1; then
        # Use plutil if available (macOS)
        METHOD_VALUE=$(plutil -extract method raw ios/ExportOptions.plist 2>/dev/null)
    else
        # Fallback to grep/sed approach
        METHOD_VALUE=$(grep -A1 "<key>method</key>" ios/ExportOptions.plist | grep "<string>" | head -1 | sed 's/.*<string>\([^<]*\)<\/string>.*/\1/')
    fi
    
    if [ -z "$METHOD_VALUE" ]; then
        log "❌ Could not extract method value from ExportOptions.plist"
        log "📋 ExportOptions.plist contents:"
        cat ios/ExportOptions.plist
        handle_error "ExportOptions.plist does not contain valid method value"
    fi
    
    if [ "$METHOD_VALUE" != "$PROFILE_TYPE" ]; then
        log "❌ ExportOptions.plist method mismatch:"
        log "   Expected: $PROFILE_TYPE"
        log "   Found: $METHOD_VALUE"
        log "📋 ExportOptions.plist contents:"
        cat ios/ExportOptions.plist
        handle_error "ExportOptions.plist method does not match profile type"
    fi
    
    log "✅ ExportOptions.plist method verified: $METHOD_VALUE"
    log "✅ Code signing setup verified"
}

# Function to generate dynamic ExportOptions.plist
generate_export_options() {
    log "Generating dynamic ExportOptions.plist..."
    
    # Extract profile UUID and name
    PROFILE_UUID=$(security cms -D -i ios/certificates/profile.mobileprovision | plutil -extract UUID raw -o - -)
    PROFILE_NAME=$(security cms -D -i ios/certificates/profile.mobileprovision | plutil -extract Name raw -o - -)
    
    if [ -z "$PROFILE_UUID" ] || [ -z "$PROFILE_NAME" ]; then
        error "Failed to extract profile information"
        exit 1
    fi
    
    log "Profile UUID: $PROFILE_UUID"
    log "Profile Name: $PROFILE_NAME"
    
    # Generate ExportOptions.plist based on profile type
    cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$PROFILE_TYPE</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$PROFILE_NAME</string>
    </dict>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
EOF

    # Add profile-specific options
    case "$PROFILE_TYPE" in
        "ad-hoc")
            cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>manifest</key>
    <dict>
        <key>appURL</key>
        <string>https://example.com/app.ipa</string>
        <key>displayImageURL</key>
        <string>https://example.com/display.png</string>
        <key>fullSizeImageURL</key>
        <string>https://example.com/fullsize.png</string>
    </dict>
EOF
            ;;
        "app-store")
            cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>distributionBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
EOF
            ;;
        "enterprise")
            cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>distributionBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
EOF
            ;;
    esac
    
    cat >> "$EXPORT_OPTIONS_PLIST" << EOF
</dict>
</plist>
EOF
    
    success "ExportOptions.plist generated successfully"
    log "ExportOptions.plist contents:"
    cat "$EXPORT_OPTIONS_PLIST"
}

# Function to archive the app
archive_app() {
    log "📦 Creating iOS app archive..."
    
    local ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
    local WORKSPACE_PATH="ios/Runner.xcworkspace"
    local SCHEME="Runner"
    
    # Create archive directory
    mkdir -p "$(dirname "$ARCHIVE_PATH")"
    
    # Archive the app
    log "🏗️ Running xcodebuild archive..."
    if xcodebuild \
        -workspace "$WORKSPACE_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        PROVISIONING_PROFILE_SPECIFIER="$(security cms -D -i ios/certificates/profile.mobileprovision | plutil -extract Name raw -o - -)" \
        clean archive; then
        log "✅ Archive created successfully: $ARCHIVE_PATH"
    else
        handle_error "Failed to create archive"
    fi
    
    # Verify archive
    if [ ! -d "$ARCHIVE_PATH" ]; then
        handle_error "Archive not found at expected location: $ARCHIVE_PATH"
    fi
    
    log "✅ App archive completed"
}

# Function to export IPA from archive
export_ipa() {
    log "📱 Exporting IPA from archive..."
    
    local ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
    local EXPORT_PATH="build/ios/ipa"
    
    # Create export directory
    mkdir -p "$EXPORT_PATH"
    
    # Export IPA
    log "🏗️ Running xcodebuild -exportArchive..."
    if xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -allowProvisioningUpdates; then
        log "✅ IPA exported successfully to: $EXPORT_PATH"
    else
        handle_error "Failed to export IPA"
    fi
    
    # Verify IPA was created
    local IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" 2>/dev/null | head -1)
    if [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
        log "✅ IPA verified: $IPA_FILE"
    else
        handle_error "No IPA file found in export directory: $EXPORT_PATH"
    fi
    
    log "✅ IPA export completed"
}

# Function to build IPA with Flutter
build_ipa() {
    log "Building IPA with profile-specific configuration..."
    
    # Validate profile type
    case "$PROFILE_TYPE" in
        "app-store"|"ad-hoc"|"enterprise")
            log "✅ Valid profile type: $PROFILE_TYPE"
            ;;
        *)
            error "Invalid profile type: $PROFILE_TYPE"
            error "Supported types: app-store, ad-hoc, enterprise"
            exit 1
            ;;
    esac
    
    # Archive the app with profile-specific settings
    archive_app
    
    # Export IPA with profile-specific settings
    export_ipa
    
    # Copy IPA to output directory
    local EXPORT_PATH="build/ios/ipa"
    mkdir -p "$OUTPUT_DIR"
    
    # Find the IPA file in the export directory
    local IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" 2>/dev/null | head -1)
    if [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
        cp "$IPA_FILE" "$OUTPUT_DIR/"
        log "✅ IPA copied to $OUTPUT_DIR/"
    else
        handle_error "No IPA file found in export directory: $EXPORT_PATH"
    fi
    
    success "IPA build completed successfully for $PROFILE_TYPE"
    log "📱 Final IPA location: $OUTPUT_DIR/$(basename "$IPA_FILE")"
    log "📊 IPA size: $(du -h "$OUTPUT_DIR/$(basename "$IPA_FILE")" | cut -f1)"
    
    # Profile-specific success message
    case "$PROFILE_TYPE" in
        "app-store")
            log "🎉 App Store IPA ready for App Store Connect upload"
            log "📋 Next steps: Upload to App Store Connect via Xcode or Transporter"
            ;;
        "ad-hoc")
            log "🎉 Ad-Hoc IPA ready for OTA distribution"
            log "📋 Next steps: Host IPA file and create manifest for OTA installation"
            ;;
        "enterprise")
            log "🎉 Enterprise IPA ready for internal distribution"
            log "📋 Next steps: Distribute to enterprise users via MDM or direct installation"
            ;;
    esac
}

# Function to find and verify IPA
find_and_verify_ipa() {
    log "🔍 Finding and verifying IPA..."
    
    local IPA_FOUND=false
    local IPA_NAME=""
    local IPA_PATH=""
    
    # Common IPA locations (in order of preference)
    local IPA_LOCATIONS=(
        "build/ios/ipa/*.ipa"
        "ios/build/ios/ipa/*.ipa"
        "ios/build/Runner.xcarchive/Products/Applications/*.ipa"
        "build/ios/archive/Runner.xcarchive/Products/Applications/*.ipa"
    )
    
    # Search for IPA in common locations
    for pattern in "${IPA_LOCATIONS[@]}"; do
        for ipa_file in $pattern; do
            if [ -f "$ipa_file" ]; then
                IPA_PATH="$ipa_file"
                IPA_NAME=$(basename "$ipa_file")
                log "✅ IPA found: $IPA_PATH"
                IPA_FOUND=true
                break 2
            fi
        done
    done
    
    # If not found in common locations, use find command
    if [ "$IPA_FOUND" = false ]; then
        log "🔍 Searching for IPA files using find command..."
        local FOUND_IPAS=$(find . -name "*.ipa" -type f 2>/dev/null | head -5)
        
        if [ -n "$FOUND_IPAS" ]; then
            log "📋 Found IPA files:"
            echo "$FOUND_IPAS" | while read -r ipa_file; do
                log "   - $ipa_file"
            done
            
            IPA_PATH=$(echo "$FOUND_IPAS" | head -1)
            IPA_NAME=$(basename "$IPA_PATH")
            log "✅ IPA found via find: $IPA_PATH"
            IPA_FOUND=true
        fi
    fi
    
    # Verify IPA was found
    if [ "$IPA_FOUND" = false ]; then
        handle_error "No IPA file found after build"
    fi
    
    # Verify IPA file
    if [ ! -f "$IPA_PATH" ]; then
        handle_error "IPA file not found at expected location: $IPA_PATH"
    fi
    
    # Get IPA file size
    local IPA_SIZE=$(stat -f%z "$IPA_PATH" 2>/dev/null || stat -c%s "$IPA_PATH" 2>/dev/null || echo "unknown")
    
    # Verify IPA file size (should be reasonable)
    if [ "$IPA_SIZE" != "unknown" ] && [ "$IPA_SIZE" -lt 1000000 ]; then
        log "⚠️ Warning: IPA file seems too small ($IPA_SIZE bytes)"
    fi
    
    log "✅ IPA verification successful:"
    log "   File: $IPA_PATH"
    log "   Size: $IPA_SIZE bytes"
    
    # Return IPA information
    echo "$IPA_PATH|$IPA_NAME|$IPA_SIZE"
}

# Function to copy IPA to output directory
copy_ipa_to_output() {
    local IPA_PATH="$1"
    local IPA_NAME="$2"
    
    log "📤 Copying IPA to output directory..."
    
    # Create output directory
    mkdir -p output/ios
    
    # Copy IPA
    if cp "$IPA_PATH" "output/ios/$IPA_NAME"; then
        log "✅ IPA copied to output/ios/$IPA_NAME"
    else
        handle_error "Failed to copy IPA to output directory"
    fi
    
    # Verify copied file
    if [ -f "output/ios/$IPA_NAME" ]; then
        local OUTPUT_SIZE=$(stat -f%z "output/ios/$IPA_NAME" 2>/dev/null || stat -c%s "output/ios/$IPA_NAME" 2>/dev/null || echo "unknown")
        log "✅ Output IPA verification:"
        log "   File: output/ios/$IPA_NAME"
        log "   Size: $OUTPUT_SIZE bytes"
    else
        handle_error "Output IPA file verification failed"
    fi
}

# Function to analyze IPA contents
analyze_ipa() {
    local IPA_PATH="$1"
    
    log "🔍 Analyzing IPA contents..."
    
    # Create temporary directory for analysis
    local TEMP_DIR=$(mktemp -d)
    
    # Extract IPA for analysis
    if unzip -q "$IPA_PATH" -d "$TEMP_DIR"; then
        log "✅ IPA extracted for analysis"
        
        # Check for main app bundle
        local APP_BUNDLE=$(find "$TEMP_DIR/Payload" -name "*.app" -type d 2>/dev/null | head -1)
        if [ -n "$APP_BUNDLE" ]; then
            log "📱 App bundle found: $(basename "$APP_BUNDLE")"
            
            # Check app size
            local APP_SIZE=$(du -sh "$APP_BUNDLE" 2>/dev/null | cut -f1 || echo "unknown")
            log "📊 App bundle size: $APP_SIZE"
            
            # Check for required files
            if [ -f "$APP_BUNDLE/Info.plist" ]; then
                log "✅ Info.plist found in app bundle"
            else
                log "⚠️ Info.plist not found in app bundle"
            fi
            
            if [ -f "$APP_BUNDLE/Runner" ]; then
                log "✅ Main executable found in app bundle"
            else
                log "⚠️ Main executable not found in app bundle"
            fi
        else
            log "⚠️ No app bundle found in IPA"
        fi
        
        # Clean up
        rm -rf "$TEMP_DIR"
    else
        log "⚠️ Failed to extract IPA for analysis"
    fi
}

# Function to generate build report
generate_build_report() {
    local IPA_PATH="$1"
    local IPA_NAME="$2"
    local IPA_SIZE="$3"
    
    log "📋 Generating build report..."
    
    # Create build report
    cat > "output/ios/build_report.txt" << EOF
iOS IPA Build Report
===================

Build Information:
- Bundle ID: $BUNDLE_ID
- Version Name: $VERSION_NAME
- Version Code: $VERSION_CODE
- Profile Type: $PROFILE_TYPE
- Build Mode: $BUILD_MODE

IPA Information:
- File Name: $IPA_NAME
- File Size: $IPA_SIZE bytes
- Build Date: $(date)

Environment:
- Flutter Version: $(flutter --version | head -1)
- Xcode Version: $(xcodebuild -version | head -1)
- Build Platform: $(uname -s) $(uname -m)

Build Status: ✅ SUCCESS
EOF
    
    log "✅ Build report generated: output/ios/build_report.txt"
}

# Main execution
main() {
    log "🚀 Starting Enhanced iOS IPA Build Process..."
    
    # Log build configuration
    log "📋 Build Configuration:"
    log "   Bundle ID: $BUNDLE_ID"
    log "   Version Name: $VERSION_NAME"
    log "   Version Code: $VERSION_CODE"
    log "   Profile Type: $PROFILE_TYPE"
    log "   Build Mode: $BUILD_MODE"
    log "   CI Environment: ${CI:-false}"
    
    # Execute build steps
    validate_build_environment
    clean_build_environment
    install_ios_dependencies
    verify_code_signing_setup
    build_ipa
    
    # Find and verify IPA
    local IPA_INFO=$(find_and_verify_ipa)
    local IPA_PATH=$(echo "$IPA_INFO" | cut -d'|' -f1)
    local IPA_NAME=$(echo "$IPA_INFO" | cut -d'|' -f2)
    local IPA_SIZE=$(echo "$IPA_INFO" | cut -d'|' -f3)
    
    # Copy to output directory
    copy_ipa_to_output "$IPA_PATH" "$IPA_NAME"
    
    # Analyze IPA (optional)
    analyze_ipa "$IPA_PATH"
    
    # Generate build report
    generate_build_report "$IPA_PATH" "$IPA_NAME" "$IPA_SIZE"
    
    log "🎉 Enhanced iOS IPA Build Process completed successfully!"
    log "📊 Summary:"
    log "   IPA File: output/ios/$IPA_NAME"
    log "   IPA Size: $IPA_SIZE bytes"
    log "   Build Report: output/ios/build_report.txt"
}

# Run main function
main "$@" 