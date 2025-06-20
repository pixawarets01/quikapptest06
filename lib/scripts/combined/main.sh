#!/bin/bash
set -euo pipefail

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Start build acceleration
log "🚀 Starting combined Android & iOS build with acceleration..."
accelerate_build "combined"

# Error handling
trap 'handle_error $LINENO $?' ERR
handle_error() {
    local line_no=$1
    local exit_code=$2
    log "❌ Error occurred at line $line_no. Exit code: $exit_code"
    exit $exit_code
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Combined" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android output/ios

# Enhanced asset download with parallel processing
log "📥 Starting enhanced asset download for both platforms..."
if [ -f "lib/scripts/android/branding.sh" ] && [ -f "lib/scripts/ios/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh lib/scripts/ios/branding.sh
    
    # Run branding in parallel
    log "🎨 Running Android and iOS branding in parallel..."
    lib/scripts/android/branding.sh &
    ANDROID_BRANDING_PID=$!
    lib/scripts/ios/branding.sh &
    IOS_BRANDING_PID=$!
    
    # Wait for both to complete
    wait $ANDROID_BRANDING_PID
    ANDROID_BRANDING_RESULT=$?
    wait $IOS_BRANDING_PID
    IOS_BRANDING_RESULT=$?
    
    if [ $ANDROID_BRANDING_RESULT -eq 0 ] && [ $IOS_BRANDING_RESULT -eq 0 ]; then
        log "✅ Both Android and iOS branding completed successfully"
        
        # Validate required assets after branding
        log "🔍 Validating assets for both platforms..."
        required_assets=("assets/images/logo.png" "assets/images/splash.png")
        for asset in "${required_assets[@]}"; do
            if [ -f "$asset" ] && [ -s "$asset" ]; then
                log "✅ $asset exists and has content"
            else
                log "❌ $asset is missing or empty after branding"
                exit 1
            fi
        done
        log "✅ All assets validated for both platforms"
    else
        log "❌ Branding failed for one or both platforms"
        exit 1
    fi
else
    log "⚠️ One or both branding scripts not found, skipping..."
fi

# Download custom icons for bottom menu
log "🎨 Downloading custom icons for bottom menu..."
if [ -f "lib/scripts/utils/download_custom_icons.sh" ]; then
    chmod +x lib/scripts/utils/download_custom_icons.sh
    if lib/scripts/utils/download_custom_icons.sh; then
        log "✅ Custom icons download completed"
        
        # Validate custom icons if BOTTOMMENU_ITEMS contains custom icons
        if [ -n "${BOTTOMMENU_ITEMS:-}" ]; then
            log "🔍 Validating custom icons..."
            if [ -d "assets/icons" ] && [ "$(ls -A assets/icons 2>/dev/null)" ]; then
                log "✅ Custom icons found in assets/icons/"
                ls -la assets/icons/ | while read -r line; do
                    log "   $line"
                done
            else
                log "ℹ️ No custom icons found (using preset icons only)"
            fi
        fi
    else
        log "❌ Custom icons download failed"
        exit 1
    fi
else
    log "⚠️ Custom icons download script not found, skipping..."
fi

# Run customization for both platforms
log "⚙️ Running customization for both platforms..."
if [ -f "lib/scripts/android/customization.sh" ] && [ -f "lib/scripts/ios/customization.sh" ]; then
    chmod +x lib/scripts/android/customization.sh lib/scripts/ios/customization.sh
    
    # Run customization in parallel
    log "🎨 Running Android and iOS customization in parallel..."
    lib/scripts/android/customization.sh &
    ANDROID_CUSTOM_PID=$!
    lib/scripts/ios/customization.sh &
    IOS_CUSTOM_PID=$!
    
    # Wait for both to complete
    wait $ANDROID_CUSTOM_PID
    ANDROID_CUSTOM_RESULT=$?
    wait $IOS_CUSTOM_PID
    IOS_CUSTOM_RESULT=$?
    
    if [ $ANDROID_CUSTOM_RESULT -eq 0 ] && [ $IOS_CUSTOM_RESULT -eq 0 ]; then
        log "✅ Both Android and iOS customization completed successfully"
    else
        log "❌ Customization failed for one or both platforms"
        exit 1
    fi
else
    log "⚠️ One or both customization scripts not found, skipping..."
fi

# Run permissions for both platforms
log "🔒 Running permissions for both platforms..."
if [ -f "lib/scripts/android/permissions.sh" ] && [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/android/permissions.sh lib/scripts/ios/permissions.sh
    
    # Run permissions in parallel
    log "🔐 Running Android and iOS permissions in parallel..."
    lib/scripts/android/permissions.sh &
    ANDROID_PERM_PID=$!
    lib/scripts/ios/permissions.sh &
    IOS_PERM_PID=$!
    
    # Wait for both to complete
    wait $ANDROID_PERM_PID
    ANDROID_PERM_RESULT=$?
    wait $IOS_PERM_PID
    IOS_PERM_RESULT=$?
    
    if [ $ANDROID_PERM_RESULT -eq 0 ] && [ $IOS_PERM_RESULT -eq 0 ]; then
        log "✅ Both Android and iOS permissions configured successfully"
    else
        log "❌ Permissions configuration failed for one or both platforms"
        exit 1
    fi
else
    log "⚠️ One or both permissions scripts not found, skipping..."
fi

# Run Firebase for both platforms
log "🔥 Running Firebase for both platforms..."
if [ -f "lib/scripts/android/firebase.sh" ] && [ -f "lib/scripts/ios/firebase.sh" ]; then
    chmod +x lib/scripts/android/firebase.sh lib/scripts/ios/firebase.sh
    
    # Run Firebase in parallel
    log "🔥 Running Android and iOS Firebase in parallel..."
    lib/scripts/android/firebase.sh &
    ANDROID_FIREBASE_PID=$!
    lib/scripts/ios/firebase.sh &
    IOS_FIREBASE_PID=$!
    
    # Wait for both to complete
    wait $ANDROID_FIREBASE_PID
    ANDROID_FIREBASE_RESULT=$?
    wait $IOS_FIREBASE_PID
    IOS_FIREBASE_RESULT=$?
    
    if [ $ANDROID_FIREBASE_RESULT -eq 0 ] && [ $IOS_FIREBASE_RESULT -eq 0 ]; then
        log "✅ Both Android and iOS Firebase configuration completed successfully"
    else
        log "❌ Firebase configuration failed for one or both platforms"
        exit 1
    fi
else
    log "⚠️ One or both Firebase scripts not found, skipping..."
fi

# Run platform-specific setup
log "🔧 Running platform-specific setup..."

# Android keystore setup
log "🔐 Running Android keystore setup..."
if [ -f "lib/scripts/android/keystore.sh" ]; then
    chmod +x lib/scripts/android/keystore.sh
    if lib/scripts/android/keystore.sh; then
        log "✅ Android keystore configuration completed"
    else
        log "❌ Android keystore configuration failed"
        exit 1
    fi
else
    log "⚠️ Android keystore script not found, skipping..."
fi

# iOS certificate setup
log "🔐 Running iOS certificate setup..."
if [ -f "lib/scripts/ios/certificate_handler.sh" ]; then
    chmod +x lib/scripts/ios/certificate_handler.sh
    if lib/scripts/ios/certificate_handler.sh; then
        log "✅ iOS certificate configuration completed"
    else
        log "❌ iOS certificate configuration failed"
        exit 1
    fi
else
    log "⚠️ iOS certificate handler script not found, skipping..."
fi

# Build Android with acceleration
log "📱 Starting Android build with acceleration..."
if [ -f "lib/scripts/android/main.sh" ]; then
    chmod +x lib/scripts/android/main.sh
    if lib/scripts/android/main.sh; then
        log "✅ Android build completed successfully"
    else
        log "❌ Android build failed"
        exit 1
    fi
else
    log "❌ Android main script not found"
    exit 1
fi

# Build iOS with acceleration
log "📱 Starting iOS build with acceleration..."
if [ -f "lib/scripts/ios/main.sh" ]; then
    chmod +x lib/scripts/ios/main.sh
    if lib/scripts/ios/main.sh; then
        log "✅ iOS build completed successfully"
    else
        log "❌ iOS build failed"
        exit 1
    fi
else
    log "❌ iOS main script not found"
    exit 1
fi

# Verify all artifacts
log "🔍 Verifying all artifacts..."

# Verify Android artifacts
if [ -f "output/android/app-release.apk" ]; then
    APK_SIZE=$(du -h output/android/app-release.apk | cut -f1)
    log "✅ Android APK created successfully (Size: $APK_SIZE)"
else
    log "❌ Android APK not found in output directory"
    exit 1
fi

if [ -f "output/android/app-release.aab" ]; then
    AAB_SIZE=$(du -h output/android/app-release.aab | cut -f1)
    log "✅ Android AAB created successfully (Size: $AAB_SIZE)"
else
    log "❌ Android AAB not found in output directory"
    exit 1
fi

# Verify iOS artifacts
if [ -f "output/ios/Runner.ipa" ]; then
    IPA_SIZE=$(du -h output/ios/Runner.ipa | cut -f1)
    log "✅ iOS IPA created successfully (Size: $IPA_SIZE)"
else
    log "❌ iOS IPA not found in output directory"
    exit 1
fi

# Send build success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    # Pass platform and build ID for individual artifact URL generation
    lib/scripts/utils/send_email.sh "build_success" "Combined (Android & iOS)" "${CM_BUILD_ID:-unknown}" || true
fi

log "🎉 Combined Android & iOS build completed successfully with acceleration!"
log "📊 Build artifacts available in:"
log "   Android: output/android/"
log "   iOS: output/ios/"

exit 0 