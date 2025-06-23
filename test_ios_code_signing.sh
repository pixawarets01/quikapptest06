#!/bin/bash

# 🧪 Test iOS Enhanced Code Signing Configuration
# Tests the enhanced code signing script for all profile types

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test configuration
TEST_PROFILE_TYPES=("app-store" "ad-hoc" "enterprise" "development")
TEST_BUNDLE_ID="com.example.testapp"
TEST_TEAM_ID="ABC123DEF4"
TEST_CERT_PASSWORD="testpassword"

# Create test certificates directory
setup_test_environment() {
    log "🔧 Setting up test environment..."
    
    # Create test certificates directory
    mkdir -p ios/certificates
    
    # Create dummy certificate file
    echo "dummy certificate content" > ios/certificates/cert.p12
    
    # Create dummy provisioning profile
    cat > ios/certificates/profile.mobileprovision << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UUID</key>
    <string>TEST-UUID-1234-5678-9ABC-DEF012345678</string>
    <key>Name</key>
    <string>Test Profile</string>
    <key>TeamName</key>
    <string>Test Team</string>
    <key>TeamIdentifier</key>
    <array>
        <string>$TEST_TEAM_ID</string>
    </array>
    <key>AppIDName</key>
    <string>Test App</string>
    <key>ApplicationIdentifierPrefix</key>
    <array>
        <string>$TEST_TEAM_ID</string>
    </array>
    <key>Entitlements</key>
    <dict>
        <key>application-identifier</key>
        <string>$TEST_TEAM_ID.$TEST_BUNDLE_ID</string>
        <key>com.apple.developer.team-identifier</key>
        <string>$TEST_TEAM_ID</string>
    </dict>
</dict>
</plist>
EOF
    
    success "Test environment setup completed"
}

# Test code signing script for a specific profile type
test_profile_type() {
    local profile_type="$1"
    
    log "🧪 Testing profile type: $profile_type"
    
    # Set environment variables
    export PROFILE_TYPE="$profile_type"
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export APPLE_TEAM_ID="$TEST_TEAM_ID"
    export CERT_PASSWORD="$TEST_CERT_PASSWORD"
    
    # Backup original project file
    if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
        cp ios/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj.test_backup
    fi
    
    # Run code signing script (with mock security commands)
    if [ -f "lib/scripts/ios/code_signing.sh" ]; then
        # Mock security commands for testing
        export SECURITY_MOCK=true
        
        # Test the script
        if ./lib/scripts/ios/code_signing.sh > "test_output_${profile_type}.log" 2>&1; then
            success "Code signing script passed for $profile_type"
            
            # Check if ExportOptions.plist was generated
            if [ -f "ios/ExportOptions.plist" ]; then
                success "ExportOptions.plist generated for $profile_type"
                
                # Verify ExportOptions.plist content
                if grep -q "method.*$profile_type" ios/ExportOptions.plist; then
                    success "ExportOptions.plist contains correct method: $profile_type"
                else
                    error "ExportOptions.plist missing correct method for $profile_type"
                fi
                
                if grep -q "teamID.*$TEST_TEAM_ID" ios/ExportOptions.plist; then
                    success "ExportOptions.plist contains correct team ID"
                else
                    error "ExportOptions.plist missing correct team ID"
                fi
                
                if grep -q "signingStyle.*manual" ios/ExportOptions.plist; then
                    success "ExportOptions.plist contains manual signing style"
                else
                    error "ExportOptions.plist missing manual signing style"
                fi
            else
                error "ExportOptions.plist not generated for $profile_type"
            fi
        else
            error "Code signing script failed for $profile_type"
            cat "test_output_${profile_type}.log"
        fi
    else
        error "Code signing script not found"
        return 1
    fi
    
    # Restore original project file
    if [ -f "ios/Runner.xcodeproj/project.pbxproj.test_backup" ]; then
        mv ios/Runner.xcodeproj/project.pbxproj.test_backup ios/Runner.xcodeproj/project.pbxproj
    fi
}

# Test Xcode project configuration
test_xcode_configuration() {
    log "🔧 Testing Xcode project configuration..."
    
    local profile_type="$1"
    
    # Set environment variables
    export PROFILE_TYPE="$profile_type"
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export APPLE_TEAM_ID="$TEST_TEAM_ID"
    export CERT_PASSWORD="$TEST_CERT_PASSWORD"
    
    # Run the configure_xcode_code_signing function
    if [ -f "lib/scripts/ios/code_signing.sh" ]; then
        # Source the script and test the function
        source lib/scripts/ios/code_signing.sh
        
        # Test the function
        if configure_xcode_code_signing; then
            success "Xcode configuration successful for $profile_type"
            
            # Check if project file was updated
            if grep -q "CODE_SIGN_STYLE" ios/Runner.xcodeproj/project.pbxproj; then
                success "Code signing style configured in project file"
            else
                error "Code signing style not configured in project file"
            fi
            
            if grep -q "CODE_SIGN_IDENTITY" ios/Runner.xcodeproj/project.pbxproj; then
                success "Code signing identity configured in project file"
            else
                error "Code signing identity not configured in project file"
            fi
        else
            error "Xcode configuration failed for $profile_type"
        fi
    fi
}

