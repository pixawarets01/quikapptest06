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
        lib/scripts/utils/send_email.sh "build_failed" "Android & iOS" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit $exit_code
}

log "🚀 Starting Combined Android & iOS build process..."

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Android & iOS" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android
mkdir -p output/ios

log "📱 Starting Android Build Phase..."

# Memory cleanup and monitoring before Android build
log "🧠 Memory cleanup and monitoring before Android build..."
# Clear system caches
sync 2>/dev/null || true
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Monitor available memory
if command -v free >/dev/null 2>&1; then
    AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    log "📊 Available memory: ${AVAILABLE_MEM}MB"
    
    if [ "$AVAILABLE_MEM" -lt 4000 ]; then
        log "⚠️  Low memory detected (${AVAILABLE_MEM}MB), performing aggressive cleanup..."
        # Force garbage collection
        java -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Xmx1G -version 2>/dev/null || true
    fi
fi

# Execute Android build logic
log "🎨 Running Android branding script..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Android branding completed"
        
        # Validate required assets after branding
        log "🔍 Validating Android assets..."
        required_assets=("assets/images/logo.png" "assets/images/splash.png")
        for asset in "${required_assets[@]}"; do
            if [ -f "$asset" ] && [ -s "$asset" ]; then
                log "✅ $asset exists and has content"
            else
                log "❌ $asset is missing or empty after branding"
                exit 1
            fi
        done
        log "✅ All Android assets validated"
    else
        log "❌ Android branding failed"
        exit 1
    fi
else
    log "⚠️  Android branding script not found, skipping..."
fi

log "⚙️  Running Android customization script..."
if [ -f "lib/scripts/android/customization.sh" ]; then
    chmod +x lib/scripts/android/customization.sh
    if lib/scripts/android/customization.sh; then
        log "✅ Android customization completed"
    else
        log "❌ Android customization failed"
        exit 1
    fi
else
    log "⚠️  Android customization script not found, skipping..."
fi

log "🔒 Running Android permissions script..."
if [ -f "lib/scripts/android/permissions.sh" ]; then
    chmod +x lib/scripts/android/permissions.sh
    if lib/scripts/android/permissions.sh; then
        log "✅ Android permissions configured"
    else
        log "❌ Android permissions configuration failed"
        exit 1
    fi
else
    log "⚠️  Android permissions script not found, skipping..."
fi

log "🔥 Running Android Firebase script..."
if [ -f "lib/scripts/android/firebase.sh" ]; then
    chmod +x lib/scripts/android/firebase.sh
    if lib/scripts/android/firebase.sh; then
        log "✅ Android Firebase configuration completed"
    else
        log "❌ Android Firebase configuration failed"
        exit 1
    fi
else
    log "⚠️  Android Firebase script not found, skipping..."
fi

log "🔐 Running Android keystore script..."
if [ -f "lib/scripts/android/keystore.sh" ]; then
    chmod +x lib/scripts/android/keystore.sh
    if lib/scripts/android/keystore.sh; then
        log "✅ Android keystore configuration completed"
    else
        log "❌ Android keystore configuration failed"
        exit 1
    fi
else
    log "⚠️  Android keystore script not found, skipping..."
fi

log "🏗️  Building Android APK..."
# Build with retry logic
log "🏗️ Attempting Android APK build with memory optimizations..."
BUILD_SUCCESS=false
MAX_RETRIES=3

