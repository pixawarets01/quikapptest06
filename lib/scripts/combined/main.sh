#!/bin/bash
set -euo pipefail

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Universal Combined Build Configuration Detection
log "🚀 Starting Universal Combined Build Configuration Detection..."

# Detect Android Configuration
log "🤖 Detecting Android Configuration..."

# Android Build Type Detection
ANDROID_BUILD_TYPE="debug"
ANDROID_FIREBASE_ENABLED="false"
ANDROID_KEYSTORE_ENABLED="false"
ANDROID_AAB_ENABLED="false"

# Check if Firebase is enabled for Android
if [[ "${PUSH_NOTIFY:-false}" == "true" ]] && [[ -n "${FIREBASE_CONFIG_ANDROID:-}" ]]; then
    ANDROID_FIREBASE_ENABLED="true"
    log "✅ Android Firebase detected and enabled"
else
    log "ℹ️ Android Firebase not enabled (PUSH_NOTIFY=false or no FIREBASE_CONFIG_ANDROID)"
fi

# Check if Keystore is available for Android
if [[ -n "${KEY_STORE_URL:-}" ]] && [[ -n "${CM_KEYSTORE_PASSWORD:-}" ]] && [[ -n "${CM_KEY_ALIAS:-}" ]] && [[ -n "${CM_KEY_PASSWORD:-}" ]]; then
    ANDROID_KEYSTORE_ENABLED="true"
    ANDROID_BUILD_TYPE="release"
    ANDROID_AAB_ENABLED="true"
    log "✅ Android Keystore detected - will build APK + AAB with release signing"
else
    log "ℹ️ Android Keystore not available - will build APK only with debug signing"
fi

# Detect iOS Configuration
log "🍎 Detecting iOS Configuration..."

# iOS Build Type Detection
IOS_BUILD_ENABLED="false"
IOS_PROFILE_TYPE=""
IOS_FIREBASE_ENABLED="false"

# Check if iOS certificates and profile are available
if [[ -n "${BUNDLE_ID:-}" ]] && [[ -n "${APPLE_TEAM_ID:-}" ]] && [[ -n "${CERT_PASSWORD:-}" ]] && [[ -n "${PROFILE_URL:-}" ]]; then
    IOS_BUILD_ENABLED="true"
    log "✅ iOS build prerequisites detected"
    
    # Check certificate availability
    if [[ -n "${CERT_P12_URL:-}" ]] || ([[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]]); then
        log "✅ iOS certificates detected"
    else
        log "❌ iOS certificates missing - disabling iOS build"
        IOS_BUILD_ENABLED="false"
    fi
else
    log "ℹ️ iOS build prerequisites not available - skipping iOS build"
fi

# Determine iOS Profile Type
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    if [[ -n "${PROFILE_TYPE:-}" ]]; then
        IOS_PROFILE_TYPE="${PROFILE_TYPE}"
        log "📋 Using specified iOS Profile Type: $IOS_PROFILE_TYPE"
    else
        # Auto-detect based on App Store Connect key
        if [[ -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ]]; then
            IOS_PROFILE_TYPE="app-store"
            log "📋 Auto-detected iOS Profile Type: app-store (App Store Connect key present)"
        else
            IOS_PROFILE_TYPE="ad-hoc"
            log "📋 Auto-detected iOS Profile Type: ad-hoc (default for testing)"
        fi
    fi
    
    # Check if Firebase is enabled for iOS
    if [[ "${PUSH_NOTIFY:-false}" == "true" ]] && [[ -n "${FIREBASE_CONFIG_IOS:-}" ]]; then
        IOS_FIREBASE_ENABLED="true"
        log "✅ iOS Firebase detected and enabled"
    else
        log "ℹ️ iOS Firebase not enabled (PUSH_NOTIFY=false or no FIREBASE_CONFIG_IOS)"
    fi
fi

