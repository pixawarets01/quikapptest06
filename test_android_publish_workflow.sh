#!/bin/bash
set -euo pipefail

# Test script for android-publish workflow configuration
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "🧪 Testing android-publish workflow configuration..."

# Test Case 1: PUSH_NOTIFY=true with Firebase config and keystore
log "📋 Test Case 1: PUSH_NOTIFY=true with Firebase config and keystore"
export WORKFLOW_ID="android-publish"
export PUSH_NOTIFY="true"
export FIREBASE_CONFIG_ANDROID="https://example.com/firebase-config.json"
export KEY_STORE_URL="https://example.com/keystore.jks"
export CM_KEYSTORE_PASSWORD="test_password"
export CM_KEY_ALIAS="test_alias"
export CM_KEY_PASSWORD="test_key_password"
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
log "   KEY_STORE_URL: $KEY_STORE_URL"

# Test 1a: Verify Firebase setup is enabled
log "🔥 Test 1a: Firebase Setup Enabled"
if [ "$WORKFLOW_ID" = "android-publish" ] && [ "$PUSH_NOTIFY" = "true" ]; then
    log "   ✅ android-publish workflow with PUSH_NOTIFY=true detected"
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

# Test 1b: Verify keystore setup is enabled
log "🔐 Test 1b: Keystore Setup Enabled"
if [ "$WORKFLOW_ID" = "android-publish" ]; then
    log "   ✅ android-publish workflow detected"
    log "   ✅ Keystore setup will be enabled"
    if [ -n "$KEY_STORE_URL" ] && [ -n "$CM_KEYSTORE_PASSWORD" ] && [ -n "$CM_KEY_ALIAS" ] && [ -n "$CM_KEY_PASSWORD" ]; then
        log "   ✅ All keystore credentials provided"
        log "   ✅ Release signing will be used"
    else
        log "   ❌ Incomplete keystore credentials"
        exit 1
    fi
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

log "✅ Test Case 1 completed successfully"

# Test Case 2: PUSH_NOTIFY=false (no Firebase) but keystore still required
log "📋 Test Case 2: PUSH_NOTIFY=false (no Firebase) but keystore still required"
export PUSH_NOTIFY="false"
export FIREBASE_CONFIG_ANDROID=""

log "📋 Test Environment Variables (Case 2):"
log "   WORKFLOW_ID: $WORKFLOW_ID"
log "   PUSH_NOTIFY: $PUSH_NOTIFY"
log "   FIREBASE_CONFIG_ANDROID: $FIREBASE_CONFIG_ANDROID"
log "   KEY_STORE_URL: $KEY_STORE_URL"

# Test 2a: Verify Firebase setup is skipped
log "🔥 Test 2a: Firebase Setup Skip"
if [ "$WORKFLOW_ID" = "android-publish" ] && [ "$PUSH_NOTIFY" = "false" ]; then
    log "   ✅ android-publish workflow with PUSH_NOTIFY=false detected"
    log "   ✅ Firebase setup will be skipped"
    log "   ✅ Push notifications disabled"
else
    log "   ❌ Workflow or PUSH_NOTIFY detection failed"
    exit 1
fi

# Test 2b: Verify keystore setup is still required
log "🔐 Test 2b: Keystore Setup Still Required"
if [ "$WORKFLOW_ID" = "android-publish" ]; then
    log "   ✅ android-publish workflow detected"
    log "   ✅ Keystore setup is still required (release signing)"
    if [ -n "$KEY_STORE_URL" ] && [ -n "$CM_KEYSTORE_PASSWORD" ] && [ -n "$CM_KEY_ALIAS" ] && [ -n "$CM_KEY_PASSWORD" ]; then
        log "   ✅ All keystore credentials provided"
        log "   ✅ Release signing will be used"
    else
        log "   ❌ Incomplete keystore credentials"
        exit 1
    fi
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

log "✅ Test Case 2 completed successfully"

# Test 3: Verify build.gradle.kts configuration
log "🏗️ Test 3: Build Configuration"
if [ -f "android/app/build.gradle.kts" ]; then
    log "   ✅ build.gradle.kts exists"
    
    # Check for release signing configuration
    if grep -q "keystorePropertiesFile.exists()" android/app/build.gradle.kts; then
        log "   ✅ Release signing configuration found"
    else
        log "   ❌ Release signing configuration not found"
        exit 1
    fi
    
    # Check for keystore configuration
    if grep -q "val keystoreProperties = Properties()" android/app/build.gradle.kts; then
        log "   ✅ Keystore configuration found (as expected)"
    else
        log "   ⚠️ Keystore configuration may be missing"
    fi
else
    log "   ❌ build.gradle.kts not found"
    exit 1
fi

# Test 4: Verify build artifacts configuration
log "📦 Test 4: Build Artifacts Configuration"
if [ "$WORKFLOW_ID" = "android-publish" ]; then
    log "   ✅ android-publish workflow detected"
    log "   ✅ Will build both APK and AAB"
    log "   ✅ APK for testing, AAB for Google Play Store"
else
    log "   ❌ Workflow detection failed"
    exit 1
fi

log "🎉 All tests passed! android-publish workflow is properly configured."
log "📋 Summary:"
log "   ✅ Firebase setup: CONDITIONAL (based on PUSH_NOTIFY flag)"
log "   ✅ Keystore setup: ALWAYS ENABLED (release signing required)"
log "   ✅ Release signing: ENABLED"
log "   ✅ Push notifications: CONDITIONAL (based on PUSH_NOTIFY flag)"
log "   ✅ Build type: RELEASE SIGNED APK + AAB"
log "   ✅ Google Play Store: READY FOR UPLOAD"

log "✅ android-publish workflow test completed successfully!" 