for attempt in $(seq 1 $MAX_RETRIES); do
    log "🔄 Android APK build attempt $attempt/$MAX_RETRIES"
    
    if flutter build apk --release --no-tree-shake-icons --target-platform android-arm64,android-arm; then
        log "✅ Android APK build completed successfully on attempt $attempt"
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            cp build/app/outputs/flutter-apk/app-release.apk output/android/
            log "✅ Android APK copied to output directory"
            BUILD_SUCCESS=true
            break
        else
            log "❌ Android APK file not found after build"
        fi
    else
        log "❌ Android APK build attempt $attempt failed"
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            log "🧹 Cleaning and retrying Android build..."
            flutter clean
            cd android
            ./gradlew --stop --no-daemon || true
            ./gradlew clean --no-daemon --max-workers=1 || true
            cd ..
            
            # Wait for memory to be freed
            sleep 10
            
            # Try with even more aggressive memory settings
            if [ $attempt -eq 2 ]; then
                log "🔧 Applying aggressive memory optimizations for Android..."
                export GRADLE_OPTS="-Xmx8G -XX:MaxMetaspaceSize=4G -XX:+UseG1GC -XX:MaxGCPauseMillis=100"
            fi
        fi
    fi
done

if [ "$BUILD_SUCCESS" = false ]; then
    log "❌ All Android APK build attempts failed"
    exit 1
fi

# Build AAB if keystore is configured
ANDROID_KEYSTORE_CONFIGURED=false
if [ -f "android/app/src/keystore.properties" ]; then
    ANDROID_KEYSTORE_CONFIGURED=true
    log "🏗️  Building Android App Bundle (AAB)..."
    # Build AAB with retry logic
    AAB_BUILD_SUCCESS=false
    MAX_AAB_RETRIES=3

    for attempt in $(seq 1 $MAX_AAB_RETRIES); do
        log "🔄 Android AAB build attempt $attempt/$MAX_AAB_RETRIES"
        
        if flutter build appbundle --release --no-tree-shake-icons --target-platform android-arm64,android-arm; then
            log "✅ Android AAB build completed successfully on attempt $attempt"
            if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
                cp build/app/outputs/bundle/release/app-release.aab output/android/
                log "✅ Android AAB copied to output directory"
                AAB_BUILD_SUCCESS=true
                break
            else
                log "❌ Android AAB file not found after build"
            fi
        else
            log "❌ Android AAB build attempt $attempt failed"
            
            if [ $attempt -lt $MAX_AAB_RETRIES ]; then
                log "🧹 Cleaning and retrying Android AAB build..."
                flutter clean
                cd android
                ./gradlew --stop --no-daemon || true
                ./gradlew clean --no-daemon --max-workers=1 || true
                cd ..
                
                # Wait for memory to be freed
                sleep 10
                
                # Try with even more aggressive memory settings
                if [ $attempt -eq 2 ]; then
                    log "🔧 Applying aggressive memory optimizations for Android AAB..."
                    export GRADLE_OPTS="-Xmx8G -XX:MaxMetaspaceSize=4G -XX:+UseG1GC -XX:MaxGCPauseMillis=100"
                fi
            fi
        fi
    done

    if [ "$AAB_BUILD_SUCCESS" = false ]; then
        log "❌ All Android AAB build attempts failed"
        exit 1
    fi
else
    log "⚠️  Android keystore not configured, skipping AAB build"
fi

log "🔍 Verifying Android build signatures..."
if [ -f "lib/scripts/android/verify_signing.sh" ]; then
    chmod +x lib/scripts/android/verify_signing.sh
    if lib/scripts/android/verify_signing.sh; then
        log "✅ Android signature verification completed"
    else
        log "⚠️  Android signature verification had issues (see logs above)"
    fi
else
    log "⚠️  Android signature verification script not found, skipping..."
fi

log "🍎 Starting iOS Build Phase..."

# Create iOS directories
mkdir -p ios/certificates

# Download iOS certificate files
log "📥 Downloading iOS certificate files..."

# Handle P12 certificate or CER/KEY combination
if [ -n "${CERT_P12_URL:-}" ]; then
    log "Downloading iOS P12 certificate from: $CERT_P12_URL"
    if curl -L -o ios/certificates/cert.p12 "$CERT_P12_URL"; then
        log "✅ iOS P12 certificate downloaded successfully"
    else
        log "❌ Failed to download iOS P12 certificate"
        exit 1
    fi
