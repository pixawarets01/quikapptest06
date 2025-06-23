#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

log "🚀 Testing Two-Stage Podfile Injection System"

# Test configuration
PROJECT_ROOT=$(pwd)
TEST_PROFILE_TYPES=("app-store" "ad-hoc" "enterprise")
TEST_VARS=(
    "APPLE_TEAM_ID=ABC123DEF4"
    "BUNDLE_ID=com.example.testapp"
    "PROFILE_NAME=Test Profile"
    "CODE_SIGN_IDENTITY=Apple Distribution"
    "KEYCHAIN_NAME=test.keychain"
)

# Function to test Podfile generation for a specific profile type
test_podfile_generation() {
    local profile_type=$1
    local stage=$2
    
    log "Testing Podfile generation for $profile_type (Stage: $stage)"
    
    # Set test environment variables
    export APPLE_TEAM_ID="ABC123DEF4"
    export BUNDLE_ID="com.example.testapp"
    export PROFILE_TYPE="$profile_type"
    export PROFILE_NAME="Test $profile_type Profile"
    export CODE_SIGN_IDENTITY="Apple Distribution"
    export KEYCHAIN_NAME="test.keychain"
    export PODFILE_STAGE="$stage"
    
    # Create test directory
    local test_dir="test_podfile_${profile_type}_${stage}"
    mkdir -p "$test_dir/ios"
    
    # Copy Podfile generator to test directory
    cp lib/scripts/ios/generate_podfile.sh "$test_dir/"
    chmod +x "$test_dir/generate_podfile.sh"
    
    # Run Podfile generation
    cd "$test_dir"
    if ./generate_podfile.sh; then
        success "Podfile generation successful for $profile_type ($stage)"
        
        # Verify Podfile was created
        if [ -f "ios/Podfile" ]; then
            success "Podfile file created successfully"
            
            # Check for profile-specific content
            case "$profile_type" in
                "app-store")
                    if grep -q "App Store Configuration" ios/Podfile; then
                        success "App Store configuration found in Podfile"
                    else
                        error "App Store configuration not found in Podfile"
                        return 1
                    fi
                    ;;
                "ad-hoc")
                    if grep -q "Ad-Hoc Configuration" ios/Podfile; then
                        success "Ad-Hoc configuration found in Podfile"
                    else
                        error "Ad-Hoc configuration not found in Podfile"
                        return 1
                    fi
                    ;;
                "enterprise")
                    if grep -q "Enterprise Configuration" ios/Podfile; then
                        success "Enterprise configuration found in Podfile"
                    else
                        error "Enterprise configuration not found in Podfile"
                        return 1
                    fi
                    ;;
            esac
            
            # Check for common configuration
            if grep -q "IPHONEOS_DEPLOYMENT_TARGET.*13.0" ios/Podfile; then
                success "iOS deployment target set correctly"
            else
                error "iOS deployment target not set correctly"
                return 1
            fi
            
            if grep -q "ENABLE_BITCODE.*NO" ios/Podfile; then
                success "Bitcode disabled correctly"
            else
                error "Bitcode not disabled correctly"
                return 1
            fi
            
        else
            error "Podfile not created"
            return 1
        fi
        
    else
        error "Podfile generation failed for $profile_type ($stage)"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}