# Export detected configurations
export ANDROID_BUILD_TYPE="$ANDROID_BUILD_TYPE"
export ANDROID_FIREBASE_ENABLED="$ANDROID_FIREBASE_ENABLED"
export ANDROID_KEYSTORE_ENABLED="$ANDROID_KEYSTORE_ENABLED"
export ANDROID_AAB_ENABLED="$ANDROID_AAB_ENABLED"
export IOS_BUILD_ENABLED="$IOS_BUILD_ENABLED"
export IOS_PROFILE_TYPE="$IOS_PROFILE_TYPE"
export IOS_FIREBASE_ENABLED="$IOS_FIREBASE_ENABLED"

# Summary of detected configuration
log "📊 Universal Build Configuration Summary:"
log "   Android Build Type: $ANDROID_BUILD_TYPE"
log "   Android Firebase: $ANDROID_FIREBASE_ENABLED"
log "   Android Keystore: $ANDROID_KEYSTORE_ENABLED"
log "   Android AAB: $ANDROID_AAB_ENABLED"
log "   iOS Build: $IOS_BUILD_ENABLED"
log "   iOS Profile Type: $IOS_PROFILE_TYPE"
log "   iOS Firebase: $IOS_FIREBASE_ENABLED"

# Start build acceleration
log "🚀 Starting universal combined build with acceleration..."
accelerate_build "combined"

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Universal Combined" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android output/ios

# Enhanced error handling with recovery
trap 'handle_error $LINENO $?' ERR

handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Send build failed email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Universal Combined" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit "$exit_code"
}

# Run version management first (resolves package conflicts)
log "🔄 Running version management and conflict resolution..."
if [ -f "lib/scripts/android/version_management.sh" ]; then
    chmod +x lib/scripts/android/version_management.sh
    if lib/scripts/android/version_management.sh; then
        log "✅ Version management and conflict resolution completed"
    else
        log "❌ Version management failed"
        exit 1
    fi
else
    log "⚠️ Version management script not found, skipping..."
fi

# Enhanced asset download with parallel processing
log "📥 Starting enhanced asset download..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Android branding completed with acceleration"
    else
        log "❌ Android branding failed"
        exit 1
    fi
else
    log "⚠️ Android branding script not found, skipping..."
fi

# iOS branding if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    log "📥 Starting iOS asset download..."
    if [ -f "lib/scripts/ios/branding.sh" ]; then
        chmod +x lib/scripts/ios/branding.sh
        if lib/scripts/ios/branding.sh; then
            log "✅ iOS branding completed with acceleration"
        else
            log "❌ iOS branding failed"
            exit 1
        fi
    else
        log "⚠️ iOS branding script not found, skipping..."
    fi
fi

# Download custom icons for bottom menu
log "🎨 Downloading custom icons for bottom menu..."
if [ "${IS_BOTTOMMENU:-false}" = "true" ]; then
    if [ -f "lib/scripts/utils/download_custom_icons.sh" ]; then
        chmod +x lib/scripts/utils/download_custom_icons.sh
        if lib/scripts/utils/download_custom_icons.sh; then
            log "✅ Custom icons download completed"
        else
            log "❌ Custom icons download failed"
            exit 1
        fi
    else
        log "⚠️ Custom icons download script not found, skipping..."
    fi
else
    log "ℹ️ Bottom menu disabled (IS_BOTTOMMENU=false), skipping custom icons download"
fi

# Run customization for both platforms
log "⚙️ Running platform customization..."

# Android customization
if [ -f "lib/scripts/android/customization.sh" ]; then
    chmod +x lib/scripts/android/customization.sh
    if lib/scripts/android/customization.sh; then
        log "✅ Android customization completed"
    else
        log "❌ Android customization failed"
        exit 1
    fi
else
    log "⚠️ Android customization script not found, skipping..."
fi

# iOS customization if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/ios/customization.sh" ]; then
        chmod +x lib/scripts/ios/customization.sh
        if lib/scripts/ios/customization.sh; then
            log "✅ iOS customization completed"
        else
            log "❌ iOS customization failed"
            exit 1
        fi
    else
        log "⚠️ iOS customization script not found, skipping..."
    fi
fi

# Run permissions for both platforms
log "🔒 Running platform permissions..."

# Android permissions
if [ -f "lib/scripts/android/permissions.sh" ]; then
    chmod +x lib/scripts/android/permissions.sh
    if lib/scripts/android/permissions.sh; then
        log "✅ Android permissions configured"
    else
        log "❌ Android permissions configuration failed"
        exit 1
    fi
