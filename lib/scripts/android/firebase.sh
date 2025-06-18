#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
FIREBASE_CONFIG_ANDROID=${FIREBASE_CONFIG_ANDROID}
PKG_NAME=${PKG_NAME}

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

# Start Firebase setup
log "Starting Firebase configuration"

# Create necessary directories
mkdir -p android/app/src/main/assets

# Download Firebase configuration
if [ -n "$FIREBASE_CONFIG_ANDROID" ]; then
    log "Downloading Firebase configuration from $FIREBASE_CONFIG_ANDROID"
    curl -L "$FIREBASE_CONFIG_ANDROID" -o android/app/google-services.json || handle_error "Failed to download Firebase configuration"

    # Validate JSON format
    if ! jq . android/app/google-services.json > /dev/null 2>&1; then
        handle_error "Invalid Firebase configuration JSON format"
    fi

    # Verify package name matches
    CONFIG_PKG_NAME=$(jq -r '.client[0].client_info.android_client_info.package_name' android/app/google-services.json)
    if [ "$CONFIG_PKG_NAME" != "$PKG_NAME" ]; then
        handle_error "Firebase configuration package name ($CONFIG_PKG_NAME) does not match app package name ($PKG_NAME)"
    fi
else
    log "WARNING: Firebase configuration URL is not provided, skipping Firebase setup"
    exit 0
fi

# Update app-level build.gradle.kts
log "Updating app-level build.gradle.kts"
cat > android/app/build.gradle.kts << EOF
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "$PKG_NAME"
    compileSdk = 34

    defaultConfig {
        applicationId = "$PKG_NAME"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
}
EOF

# Update project-level build.gradle.kts
log "Updating project-level build.gradle.kts"
cat > android/build.gradle.kts << EOF
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
        classpath("com.google.gms:google-services:4.4.1")
        classpath("com.google.firebase:firebase-crashlytics-gradle:2.9.9")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOF

log "Firebase configuration completed successfully"
exit 0 