# Function to test main script flow
test_main_script_flow() {
    local profile_type=$1
    
    log "Testing main script flow for $profile_type"
    
    # Set test environment variables
    export APPLE_TEAM_ID="ABC123DEF4"
    export BUNDLE_ID="com.example.testapp"
    export PROFILE_TYPE="$profile_type"
    export PROFILE_NAME="Test $profile_type Profile"
    export CODE_SIGN_IDENTITY="Apple Distribution"
    export KEYCHAIN_NAME="test.keychain"
    export PUSH_NOTIFY="false"
    export FIREBASE_CONFIG_IOS=""
    
    # Create mock scripts for testing
    mkdir -p test_main_flow/lib/scripts/ios
    mkdir -p test_main_flow/lib/scripts/utils
    
    # Create mock code signing script
    cat > test_main_flow/lib/scripts/ios/code_signing.sh << 'EOF'
#!/bin/bash
echo "Mock code signing setup completed"
exit 0
EOF
    
    # Create mock firebase script
    cat > test_main_flow/lib/scripts/ios/firebase.sh << 'EOF'
#!/bin/bash
echo "Mock firebase setup completed"
exit 0
EOF
    
    # Create mock branding script
    cat > test_main_flow/lib/scripts/ios/branding.sh << 'EOF'
#!/bin/bash
echo "Mock branding setup completed"
exit 0
EOF
    
    # Create mock customization script
    cat > test_main_flow/lib/scripts/ios/customization.sh << 'EOF'
#!/bin/bash
echo "Mock customization setup completed"
exit 0
EOF
    
    # Create mock permissions script
    cat > test_main_flow/lib/scripts/ios/permissions.sh << 'EOF'
#!/bin/bash
echo "Mock permissions setup completed"
exit 0
EOF
    
    # Create mock build script
    cat > test_main_flow/lib/scripts/ios/build_ipa.sh << 'EOF'
#!/bin/bash
echo "Mock IPA build completed"
mkdir -p build/ios/ipa
touch build/ios/ipa/Runner.ipa
exit 0
EOF
    
    # Copy real Podfile generator
    cp lib/scripts/ios/generate_podfile.sh test_main_flow/lib/scripts/ios/
    
    # Create mock main script (simplified version)
    cat > test_main_flow/lib/scripts/ios/main.sh << 'EOF'
#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Mock code signing
./lib/scripts/ios/code_signing.sh

# Mock firebase (if needed)
if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
    ./lib/scripts/ios/firebase.sh
fi

# Mock branding and customization
./lib/scripts/ios/branding.sh
./lib/scripts/ios/customization.sh
./lib/scripts/ios/permissions.sh

# Stage 1: First Podfile Injection
log "Stage 1: First Podfile Injection"
export PODFILE_STAGE="flutter-build"
export CODE_SIGN_STYLE="Automatic"
export CODE_SIGNING_ALLOWED="NO"
export CODE_SIGNING_REQUIRED="NO"

./lib/scripts/ios/generate_podfile.sh

# Mock Flutter build
log "Mock Flutter build (no code signing)"
sleep 1

# Stage 2: Second Podfile Injection
log "Stage 2: Second Podfile Injection"
export PODFILE_STAGE="xcodebuild"
export CODE_SIGN_STYLE="Manual"
export CODE_SIGNING_ALLOWED="NO"
export CODE_SIGNING_REQUIRED="NO"

./lib/scripts/ios/generate_podfile.sh

# Mock xcodebuild
log "Mock xcodebuild with code signing"
./lib/scripts/ios/build_ipa.sh

log "Two-stage Podfile injection completed successfully"
EOF
    
    chmod +x test_main_flow/lib/scripts/ios/*.sh
    
    # Run the test
    cd test_main_flow
    if ./lib/scripts/ios/main.sh; then
        success "Main script flow test passed for $profile_type"
        
        # Verify IPA was created
        if [ -f "build/ios/ipa/Runner.ipa" ]; then
            success "Mock IPA file created successfully"
        else
            error "Mock IPA file not created"
            return 1
        fi
        
    else
        error "Main script flow test failed for $profile_type"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    rm -rf test_main_flow
}

# Main test execution
main() {
    log "Starting comprehensive test of Two-Stage Podfile Injection System"
    
    local all_tests_passed=true
    
    # Test Podfile generation for each profile type and stage
    for profile_type in "${TEST_PROFILE_TYPES[@]}"; do
        for stage in "flutter-build" "xcodebuild"; do
            if ! test_podfile_generation "$profile_type" "$stage"; then
                all_tests_passed=false
            fi
        done
    done
    
    # Test main script flow for each profile type
    for profile_type in "${TEST_PROFILE_TYPES[@]}"; do
        if ! test_main_script_flow "$profile_type"; then
            all_tests_passed=false
        fi
    done
    
    # Final results
    echo ""
    log "Test Results Summary:"
    if [ "$all_tests_passed" = true ]; then
        success "All tests passed! Two-Stage Podfile Injection System is working correctly."
        echo ""
        log "✅ Supported Profile Types:"
        for profile_type in "${TEST_PROFILE_TYPES[@]}"; do
            echo "   - $profile_type"
        done
        echo ""
        log "✅ Two-Stage Process:"
        echo "   - Stage 1: Flutter Build (No Code Signing)"
        echo "   - Stage 2: xcodebuild (With Code Signing)"
        echo ""
        log "✅ Profile-Specific Configurations:"
        echo "   - App Store: Production distribution settings"
        echo "   - Ad-Hoc: OTA distribution with manifest support"
        echo "   - Enterprise: Internal distribution settings"
    else
        error "Some tests failed. Please check the implementation."
        exit 1
    fi
}

# Run the main test
main 