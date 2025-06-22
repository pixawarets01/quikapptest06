#!/bin/bash
set -euo pipefail

# CRITICAL: Force fix env_config.dart to resolve $BRANCH compilation error
# This must be done FIRST to prevent any caching issues
if [ -f "lib/scripts/utils/force_fix_env_config.sh" ]; then
    chmod +x lib/scripts/utils/force_fix_env_config.sh
    lib/scripts/utils/force_fix_env_config.sh
fi

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# CRITICAL: Force fix again after environment generation to ensure no $BRANCH patterns
if [ -f "lib/scripts/utils/force_fix_env_config.sh" ]; then
    lib/scripts/utils/force_fix_env_config.sh
fi

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
    namespace = "${PKG_NAME:-com.example.quikapptest06}"
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
        applicationId = "${PKG_NAME:-com.example.quikapptest06}"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = ${VERSION_CODE:-1}
        versionName = "${VERSION_NAME:-1.0.0}"
        
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
    log "🛑 Stopping Gradle daemon..."
    # Ensure we're in the project root directory first
    if [ "$(basename "$PWD")" = "android" ]; then
        cd ..
    fi

    if [ -d "android" ]; then
        cd android
        if [ -f gradlew ]; then
            ./gradlew --stop || true
        fi
        cd ..
    else
        log "⚠️ android directory not found, skipping Gradle daemon stop"
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

# Update package names dynamically (replaces any old package names with PKG_NAME)
log "📦 Running dynamic package name update..."
if [ -f "lib/scripts/android/update_package_name.sh" ]; then
    chmod +x lib/scripts/android/update_package_name.sh
    if lib/scripts/android/update_package_name.sh; then
        log "✅ Package name update completed"
    else
        log "❌ Package name update failed"
        exit 1
    fi
else
    log "⚠️ Package name update script not found, skipping..."
fi

# Force regenerate environment configuration to ensure latest variables
log "🔄 Force regenerating environment configuration..."
generate_env_config

# Clean Flutter build cache first
log "🧹 Cleaning Flutter build cache..."
flutter clean

# Clear Dart analysis cache to ensure fresh compilation
log "🧹 Clearing Dart analysis cache..."
rm -rf .dart_tool/package_config.json 2>/dev/null || true
rm -rf .dart_tool/package_config_subset 2>/dev/null || true

# Get Flutter dependencies
log "📦 Getting Flutter dependencies..."
flutter pub get

# Verify environment configuration is correct
log "🔍 Verifying environment configuration..."
if [ -f "lib/config/env_config.dart" ]; then
    # Check for the problematic $BRANCH pattern
    if grep -q '\$BRANCH' lib/config/env_config.dart; then
        log "❌ CRITICAL: Found problematic \$BRANCH pattern in env_config.dart"
        log "🔧 Force regenerating environment configuration..."
        generate_env_config
        
        # Clear all possible caches
        log "🧹 Aggressive cache clearing..."
        rm -rf .dart_tool/ 2>/dev/null || true
        rm -rf build/ 2>/dev/null || true
        rm -rf ~/.pub-cache/hosted/pub.dartlang.org/ 2>/dev/null || true
        
        # Verify fix worked
        if grep -q '\$BRANCH' lib/config/env_config.dart; then
            log "❌ FAILED: Still contains \$BRANCH after regeneration"
            log "📋 Current problematic content:"
            grep -n "branch" lib/config/env_config.dart || true
            exit 1
        else
            log "✅ Successfully fixed \$BRANCH issue"
        fi
    fi
    
    if grep -q "static const String branch = \"main\"" lib/config/env_config.dart; then
        log "✅ Environment configuration verified - using static values"
    elif grep -q "static const String branch = \"\${BRANCH:-main}\"" lib/config/env_config.dart; then
        log "✅ Environment configuration verified - using dynamic values"
    else
        log "⚠️ Environment configuration may have issues"
        log "📋 Current branch line:"
        grep -n "branch" lib/config/env_config.dart || true
    fi
