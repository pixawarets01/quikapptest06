#!/bin/bash

# 🚀 Enhanced IPA Build Script for iOS
# Ensures consistent IPA generation between local and Codemagic environments

set -euo pipefail

# Source common functions
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../utils/safe_run.sh"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🚀 $1"
}

# Error handling
handle_error() { 
    log "❌ ERROR: $1"; 
    exit 1; 
}
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Environment variables
BUNDLE_ID=${BUNDLE_ID:-}
VERSION_NAME=${VERSION_NAME:-}
VERSION_CODE=${VERSION_CODE:-}
PROFILE_TYPE=${PROFILE_TYPE:-"app-store"}
BUILD_MODE=${BUILD_MODE:-"release"}

# Function to validate build environment
validate_build_environment() {
    log "🔍 Validating build environment..."
    
    # Check required variables
    if [ -z "$BUNDLE_ID" ]; then
        handle_error "BUNDLE_ID is required"
    fi
    
    if [ -z "$VERSION_NAME" ]; then
        handle_error "VERSION_NAME is required"
    fi
    
    if [ -z "$VERSION_CODE" ]; then
        handle_error "VERSION_CODE is required"
    fi
    
    # Check required files
    if [ ! -f "ios/Runner/Info.plist" ]; then
        handle_error "Info.plist not found"
    fi
    
    if [ ! -f "ios/ExportOptions.plist" ]; then
        handle_error "ExportOptions.plist not found"
    fi
    
    if [ ! -f "ios/Podfile" ]; then
        handle_error "Podfile not found"
    fi
    
    # Check Flutter environment
    if ! command -v flutter &> /dev/null; then
        handle_error "Flutter not found in PATH"
    fi
    
    # Check Xcode environment
    if ! command -v xcodebuild &> /dev/null; then
        handle_error "Xcode not found in PATH"
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
        handle_error "Build keychain not found"
    fi
    
    # Check certificate
    if ! security find-identity -v -p codesigning build.keychain | grep -q "iPhone Distribution\|iPhone Developer\|iOS Distribution Certificate\|Apple Distribution"; then
        handle_error "Code signing certificate not found"
    fi
    
    # Check provisioning profile
    if [ ! -f "ios/certificates/profile.mobileprovision" ]; then
        handle_error "Provisioning profile not found"
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
        log "📦 Generating ExportOptions.plist..."
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
        
        # Create ExportOptions.plist
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
    <string>iOS Distribution Certificate</string>
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
</dict>
</plist>
EOF
        
        log "✅ ExportOptions.plist generated for $profile_type"
        log "📋 Export method: $method"
        log "📦 Destination: $destination"
        log "🔧 Thinning: $thinning"
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

# Function to build IPA with Flutter
build_ipa_with_flutter() {
    log "🚀 Building IPA with Flutter..."
    
    # Set Flutter build arguments
    local flutter_args=(
        "build"
        "ipa"
        "--release"
        "--bundle-id" "$BUNDLE_ID"
        "--build-name" "$VERSION_NAME"
        "--build-number" "$VERSION_CODE"
        "--export-options-plist" "ios/ExportOptions.plist"
    )
    
    # Add additional arguments for CI environment
    if [ "${CI:-false}" = "true" ]; then
        flutter_args+=("--verbose")
    fi
    
    # Build IPA
    log "📱 Executing: flutter ${flutter_args[*]}"
    if flutter "${flutter_args[@]}"; then
        log "✅ Flutter IPA build completed successfully"
    else
        handle_error "Flutter IPA build failed"
    fi
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
    build_ipa_with_flutter
    
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