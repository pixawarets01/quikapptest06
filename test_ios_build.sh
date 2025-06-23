#!/bin/bash

# 🧪 Test iOS Enhanced Build Process
# Tests the enhanced build process for consistent IPA generation

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
TEST_BUNDLE_ID="com.example.testapp"
TEST_VERSION_NAME="1.0.0"
TEST_VERSION_CODE="1"
TEST_PROFILE_TYPE="app-store"

# Setup test environment
setup_test_environment() {
    log "🔧 Setting up test environment..."
    
    # Create necessary directories
    mkdir -p ios/Runner
    mkdir -p ios/certificates
    mkdir -p assets
    mkdir -p output/ios
    
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
    <string>$TEST_VERSION_CODE</string>
    <key>CFBundleShortVersionString</key>
    <string>$TEST_VERSION_NAME</string>
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
    
    # Create test ExportOptions.plist
    cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$TEST_PROFILE_TYPE</string>
    <key>teamID</key>
    <string>TEST123</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$TEST_BUNDLE_ID</key>
        <string>TestProfile</string>
    </dict>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF
    
    # Create test certificate and profile
    echo "dummy certificate content" > ios/certificates/cert.p12
    echo "dummy profile content" > ios/certificates/profile.mobileprovision
    
    success "Test environment setup completed"
}

