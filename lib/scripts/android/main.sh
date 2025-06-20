#!/bin/bash
set -euo pipefail

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Start build acceleration
log "🚀 Starting Android build with acceleration..."
accelerate_build "android"

# CRITICAL FIX: Ensure Java imports are present in build.gradle.kts
log "🔧 Ensuring Java imports in build.gradle.kts..."
if [ -f "android/app/build.gradle.kts" ]; then
    if ! grep -q 'import java.util.Properties' android/app/build.gradle.kts; then
        log "Adding missing Java imports to build.gradle.kts"
        # Create a temporary file with imports at the top
        {
            echo "import java.util.Properties"
            echo "import java.io.FileInputStream"
            echo ""
            cat android/app/build.gradle.kts
        } > android/app/build.gradle.kts.tmp
        mv android/app/build.gradle.kts.tmp android/app/build.gradle.kts
        log "✅ Java imports added to build.gradle.kts"
    else
        log "✅ Java imports already present in build.gradle.kts"
    fi
else
    log "⚠️ build.gradle.kts not found"
fi

# Generate complete build.gradle.kts based on workflow
log "📝 Generating build.gradle.kts for workflow: ${WORKFLOW_ID:-unknown}"

# Backup original file
cp android/app/build.gradle.kts android/app/build.gradle.kts.original 2>/dev/null || true

# Determine keystore configuration based on workflow
KEYSTORE_CONFIG=""
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    KEYSTORE_CONFIG='
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
        }'
else
    KEYSTORE_CONFIG='
        // No keystore configuration for this workflow'
fi

# Determine build type configuration
BUILD_TYPE_CONFIG=""
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    BUILD_TYPE_CONFIG='
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
        }'
else
    BUILD_TYPE_CONFIG='
        release {
            // Debug signing for free/paid workflows
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }'
fi

# Generate complete build.gradle.kts with optimizations
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

    // Enhanced AGP 8.7.3 optimizations
    buildFeatures {
        buildConfig = true
        aidl = false
        renderScript = false
        resValues = false
        shaders = false
        viewBinding = false
        dataBinding = false
    }

    signingConfigs {$KEYSTORE_CONFIG
    }

    buildTypes {$BUILD_TYPE_CONFIG
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

log "✅ Generated optimized build.gradle.kts for ${WORKFLOW_ID:-unknown} workflow"

# Enhanced error handling with recovery
trap 'handle_error $LINENO $?' ERR

handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Perform emergency cleanup
    log "🚨 Performing emergency cleanup..."
    
    # Stop all Gradle processes
    cd android
    ./gradlew --stop --no-daemon 2>/dev/null || true
    cd ..
    
    # Clear all caches
    flutter clean 2>/dev/null || true
    rm -rf ~/.gradle/caches/ 2>/dev/null || true
    rm -rf .dart_tool/ 2>/dev/null || true
    rm -rf build/ 2>/dev/null || true
    
    # Force garbage collection
    java -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -Xmx1G -version 2>/dev/null || true
    
    # Generate detailed error report
    log "📊 Generating detailed error report..."
    
    # System diagnostics
    if command -v free >/dev/null 2>&1; then
        AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        log "📊 Memory at failure: ${AVAILABLE_MEM}MB available"
    fi
    
    if command -v df >/dev/null 2>&1; then
        DISK_SPACE=$(df -h . | awk 'NR==2{print $4}')
        log "💾 Disk space at failure: $DISK_SPACE"
    fi
    
    # Send build failed email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Android" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit $exit_code
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Android" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android

# Enhanced asset download with parallel processing
log "📥 Starting enhanced asset download..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Android branding completed with acceleration"
        
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
    log "⚠️ Android branding script not found, skipping..."
fi

# Run customization with acceleration
log "⚙️ Running Android customization with acceleration..."
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

# Run permissions with acceleration
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
    log "⚠️ Android permissions script not found, skipping..."
fi

# Run Firebase with acceleration
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
    log "⚠️ Android Firebase script not found, skipping..."
fi

# Run keystore with acceleration
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
    log "⚠️ Android keystore script not found, skipping..."
fi

# Enhanced Flutter build with acceleration
log "📱 Starting enhanced Flutter build..."
cd android

# Pre-warm Gradle daemon
log "🔥 Pre-warming Gradle daemon for faster build..."
./gradlew --version --no-daemon >/dev/null 2>&1 || true

# Build with optimizations
log "🔨 Building Android APK with optimizations..."
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Build both APK and AAB for publish workflows
    log "📦 Building APK and AAB..."
    if ./gradlew assembleRelease bundleRelease --parallel --max-workers=4 --daemon; then
        log "✅ APK and AAB build completed successfully"
    else
        log "❌ APK and AAB build failed"
        exit 1
    fi
else
    # Build only APK for free/paid workflows
    log "📦 Building APK only..."
    if ./gradlew assembleRelease --parallel --max-workers=4 --daemon; then
        log "✅ APK build completed successfully"
    else
        log "❌ APK build failed"
        exit 1
    fi
fi

cd ..

# Copy artifacts to output directory
log "📁 Copying artifacts to output directory..."
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Copy both APK and AAB
    cp build/app/outputs/flutter-apk/app-release.apk output/android/ 2>/dev/null || true
    cp build/app/outputs/bundle/release/app-release.aab output/android/ 2>/dev/null || true
    log "✅ APK and AAB copied to output/android/"
else
    # Copy only APK
    cp build/app/outputs/flutter-apk/app-release.apk output/android/ 2>/dev/null || true
    log "✅ APK copied to output/android/"
fi

# Verify artifacts
log "🔍 Verifying artifacts..."
if [ -f "output/android/app-release.apk" ]; then
    APK_SIZE=$(du -h output/android/app-release.apk | cut -f1)
    log "✅ APK created successfully (Size: $APK_SIZE)"
else
    log "❌ APK not found in output directory"
    exit 1
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ -f "output/android/app-release.aab" ]; then
        AAB_SIZE=$(du -h output/android/app-release.aab | cut -f1)
        log "✅ AAB created successfully (Size: $AAB_SIZE)"
    else
        log "❌ AAB not found in output directory"
        exit 1
    fi
fi

# Send build success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "Android" "${CM_BUILD_ID:-unknown}" || true
fi

log "🎉 Android build completed successfully with acceleration!"
log "📊 Build artifacts available in output/android/"

exit 0 