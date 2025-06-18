#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
KEY_STORE_URL=${KEY_STORE_URL}
CM_KEYSTORE_PASSWORD=${CM_KEYSTORE_PASSWORD}
CM_KEY_ALIAS=${CM_KEY_ALIAS}
CM_KEY_PASSWORD=${CM_KEY_PASSWORD}
PKG_NAME=${PKG_NAME}
VERSION_NAME=${VERSION_NAME}
VERSION_CODE=${VERSION_CODE}

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Set up error handling
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Start keystore setup
log "Starting keystore configuration"

# Validate required variables
if [ -z "$KEY_STORE_URL" ] || [ -z "$CM_KEYSTORE_PASSWORD" ] || [ -z "$CM_KEY_ALIAS" ] || [ -z "$CM_KEY_PASSWORD" ]; then
    handle_error "Missing required keystore variables"
fi

# Create keystore.properties
log "Creating keystore.properties"
cat > android/keystore.properties << EOF
storeFile=keystore.jks
storePassword=$CM_KEYSTORE_PASSWORD
keyAlias=$CM_KEY_ALIAS
keyPassword=$CM_KEY_PASSWORD
EOF

# Download keystore file
log "Downloading keystore from $KEY_STORE_URL"
curl -L "$KEY_STORE_URL" -o android/app/keystore.jks || handle_error "Failed to download keystore file"

# Verify keystore
log "Verifying keystore"
keytool -list -v -keystore android/app/keystore.jks -storepass "$CM_KEYSTORE_PASSWORD" > /dev/null 2>&1 || handle_error "Invalid keystore file or password"

# Update app-level build.gradle.kts
log "Updating app-level build.gradle.kts with signing configuration"
cat > android/app/build.gradle.kts << EOF
plugins {
    id("com.android.application")
    id("kotlin-android")
}

android {
    namespace = "$PKG_NAME"
    compileSdk = 34

    defaultConfig {
        applicationId = "$PKG_NAME"
        minSdk = 21
        targetSdk = 34
        versionCode = $VERSION_CODE
        versionName = "$VERSION_NAME"
    }

    signingConfigs {
        create("release") {
            val keystoreProperties = rootProject.file("keystore.properties").inputStream().use {
                java.util.Properties().apply { load(it) }
            }
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")
}
EOF

log "Keystore configuration completed successfully"
exit 0 