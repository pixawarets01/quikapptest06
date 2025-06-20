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
    if [ -d "android" ]; then
        cd android
        chmod +x gradlew 2>/dev/null || true
        ./gradlew --stop --no-daemon 2>/dev/null || true
        cd ..
    fi
    
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
    
    # shellcheck disable=SC2317
    if command -v df >/dev/null 2>&1; then
        DISK_SPACE=$(df -h . | awk 'NR==2{print $4}')
        log "💾 Disk space at failure: $DISK_SPACE"
    fi
    
    # Send build failed email
    # shellcheck disable=SC2317
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Android" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit "$exit_code"
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Android" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android

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

# Download custom icons for bottom menu
log "🎨 Downloading custom icons for bottom menu..."
if [ "${IS_BOTTOMMENU:-false}" = "true" ]; then
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
else
    log "ℹ️ Bottom menu disabled (IS_BOTTOMMENU=false), skipping custom icons download"
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

# Configure global build optimizations
log "⚙️ Configuring global build optimizations..."

# Clear any conflicting JVM options first
log "🧹 Clearing conflicting JVM options..."
unset GRADLE_OPTS
unset JAVA_OPTS
unset _JAVA_OPTIONS

# Configure JVM options - Fixed to avoid multiple garbage collector conflicts
log "🔧 Configuring JVM options..."
export JAVA_TOOL_OPTIONS="-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Dfile.encoding=UTF-8"

# Configure environment
log "🔧 Configuring build environment..."
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create optimized gradle.properties
log "📝 Creating optimized gradle.properties..."
if [ ! -f android/gradle.properties ] || ! grep -q "org.gradle.jvmargs" android/gradle.properties; then
    cat >> android/gradle.properties << EOF
org.gradle.jvmargs=-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.caching=true
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
kotlin.code.style=official
EOF
    log "✅ Created/updated gradle.properties with optimized settings"
else
    log "✅ gradle.properties already exists with JVM args"
fi

# Clean Flutter build cache first
log "🧹 Cleaning Flutter build cache..."
flutter clean

# Create a list of safe environment variables to pass to Flutter
log "🔧 Preparing environment variables for Flutter..."

# Create a temporary file for environment variables
ENV_FILE=$(mktemp)
trap "rm -f $ENV_FILE" EXIT

# Write essential environment variables to file
cat > "$ENV_FILE" << EOF
--dart-define=APP_ID=${APP_ID:-}
--dart-define=WORKFLOW_ID=${WORKFLOW_ID:-}
--dart-define=VERSION_NAME=${VERSION_NAME:-}
--dart-define=VERSION_CODE=${VERSION_CODE:-}
--dart-define=APP_NAME="${APP_NAME:-}"
--dart-define=PKG_NAME=${PKG_NAME:-}
--dart-define=PUSH_NOTIFY=${PUSH_NOTIFY:-false}
--dart-define=IS_CHATBOT=${IS_CHATBOT:-false}
--dart-define=IS_DOMAIN_URL=${IS_DOMAIN_URL:-false}
--dart-define=IS_SPLASH=${IS_SPLASH:-false}
--dart-define=IS_PULLDOWN=${IS_PULLDOWN:-false}
--dart-define=IS_BOTTOMMENU=${IS_BOTTOMMENU:-false}
--dart-define=IS_LOAD_IND=${IS_LOAD_IND:-false}
--dart-define=IS_CAMERA=${IS_CAMERA:-false}
--dart-define=IS_LOCATION=${IS_LOCATION:-false}
--dart-define=IS_MIC=${IS_MIC:-false}
--dart-define=IS_NOTIFICATION=${IS_NOTIFICATION:-false}
--dart-define=IS_CONTACT=${IS_CONTACT:-false}
--dart-define=IS_BIOMETRIC=${IS_BIOMETRIC:-false}
--dart-define=IS_CALENDAR=${IS_CALENDAR:-false}
--dart-define=IS_STORAGE=${IS_STORAGE:-false}
--dart-define=FLUTTER_BUILD_NAME=${VERSION_NAME:-}
--dart-define=FLUTTER_BUILD_NUMBER=${VERSION_CODE:-}
EOF