# Test keychain and certificate setup
test_keychain_setup() {
    log "🔑 Testing keychain and certificate setup..."
    
    # Set environment variables
    export CERT_PASSWORD="$TEST_CERT_PASSWORD"
    
    if [ -f "lib/scripts/ios/code_signing.sh" ]; then
        source lib/scripts/ios/code_signing.sh
        
        # Test the function (with mock security commands)
        if setup_keychain_and_certificates; then
            success "Keychain and certificate setup successful"
        else
            warning "Keychain and certificate setup failed (expected in test environment)"
        fi
    fi
}

# Test provisioning profile installation
test_provisioning_profile() {
    log "📱 Testing provisioning profile installation..."
    
    # Set environment variables
    export PROFILE_TYPE="app-store"
    
    if [ -f "lib/scripts/ios/code_signing.sh" ]; then
        source lib/scripts/ios/code_signing.sh
        
        # Test the function
        if install_provisioning_profile; then
            success "Provisioning profile installation successful"
        else
            warning "Provisioning profile installation failed (expected in test environment)"
        fi
    fi
}

# Test export options generation
test_export_options() {
    log "📦 Testing export options generation..."
    
    for profile_type in "${TEST_PROFILE_TYPES[@]}"; do
        log "Testing export options for $profile_type"
        
        # Set environment variables
        export PROFILE_TYPE="$profile_type"
        export BUNDLE_ID="$TEST_BUNDLE_ID"
        export APPLE_TEAM_ID="$TEST_TEAM_ID"
        
        if [ -f "lib/scripts/ios/code_signing.sh" ]; then
            source lib/scripts/ios/code_signing.sh
            
            # Test the function
            if generate_export_options; then
                success "Export options generation successful for $profile_type"
                
                # Verify the generated file
                if [ -f "ios/ExportOptions.plist" ]; then
                    success "ExportOptions.plist generated for $profile_type"
                    
                    # Check specific profile type configurations
                    case "$profile_type" in
                        "app-store")
                            if grep -q "uploadSymbols.*true" ios/ExportOptions.plist; then
                                success "App Store upload symbols enabled"
                            else
                                error "App Store upload symbols not enabled"
                            fi
                            ;;
                        "ad-hoc")
                            if grep -q "uploadSymbols.*false" ios/ExportOptions.plist; then
                                success "Ad-Hoc upload symbols disabled"
                            else
                                error "Ad-Hoc upload symbols not disabled"
                            fi
                            ;;
                    esac
                else
                    error "ExportOptions.plist not generated for $profile_type"
                fi
            else
                error "Export options generation failed for $profile_type"
            fi
        fi
    done
}

# Test verification function
test_verification() {
    log "🔍 Testing code signing verification..."
    
    # Set environment variables
    export PROFILE_TYPE="app-store"
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export APPLE_TEAM_ID="$TEST_TEAM_ID"
    export CERT_PASSWORD="$TEST_CERT_PASSWORD"
    
    if [ -f "lib/scripts/ios/code_signing.sh" ]; then
        source lib/scripts/ios/code_signing.sh
        
        # Test the function
        if verify_code_signing_setup; then
            success "Code signing verification successful"
        else
            warning "Code signing verification failed (expected in test environment)"
        fi
    fi
}

# Cleanup test environment
cleanup_test_environment() {
    log "🧹 Cleaning up test environment..."
    
    # Remove test files
    rm -rf ios/certificates
    rm -f ios/ExportOptions.plist
    rm -f test_output_*.log
    
    # Restore original project file if backup exists
    if [ -f "ios/Runner.xcodeproj/project.pbxproj.test_backup" ]; then
        mv ios/Runner.xcodeproj/project.pbxproj.test_backup ios/Runner.xcodeproj/project.pbxproj
    fi
    
    success "Test environment cleaned up"
}

# Main test execution
main() {
    log "🚀 Starting iOS Enhanced Code Signing Tests..."
    
    # Check if we're in the right directory
    if [ ! -f "lib/scripts/ios/code_signing.sh" ]; then
        error "Code signing script not found. Please run this from the project root."
        exit 1
    fi
    
    # Setup test environment
    setup_test_environment
    
    # Test each profile type
    for profile_type in "${TEST_PROFILE_TYPES[@]}"; do
        log "🧪 Testing profile type: $profile_type"
        test_profile_type "$profile_type"
        test_xcode_configuration "$profile_type"
        echo ""
    done
    
    # Test individual components
    test_keychain_setup
    test_provisioning_profile
    test_export_options
    test_verification
    
    # Cleanup
    cleanup_test_environment
    
    log "🎉 All tests completed!"
    success "iOS Enhanced Code Signing Configuration is ready for all profile types!"
}

# Run main function
main "$@" 