# Test build script validation
test_build_script_validation() {
    log "🧪 Testing build script validation..."
    
    # Set environment variables
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export VERSION_NAME="$TEST_VERSION_NAME"
    export VERSION_CODE="$TEST_VERSION_CODE"
    export PROFILE_TYPE="$TEST_PROFILE_TYPE"
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        chmod +x lib/scripts/ios/build_ipa.sh
        
        # Test validation function
        if source lib/scripts/ios/build_ipa.sh && validate_build_environment; then
            success "Build script validation passed"
        else
            error "Build script validation failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test build environment cleaning
test_build_environment_cleaning() {
    log "🧪 Testing build environment cleaning..."
    
    # Create some test build files
    mkdir -p ios/build/test
    mkdir -p ios/Pods/test
    echo "test" > ios/build/test/file.txt
    echo "test" > ios/Pods/test/file.txt
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Test cleaning function
        if clean_build_environment; then
            success "Build environment cleaning passed"
            
            # Verify files were cleaned
            if [ ! -d "ios/build" ] || [ ! -d "ios/Pods" ]; then
                success "Build directories cleaned successfully"
            else
                error "Build directories not cleaned properly"
                return 1
            fi
        else
            error "Build environment cleaning failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test dependency installation
test_dependency_installation() {
    log "🧪 Testing dependency installation..."
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Mock pod install for testing
        function pod() {
            if [ "$1" = "install" ]; then
                mkdir -p ios/Pods
                echo "Mock pod install completed"
                return 0
            fi
            return 1
        }
        export -f pod
        
        # Test dependency installation
        if install_ios_dependencies; then
            success "Dependency installation test passed"
        else
            error "Dependency installation test failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test code signing verification
test_code_signing_verification() {
    log "🧪 Testing code signing verification..."
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Mock security commands for testing
        function security() {
            if [ "$1" = "list-keychains" ]; then
                echo "build.keychain"
                return 0
            elif [ "$1" = "find-identity" ]; then
                echo "iPhone Distribution: Test Certificate"
                return 0
            fi
            return 1
        }
        export -f security
        
        # Test code signing verification
        if verify_code_signing_setup; then
            success "Code signing verification test passed"
        else
            error "Code signing verification test failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test Flutter build process
test_flutter_build() {
    log "🧪 Testing Flutter build process..."
    
    # Set environment variables
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export VERSION_NAME="$TEST_VERSION_NAME"
    export VERSION_CODE="$TEST_VERSION_CODE"
    export PROFILE_TYPE="$TEST_PROFILE_TYPE"
    export CI="true"
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Mock flutter command for testing
        function flutter() {
            if [ "$1" = "build" ] && [ "$2" = "ipa" ]; then
                # Create mock IPA file
                mkdir -p build/ios/ipa
                echo "Mock IPA content" > build/ios/ipa/Runner.ipa
                echo "Mock Flutter build completed"
                return 0
            fi
            return 1
        }
        export -f flutter
        
        # Test Flutter build
        if build_ipa_with_flutter; then
            success "Flutter build test passed"
        else
            error "Flutter build test failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test IPA finding and verification
test_ipa_finding() {
    log "🧪 Testing IPA finding and verification..."
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Create mock IPA files
        mkdir -p build/ios/ipa
        echo "Mock IPA content" > build/ios/ipa/Runner.ipa
        
        # Test IPA finding
        local IPA_INFO=$(find_and_verify_ipa)
        if [ -n "$IPA_INFO" ]; then
            success "IPA finding test passed"
            
            # Parse IPA info
            local IPA_PATH=$(echo "$IPA_INFO" | cut -d'|' -f1)
            local IPA_NAME=$(echo "$IPA_INFO" | cut -d'|' -f2)
            local IPA_SIZE=$(echo "$IPA_INFO" | cut -d'|' -f3)
            
            log "IPA Info: $IPA_PATH | $IPA_NAME | $IPA_SIZE"
        else
            error "IPA finding test failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test IPA copying to output
test_ipa_copying() {
    log "🧪 Testing IPA copying to output..."
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Create mock IPA
        mkdir -p build/ios/ipa
        echo "Mock IPA content" > build/ios/ipa/Runner.ipa
        
        # Test IPA copying
        if copy_ipa_to_output "build/ios/ipa/Runner.ipa" "Runner.ipa"; then
            success "IPA copying test passed"
            
            # Verify copied file
            if [ -f "output/ios/Runner.ipa" ]; then
                success "IPA file copied successfully"
            else
                error "IPA file not copied"
                return 1
            fi
        else
            error "IPA copying test failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test build report generation
test_build_report() {
    log "🧪 Testing build report generation..."
    
    # Set environment variables
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export VERSION_NAME="$TEST_VERSION_NAME"
    export VERSION_CODE="$TEST_VERSION_CODE"
    export PROFILE_TYPE="$TEST_PROFILE_TYPE"
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        source lib/scripts/ios/build_ipa.sh
        
        # Mock flutter and xcodebuild for testing
        function flutter() {
            echo "Flutter 3.32.2"
        }
        function xcodebuild() {
            echo "Xcode 15.4"
        }
        export -f flutter xcodebuild
        
        # Test build report generation
        if generate_build_report "build/ios/ipa/Runner.ipa" "Runner.ipa" "1024"; then
            success "Build report generation test passed"
            
            # Verify report file
            if [ -f "output/ios/build_report.txt" ]; then
                success "Build report file created"
                
                # Check report content
                if grep -q "Bundle ID: $TEST_BUNDLE_ID" output/ios/build_report.txt; then
                    success "Build report contains correct bundle ID"
                else
                    error "Build report missing bundle ID"
                    return 1
                fi
            else
                error "Build report file not created"
                return 1
            fi
        else
            error "Build report generation test failed"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Test complete build process
test_complete_build_process() {
    log "🧪 Testing complete build process..."
    
    # Set environment variables
    export BUNDLE_ID="$TEST_BUNDLE_ID"
    export VERSION_NAME="$TEST_VERSION_NAME"
    export VERSION_CODE="$TEST_VERSION_CODE"
    export PROFILE_TYPE="$TEST_PROFILE_TYPE"
    export CI="true"
    
    # Mock all required commands
    function flutter() {
        if [ "$1" = "clean" ]; then
            echo "Flutter clean completed"
            return 0
        elif [ "$1" = "build" ]; then
            mkdir -p build/ios/ipa
            echo "Mock IPA content" > build/ios/ipa/Runner.ipa
            echo "Flutter build completed"
            return 0
        elif [ "$1" = "--version" ]; then
            echo "Flutter 3.32.2"
            return 0
        fi
        return 1
    }
    
    function pod() {
        if [ "$1" = "install" ]; then
            mkdir -p ios/Pods
            echo "Mock pod install completed"
            return 0
        fi
        return 1
    }
    
    function security() {
        if [ "$1" = "list-keychains" ]; then
            echo "build.keychain"
            return 0
        elif [ "$1" = "find-identity" ]; then
            echo "iPhone Distribution: Test Certificate"
            return 0
        fi
        return 1
    }
    
    function xcodebuild() {
        if [ "$1" = "--version" ]; then
            echo "Xcode 15.4"
            return 0
        fi
        return 1
    }
    
    export -f flutter pod security xcodebuild
    
    if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
        chmod +x lib/scripts/ios/build_ipa.sh
        
        # Run complete build process
        if ./lib/scripts/ios/build_ipa.sh > "test_output_complete_build.log" 2>&1; then
            success "Complete build process test passed"
            
            # Verify outputs
            if [ -f "output/ios/Runner.ipa" ]; then
                success "IPA file generated successfully"
            else
                error "IPA file not generated"
                return 1
            fi
            
            if [ -f "output/ios/build_report.txt" ]; then
                success "Build report generated successfully"
            else
                error "Build report not generated"
                return 1
            fi
        else
            error "Complete build process test failed"
            cat "test_output_complete_build.log"
            return 1
        fi
    else
        error "Build script not found"
        return 1
    fi
}

# Cleanup test environment
cleanup_test_environment() {
    log "🧹 Cleaning up test environment..."
    
    # Remove test files and directories
    rm -rf ios/build/ 2>/dev/null || true
    rm -rf ios/Pods/ 2>/dev/null || true
    rm -rf build/ 2>/dev/null || true
    rm -rf output/ 2>/dev/null || true
    rm -f test_output_*.log 2>/dev/null || true
    
    # Restore original files if backups exist
    if [ -f "ios/Runner/Info.plist.backup" ]; then
        mv ios/Runner/Info.plist.backup ios/Runner/Info.plist
    fi
    
    if [ -f "ios/Podfile.backup" ]; then
        mv ios/Podfile.backup ios/Podfile
    fi
    
    if [ -f "ios/ExportOptions.plist.backup" ]; then
        mv ios/ExportOptions.plist.backup ios/ExportOptions.plist
    fi
    
    success "Test environment cleaned up"
}

# Main test execution
main() {
    log "🚀 Starting iOS Enhanced Build Process Tests..."
    
    # Check if we're in the right directory
    if [ ! -f "lib/scripts/ios/build_ipa.sh" ]; then
        error "Build script not found. Please run this from the project root."
        exit 1
    fi
    
    # Setup test environment
    setup_test_environment
    
    # Run tests
    test_build_script_validation
    test_build_environment_cleaning
    test_dependency_installation
    test_code_signing_verification
    test_flutter_build
    test_ipa_finding
    test_ipa_copying
    test_build_report
    test_complete_build_process
    
    # Cleanup
    cleanup_test_environment
    
    log "🎉 All tests completed!"
    success "iOS Enhanced Build Process is working correctly!"
    log "📊 Summary:"
    log "   ✅ Build script validation"
    log "   ✅ Environment cleaning"
    log "   ✅ Dependency installation"
    log "   ✅ Code signing verification"
    log "   ✅ Flutter build process"
    log "   ✅ IPA finding and verification"
    log "   ✅ IPA copying to output"
    log "   ✅ Build report generation"
    log "   ✅ Complete build process"
}

# Run main function
main "$@" 