elif [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ]; then
    log "Downloading iOS certificate from: $CERT_CER_URL"
    if curl -L -o ios/certificates/cert.cer "$CERT_CER_URL"; then
        log "✅ iOS certificate downloaded successfully"
    else
        log "❌ Failed to download iOS certificate"
        exit 1
    fi
    
    log "Downloading iOS private key from: $CERT_KEY_URL"
    if curl -L -o ios/certificates/cert.key "$CERT_KEY_URL"; then
        log "✅ iOS private key downloaded successfully"
    else
        log "❌ Failed to download iOS private key"
        exit 1
    fi
else
    log "❌ Either CERT_P12_URL or both CERT_CER_URL and CERT_KEY_URL are required for iOS signing"
    exit 1
fi

if [ -n "${PROFILE_URL:-}" ]; then
    log "Downloading iOS provisioning profile from: $PROFILE_URL"
    if curl -L -o ios/certificates/profile.mobileprovision "$PROFILE_URL"; then
        log "✅ iOS provisioning profile downloaded successfully"
    else
        log "❌ Failed to download iOS provisioning profile"
        exit 1
    fi
else
    log "❌ PROFILE_URL is required for iOS signing"
    exit 1
fi

# Validate required iOS variables
log "🔍 Validating required iOS variables..."
required_ios_vars=(
    "CERT_PASSWORD"
    "APPLE_TEAM_ID"
    "APNS_KEY_ID"
    "APNS_AUTH_KEY_URL"
    "APP_STORE_CONNECT_KEY_IDENTIFIER"
)

for var in "${required_ios_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        log "❌ Required iOS variable $var is missing"
        exit 1
    fi
done

# Process iOS certificates
log "🔐 Processing iOS certificates..."
if [ -f "ios/certificates/cert.p12" ]; then
    log "✅ P12 certificate already available, skipping conversion"
elif [ -f "ios/certificates/cert.cer" ] && [ -f "ios/certificates/cert.key" ]; then
    log "Converting CER and KEY to P12..."
    if [ -f "lib/scripts/ios/certificate_handler.sh" ]; then
        chmod +x lib/scripts/ios/certificate_handler.sh
        if lib/scripts/ios/certificate_handler.sh \
            "ios/certificates/cert.cer" \
            "ios/certificates/cert.key" \
            "$CERT_PASSWORD" \
            "ios/certificates/cert.p12"; then
            log "✅ iOS certificate processing completed"
        else
            log "❌ iOS certificate processing failed"
            exit 1
        fi
    else
        log "❌ iOS certificate handler script not found"
        exit 1
    fi
else
    log "❌ Neither P12 nor CER/KEY files found"
    exit 1
fi

# Install iOS provisioning profile
log "📱 Installing iOS provisioning profile..."
if [ -f "ios/certificates/profile.mobileprovision" ]; then
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
    cp ios/certificates/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
    log "✅ iOS provisioning profile installed"
else
    log "❌ iOS provisioning profile not found"
    exit 1
fi

# Download APNS auth key
log "🔑 Downloading APNS auth key..."
if [ -n "${APNS_AUTH_KEY_URL:-}" ]; then
    if curl -L -o ios/certificates/AuthKey_${APNS_KEY_ID}.p8 "$APNS_AUTH_KEY_URL"; then
        log "✅ APNS auth key downloaded"
    else
        log "❌ Failed to download APNS auth key"
        exit 1
    fi
else
    log "❌ APNS_AUTH_KEY_URL is required"
    exit 1
fi

