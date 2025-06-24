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
        exit 1
    fi
    
    # Check certificate
    if ! security find-identity -v -p codesigning build.keychain | grep -q "iPhone Distribution\|iPhone Developer\|iOS Distribution Certificate\|Apple Distribution"; then
        error "Code signing certificate not found"
        exit 1
    fi
    
    # Check provisioning profile
    if [ ! -f "ios/certificates/profile.mobileprovision" ]; then
        error "Provisioning profile not found"
        exit 1
    fi
    
    # Check ExportOptions.plist - generate if missing
    log "🔍 Checking for ExportOptions.plist..."
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log "⚠️ ExportOptions.plist not found, generating it..."
        
        # Check if we have the required environment variables
        log "🔍 Environment variables check:"
        log "   APPLE_TEAM_ID: ${APPLE_TEAM_ID:-not_set}"
        log "   BUNDLE_ID: ${BUNDLE_ID:-not_set}"
        log "   PROFILE_TYPE: ${PROFILE_TYPE:-not_set}"
        
        if [ -z "${APPLE_TEAM_ID:-}" ] || [ -z "${BUNDLE_ID:-}" ] || [ -z "${PROFILE_TYPE:-}" ]; then
            log "❌ Missing required environment variables for ExportOptions.plist generation"
            handle_error "Cannot generate ExportOptions.plist without required environment variables"
        fi
        
        # Generate ExportOptions.plist
        log "🔧 Generating ExportOptions.plist..."
        generate_export_options
    else
        log "✅ ExportOptions.plist already exists"
    fi
    
    # Verify ExportOptions.plist content - check for method value
    log "🔍 Checking ExportOptions.plist method..."
    log "🔍 Current working directory: $(pwd)"
    log "🔍 ExportOptions.plist path: $(realpath ios/ExportOptions.plist 2>/dev/null || echo 'ios/ExportOptions.plist')"
    log "🔍 ExportOptions.plist exists: $([ -f "ios/ExportOptions.plist" ] && echo 'yes' || echo 'no')"
    
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log "❌ ExportOptions.plist still not found after generation attempt"
        handle_error "ExportOptions.plist does not exist"
    fi
    
    log "🔍 ExportOptions.plist file size: $(ls -lh ios/ExportOptions.plist | awk '{print $5}')"
    log "📋 ExportOptions.plist contents:"
    cat ios/ExportOptions.plist
    
    # Use a more reliable method to extract the method value
    local METHOD_VALUE=""
    log "🔍 Attempting to extract method value..."
    
    if command -v plutil >/dev/null 2>&1; then
        # Use plutil if available (macOS)
        log "🔧 Using plutil to extract method..."
        METHOD_VALUE=$(plutil -extract method raw ios/ExportOptions.plist 2>/dev/null || echo "")
        log "🔍 plutil result: '$METHOD_VALUE'"
    fi
    
    if [ -z "$METHOD_VALUE" ]; then
        # Fallback to grep/sed approach
        log "🔧 Using grep/sed fallback to extract method..."
        METHOD_VALUE=$(grep -A1 "<key>method</key>" ios/ExportOptions.plist | grep "<string>" | head -1 | sed 's/.*<string>\([^<]*\)<\/string>.*/\1/' 2>/dev/null || echo "")
        log "🔍 grep/sed result: '$METHOD_VALUE'"
    fi
    
    if [ -z "$METHOD_VALUE" ]; then
        log "❌ Could not extract method value from ExportOptions.plist"
        log "🔧 Attempting alternative extraction methods..."
        
        # Try alternative grep approach
        METHOD_VALUE=$(grep -o '<string>[^<]*</string>' ios/ExportOptions.plist | head -1 | sed 's/<string>\(.*\)<\/string>/\1/' 2>/dev/null || echo "")
        log "🔍 Alternative grep result: '$METHOD_VALUE'"
        
        if [ -z "$METHOD_VALUE" ]; then
            log "❌ All method extraction attempts failed"
            log "🔍 Expected PROFILE_TYPE: '$PROFILE_TYPE'"
            log "❌ This indicates the ExportOptions.plist file is malformed or corrupted"
            handle_error "ExportOptions.plist does not contain valid method value"
        fi
    fi
    
    log "🔍 Extracted method value: '$METHOD_VALUE'"
    log "🔍 Expected profile type: '$PROFILE_TYPE'"
    
    if [ "$METHOD_VALUE" != "$PROFILE_TYPE" ]; then
        log "❌ ExportOptions.plist method mismatch:"
        log "   Expected: '$PROFILE_TYPE'"
        log "   Found: '$METHOD_VALUE'"
        log "🔧 This suggests the ExportOptions.plist was not generated correctly"
        handle_error "ExportOptions.plist method does not match profile type"
    fi
    
    log "✅ ExportOptions.plist method verified: $METHOD_VALUE"
    log "✅ Code signing setup verified"
}

