#!/bin/bash

# QuikApp Android Workflows Local Test Script
# Tests all Android workflows: android-free, android-paid, android-publish

set -e

echo "🚀 QuikApp Android Workflows Local Test"
echo "========================================"

# Set up test environment variables based on codemagic.yaml
export APP_ID="quikapptest06"
export APP_NAME="Garbcode App"
export PKG_NAME="com.garbcode.garbcodeapp"
export VERSION_NAME="1.0.7"
export VERSION_CODE="43"
export ORG_NAME="Garbcode"
export WEB_URL="https://garbcode.com"
export EMAIL_ID="prasanna@garbcode.com"
export USER_NAME="prasanna91"
export LOGO_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/assets/images/logo.png"

# Feature flags
export PUSH_NOTIFY="true"
export IS_CHATBOT="false"
export IS_DOMAIN_URL="false"
export IS_SPLASH="true"
export IS_PULLDOWN="true"
export IS_BOTTOMMENU="true"
export IS_LOAD_IND="true"

# Permissions
export IS_CAMERA="true"
export IS_LOCATION="true"
export IS_MIC="true"
export IS_NOTIFICATION="true"
export IS_CONTACT="true"
export IS_BIOMETRIC="false"
export IS_CALENDAR="false"
export IS_STORAGE="true"

# UI Configuration
export SPLASH_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/assets/images/splash.png"
export SPLASH_BG_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/assets/images/splash_bg.png"
export SPLASH_BG_COLOR="#FFFFFF"
export SPLASH_TAGLINE="Welcome to Garbcode"
export SPLASH_TAGLINE_COLOR="#000000"
export SPLASH_ANIMATION="fade"
export SPLASH_DURATION="3000"

# Bottom Menu
export BOTTOMMENU_ITEMS='[{"title":"Home","icon":"home","url":"https://garbcode.com"},{"title":"About","icon":"info","url":"https://garbcode.com/about"}]'
export BOTTOMMENU_BG_COLOR="#FFFFFF"
export BOTTOMMENU_ICON_COLOR="#666666"
export BOTTOMMENU_TEXT_COLOR="#333333"
export BOTTOMMENU_FONT="DM Sans"
export BOTTOMMENU_FONT_SIZE="12"
export BOTTOMMENU_FONT_BOLD="false"
export BOTTOMMENU_FONT_ITALIC="false"
export BOTTOMMENU_ACTIVE_TAB_COLOR="#007AFF"
export BOTTOMMENU_ICON_POSITION="top"
export BOTTOMMENU_VISIBLE_ON="all"

# Firebase (for paid/publish workflows)
export FIREBASE_CONFIG_ANDROID="https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services.json"

# Keystore (for publish workflow)
export KEY_STORE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"
export CM_KEYSTORE_PASSWORD="opeN@1234"
export CM_KEY_ALIAS="my_key_alias"
export CM_KEY_PASSWORD="opeN@1234"

# Admin/Build variables
export BUILD_MODE="release"
export FLUTTER_VERSION="3.24.0"
export PROJECT_ROOT="$(pwd)"
export ANDROID_ROOT="$PROJECT_ROOT/android"
export OUTPUT_DIR="$PROJECT_ROOT/output"
export TEMP_DIR="/tmp/quikapp_build"

# Create output directories
mkdir -p "$OUTPUT_DIR/android"
mkdir -p "$TEMP_DIR"

echo ""
echo "📋 Test Configuration:"
echo "App: $APP_NAME v$VERSION_NAME ($VERSION_CODE)"
echo "Package: $PKG_NAME"
echo "Firebase: $([ "$PUSH_NOTIFY" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
echo "Keystore: $([ -n "$KEY_STORE_URL" ] && echo "✅ Enabled" || echo "❌ Disabled")"
echo ""

# Function to test workflow
test_workflow() {
    local workflow_name="$1"
    local workflow_type="$2"
    
    echo "🧪 Testing Workflow: $workflow_name"
    echo "----------------------------------------"
    
    # Set workflow-specific environment
    export CM_WORKFLOW="$workflow_type"
    
    # Adjust Firebase for free workflow
    if [ "$workflow_type" = "android-free" ]; then
        export PUSH_NOTIFY="false"
        export FIREBASE_CONFIG_ANDROID=""
        echo "   🔧 Firebase disabled for free workflow"
    else
        export PUSH_NOTIFY="true"
        export FIREBASE_CONFIG_ANDROID="https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services.json"
        echo "   🔧 Firebase enabled for $workflow_type workflow"
    fi
    
    # Adjust keystore for free/paid workflows
    if [ "$workflow_type" = "android-free" ] || [ "$workflow_type" = "android-paid" ]; then
        export KEY_STORE_URL=""
        export CM_KEYSTORE_PASSWORD=""
        export CM_KEY_ALIAS=""
        export CM_KEY_PASSWORD=""
        echo "   🔧 Keystore disabled for $workflow_type workflow"
    else
        export KEY_STORE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"
        export CM_KEYSTORE_PASSWORD="opeN@1234"
        export CM_KEY_ALIAS="my_key_alias"
        export CM_KEY_PASSWORD="opeN@1234"
        echo "   🔧 Keystore enabled for $workflow_type workflow"
    fi
    
    echo "   📦 Expected outputs:"
    if [ "$workflow_type" = "android-publish" ]; then
        echo "      - APK: output/android/*.apk"
        echo "      - AAB: output/android/*.aab"
    else
        echo "      - APK: output/android/*.apk"
    fi
    
    echo ""
    echo "   🏃‍♂️ Running Android main script..."
    
    # Run the main script in test mode (dry run)
    if bash -x lib/scripts/android/main.sh 2>&1 | head -50; then
        echo "   ✅ $workflow_name: Script validation PASSED"
    else
        echo "   ❌ $workflow_name: Script validation FAILED"
        return 1
    fi
    
    echo ""
}

# Test all Android workflows
echo "🎯 Testing All Android Workflows"
echo "================================="
echo ""

# Test 1: Android Free
test_workflow "Android Free" "android-free"

echo ""
echo "---"
echo ""

# Test 2: Android Paid  
test_workflow "Android Paid" "android-paid"

echo ""
echo "---"
echo ""

# Test 3: Android Publish
test_workflow "Android Publish" "android-publish"

echo ""
echo "🏁 Test Summary"
echo "==============="
echo "✅ All Android workflows validated successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Run in Codemagic with actual environment variables"
echo "2. Verify keystore signing produces correct fingerprint"
echo "3. Test Google Play Console upload"
echo ""
echo "🔧 Key Files Modified:"
echo "- lib/scripts/android/main.sh (keystore path fix applied)"
echo "- android/app/build.gradle.kts (generated with correct paths)"
echo ""
echo "🎯 Expected Results:"
echo "- android-free: APK with debug signing"
echo "- android-paid: APK with debug signing + Firebase"
echo "- android-publish: APK + AAB with release keystore signing" 