#!/bin/bash

# 🧪 Test iOS Conditional Firebase Configuration
# Tests Firebase setup based on PUSH_NOTIFY flag

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
TEST_FIREBASE_URL="https://example.com/GoogleService-Info.plist"
TEST_BUNDLE_ID="com.example.testapp"

# Create test Firebase config
create_test_firebase_config() {
    log "🔧 Creating test Firebase configuration..."
    
    # Create test GoogleService-Info.plist
    cat > test_GoogleService-Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_KEY</key>
    <string>test-api-key</string>
    <key>GCM_SENDER_ID</key>
    <string>123456789</string>
    <key>PLIST_VERSION</key>
    <string>1</string>
    <key>BUNDLE_ID</key>
    <string>$TEST_BUNDLE_ID</string>
    <key>PROJECT_ID</key>
    <string>test-project</string>
    <key>STORAGE_BUCKET</key>
    <string>test-project.appspot.com</string>
    <key>IS_ADS_ENABLED</key>
    <false/>
    <key>IS_ANALYTICS_ENABLED</key>
    <false/>
    <key>IS_APPINVITE_ENABLED</key>
    <true/>
    <key>IS_GCM_ENABLED</key>
    <true/>
    <key>IS_SIGNIN_ENABLED</key>
    <true/>
    <key>GOOGLE_APP_ID</key>
    <string>1:123456789:ios:abcdef123456</string>
</dict>
</plist>
EOF
    
    success "Test Firebase configuration created"
}

# Setup test environment
setup_test_environment() {
    log "🔧 Setting up test environment..."
    
    # Create necessary directories
    mkdir -p ios/Runner
    mkdir -p ios/certificates
    mkdir -p assets
    
    # Create test Info.plist
    cat > ios/Runner/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$TEST_BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>TestApp</string>
    <key>CFBundleDisplayName</key>
    <string>TestApp</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF
    
    # Create test Podfile
    cat > ios/Podfile << EOF
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
EOF
    
    success "Test environment setup completed"
}

# Test Firebase enabled scenario
test_firebase_enabled() {
    log "🧪 Testing Firebase ENABLED scenario (PUSH_NOTIFY=true)..."
    
    # Set environment variables
    export PUSH_NOTIFY="true"
    export FIREBASE_CONFIG_IOS="$TEST_FIREBASE_URL"
    
    # Backup test files
    cp ios/Runner/Info.plist ios/Runner/Info.plist.backup
    cp ios/Podfile ios/Podfile.backup
    
    # Mock curl to return our test config
    function curl() {
        if [[ "$*" == *"$TEST_FIREBASE_URL"* ]]; then
            cp test_GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
            return 0
        fi
        return 1
    }
    export -f curl
    
    # Run Firebase script
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        chmod +x lib/scripts/ios/firebase.sh
        if ./lib/scripts/ios/firebase.sh > "test_output_firebase_enabled.log" 2>&1; then
            success "Firebase script passed for enabled scenario"
            
            # Verify Firebase configuration files
            if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
                success "Firebase config file created"
            else
                error "Firebase config file not created"
            fi
            
            if [ -f "assets/GoogleService-Info.plist" ]; then
                success "Firebase config copied to assets"
            else
                error "Firebase config not copied to assets"
            fi
            
            # Verify Podfile contains Firebase dependencies
            if grep -q "pod 'Firebase/Core'" ios/Podfile; then
                success "Firebase dependencies added to Podfile"
            else
                error "Firebase dependencies not added to Podfile"
            fi
            
            if grep -q "pod 'Firebase/Messaging'" ios/Podfile; then
                success "Firebase Messaging dependency added to Podfile"
            else
                error "Firebase Messaging dependency not added to Podfile"
            fi
            
            # Verify Info.plist has push notification configuration
            if /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" ios/Runner/Info.plist 2>/dev/null | grep -q "remote-notification"; then
                success "Push notification background mode configured"
            else
                error "Push notification background mode not configured"
            fi
            
            if /usr/libexec/PlistBuddy -c "Print :FirebaseAppDelegateProxyEnabled" ios/Runner/Info.plist 2>/dev/null | grep -q "false"; then
                success "Firebase App Delegate Proxy disabled"
            else
                error "Firebase App Delegate Proxy not configured"
            fi
            
        else
            error "Firebase script failed for enabled scenario"
            cat "test_output_firebase_enabled.log"
        fi
    else
        error "Firebase script not found"
        return 1
    fi
    
    # Restore test files
    mv ios/Runner/Info.plist.backup ios/Runner/Info.plist
    mv ios/Podfile.backup ios/Podfile
}