else
    log "⚠️ Android permissions script not found, skipping..."
fi

# iOS permissions if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/ios/permissions.sh" ]; then
        chmod +x lib/scripts/ios/permissions.sh
        if lib/scripts/ios/permissions.sh; then
            log "✅ iOS permissions configured"
        else
            log "❌ iOS permissions configuration failed"
            exit 1
        fi
    else
        log "⚠️ iOS permissions script not found, skipping..."
    fi
fi

# Run Firebase for both platforms
log "🔥 Running Firebase for both platforms..."

# Android Firebase
if [[ "${ANDROID_FIREBASE_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/android/firebase.sh" ]; then
        chmod +x lib/scripts/android/firebase.sh
        if lib/scripts/android/firebase.sh; then
            log "✅ Android Firebase configuration completed"
        else
            log "❌ Android Firebase configuration failed"
            exit 1
        fi
    else
        log "⚠️ Android Firebase script not found, skipping..."
    fi
else
    log "ℹ️ Android Firebase not enabled, skipping..."
fi

# iOS Firebase if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]] && [[ "${IOS_FIREBASE_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        chmod +x lib/scripts/ios/firebase.sh
        if lib/scripts/ios/firebase.sh; then
            log "✅ iOS Firebase configuration completed"
        else
            log "❌ iOS Firebase configuration failed"
            exit 1
        fi
    else
        log "⚠️ iOS Firebase script not found, skipping..."
    fi
else
    log "ℹ️ iOS Firebase not enabled, skipping..."
fi

# Run platform-specific setup
log "🔧 Running platform-specific setup..."

# Android keystore setup
if [[ "${ANDROID_KEYSTORE_ENABLED}" == "true" ]]; then
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
else
    log "ℹ️ Android keystore not enabled, skipping..."
fi

# iOS certificate setup if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
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
fi

# Configure global build optimizations
log "⚙️ Configuring global build optimizations..."

# Configure JVM options
log "🔧 Configuring JVM options..."
export JAVA_TOOL_OPTIONS="-Xmx4G -XX:MaxPermSize=512m -XX:+UseParallelGC"

# Configure environment
log "🔧 Configuring build environment..."
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create optimized gradle.properties
log "📝 Creating optimized gradle.properties..."
if [ ! -f android/gradle.properties ] || ! grep -q "org.gradle.jvmargs" android/gradle.properties; then
    cat >> android/gradle.properties << EOF
org.gradle.jvmargs=-Xmx4G -XX:MaxPermSize=512m -XX:+UseParallelGC -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.caching=true
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
kotlin.code.style=official
EOF
fi

# Clean build environment
log "🧹 Cleaning build environment..."
flutter clean

# Create a list of safe environment variables to pass to Flutter
log "🔧 Preparing environment variables for Flutter..."
ENV_ARGS=""

# Define a list of safe variables that can be passed to Flutter
SAFE_VARS=(
    "APP_ID" "WORKFLOW_ID" "BRANCH" "VERSION_NAME" "VERSION_CODE" 
    "APP_NAME" "ORG_NAME" "WEB_URL" "PKG_NAME" "BUNDLE_ID" "EMAIL_ID" "USER_NAME"
    "PUSH_NOTIFY" "IS_CHATBOT" "IS_DOMAIN_URL" "IS_SPLASH" "IS_PULLDOWN"
    "IS_BOTTOMMENU" "IS_LOAD_IND" "IS_CAMERA" "IS_LOCATION" "IS_MIC"
    "IS_NOTIFICATION" "IS_CONTACT" "IS_BIOMETRIC" "IS_CALENDAR" "IS_STORAGE"
    "LOGO_URL" "SPLASH_URL" "SPLASH_BG_URL" "SPLASH_BG_COLOR" "SPLASH_TAGLINE" 
    "SPLASH_TAGLINE_COLOR" "SPLASH_ANIMATION" "SPLASH_DURATION" "BOTTOMMENU_FONT" 
    "BOTTOMMENU_FONT_SIZE" "BOTTOMMENU_FONT_BOLD" "BOTTOMMENU_FONT_ITALIC" 
    "BOTTOMMENU_BG_COLOR" "BOTTOMMENU_TEXT_COLOR" "BOTTOMMENU_ICON_COLOR" 
    "BOTTOMMENU_ACTIVE_TAB_COLOR" "BOTTOMMENU_ICON_POSITION"
    "FIREBASE_CONFIG_ANDROID" "FIREBASE_CONFIG_IOS"
    "ENABLE_EMAIL_NOTIFICATIONS" "EMAIL_SMTP_SERVER" "EMAIL_SMTP_PORT"
    "EMAIL_SMTP_USER" "CM_BUILD_ID" "CM_WORKFLOW_NAME" "CM_BRANCH"
    "FCI_BUILD_ID" "FCI_WORKFLOW_NAME" "FCI_BRANCH" "CONTINUOUS_INTEGRATION"
    "CI" "BUILD_NUMBER" "PROJECT_BUILD_NUMBER"
)

# Only pass safe variables to Flutter
for var_name in "${SAFE_VARS[@]}"; do
    if [ -n "${!var_name:-}" ]; then
        # Escape the value to handle special characters
        var_value="${!var_name}"
        # Remove any newlines or problematic characters
        var_value=$(echo "$var_value" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        
        # Special handling for APP_NAME to properly escape spaces
        if [ "$var_name" = "APP_NAME" ]; then
            var_value=$(printf '%q' "$var_value")
        fi
        
        ENV_ARGS="$ENV_ARGS --dart-define=$var_name=$var_value"
    fi
done

# Add essential build arguments
ENV_ARGS="$ENV_ARGS --dart-define=FLUTTER_BUILD_NAME=$VERSION_NAME"
ENV_ARGS="$ENV_ARGS --dart-define=FLUTTER_BUILD_NUMBER=$VERSION_CODE"

log "📋 Prepared $ENV_ARGS environment variables for Flutter build"

# Build Android with acceleration
log "📱 Starting Android build with acceleration..."
if [[ "${ANDROID_AAB_ENABLED}" == "true" ]]; then
    # Build both APK and AAB
    log "📦 Building Android APK and AAB..."
    if GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx4G -XX:MaxPermSize=512m -XX:+UseParallelGC" \
       flutter build apk --release $ENV_ARGS && \
       flutter build appbundle --release $ENV_ARGS; then
        log "✅ Android APK and AAB build completed successfully"
    else
        log "❌ Android APK and AAB build failed"
        exit 1
    fi
else
    # Build only APK
    log "📦 Building Android APK only..."
    if GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx4G -XX:MaxPermSize=512m -XX:+UseParallelGC" \
       flutter build apk --release $ENV_ARGS; then
        log "✅ Android APK build completed successfully"
    else
        log "❌ Android APK build failed"
        exit 1
    fi
fi

# Build iOS with acceleration if enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    log "📱 Starting iOS build with acceleration..."
    if flutter build ios --release --no-codesign \
        --dart-define=ENABLE_BITCODE=NO \
        --dart-define=STRIP_STYLE=non-global \
        $ENV_ARGS; then
        log "✅ iOS build completed successfully"
    else
        log "❌ iOS build failed"
        exit 1
    fi

    # Archive and export IPA with optimizations
    log "📦 Archiving and exporting iOS IPA with optimizations..."
    cd ios

    # Create archive with optimized settings
    log "📦 Creating iOS archive..."
    if xcodebuild -workspace Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath build/Runner.xcarchive \
        -destination 'generic/platform=iOS' \
        -allowProvisioningUpdates \
        ENABLE_BITCODE=NO \
        STRIP_STYLE=non-global \
        COMPILER_INDEX_STORE_ENABLE=NO \
        archive; then
        log "✅ iOS archive created successfully"
    else
        log "❌ iOS archive creation failed"
        exit 1
    fi

    # Export IPA with optimized settings
    log "📦 Exporting iOS IPA..."
    if xcodebuild -exportArchive \
        -archivePath build/Runner.xcarchive \
        -exportPath build/ios/ipa \
        -exportOptionsPlist ExportOptions.plist \
        -allowProvisioningUpdates \
        ENABLE_BITCODE=NO \
        STRIP_STYLE=non-global \
        COMPILER_INDEX_STORE_ENABLE=NO; then
        log "✅ iOS IPA exported successfully"
    else
        log "❌ iOS IPA export failed"
        exit 1
    fi

    cd ..
else
    log "ℹ️ iOS build not enabled, skipping..."
fi

# Copy iOS artifacts if iOS build was enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    log "📦 Locating and copying iOS IPA file..."
    IPA_FOUND=false
    IPA_NAME=""

    # Look for IPA in common locations
    IPA_LOCATIONS=(
        "ios/build/ios/ipa/*.ipa"
        "ios/build/Runner.xcarchive/Products/Applications/*.ipa"
        "ios/build/archive/*.ipa"
        "build/ios/ipa/*.ipa"
        "build/ios/archive/Runner.xcarchive/Products/Applications/*.ipa"
    )

    for pattern in "${IPA_LOCATIONS[@]}"; do
        for ipa_file in $pattern; do
            if [ -f "$ipa_file" ]; then
                IPA_NAME=$(basename "$ipa_file")
                cp "$ipa_file" "output/ios/$IPA_NAME"
                log "✅ IPA found and copied: $ipa_file → output/ios/$IPA_NAME"
                IPA_FOUND=true
                break 2
            fi
        done
    done

    # If no IPA found with patterns, try find command
    if [ "$IPA_FOUND" = false ]; then
        log "🔍 Searching for IPA files using find command..."
        FOUND_IPAS=$(find . -name "*.ipa" -type f 2>/dev/null | head -5)
        
        if [ -n "$FOUND_IPAS" ]; then
            log "📋 Found IPA files:"
            echo "$FOUND_IPAS" | while read -r ipa_file; do
                log "   - $ipa_file"
            done
            
            # Use the first IPA found
            FIRST_IPA=$(echo "$FOUND_IPAS" | head -1)
            IPA_NAME=$(basename "$FIRST_IPA")
            cp "$FIRST_IPA" "output/ios/$IPA_NAME"
            log "✅ IPA copied from find: $FIRST_IPA → output/ios/$IPA_NAME"
            IPA_FOUND=true
        fi
    fi

    # Verify IPA was created and copied
    if [ "$IPA_FOUND" = false ]; then
        log "❌ No IPA file found after iOS build!"
        log "   Searched locations:"
        for pattern in "${IPA_LOCATIONS[@]}"; do
            log "   - $pattern"
        done
        
        # List build directory contents for debugging
        log "🔍 Build directory contents:"
        find . -name "*.ipa" -type f 2>/dev/null || log "   No IPA files found in project"
        
        # Check if archive was created
        if [ -d "ios/build/Runner.xcarchive" ]; then
            log "✅ Archive exists at ios/build/Runner.xcarchive"
            log "🔍 Archive contents:"
            ls -la ios/build/Runner.xcarchive/Products/Applications/ 2>/dev/null || log "   No Applications directory in archive"
        else
            log "❌ Archive not found at ios/build/Runner.xcarchive"
        fi
        
        # Send failure email
        if [ -f "lib/scripts/utils/send_email.sh" ]; then
            chmod +x lib/scripts/utils/send_email.sh
            lib/scripts/utils/send_email.sh "build_failed" "Universal Combined" "${CM_BUILD_ID:-unknown}" "No IPA file generated after iOS build" || true
        fi
        exit 1
    fi

    # Verify the copied IPA file
    if [ -f "output/ios/$IPA_NAME" ]; then
        IPA_SIZE=$(stat -f%z "output/ios/$IPA_NAME" 2>/dev/null || stat -c%s "output/ios/$IPA_NAME" 2>/dev/null || echo "unknown")
        log "✅ iOS IPA verification successful:"
        log "   File: output/ios/$IPA_NAME"
        log "   Size: $IPA_SIZE bytes"
        
        # Additional verification - check if it's a valid ZIP/IPA
        if file "output/ios/$IPA_NAME" | grep -q "Zip archive"; then
            log "✅ IPA file format verified (ZIP archive)"
        else
            log "⚠️ IPA file format verification failed - may not be a valid ZIP archive"
        fi
    else
        log "❌ iOS IPA file verification failed!"
        log "   Expected: output/ios/$IPA_NAME"
        
        # Send failure email
        if [ -f "lib/scripts/utils/send_email.sh" ]; then
            chmod +x lib/scripts/utils/send_email.sh
            lib/scripts/utils/send_email.sh "build_failed" "Universal Combined" "${CM_BUILD_ID:-unknown}" "iOS IPA file verification failed" || true
        fi
        exit 1
    fi

    # List iOS output directory contents
    log "📋 iOS output directory contents:"
    ls -la output/ios/ || log "   No files in output/ios/"
fi

# Copy Android artifacts
APK_FOUND=false
AAB_FOUND=false

# Look for APK files in various possible locations
for apk_path in \
    "build/app/outputs/flutter-apk/app-release.apk" \
    "build/app/outputs/apk/release/app-release.apk" \
    "android/app/build/outputs/apk/release/app-release.apk"; do
    
    if [ -f "$apk_path" ]; then
        cp "$apk_path" output/android/app-release.apk
        APK_SIZE=$(du -h output/android/app-release.apk | cut -f1)
        log "✅ Android APK copied from $apk_path (Size: $APK_SIZE)"
        APK_FOUND=true
        break
    fi
done

if [[ "${ANDROID_AAB_ENABLED}" == "true" ]]; then
    # Look for AAB files in various possible locations
    for aab_path in \
        "build/app/outputs/bundle/release/app-release.aab" \
        "android/app/build/outputs/bundle/release/app-release.aab"; do
        
        if [ -f "$aab_path" ]; then
            cp "$aab_path" output/android/app-release.aab
            AAB_SIZE=$(du -h output/android/app-release.aab | cut -f1)
            log "✅ Android AAB copied from $aab_path (Size: $AAB_SIZE)"
            AAB_FOUND=true
            break
        fi
    done
fi

# Verify required artifacts were found
if [ "$APK_FOUND" = false ]; then
    log "❌ Android APK file not found in any expected location"
    exit 1
fi

if [[ "${ANDROID_AAB_ENABLED}" == "true" ]] && [ "$AAB_FOUND" = false ]; then
    log "❌ Android AAB file not found in any expected location"
    exit 1
fi

# Clean up Gradle daemon
log "🧹 Cleaning up Gradle daemon..."
if [ -f "android/gradlew" ]; then
    cd android
    ./gradlew --stop || true
    cd ..
fi

# Generate installation helper for Android
log "🔧 Generating Android installation helper and guide..."
if [ -f "lib/scripts/android/install_helper.sh" ]; then
    chmod +x lib/scripts/android/install_helper.sh
    # Run installation helper to generate guides (without actual installation)
    lib/scripts/android/install_helper.sh output/android/app-release.apk false 2>/dev/null || true
fi

# Send build success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    # Pass platform and build ID for individual artifact URL generation
    lib/scripts/utils/send_email.sh "build_success" "Universal Combined" "${CM_BUILD_ID:-unknown}" || true
fi

# Final summary
log "🎉 Universal Combined Build completed successfully!"
log "📊 Build Summary:"
log "   Android Build Type: $ANDROID_BUILD_TYPE"
log "   Android Firebase: $ANDROID_FIREBASE_ENABLED"
log "   Android Keystore: $ANDROID_KEYSTORE_ENABLED"
log "   Android AAB: $ANDROID_AAB_ENABLED"
log "   iOS Build: $IOS_BUILD_ENABLED"
log "   iOS Profile Type: $IOS_PROFILE_TYPE"
log "   iOS Firebase: $IOS_FIREBASE_ENABLED"

log "📁 Build artifacts available in:"
if [ "$APK_FOUND" = true ]; then
    log "   Android APK: output/android/app-release.apk"
fi
if [ "$AAB_FOUND" = true ]; then
    log "   Android AAB: output/android/app-release.aab"
fi
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    log "   iOS IPA: output/ios/Runner.ipa"
fi

log "📋 Installation guides available:"
log "   - output/android/INSTALL_GUIDE.txt (Version management guide)"
log "   - output/android/installation_report.txt (Installation helper guide)"

exit 0 