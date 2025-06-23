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

log "🚀 Testing Firebase Compatibility Fixes"

# Test configuration
PROJECT_ROOT=$(pwd)
TEST_PROFILE_TYPES=("app-store" "ad-hoc" "enterprise")
TEST_VARS=(
    "APPLE_TEAM_ID=ABC123DEF4"
    "BUNDLE_ID=com.example.testapp"
    "PROFILE_NAME=Test Profile"
    "CODE_SIGN_IDENTITY=Apple Distribution"
    "KEYCHAIN_NAME=test.keychain"
    "PUSH_NOTIFY=true"
    "FIREBASE_CONFIG_IOS=https://example.com/GoogleService-Info.plist"
)

# Function to test Podfile generation with Firebase compatibility
test_firebase_compatibility() {
    local PROFILE_TYPE=$1
    local STAGE=$2
    
    log "Testing Firebase compatibility for $PROFILE_TYPE profile, $STAGE stage"
    
    # Set test environment variables
    for VAR in "${TEST_VARS[@]}"; do
        export "$VAR"
    done
    export PROFILE_TYPE="$PROFILE_TYPE"
    
    # Clean up any existing files
    rm -rf ios/Pods ios/Podfile.lock ios/Pods.xcodeproj 2>/dev/null || true
    
    # Generate Podfile
    if [ -f "lib/scripts/ios/generate_podfile.sh" ]; then
        chmod +x lib/scripts/ios/generate_podfile.sh
        if ./lib/scripts/ios/generate_podfile.sh "$STAGE" "$PROFILE_TYPE"; then
            success "Podfile generated for $PROFILE_TYPE, $STAGE stage"
        else
            error "Podfile generation failed for $PROFILE_TYPE, $STAGE stage"
            return 1
        fi
    else
        error "Podfile generator script not found"
        return 1
    fi
    
    # Verify Podfile contains Firebase compatibility fixes
    if [ -f "ios/Podfile" ]; then
        log "Verifying Firebase compatibility fixes in Podfile..."
        
        # Check for Swift compiler flags
        if grep -q "enable-experimental-feature AccessLevelOnImport" ios/Podfile; then
            success "Swift compiler flag found"
        else
            error "Swift compiler flag not found"
            return 1
        fi
        
        # Check for pre_install hook
        if grep -q "pre_install do" ios/Podfile; then
            success "Pre-install hook found"
        else
            error "Pre-install hook not found"
            return 1
        fi
        
        # Check for CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER
        if grep -q "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER.*NO" ios/Podfile; then
            success "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER fix found"
        else
            error "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER fix not found"
            return 1
        fi
        
        # Check for post_install hook with Swift compiler fixes
        if grep -q "OTHER_SWIFT_FLAGS.*enable-experimental-feature AccessLevelOnImport" ios/Podfile; then
            success "Post-install Swift compiler fixes found"
        else
            error "Post-install Swift compiler fixes not found"
            return 1
        fi
        
        success "All Firebase compatibility fixes verified for $PROFILE_TYPE, $STAGE stage"
        return 0
    else
        error "Podfile not found"
        return 1
    fi
}

# Test all profile types and stages
log "Testing all profile types and stages..."
TOTAL_TESTS=0
PASSED_TESTS=0

for PROFILE_TYPE in "${TEST_PROFILE_TYPES[@]}"; do
    for STAGE in "flutter-build" "xcodebuild"; do
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if test_firebase_compatibility "$PROFILE_TYPE" "$STAGE"; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi
        echo ""
    done
done

# Summary
log "Test Summary:"
log "  Total tests: $TOTAL_TESTS"
log "  Passed: $PASSED_TESTS"
log "  Failed: $((TOTAL_TESTS - PASSED_TESTS))"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    success "All Firebase compatibility tests passed!"
    exit 0
else
    error "Some Firebase compatibility tests failed!"
    exit 1
fi 