# Function to generate ExportOptions.plist
generate_export_options() {
    log "📝 Generating ExportOptions.plist for profile type: $PROFILE_TYPE"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$EXPORT_OPTIONS_PLIST")"
    
    # Generate ExportOptions.plist based on profile type
    case "$PROFILE_TYPE" in
        "app-store")
            log "🔍 Creating App Store export options"
            cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>none</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>generateAppStoreInformation</key>
    <true/>
</dict>
</plist>
EOF
            ;;
        "ad-hoc")
            log "🔍 Creating Ad-Hoc export options"
            cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>none</string>
    <key>stripSwiftSymbols</key>
    <true/>
EOF
            
            # Add manifest options if INSTALL_URL is provided
            if [ -n "${INSTALL_URL:-}" ]; then
                log "🔍 Adding OTA manifest options for Ad-Hoc distribution"
                cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>manifest</key>
    <dict>
        <key>appURL</key>
        <string>$INSTALL_URL</string>
        <key>displayImageURL</key>
        <string>${DISPLAY_IMAGE_URL:-$INSTALL_URL/icon.png}</string>
        <key>fullSizeImageURL</key>
        <string>${FULL_SIZE_IMAGE_URL:-$INSTALL_URL/icon.png}</string>
    </dict>
EOF
            fi
            
            cat >> "$EXPORT_OPTIONS_PLIST" << EOF
</dict>
</plist>
EOF
            ;;
        "enterprise")
            log "🔍 Creating Enterprise export options"
            cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>enterprise</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>none</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
            ;;
        "development")
            log "🔍 Creating Development export options"
            cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>none</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
            ;;
        *)
            handle_error "Unsupported profile type: $PROFILE_TYPE"
            ;;
    esac
    
    # Validate the generated plist
    if ! plutil -lint "$EXPORT_OPTIONS_PLIST" >/dev/null 2>&1; then
        handle_error "Generated ExportOptions.plist is invalid"
    fi
    
    log "✅ ExportOptions.plist generated successfully: $EXPORT_OPTIONS_PLIST"
    log "🔍 ExportOptions.plist contents:"
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

# Function to validate archive before export
validate_archive() {
    log "🔍 Validating archive before export..."
    
    local ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
    
    if [ ! -d "$ARCHIVE_PATH" ]; then
        handle_error "Archive not found at: $ARCHIVE_PATH"
    fi
    
    # Check archive structure
    if [ ! -d "$ARCHIVE_PATH/Products/Applications" ]; then
        handle_error "Invalid archive structure - missing Products/Applications directory"
    fi
    
    # Find the .app bundle
    local APP_BUNDLE=$(find "$ARCHIVE_PATH/Products/Applications" -name "*.app" -type d 2>/dev/null | head -1)
    if [ -z "$APP_BUNDLE" ]; then
        handle_error "No .app bundle found in archive"
    fi
    
    log "✅ Archive validation passed"
    log "🔍 App bundle: $APP_BUNDLE"
    log "📊 App bundle size: $(du -sh "$APP_BUNDLE" | cut -f1)"
    
    # Check if app is properly signed
    if codesign -dv "$APP_BUNDLE" 2>&1 | grep -q "not signed"; then
        log "⚠️ App bundle is not signed"
    else
        log "✅ App bundle is properly signed"
        log "🔍 Code signing details:"
        codesign -dv "$APP_BUNDLE" 2>&1 | grep -E "(Authority|TeamIdentifier|BundleIdentifier)" | head -5 || log "   Could not extract signing details"
    fi
    
    # Check bundle identifier
    local BUNDLE_ID_IN_APP=$(defaults read "$APP_BUNDLE/Info.plist" CFBundleIdentifier 2>/dev/null || echo "")
    if [ -n "$BUNDLE_ID_IN_APP" ]; then
        log "🔍 Bundle ID in app: $BUNDLE_ID_IN_APP"
        if [ "$BUNDLE_ID_IN_APP" != "$BUNDLE_ID" ]; then
            log "⚠️ Bundle ID mismatch: expected $BUNDLE_ID, found $BUNDLE_ID_IN_APP"
        else
            log "✅ Bundle ID matches: $BUNDLE_ID"
        fi
    else
        log "⚠️ Could not read bundle ID from app"
    fi
}

