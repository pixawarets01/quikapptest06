#!/bin/bash
set -euo pipefail

# Source environment variables
source lib/scripts/utils/gen_env_config.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Error handling with email notification
trap 'handle_error $LINENO $?' ERR

handle_error() {
    # shellcheck disable=SC2317
    local line_no=$1
    # shellcheck disable=SC2317
    local exit_code=$2
    # shellcheck disable=SC2317
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    # shellcheck disable=SC2317
    log "❌ $error_msg"
    
    # Send build failed email
    # shellcheck disable=SC2317
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Android" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    # shellcheck disable=SC2086
    # shellcheck disable=SC2317
    exit $exit_code
}

log "🚀 Starting Android build process..."

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Android" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android

# Step 1: Run branding script
log "🎨 Running branding script..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Branding completed"
    else
        log "❌ Branding failed"
        exit 1
    fi
else
    log "⚠️  Branding script not found, skipping..."
fi

# Step 2: Run customization script
log "⚙️  Running customization script..."
if [ -f "lib/scripts/android/customization.sh" ]; then
    chmod +x lib/scripts/android/customization.sh
    if lib/scripts/android/customization.sh; then
        log "✅ Customization completed"
    else
        log "❌ Customization failed"
        exit 1
    fi
else
    log "⚠️  Customization script not found, skipping..."
fi

# Step 3: Run permissions script
log "🔒 Running permissions script..."
if [ -f "lib/scripts/android/permissions.sh" ]; then
    chmod +x lib/scripts/android/permissions.sh
    if lib/scripts/android/permissions.sh; then
        log "✅ Permissions configured"
    else
        log "❌ Permissions configuration failed"
        exit 1
    fi
else
    log "⚠️  Permissions script not found, skipping..."
fi

# Detect workflow type using WORKFLOW_ID from Codemagic environment variable
ANDROID_FREE_WORKFLOW=false
ANDROID_PAID_WORKFLOW=false

if [[ "${WORKFLOW_ID:-}" == "android-free" ]]; then
    ANDROID_FREE_WORKFLOW=true
    log "🟢 Detected android-free workflow: Skipping Firebase and Keystore setup."
elif [[ "${WORKFLOW_ID:-}" == "android-paid" ]]; then
    ANDROID_PAID_WORKFLOW=true
    log "🟡 Detected android-paid workflow: Skipping keystore setup. Firebase setup is optional."
fi

# Step 4: Run Firebase script
if [ "$ANDROID_FREE_WORKFLOW" = true ]; then
    log "⏭️  Skipping Firebase setup for android-free workflow."
elif [ "$ANDROID_PAID_WORKFLOW" = true ]; then
    if [[ "${PUSH_NOTIFY:-false}" == "true" && -n "${FIREBASE_CONFIG_ANDROID:-}" ]]; then
        log "🔥 Running Firebase script for android-paid..."
        if [ -f "lib/scripts/android/firebase.sh" ]; then
            chmod +x lib/scripts/android/firebase.sh
            if lib/scripts/android/firebase.sh; then
                log "✅ Firebase configuration completed"
            else
                log "❌ Firebase configuration failed"
                exit 1
            fi
        else
            log "⚠️  Firebase script not found, skipping..."
        fi
    else
        log "⏭️  Skipping Firebase setup for android-paid (PUSH_NOTIFY is false or FIREBASE_CONFIG_ANDROID not set)."
    fi
else
    true
fi

# Step 5: Run keystore script
if [ "$ANDROID_FREE_WORKFLOW" = true ]; then
    log "⏭️  Skipping keystore setup for android-free workflow."
elif [ "$ANDROID_PAID_WORKFLOW" = true ]; then
    log "⏭️  Skipping keystore setup for android-paid workflow. Debug signing will be used."
else
    true
fi

# Step 6: Build APK
log "🏗️  Building Android APK..."
if flutter build apk --release; then
    log "✅ APK build completed"
    # Copy APK to output directory
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        cp build/app/outputs/flutter-apk/app-release.apk output/android/
        log "✅ APK copied to output directory"
    else
        log "❌ APK file not found after build"
        exit 1
    fi
else
    log "❌ APK build failed"
    exit 1
fi

# Step 7: Build AAB (if keystore is configured)
KEYSTORE_CONFIGURED=false
if [ -f "android/app/keystore.properties" ]; then
    KEYSTORE_CONFIGURED=true
    log "🏗️  Building Android App Bundle (AAB)..."
    if flutter build appbundle --release; then
        log "✅ AAB build completed"
        # Copy AAB to output directory
        if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
            cp build/app/outputs/bundle/release/app-release.aab output/android/
            log "✅ AAB copied to output directory"
        else
            log "❌ AAB file not found after build"
            exit 1
        fi
    else
        log "❌ AAB build failed"
        exit 1
    fi
else
    log "⚠️  Keystore not configured, skipping AAB build"
fi

# Step 8: Verify signing
log "🔍 Verifying build signatures..."
if [ -f "lib/scripts/android/verify_signing.sh" ]; then
    chmod +x lib/scripts/android/verify_signing.sh
    if lib/scripts/android/verify_signing.sh; then
        log "✅ Signature verification completed"
    else
        log "⚠️  Signature verification had issues (see logs above)"
    fi
else
    log "⚠️  Signature verification script not found, skipping..."
fi

# Step 9: Generate environment config
log "⚙️  Generating environment configuration..."
if [ -f "lib/scripts/utils/gen_env_config.sh" ]; then
    chmod +x lib/scripts/utils/gen_env_config.sh
    if lib/scripts/utils/gen_env_config.sh; then
        log "✅ Environment configuration generated"
    else
        log "❌ Environment configuration generation failed"
        exit 1
    fi
else
    log "⚠️  Environment config script not found, skipping..."
fi

# Step 10: Send build success email
log "📧 Sending build success notification..."
ARTIFACTS_URL="https://codemagic.io/builds/${CM_BUILD_ID:-unknown}/artifacts"
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    lib/scripts/utils/send_email.sh "build_success" "Android" "${CM_BUILD_ID:-unknown}" "$ARTIFACTS_URL" || true
fi

log "🎉 Android build process completed successfully!"
log "📱 APK file location: output/android/app-release.apk"
if [ "$KEYSTORE_CONFIGURED" = true ]; then
    log "📦 AAB file location: output/android/app-release.aab"
fi

exit 0 