# Read the environment variables from file
ENV_ARGS=$(cat "$ENV_FILE" | tr '\n' ' ')

log "📋 Prepared environment variables for Flutter build"

# Debug: Show the exact Flutter build command that will be executed
log "🔍 Debug: Flutter build command will be:"
log "   flutter build apk --release $ENV_ARGS"
log "🔍 Debug: Environment variables content:"
cat "$ENV_FILE" | head -10

# Validate critical environment variables
log "🔍 Debug: Validating critical environment variables..."
if [ -z "${APP_NAME:-}" ]; then
    log "⚠️ Warning: APP_NAME is empty"
else
    log "✅ APP_NAME: ${APP_NAME}"
fi

if [ -z "${PKG_NAME:-}" ]; then
    log "⚠️ Warning: PKG_NAME is empty"
else
    log "✅ PKG_NAME: ${PKG_NAME}"
fi

if [ -z "${VERSION_NAME:-}" ]; then
    log "⚠️ Warning: VERSION_NAME is empty"
else
    log "✅ VERSION_NAME: ${VERSION_NAME}"
fi

if [ -z "${VERSION_CODE:-}" ]; then
    log "⚠️ Warning: VERSION_CODE is empty"
else
    log "✅ VERSION_CODE: ${VERSION_CODE}"
fi

# Debug: Show current directory and Flutter project structure
log "🔍 Debug: Current directory: $(pwd)"
log "🔍 Debug: Flutter project structure:"
ls -la | head -10
log "🔍 Debug: pubspec.yaml exists: $([ -f pubspec.yaml ] && echo 'YES' || echo 'NO')"
log "🔍 Debug: android/ directory exists: $([ -d android ] && echo 'YES' || echo 'NO')"

# Verify Flutter is working
log "🔍 Debug: Flutter doctor:"
flutter doctor --verbose 2>&1 | head -20 || true

# Test basic Flutter build without environment variables first
log "🧪 Testing basic Flutter build without environment variables..."
log "🔍 Debug: Running: flutter build apk --release"
if flutter build apk --release 2>&1 | tee /tmp/flutter_build_test.log; then
    log "✅ Basic Flutter build test successful"
    # Clean after successful test build
    flutter clean
else
    log "❌ Basic Flutter build test failed - there's a fundamental issue"
    log "🔍 Debug: Full build log:"
    cat /tmp/flutter_build_test.log || true
    log "🔍 Debug: Trying to get more information about the failure..."
    
    # Try to get more specific error information
    log "🔍 Debug: Checking Flutter project structure..."
    flutter analyze 2>&1 | head -30 || true
    
    log "🔍 Debug: Checking pub dependencies..."
    flutter pub deps 2>&1 | head -20 || true
    
    log "🔍 Debug: Checking Android configuration..."
    if [ -d "android" ]; then
        cd android
        if [ -f "gradlew" ]; then
            # Use a simpler command to avoid JVM conflicts
            ./gradlew --version 2>&1 | head -10 || true
            log "🔍 Debug: Gradle wrapper is executable"
        else
            log "🔍 Debug: Gradle wrapper not found"
        fi
        cd ..
    fi
    
    exit 1
fi

# Clean after test build
flutter clean

# Build with optimizations
log "🔨 Building Android APK with optimizations..."
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Build both APK and AAB for publish workflows
    log "📦 Building APK and AAB..."
    
    # Set GRADLE_OPTS for the flutter build command
    export GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Dfile.encoding=UTF-8"
    
    # Build APK first
    log "📱 Building APK with environment variables..."
    if flutter build apk --release $ENV_ARGS; then
        log "✅ APK build completed successfully"
    else
        log "❌ APK build with environment variables failed, trying without..."
        if flutter build apk --release; then
            log "✅ APK build completed successfully (without environment variables)"
        else
            log "❌ APK build failed completely"
            exit 1
        fi
    fi
    
    # Build AAB second
    log "📦 Building AAB..."
    if flutter build appbundle --release $ENV_ARGS; then
        log "✅ AAB build completed successfully"
    else
        log "❌ AAB build with environment variables failed, trying without..."
        if flutter build appbundle --release; then
            log "✅ AAB build completed successfully (without environment variables)"
        else
            log "❌ AAB build failed completely"
            exit 1
        fi
    fi