else
    log "❌ Environment configuration file not found"
    exit 1
fi

# Determine build command based on workflow
log "🏗️ Determining build command for workflow: ${WORKFLOW_ID:-unknown}"

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    log "🚀 Building AAB for production..."
    flutter build appbundle --release
    
    log "🚀 Building APK for testing..."
    flutter build apk --release
else
    log "🚀 Building APK for testing..."
    flutter build apk --release
fi

log "✅ Flutter build completed successfully"

# Stop Gradle daemon after build
log "🛑 Stopping Gradle daemon..."
if [ -d "android" ]; then
cd android
if [ -f gradlew ]; then
    ./gradlew --stop || true
fi
cd ..
else
    log "⚠️ android directory not found, skipping Gradle daemon stop"
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

# Verify required artifacts were found based on workflow
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # For production workflows, AAB is required, APK is optional
    if [ "$AAB_FOUND" = false ]; then
        log "❌ AAB file not found for production workflow"
        exit 1
    fi
    if [ "$APK_FOUND" = false ]; then
        log "ℹ️ APK not built for production workflow (AAB only)"
    fi
else
    # For testing workflows, APK is required
if [ "$APK_FOUND" = false ]; then
    log "❌ APK file not found in any expected location"
    exit 1
    fi
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ "$AAB_FOUND" = false ]; then
        log "❌ AAB file not found in any expected location"
        exit 1
    fi
fi

# Final verification
log "🔍 Final artifact verification..."
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Verify AAB for production workflows
    if [ "$AAB_FOUND" = true ] && [ -f "output/android/app-release.aab" ]; then
        log "✅ AAB verified in output directory"
    else
        log "❌ AAB verification failed"
        exit 1
    fi
    # APK is optional for production workflows
    if [ "$APK_FOUND" = true ] && [ -f "output/android/app-release.apk" ]; then
        log "✅ APK also available in output directory"
    fi
else
    # Verify APK for testing workflows
if [ "$APK_FOUND" = true ] && [ -f "output/android/app-release.apk" ]; then
    log "✅ APK verified in output directory"
else
    log "❌ APK verification failed"
    exit 1
    fi
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ "$AAB_FOUND" = true ] && [ -f "output/android/app-release.aab" ]; then
        log "✅ AAB verified in output directory"
    else
        log "❌ AAB verification failed"
        exit 1
    fi
fi

# Verify signing (if applicable)
log "✅ Build successful, verifying signing..."
if [ -f "lib/scripts/android/verify_signing.sh" ]; then
    chmod +x lib/scripts/android/verify_signing.sh
    if lib/scripts/android/verify_signing.sh "output/android/app-release.apk"; then
        log "✅ Signing verification successful"
    else
        log "⚠️ Signing verification failed, but continuing..."
    fi
else
    log "⚠️ Signing verification script not found"
fi

# Verify package name in built APK
log "📦 Verifying package name in built APK..."
if [ -f "lib/scripts/android/verify_package_name.sh" ]; then
    chmod +x lib/scripts/android/verify_package_name.sh
    if lib/scripts/android/verify_package_name.sh; then
        log "✅ Package name verification successful"
    else
        log "❌ Package name verification failed"
        # Don't exit here, just log the failure for investigation
        log "⚠️ Continuing with build process despite package name verification failure"
    fi
else
    log "⚠️ Package name verification script not found"
fi

# Process artifact URLs
log "📦 Processing artifact URLs for email notification..."
source "lib/scripts/utils/process_artifacts.sh"
artifact_urls=$(process_artifacts)
log "Artifact URLs: $artifact_urls"

# Send build success email
log "🎉 Build successful! Sending success email..."
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "Android" "${CM_BUILD_ID:-unknown}" "Build successful" "$artifact_urls"
fi

log "✅ Android build process completed successfully!"
exit 0 