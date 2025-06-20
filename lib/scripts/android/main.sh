#!/bin/bash
set -euo pipefail

# Source environment variables
source lib/scripts/utils/gen_env_config.sh

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

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

# Generate complete build.gradle.kts
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
    }

    defaultConfig {
        // Application ID will be updated by customization script
        applicationId = "com.example.quikapptest06"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {$KEYSTORE_CONFIG
    }

    buildTypes {$BUILD_TYPE_CONFIG
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
EOF

log "✅ Generated build.gradle.kts for ${WORKFLOW_ID:-unknown} workflow"

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

# Ensure assets directories exist and have content
log "📁 Setting up assets directories..."
mkdir -p assets/icons
mkdir -p assets/images

# Create placeholder files if directories are empty
if [ ! -f "assets/icons/.gitkeep" ]; then
    echo "# This file ensures the assets/icons directory is tracked by git" > assets/icons/.gitkeep
    log "✅ Created assets/icons/.gitkeep"
fi

if [ ! -f "assets/images/.gitkeep" ]; then
    echo "# This file ensures the assets/images directory is tracked by git" > assets/images/.gitkeep
    log "✅ Created assets/images/.gitkeep"
fi

# Verify assets are properly configured
if [ -f "pubspec.yaml" ]; then
    if grep -q "assets/icons/" pubspec.yaml && [ -d "assets/icons" ]; then
        log "✅ assets/icons/ directory exists and is referenced in pubspec.yaml"
    else
        log "⚠️ assets/icons/ directory or pubspec.yaml reference missing"
    fi
    
    if grep -q "assets/images/" pubspec.yaml && [ -d "assets/images" ]; then
        log "✅ assets/images/ directory exists and is referenced in pubspec.yaml"
    else
        log "⚠️ assets/images/ directory or pubspec.yaml reference missing"
    fi
fi

# Step 1: Run branding script
log "🎨 Running branding script..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Branding completed"
        
        # Validate required assets after branding
        log "🔍 Validating required assets..."
        required_assets=("assets/images/logo.png" "assets/images/splash.png")
        for asset in "${required_assets[@]}"; do
            if [ -f "$asset" ] && [ -s "$asset" ]; then
                log "✅ $asset exists and has content"
            else
                log "❌ $asset is missing or empty after branding"
                exit 1
            fi
        done
        log "✅ All required assets validated"
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
    if [[ "${PUSH_NOTIFY:-false}" == "true" ]]; then
        if [ -n "${FIREBASE_CONFIG_ANDROID:-}" ]; then
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
                log "❌ Firebase script not found"
                exit 1
            fi
        else
            log "❌ PUSH_NOTIFY is enabled but FIREBASE_CONFIG_ANDROID is not set"
            log "ℹ️  Please provide FIREBASE_CONFIG_ANDROID URL for Firebase integration"
            exit 1
        fi
    else
        log "⏭️  Skipping Firebase setup for android-paid (PUSH_NOTIFY is false)."
    fi
else
    # For android-publish and combined workflows
    if [[ "${PUSH_NOTIFY:-false}" == "true" && -n "${FIREBASE_CONFIG_ANDROID:-}" ]]; then
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
            log "❌ Firebase script not found"
            exit 1
        fi
    else
        log "⏭️  Skipping Firebase setup (PUSH_NOTIFY disabled or no config provided)."
    fi
fi

# Step 5: Run keystore script
if [ "$ANDROID_FREE_WORKFLOW" = true ]; then
    log "⏭️  Skipping keystore setup for android-free workflow."
elif [ "$ANDROID_PAID_WORKFLOW" = true ]; then
    log "⏭️  Skipping keystore setup for android-paid workflow. Debug signing will be used."
else
    # For android-publish and combined workflows
    log "🔐 Setting up keystore for release signing..."
    if [ -f "lib/scripts/android/keystore.sh" ]; then
        chmod +x lib/scripts/android/keystore.sh
        if lib/scripts/android/keystore.sh; then
            log "✅ Keystore configuration completed"
        else
            log "❌ Keystore configuration failed"
            exit 1
        fi
    else
        log "❌ Keystore script not found"
        exit 1
    fi
fi

# Step 6: Flutter setup and dependencies
log "📦 Setting up Flutter dependencies..."
flutter clean
flutter pub get
log "✅ Flutter dependencies updated"

# Memory cleanup and monitoring
log "🧠 Memory cleanup and monitoring..."
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

# Step 7: Build APK
log "🏗️  Attempting APK build with memory optimizations..."
BUILD_SUCCESS=false
MAX_RETRIES=3

for attempt in $(seq 1 $MAX_RETRIES); do
    log "🔄 Build attempt $attempt/$MAX_RETRIES"
    
    if flutter build apk --release --no-tree-shake-icons --target-platform android-arm64,android-arm; then
        log "✅ APK build completed successfully on attempt $attempt"
        BUILD_SUCCESS=true
        break
    else
        log "❌ Build attempt $attempt failed"
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            log "🧹 Cleaning and retrying..."
            flutter clean
            cd android
            ./gradlew --stop --no-daemon || true
            ./gradlew clean --no-daemon --max-workers=1 || true
            cd ..
            
            # Wait for memory to be freed
            sleep 10
            
            # Try with even more aggressive memory settings
            if [ $attempt -eq 2 ]; then
                log "🔧 Applying aggressive memory optimizations..."
                export GRADLE_OPTS="-Xmx8G -XX:MaxMetaspaceSize=4G -XX:+UseG1GC -XX:MaxGCPauseMillis=100"
            fi
        fi
    fi
done

if [ "$BUILD_SUCCESS" = false ]; then
    log "❌ All build attempts failed"
    exit 1
fi

# Copy APK to output directory
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk output/android/
    log "✅ APK copied to output directory"
else
    log "❌ APK file not found after build"
    exit 1
fi

# Step 8: Build AAB (if keystore is configured)
KEYSTORE_CONFIGURED=false
if [ -f "android/app/src/keystore.properties" ]; then
    KEYSTORE_CONFIGURED=true
    log "🏗️  Building Android App Bundle (AAB)..."
    
    # Clean before AAB build
    log "🧹 Cleaning before AAB build..."
    flutter clean
    cd android
    ./gradlew --stop --no-daemon || true
    ./gradlew clean --no-daemon --max-workers=2 || true
    cd ..
    
    if flutter build appbundle --release --no-tree-shake-icons --target-platform android-arm64,android-arm; then
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
    log "⚠️  Android keystore not configured, skipping AAB build"
fi

# Step 9: Verify signing
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

# Step 10: Generate environment config
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

# Step 11: Send build success email
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