# Execute iOS build logic
log "🎨 Running iOS branding script..."
if [ -f "lib/scripts/ios/branding.sh" ]; then
    chmod +x lib/scripts/ios/branding.sh
    if lib/scripts/ios/branding.sh; then
        log "✅ iOS branding completed"
        
        # Validate required assets after branding
        log "🔍 Validating iOS assets..."
        required_assets=("assets/images/logo.png" "assets/images/splash.png")
        for asset in "${required_assets[@]}"; do
            if [ -f "$asset" ] && [ -s "$asset" ]; then
                log "✅ $asset exists and has content"
            else
                log "❌ $asset is missing or empty after branding"
                exit 1
            fi
        done
        log "✅ All iOS assets validated"
    else
        log "❌ iOS branding failed"
        exit 1
    fi
else
    log "⚠️  iOS branding script not found, skipping..."
fi

log "⚙️  Running iOS customization script..."
if [ -f "lib/scripts/ios/customization.sh" ]; then
    chmod +x lib/scripts/ios/customization.sh
    if lib/scripts/ios/customization.sh; then
        log "✅ iOS customization completed"
    else
        log "❌ iOS customization failed"
        exit 1
    fi
else
    log "⚠️  iOS customization script not found, skipping..."
fi

log "🔒 Running iOS permissions script..."
if [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/ios/permissions.sh
    if lib/scripts/ios/permissions.sh; then
        log "✅ iOS permissions configured"
    else
        log "❌ iOS permissions configuration failed"
        exit 1
    fi
else
    log "⚠️  iOS permissions script not found, skipping..."
fi

log "📱 Setting iOS deployment target..."
if [ -f "lib/scripts/ios/deployment_target.sh" ]; then
    chmod +x lib/scripts/ios/deployment_target.sh
    if lib/scripts/ios/deployment_target.sh; then
        log "✅ iOS deployment target set"
    else
        log "❌ iOS deployment target setting failed"
        exit 1
    fi
else
    log "⚠️  iOS deployment target script not found, skipping..."
fi

log "🔥 Running iOS Firebase script..."
if [ -f "lib/scripts/ios/firebase.sh" ]; then
    chmod +x lib/scripts/ios/firebase.sh
    if lib/scripts/ios/firebase.sh; then
        log "✅ iOS Firebase configuration completed"
    else
        log "❌ iOS Firebase configuration failed"
        exit 1
    fi
else
    log "⚠️  iOS Firebase script not found, skipping..."
fi

# Update Podfile for Firebase compatibility (avoid duplication)
log "📦 Updating Podfile for Firebase compatibility..."
if [ -f "ios/Podfile" ]; then
    # Check if Firebase settings already exist
    if ! grep -q "Firebase compatibility settings" ios/Podfile; then
        cat >> ios/Podfile << 'EOF'

# Firebase compatibility settings
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
EOF
        log "✅ Podfile updated with Firebase settings"
    else
        log "✅ Podfile already contains Firebase settings"
    fi
else
    log "❌ Podfile not found"
    exit 1
fi

# Flutter setup for iOS
log "📦 Setting up Flutter for iOS..."
flutter clean
flutter pub get

# Memory cleanup and monitoring before iOS build
log "🧠 Memory cleanup and monitoring before iOS build..."
# Clear system caches
sync 2>/dev/null || true
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Monitor available memory
if command -v free >/dev/null 2>&1; then
    AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    log "📊 Available memory: ${AVAILABLE_MEM}MB"
    
    if [ "$AVAILABLE_MEM" -lt 4000 ]; then
        log "⚠️  Low memory detected (${AVAILABLE_MEM}MB), performing aggressive cleanup..."
        # Force garbage collection
        java -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Xmx1G -version 2>/dev/null || true
    fi
fi

# Install pods
log "📦 Installing CocoaPods dependencies..."
cd ios
if pod install --repo-update; then
    log "✅ CocoaPods dependencies installed"
else
    log "❌ CocoaPods installation failed"
    exit 1
fi
cd ..

# Build iOS app
log "🏗️  Building iOS app..."

# Determine if we should build signed or unsigned
IOS_BUILD_SIGNED=true
if ! security find-identity -v -p codesigning build.keychain 2>/dev/null | grep -q "iPhone Distribution"; then
    log "⚠️  No valid iOS signing identity found, attempting unsigned build"
    IOS_BUILD_SIGNED=false
fi

# Create export options plist
cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${PROFILE_TYPE:-app-store}</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$(basename ios/certificates/profile.mobileprovision .mobileprovision)</string>
    </dict>
    <key>compileBitcode</key>
    <false/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

# Setup iOS keychain and certificates
log "🔐 Setting up iOS keychain..."
security create-keychain -p "" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "" build.keychain
security set-keychain-settings -t 3600 -u build.keychain

# Import P12 certificate
log "📥 Importing P12 certificate to keychain..."
if security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A; then
    log "✅ P12 certificate imported successfully"
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
else
    log "❌ Failed to import P12 certificate"
    exit 1
fi

# Build the iOS app
cd ios

# Clean previous builds
rm -rf build/Runner.xcarchive
rm -rf build/ios/ipa

# Build with retry logic
log "🏗️ Attempting iOS build with memory optimizations..."
BUILD_SUCCESS=false
MAX_RETRIES=3

for attempt in $(seq 1 $MAX_RETRIES); do
    log "🔄 iOS build attempt $attempt/$MAX_RETRIES"
    
    if [ "$IOS_BUILD_SIGNED" = true ]; then
        log "Building iOS with code signing..."
        if xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive | xcpretty; then
            log "✅ iOS archive created successfully"
            
            if xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build/ios/ipa -exportOptionsPlist ExportOptions.plist | xcpretty; then
                log "✅ iOS IPA exported successfully"
                if [ -f "build/ios/ipa/Runner.ipa" ]; then
                    cp build/ios/ipa/Runner.ipa ../output/ios/
                    log "✅ IPA copied to output directory"
                    BUILD_SUCCESS=true
                    break
                else
                    log "❌ IPA file not found after export"
                fi
            else
                log "❌ iOS IPA export failed"
            fi
        else
            log "❌ iOS archive creation failed"
        fi
    else
        log "Building iOS without code signing..."
        if flutter build ios --release --no-codesign; then
            log "✅ iOS unsigned build completed"
            # Create a simple IPA structure for unsigned build
            mkdir -p Payload/Runner.app
            cp -r build/ios/Release-iphoneos/Runner.app Payload/
            zip -r ../output/ios/Runner-unsigned.ipa Payload/
            rm -rf Payload
            BUILD_SUCCESS=true
            break
        else
            log "❌ iOS unsigned build failed"
        fi
    fi
    
    if [ $attempt -lt $MAX_RETRIES ]; then
        log "🧹 Cleaning and retrying iOS build..."
        # Clean build artifacts
        rm -rf build/Runner.xcarchive
        rm -rf build/ios/ipa
        
        # Wait for memory to be freed
        sleep 10
        
        # Try with reduced parallel jobs on retry
        if [ $attempt -eq 2 ]; then
            log "🔧 Applying aggressive memory optimizations for iOS..."
            export XCODE_PARALLEL_JOBS=2
        fi
    fi
done

if [ "$BUILD_SUCCESS" = false ]; then
    log "❌ All iOS build attempts failed"
    cd ..
    exit 1
fi
cd ..

# Generate environment config
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

# Send build success email
log "📧 Sending build success notification..."
ARTIFACTS_URL="https://codemagic.io/builds/${CM_BUILD_ID:-unknown}/artifacts"
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    lib/scripts/utils/send_email.sh "build_success" "Android & iOS" "${CM_BUILD_ID:-unknown}" "$ARTIFACTS_URL" || true
fi

log "🎉 Combined Android & iOS build process completed successfully!"
log "📱 Android APK file location: output/android/app-release.apk"
if [ "$ANDROID_KEYSTORE_CONFIGURED" = true ]; then
    log "📦 Android AAB file location: output/android/app-release.aab"
fi
log "🍎 iOS IPA file location: output/ios/"

exit 0 