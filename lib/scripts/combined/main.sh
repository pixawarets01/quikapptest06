#!/bin/bash
set -euo pipefail

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Start build acceleration for combined workflow
log "🚀 Starting Combined Android & iOS build with acceleration..."
accelerate_build "all"

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

# Execute Android build logic with acceleration
log "🎨 Running Android branding script with acceleration..."
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

log "⚙️  Running Android customization with acceleration..."
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

log "🔒 Running Android permissions with acceleration..."
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

log "🔥 Running Android Firebase with acceleration..."
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

log "🔐 Running Android keystore with acceleration..."
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

# Generate build.gradle.kts for combined workflow with optimizations
log "📝 Generating optimized build.gradle.kts for combined workflow..."

# Backup original file
cp android/app/build.gradle.kts android/app/build.gradle.kts.original 2>/dev/null || true

# Generate complete build.gradle.kts for combined workflow with optimizations
cat > android/app/build.gradle.kts <<EOF
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.quikapptest06"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        // Enhanced Kotlin compilation optimizations
        freeCompilerArgs += listOf(
            "-Xno-param-assertions",
            "-Xno-call-assertions",
            "-Xno-receiver-assertions",
            "-Xno-optimized-callable-references",
            "-Xuse-ir",
            "-Xskip-prerelease-check"
        )
    }

    defaultConfig {
        // Application ID will be updated by customization script
        applicationId = "com.example.quikapptest06"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Optimized architecture targeting
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    // Enhanced AGP 8.7.3 optimizations for combined workflow
    buildFeatures {
        buildConfig = true
        aidl = false
        renderScript = false
        resValues = false
        shaders = false
        viewBinding = false
        dataBinding = false
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("app/keystore.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            val keystorePropertiesFile = rootProject.file("app/keystore.properties")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing if keystore not available
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    
    // Build optimization settings
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            excludes += listOf("META-INF/DEPENDENCIES", "META-INF/LICENSE", "META-INF/LICENSE.txt", "META-INF/license.txt", "META-INF/NOTICE", "META-INF/NOTICE.txt", "META-INF/notice.txt", "META-INF/ASL2.0", "META-INF/*.kotlin_module")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
EOF

log "✅ Generated optimized build.gradle.kts for combined workflow"

# Enhanced Android build with acceleration
log "📱 Starting enhanced Android build..."
cd android

# Pre-warm Gradle daemon
log "🔥 Pre-warming Gradle daemon for faster build..."
./gradlew --version --no-daemon >/dev/null 2>&1 || true

# Build both APK and AAB with optimizations
log "📦 Building APK and AAB with optimizations..."
if ./gradlew assembleRelease bundleRelease --parallel --max-workers=4 --daemon; then
    log "✅ APK and AAB build completed successfully"
else
    log "❌ APK and AAB build failed"
    exit 1
fi

cd ..

# Copy Android artifacts to output directory
log "📁 Copying Android artifacts to output directory..."
cp build/app/outputs/flutter-apk/app-release.apk output/android/ 2>/dev/null || true
cp build/app/outputs/bundle/release/app-release.aab output/android/ 2>/dev/null || true
log "✅ Android artifacts copied to output/android/"

# Verify Android artifacts
log "🔍 Verifying Android artifacts..."
if [ -f "output/android/app-release.apk" ]; then
    APK_SIZE=$(du -h output/android/app-release.apk | cut -f1)
    log "✅ APK created successfully (Size: $APK_SIZE)"
else
    log "❌ APK not found in output directory"
    exit 1
fi

if [ -f "output/android/app-release.aab" ]; then
    AAB_SIZE=$(du -h output/android/app-release.aab | cut -f1)
    log "✅ AAB created successfully (Size: $AAB_SIZE)"
else
    log "❌ AAB not found in output directory"
    exit 1
fi

log "🍎 Starting iOS Build Phase..."

# Memory cleanup between Android and iOS builds
log "🧠 Memory cleanup between Android and iOS builds..."
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

# Execute iOS build logic with acceleration
log "🎨 Running iOS branding script with acceleration..."
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

log "⚙️  Running iOS customization with acceleration..."
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

log "🔒 Running iOS permissions with acceleration..."
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

log "🔥 Running iOS Firebase with acceleration..."
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

# Setup certificates and provisioning with acceleration
log "🔐 Setting up certificates and provisioning with acceleration..."

# Download provisioning profile
log "📥 Downloading provisioning profile..."
if ! curl -L --fail --silent --show-error --output "ios/certificates/profile.mobileprovision" "$PROFILE_URL"; then
    log "❌ Failed to download provisioning profile"
    exit 1
fi

# Setup keychain and certificates
log "🔐 Setting up keychain..."
security create-keychain -p "" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "" build.keychain
security set-keychain-settings -t 3600 -u build.keychain

# Create certificates directory
mkdir -p ios/certificates

# Handle P12 certificate
if [ -n "${CERT_P12_URL:-}" ]; then
    log "🔍 Validating P12 certificate URL..."
    if ! curl -L --fail --silent --show-error --output "ios/certificates/cert.p12" "$CERT_P12_URL"; then
        log "❌ Failed to download P12 certificate"
        exit 1
    fi
    
    # Import P12 certificate
    log "🔄 Importing P12 certificate..."
    if ! security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A; then
        log "❌ Failed to import P12 certificate"
        exit 1
    fi
else
    # Handle CER and KEY files
    log "🔍 Validating certificate and key URLs..."
    if ! curl -L --fail --silent --show-error --output "ios/certificates/cert.cer" "$CERT_CER_URL"; then
        log "❌ Failed to download certificate"
        exit 1
    fi
    if ! curl -L --fail --silent --show-error --output "ios/certificates/cert.key" "$CERT_KEY_URL"; then
        log "❌ Failed to download private key"
        exit 1
    fi

    # Convert certificates using certificate handler
    log "🔄 Converting certificates using certificate handler..."
    if [ -f "lib/scripts/ios/certificate_handler.sh" ]; then
        chmod +x lib/scripts/ios/certificate_handler.sh
        if ! lib/scripts/ios/certificate_handler.sh \
            "ios/certificates/cert.cer" \
            "ios/certificates/cert.key" \
            "$CERT_PASSWORD" \
            "ios/certificates/cert.p12"; then
            log "❌ Certificate handler failed"
            exit 1
        fi
    else
        # Fallback to direct conversion
        log "🔄 Using fallback certificate conversion..."
        if ! openssl x509 -in ios/certificates/cert.cer -inform DER -out ios/certificates/cert.pem -outform PEM; then
            log "❌ Failed to convert certificate to PEM format"
            exit 1
        fi
        if ! openssl pkcs12 -export -inkey ios/certificates/cert.key -in ios/certificates/cert.pem -out ios/certificates/cert.p12 -password pass:"$CERT_PASSWORD"; then
            log "❌ Failed to create P12 file"
            exit 1
        fi

        # Import converted P12
        log "🔄 Importing converted P12 certificate..."
        if ! security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -A; then
            log "❌ Failed to import converted P12 certificate"
            exit 1
        fi
    fi
fi

# Set partition list for codesigning
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain

# Setup provisioning
log "📱 Setting up provisioning profile..."
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp ios/certificates/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

# Determine distribution method from profile type
local method="${PROFILE_TYPE:-app-store}"
local thinning="${THINNING:-none}"
local strip_bitcode="true"
local upload_bitcode="false"
local upload_symbols="true"
local compile_bitcode="false"

# Set specific options based on distribution method
if [ "$method" = "ad-hoc" ]; then
    strip_bitcode="true"
    upload_bitcode="false"
    upload_symbols="false"
    compile_bitcode="false"
    
    # For ad-hoc, we can enable device specific builds
    if [ "${ENABLE_DEVICE_SPECIFIC_BUILDS:-false}" = "true" ]; then
        thinning="thin-for-all-variants"
    fi
fi

# Create export options plist
cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$method</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$(basename ios/certificates/profile.mobileprovision .mobileprovision)</string>
    </dict>
    <key>stripBitcode</key>
    <$strip_bitcode/>
    <key>uploadBitcode</key>
    <$upload_bitcode/>
    <key>uploadSymbols</key>
    <$upload_symbols/>
    <key>compileBitcode</key>
    <$compile_bitcode/>
    <key>thinning</key>
    <string>$thinning</string>
</dict>
</plist>
EOF

log "✅ Provisioning profile setup completed"

# Enhanced iOS build with acceleration
log "📱 Starting enhanced iOS build..."

# Pre-install CocoaPods dependencies
log "📦 Pre-installing CocoaPods dependencies..."
cd ios
if [ "${COCOAPODS_FAST_INSTALL:-true}" = "true" ]; then
    pod install --repo-update --verbose || pod install --verbose
else
    pod install --verbose
fi
cd ..

# Build iOS app with optimizations
log "🔨 Building iOS app with optimizations..."
if flutter build ios --release --no-codesign; then
    log "✅ iOS build completed successfully"
else
    log "❌ iOS build failed"
    exit 1
fi

# Archive and export IPA with optimizations
log "📦 Archiving and exporting IPA with optimizations..."
cd ios

# Create archive
if xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -archivePath build/Runner.xcarchive archive; then
    log "✅ Archive created successfully"
else
    log "❌ Archive creation failed"
    exit 1
fi

# Export IPA
if xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build/ios/ipa -exportOptionsPlist ExportOptions.plist; then
    log "✅ IPA exported successfully"
else
    log "❌ IPA export failed"
    exit 1
fi

cd ..

# Copy iOS artifacts to output directory
log "📁 Copying iOS artifacts to output directory..."
cp ios/build/ios/ipa/*.ipa output/ios/ 2>/dev/null || true
log "✅ iOS artifacts copied to output/ios/"

# Verify iOS artifacts
log "🔍 Verifying iOS artifacts..."
if [ -f "output/ios/Runner.ipa" ]; then
    IPA_SIZE=$(du -h output/ios/Runner.ipa | cut -f1)
    log "✅ IPA created successfully (Size: $IPA_SIZE)"
else
    log "❌ IPA not found in output directory"
    exit 1
fi

# Send build success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "Android & iOS" "${CM_BUILD_ID:-unknown}" || true
fi

log "🎉 Combined Android & iOS build completed successfully with acceleration!"
log "📊 Build artifacts available in output/android/ and output/ios/"

exit 0 