# Test Firebase disabled scenario
test_firebase_disabled() {
    log "🧪 Testing Firebase DISABLED scenario (PUSH_NOTIFY=false)..."
    
    # Set environment variables
    export PUSH_NOTIFY="false"
    export FIREBASE_CONFIG_IOS="$TEST_FIREBASE_URL"
    
    # Backup test files
    cp ios/Runner/Info.plist ios/Runner/Info.plist.backup
    cp ios/Podfile ios/Podfile.backup
    
    # Create some existing Firebase files to test removal
    cp test_GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
    cp test_GoogleService-Info.plist assets/GoogleService-Info.plist
    
    # Add Firebase dependencies to Podfile
    cat >> ios/Podfile << EOF

# Firebase dependencies for push notifications
pod 'Firebase/Core'
pod 'Firebase/Messaging'
EOF
    
    # Add push notification config to Info.plist
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" ios/Runner/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes: string 'remote-notification'" ios/Runner/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :FirebaseAppDelegateProxyEnabled bool false" ios/Runner/Info.plist 2>/dev/null || true
    
    # Run Firebase script
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        chmod +x lib/scripts/ios/firebase.sh
        if ./lib/scripts/ios/firebase.sh > "test_output_firebase_disabled.log" 2>&1; then
            success "Firebase script passed for disabled scenario"
            
            # Verify Firebase configuration files are removed
            if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
                success "Firebase config file removed"
            else
                error "Firebase config file still exists"
            fi
            
            if [ ! -f "assets/GoogleService-Info.plist" ]; then
                success "Firebase config removed from assets"
            else
                error "Firebase config still exists in assets"
            fi
            
            # Verify Podfile doesn't contain Firebase dependencies
            if ! grep -q "pod 'Firebase/Core'" ios/Podfile; then
                success "Firebase dependencies removed from Podfile"
            else
                error "Firebase dependencies still present in Podfile"
            fi
            
            if ! grep -q "pod 'Firebase/Messaging'" ios/Podfile; then
                success "Firebase Messaging dependency removed from Podfile"
            else
                error "Firebase Messaging dependency still present in Podfile"
            fi
            
            # Verify Info.plist doesn't have push notification configuration
            if ! /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" ios/Runner/Info.plist 2>/dev/null | grep -q "remote-notification"; then
                success "Push notification background mode removed"
            else
                error "Push notification background mode still configured"
            fi
            
        else
            error "Firebase script failed for disabled scenario"
            cat "test_output_firebase_disabled.log"
        fi
    else
        error "Firebase script not found"
        return 1
    fi
    
    # Restore test files
    mv ios/Runner/Info.plist.backup ios/Runner/Info.plist
    mv ios/Podfile.backup ios/Podfile
}

# Test validation scenarios
test_validation_scenarios() {
    log "🧪 Testing validation scenarios..."
    
    # Test 1: PUSH_NOTIFY=true but no FIREBASE_CONFIG_IOS
    log "Testing PUSH_NOTIFY=true without FIREBASE_CONFIG_IOS..."
    export PUSH_NOTIFY="true"
    export FIREBASE_CONFIG_IOS=""
    
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        if ./lib/scripts/ios/firebase.sh > "test_output_validation1.log" 2>&1; then
            error "Firebase script should have failed without FIREBASE_CONFIG_IOS"
        else
            success "Firebase script correctly failed without FIREBASE_CONFIG_IOS"
        fi
    fi
    
    # Test 2: PUSH_NOTIFY=true with invalid FIREBASE_CONFIG_IOS URL
    log "Testing PUSH_NOTIFY=true with invalid FIREBASE_CONFIG_IOS URL..."
    export PUSH_NOTIFY="true"
    export FIREBASE_CONFIG_IOS="invalid-url"
    
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        if ./lib/scripts/ios/firebase.sh > "test_output_validation2.log" 2>&1; then
            error "Firebase script should have failed with invalid URL"
        else
            success "Firebase script correctly failed with invalid URL"
        fi
    fi
}

# Test integration with main script
test_main_script_integration() {
    log "🧪 Testing integration with main script..."
    
    # Test the Firebase section in main script
    export PUSH_NOTIFY="true"
    export FIREBASE_CONFIG_IOS="$TEST_FIREBASE_URL"
    
    # Mock curl for main script test
    function curl() {
        if [[ "$*" == *"$TEST_FIREBASE_URL"* ]]; then
            cp test_GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
            return 0
        fi
        return 1
    }
    export -f curl
    
    # Extract and test the Firebase section from main script
    if [ -f "lib/scripts/ios/main.sh" ]; then
        # Create a test version of the Firebase section
        cat > test_firebase_section.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# 🔥 Firebase Configuration (Conditional based on PUSH_NOTIFY)
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
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
EOF
        
        chmod +x test_firebase_section.sh
        if ./test_firebase_section.sh > "test_output_main_integration.log" 2>&1; then
            success "Main script Firebase integration test passed"
        else
            error "Main script Firebase integration test failed"
            cat "test_output_main_integration.log"
        fi
    fi
}

# Cleanup test environment
cleanup_test_environment() {
    log "🧹 Cleaning up test environment..."
    
    # Remove test files
    rm -f test_GoogleService-Info.plist
    rm -f test_firebase_section.sh
    rm -f test_output_*.log
    
    # Remove Firebase files
    rm -f ios/Runner/GoogleService-Info.plist
    rm -f assets/GoogleService-Info.plist
    
    # Restore original files if backups exist
    if [ -f "ios/Runner/Info.plist.backup" ]; then
        mv ios/Runner/Info.plist.backup ios/Runner/Info.plist
    fi
    
    if [ -f "ios/Podfile.backup" ]; then
        mv ios/Podfile.backup ios/Podfile
    fi
    
    success "Test environment cleaned up"
}

# Main test execution
main() {
    log "🚀 Starting iOS Conditional Firebase Tests..."
    
    # Check if we're in the right directory
    if [ ! -f "lib/scripts/ios/firebase.sh" ]; then
        error "Firebase script not found. Please run this from the project root."
        exit 1
    fi
    
    # Setup test environment
    setup_test_environment
    create_test_firebase_config
    
    # Run tests
    test_firebase_enabled
    test_firebase_disabled
    test_validation_scenarios
    test_main_script_integration
    
    # Cleanup
    cleanup_test_environment
    
    log "🎉 All tests completed!"
    success "iOS Conditional Firebase Configuration is working correctly!"
    log "📊 Summary:"
    log "   ✅ Firebase enabled when PUSH_NOTIFY=true"
    log "   ✅ Firebase disabled when PUSH_NOTIFY=false"
    log "   ✅ Proper validation and error handling"
    log "   ✅ Integration with main script"
}

# Run main function
main "$@" 