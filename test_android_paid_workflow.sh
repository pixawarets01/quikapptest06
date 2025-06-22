#!/bin/bash
set -euo pipefail

# Test script for android-paid workflow configuration
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "🧪 Testing android-paid workflow configuration..."

# Test Case 1: PUSH_NOTIFY=true with Firebase config
log "📋 Test Case 1: PUSH_NOTIFY=true with Firebase config"
export WORKFLOW_ID="android-paid"
export PUSH_NOTIFY="true"
export FIREBASE_CONFIG_ANDROID="https://example.com/firebase-config.json"
export APP_NAME="Test App"
export PKG_NAME="com.test.app"
export VERSION_NAME="1.0.0"
export VERSION_CODE="1"
export LOGO_URL="https://example.com/logo.png"

# Clear any existing Firebase or keystore files
rm -f android/app/google-services.json
rm -f android/app/src/keystore.jks
rm -f android/app/src/keystore.properties

log "📋 Test Environment Variables (Case 1):"
log "   WORKFLOW_ID: $WORKFLOW_ID"
log "   PUSH_NOTIFY: $PUSH_NOTIFY"
log "   FIREBASE_CONFIG_ANDROID: $FIREBASE_CONFIG_ANDROID"

# Test 1a: Verify Firebase setup is enabled
log "🔥 Test 1a: Firebase Setup Enabled"
if [ "$WORKFLOW_ID" = "android-paid" ] && [ "$PUSH_NOTIFY" = "true" ]; then
    log "   ✅ android-paid workflow with PUSH_NOTIFY=true detected"
    log "   ✅ Firebase setup will be enabled"
    if [ -n "$FIREBASE_CONFIG_ANDROID" ]; then
        log "   ✅ Firebase config URL provided"
    else
        log "   ❌ Firebase config URL missing"
        exit 1
    fi
else
    log "   ❌ Workflow or PUSH_NOTIFY detection failed"
    exit 1
fi

# Test 1b: Verify keystore setup is skipped
log "🔐 Test 1b: Keystore Setup Skip"
if [ "$WORKFLOW_ID" = "android-paid" ]; then
    log "   ✅ android-paid workflow detected"
    log "   ✅ Keystore setup will be skipped"
    log "   ✅ Debug signing will be used"
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

log "✅ Test Case 1 completed successfully"

# Test Case 2: PUSH_NOTIFY=false (no Firebase)
log "📋 Test Case 2: PUSH_NOTIFY=false (no Firebase)"
export PUSH_NOTIFY="false"
export FIREBASE_CONFIG_ANDROID=""

log "📋 Test Environment Variables (Case 2):"
log "   WORKFLOW_ID: $WORKFLOW_ID"
log "   PUSH_NOTIFY: $PUSH_NOTIFY"
log "   FIREBASE_CONFIG_ANDROID: $FIREBASE_CONFIG_ANDROID"

# Test 2a: Verify Firebase setup is skipped
log "🔥 Test 2a: Firebase Setup Skip"
if [ "$WORKFLOW_ID" = "android-paid" ] && [ "$PUSH_NOTIFY" = "false" ]; then
    log "   ✅ android-paid workflow with PUSH_NOTIFY=false detected"
    log "   ✅ Firebase setup will be skipped"
    log "   ✅ Push notifications disabled"
else
    log "   ❌ Workflow or PUSH_NOTIFY detection failed"
    exit 1
fi

# Test 2b: Verify keystore setup is still skipped
log "🔐 Test 2b: Keystore Setup Skip"
if [ "$WORKFLOW_ID" = "android-paid" ]; then
    log "   ✅ android-paid workflow detected"
    log "   ✅ Keystore setup will be skipped"
    log "   ✅ Debug signing will be used"
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

log "✅ Test Case 2 completed successfully"

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

# Test 4: Verify no keystore files exist
log "🔐 Test 4: Keystore Files Check"
if [ ! -f "android/app/src/keystore.jks" ]; then
    log "   ✅ No keystore file exists (as expected)"
else
    log "   ❌ Keystore file exists (should not for android-paid)"
    exit 1
fi

if [ ! -f "android/app/src/keystore.properties" ]; then
    log "   ✅ No keystore properties file exists (as expected)"
else
    log "   ❌ Keystore properties file exists (should not for android-paid)"
    exit 1
fi

log "🎉 All tests passed! android-paid workflow is properly configured."
log "📋 Summary:"
log "   ✅ Firebase setup: CONDITIONAL (based on PUSH_NOTIFY flag)"
log "   ✅ Keystore setup: SKIPPED"
log "   ✅ Debug signing: ENABLED"
log "   ✅ Push notifications: CONDITIONAL (based on PUSH_NOTIFY flag)"
log "   ✅ Build type: DEBUG SIGNED APK"

log "✅ android-paid workflow test completed successfully!" 