else
    # Build only APK for free/paid workflows
    log "📦 Building APK only..."
    
    # Set GRADLE_OPTS for the flutter build command
    export GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Dfile.encoding=UTF-8"
    
    if flutter build apk --release $ENV_ARGS; then
        log "✅ APK build completed successfully"
    else
        log "❌ APK build with environment variables failed, trying without..."
        if flutter build apk --release; then
            log "✅ APK build completed successfully (without environment variables)"
        else
            log "❌ APK build failed completely"
            exit 1
        fi
    fi
fi

# Stop Gradle daemon after build
log "🛑 Stopping Gradle daemon..."
cd android
if [ -f gradlew ]; then
    ./gradlew --stop || true
fi
cd ..

# Ensure we're in the project root directory
if [ "$(basename "$PWD")" = "android" ]; then
    cd ..
fi

# Copy artifacts to output directory
log "📁 Copying artifacts to output directory..."

# Debug: List all APK and AAB files in build directory
log "🔍 Searching for built artifacts..."
find build -name "*.apk" -o -name "*.aab" 2>/dev/null | while read -r file; do
    log "   Found: $file ($(du -h "$file" | cut -f1))"
done
# Smart artifact detection and copying
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
        log "✅ APK copied from $apk_path (Size: $APK_SIZE)"
        APK_FOUND=true
        break
    fi
done

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Look for AAB files in various possible locations
    for aab_path in \
        "build/app/outputs/bundle/release/app-release.aab" \
        "android/app/build/outputs/bundle/release/app-release.aab"; do
        
        if [ -f "$aab_path" ]; then
            cp "$aab_path" output/android/app-release.aab
            AAB_SIZE=$(du -h output/android/app-release.aab | cut -f1)
            log "✅ AAB copied from $aab_path (Size: $AAB_SIZE)"
            AAB_FOUND=true
            break
        fi
    done
fi

# Verify required artifacts were found
if [ "$APK_FOUND" = false ]; then
    log "❌ APK file not found in any expected location"
    exit 1
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ "$AAB_FOUND" = false ]; then
        log "❌ AAB file not found in any expected location"
        exit 1
    fi
fi

# Final verification
log "🔍 Final artifact verification..."
if [ "$APK_FOUND" = true ] && [ -f "output/android/app-release.apk" ]; then
    log "✅ APK verified in output directory"
else
    log "❌ APK verification failed"
    exit 1
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ "$AAB_FOUND" = true ] && [ -f "output/android/app-release.aab" ]; then
        log "✅ AAB verified in output directory"
    else
        log "❌ AAB verification failed"
        exit 1
    fi
fi

# Generate installation helper
log "🔧 Generating installation helper and guide..."
if [ -f "lib/scripts/android/install_helper.sh" ]; then
    chmod +x lib/scripts/android/install_helper.sh
    # Run installation helper to generate guides (without actual installation)
    lib/scripts/android/install_helper.sh output/android/app-release.apk false 2>/dev/null || true
fi

# Send build success email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    # Pass platform and build ID for individual artifact URL generation
    lib/scripts/utils/send_email.sh "build_success" "Android" "${CM_BUILD_ID:-unknown}" || true
fi

log "🎉 Android build completed successfully with acceleration!"
log "📊 Build artifacts available in output/android/"
log "📋 Installation guides available:"
log "   - output/android/INSTALL_GUIDE.txt (Version management guide)"
log "   - output/android/installation_report.txt (Installation helper guide)"

exit 0 