# Function to export IPA from archive
export_ipa() {
    log "📱 Exporting IPA from archive..."
    
    local ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
    local EXPORT_PATH="build/ios/ipa"
    
    # Create export directory
    mkdir -p "$EXPORT_PATH"
    
    # Verify archive exists
    if [ ! -d "$ARCHIVE_PATH" ]; then
        handle_error "Archive not found at: $ARCHIVE_PATH"
    fi
    
    # Verify ExportOptions.plist exists
    if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
        handle_error "ExportOptions.plist not found at: $EXPORT_OPTIONS_PLIST"
    fi
    
    # Validate archive before export
    validate_archive
    
    # Export IPA with better error handling
    log "🏗️ Running xcodebuild -exportArchive..."
    log "🔍 Export method: $PROFILE_TYPE"
    log "🔍 ExportOptions.plist: $EXPORT_OPTIONS_PLIST"
    log "🔍 Archive path: $ARCHIVE_PATH"
    log "🔍 Export path: $EXPORT_PATH"
    
    # Show ExportOptions.plist contents for debugging
    log "🔍 ExportOptions.plist contents:"
    cat "$EXPORT_OPTIONS_PLIST"
    
    # Run export and capture output
    local export_output
    export_output=$(xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -allowProvisioningUpdates 2>&1)
    
    local export_exit_code=$?
    
    # Log the full output
    log "🔍 Export command output:"
    echo "$export_output"
    
    if [ $export_exit_code -eq 0 ]; then
        log "✅ IPA exported successfully to: $EXPORT_PATH"
    else
        log "❌ Export failed with exit code: $export_exit_code"
        
        # Check if it's an authentication issue
        if echo "$export_output" | grep -q "Failed to Use Accounts\|App Store Connect access"; then
            log "🔍 Detected App Store Connect authentication issue"
            log "🔧 This is expected in CI/CD environments without App Store Connect credentials"
            log "📱 The IPA can still be used for manual upload to App Store Connect"
            
            # Check if IPA was actually created despite the error
            local IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" 2>/dev/null | head -1)
            if [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
                log "✅ IPA was created successfully despite authentication warning: $IPA_FILE"
                log "📊 IPA size: $(du -h "$IPA_FILE" | cut -f1)"
                log "🎉 Build completed - IPA ready for manual upload"
                return 0
            else
                handle_error "No IPA file found after export attempt"
            fi
        elif echo "$export_output" | grep -q "exportOptionsPlist.*error\|invalid.*plist"; then
            log "🔍 Detected ExportOptions.plist error"
            log "🔧 Attempting to fix ExportOptions.plist..."
            
            # Try to regenerate ExportOptions.plist
            generate_export_options
            
            # Try export again
            log "🔄 Retrying export with regenerated ExportOptions.plist..."
            export_output=$(xcodebuild \
                -exportArchive \
                -archivePath "$ARCHIVE_PATH" \
                -exportPath "$EXPORT_PATH" \
                -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
                -allowProvisioningUpdates 2>&1)
            
            export_exit_code=$?
            echo "$export_output"
            
            if [ $export_exit_code -eq 0 ]; then
                log "✅ IPA exported successfully on retry"
            else
                handle_error "Export failed on retry: $export_output"
            fi
        elif echo "$export_output" | grep -q "provisioning.*profile\|certificate.*error"; then
            log "🔍 Detected provisioning profile or certificate error"
            log "🔧 Checking provisioning profile and certificate setup..."
            
            # Check provisioning profile
            if [ -f "ios/certificates/profile.mobileprovision" ]; then
                log "✅ Provisioning profile exists"
                log "🔍 Profile details:"
                security cms -D -i ios/certificates/profile.mobileprovision 2>/dev/null | grep -E "(Name|UUID|application-identifier)" | head -5 || log "   Could not extract profile details"
            else
                log "❌ Provisioning profile not found"
            fi
            
            # Check certificate
            if [ -f "ios/certificates/cert.p12" ]; then
                log "✅ Certificate exists"
                log "🔍 Certificate details:"
                security find-identity -v -p codesigning build.keychain | grep "Apple Distribution" || log "   Could not find Apple Distribution certificate"
            else
                log "❌ Certificate not found"
            fi
            
            handle_error "Provisioning profile or certificate issue: $export_output"
        else
            log "🔍 Unknown export error - analyzing output..."
            log "🔍 Common export issues:"
            log "   - Invalid ExportOptions.plist format"
            log "   - Missing provisioning profile"
            log "   - Certificate not in keychain"
            log "   - Bundle ID mismatch"
            log "   - Archive corruption"
            
            handle_error "Failed to export IPA: $export_output"
        fi
    fi
    
    # Verify IPA was created
    local IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" 2>/dev/null | head -1)
    if [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
        log "✅ IPA verified: $IPA_FILE"
        log "📊 IPA size: $(du -h "$IPA_FILE" | cut -f1)"
    else
        log "❌ No IPA file found in export directory: $EXPORT_PATH"
        log "🔍 Export directory contents:"
        ls -la "$EXPORT_PATH" 2>/dev/null || log "   Directory not accessible"
        handle_error "No IPA file found in export directory: $EXPORT_PATH"
    fi
    
    log "✅ IPA export completed"
}

# Main build function
build_ipa() {
    log "🚀 Starting enhanced iOS IPA build process..."
    log "📱 Profile Type: $PROFILE_TYPE"
    log "📦 Bundle ID: $BUNDLE_ID"
    log "👥 Team ID: $APPLE_TEAM_ID"
    
    # Set up build environment
    setup_build_environment
    
    # Generate ExportOptions.plist
    generate_export_options
    
    # Build and archive the app
    build_and_archive_app
    
    # Validate archive before export
    validate_archive
    
    # Export IPA
    export_ipa
    
    # Final verification
    verify_ipa
    
    # Process final IPA (copy to output, TestFlight upload, etc.)
    process_final_ipa
    
    log "🎉 Enhanced iOS IPA build completed successfully!"
    log "📱 IPA file: $OUTPUT_DIR/Runner.ipa"
    log "📊 IPA size: $(du -h $OUTPUT_DIR/Runner.ipa | cut -f1)"
}

# Function to verify IPA after export
verify_ipa() {
    log "🔍 Verifying exported IPA..."
    
    local IPA_FILE="build/ios/ipa/Runner.ipa"
    
    if [ ! -f "$IPA_FILE" ]; then
        handle_error "IPA file not found at: $IPA_FILE"
    fi
    
    # Check IPA size
    local IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
    log "📊 IPA size: $IPA_SIZE"
    
    # Verify IPA structure
    if ! unzip -t "$IPA_FILE" >/dev/null 2>&1; then
        handle_error "IPA file is corrupted or invalid"
    fi
    
    # Check for Payload/Runner.app
    if ! unzip -l "$IPA_FILE" | grep -q "Payload/Runner.app"; then
        handle_error "IPA does not contain Runner.app"
    fi
    
    log "✅ IPA verification passed"
    log "🎯 IPA is ready for distribution"
}

# Function to process final IPA
process_final_ipa() {
    log "📱 Processing final IPA..."
    
    local SOURCE_IPA="build/ios/ipa/Runner.ipa"
    local OUTPUT_IPA="$OUTPUT_DIR/Runner.ipa"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Copy IPA to output directory
    if [ -f "$SOURCE_IPA" ]; then
        cp "$SOURCE_IPA" "$OUTPUT_IPA"
        log "✅ IPA copied to: $OUTPUT_IPA"
        log "📊 Final IPA size: $(du -h "$OUTPUT_IPA" | cut -f1)"
    else
        handle_error "Source IPA not found: $SOURCE_IPA"
    fi
    
    # TestFlight upload integration
    if [[ "$PROFILE_TYPE" == "app-store" && "${IS_TESTFLIGHT:-false}" == "true" ]]; then
        log "🚀 TestFlight upload enabled - attempting automatic upload..."
        
        # Source the TestFlight script
        local TESTFLIGHT_SCRIPT="$SCRIPT_DIR/testflight.sh"
        if [[ -f "$TESTFLIGHT_SCRIPT" ]]; then
            log "📱 Loading TestFlight upload script: $TESTFLIGHT_SCRIPT"
            source "$TESTFLIGHT_SCRIPT"
            
            # Attempt TestFlight upload
            if upload_to_testflight "$OUTPUT_IPA"; then
                log "🎉 TestFlight upload completed successfully!"
            else
                log "⚠️ TestFlight upload failed, but IPA build was successful"
                log "📱 You can manually upload the IPA to TestFlight"
            fi
        else
            log "❌ TestFlight script not found: $TESTFLIGHT_SCRIPT"
            log "📱 Skipping automatic TestFlight upload"
        fi
    else
        log "📱 TestFlight upload not enabled (PROFILE_TYPE=$PROFILE_TYPE, IS_TESTFLIGHT=${IS_TESTFLIGHT:-false})"
    fi
    
    # Profile-specific success message
    case "$PROFILE_TYPE" in
        "app-store")
            log "🎉 App Store IPA ready for manual upload to App Store Connect"
            log "📋 Next steps: Download IPA and upload via Xcode or Transporter"
            log "🔐 Note: App Store Connect authentication is handled during upload, not build"
            if [[ "${IS_TESTFLIGHT:-false}" == "true" ]]; then
                log "🚀 TestFlight upload was attempted automatically"
            fi
            ;;
        "ad-hoc")
            log "🎉 Ad-Hoc IPA ready for OTA distribution"
            log "📋 Next steps: Host IPA file and create manifest for OTA installation"
            ;;
        "enterprise")
            log "🎉 Enterprise IPA ready for internal distribution"
            log "📋 Next steps: Distribute to enterprise users via MDM or direct installation"
            ;;
        "development")
            log "🎉 Development IPA ready for testing"
            log "📋 Next steps: Install on development devices for testing"
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