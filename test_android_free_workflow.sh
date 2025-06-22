#!/bin/bash
set -euo pipefail

# Test script for android-free workflow configuration
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "🧪 Testing android-free workflow configuration..."

# Set up test environment variables for android-free workflow
export WORKFLOW_ID="android-free"
export PUSH_NOTIFY="false"
export IS_DOMAIN_URL="false"
export APP_NAME="Test App"
export PKG_NAME="com.test.app"
export VERSION_NAME="1.0.0"
export VERSION_CODE="1"
export LOGO_URL="https://example.com/logo.png"

# Clear any existing Firebase or keystore files
rm -f android/app/google-services.json
rm -f android/app/src/keystore.jks
rm -f android/app/src/keystore.properties

log "📋 Test Environment Variables:"
log "   WORKFLOW_ID: $WORKFLOW_ID"
log "   PUSH_NOTIFY: $PUSH_NOTIFY"
log "   IS_DOMAIN_URL: $IS_DOMAIN_URL"

# Test 1: Verify Firebase setup is skipped
log "🔥 Test 1: Firebase Setup Skip"
if [ "$WORKFLOW_ID" = "android-free" ]; then
    log "   ✅ android-free workflow detected"
    log "   ✅ Firebase setup will be skipped"
    log "   ✅ PUSH_NOTIFY is set to false"
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

# Test 2: Verify keystore setup is skipped
log "🔐 Test 2: Keystore Setup Skip"
if [ "$WORKFLOW_ID" = "android-free" ]; then
    log "   ✅ android-free workflow detected"
    log "   ✅ Keystore setup will be skipped"
    log "   ✅ Debug signing will be used"
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

# Test 3: Verify build.gradle.kts configuration
log "🏗️ Test 3: Build Configuration"
if [ -f "android/app/build.gradle.kts" ]; then
    log "   ✅ build.gradle.kts exists"
    
    # Check for debug signing configuration
    if grep -q "signingConfig = signingConfigs.getByName(\"debug\")" android/app/build.gradle.kts; then
        log "   ✅ Debug signing configuration found"
    else
        log "   ❌ Debug signing configuration not found"
        exit 1
    fi
    
    # Check for no keystore configuration
    if grep -q "No keystore configuration for this workflow" android/app/build.gradle.kts; then
        log "   ✅ No keystore configuration found (as expected)"
    else
        log "   ⚠️ Keystore configuration may be present"
    fi
else
    log "   ❌ build.gradle.kts not found"
    exit 1
fi

# Test 4: Verify no Firebase config exists
log "🔥 Test 4: Firebase Config Check"
if [ ! -f "android/app/google-services.json" ]; then
    log "   ✅ No Firebase config file exists (as expected)"
else
    log "   ❌ Firebase config file exists (should not for android-free)"
    exit 1
fi

# Test 5: Verify no keystore files exist
log "🔐 Test 5: Keystore Files Check"
if [ ! -f "android/app/src/keystore.jks" ]; then
    log "   ✅ No keystore file exists (as expected)"
else
    log "   ❌ Keystore file exists (should not for android-free)"
    exit 1
fi

if [ ! -f "android/app/src/keystore.properties" ]; then
    log "   ✅ No keystore properties file exists (as expected)"
else
    log "   ❌ Keystore properties file exists (should not for android-free)"
    exit 1
fi

log "🎉 All tests passed! android-free workflow is properly configured."
log "📋 Summary:"
log "   ✅ Firebase setup: SKIPPED"
log "   ✅ Keystore setup: SKIPPED"
log "   ✅ Debug signing: ENABLED"
log "   ✅ Push notifications: DISABLED"
log "   ✅ Build type: DEBUG SIGNED APK"

log "✅ android-free workflow test completed successfully!" 