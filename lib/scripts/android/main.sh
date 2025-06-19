#!/bin/bash
set -euo pipefail

# Source environment variables
source lib/scripts/utils/gen_env_config.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Error handling with email notification
trap 'handle_error $LINENO $?' ERR

handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Send build failed email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Android" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
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

# Detect android-free workflow (no push notify, no keystore)
ANDROID_FREE_WORKFLOW=false
if [[ "${PUSH_NOTIFY:-false}" == "false" && -z "${KEY_STORE_URL:-}" ]]; then
    ANDROID_FREE_WORKFLOW=true
    log "🟢 Detected android-free workflow: Skipping Firebase and Keystore setup."
fi

# Step 4: Run Firebase script
if [ "$ANDROID_FREE_WORKFLOW" = false ]; then
    log "🔥 Running Firebase script..."
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
    log "⏭️  Skipping Firebase setup for android-free workflow."
fi

# Step 5: Run keystore script
if [ "$ANDROID_FREE_WORKFLOW" = false ]; then
    log "🔐 Running keystore script..."
    if [ -f "lib/scripts/android/keystore.sh" ]; then
        chmod +x lib/scripts/android/keystore.sh
        if lib/scripts/android/keystore.sh; then
            log "✅ Keystore configuration completed"
        else
            log "❌ Keystore configuration failed"
            exit 1
        fi
    else
        log "⚠️  Keystore script not found, skipping..."
    fi
else
    log "⏭️  Skipping keystore setup for android-free workflow."
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