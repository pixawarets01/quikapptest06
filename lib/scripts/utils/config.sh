#!/bin/bash
set -euo pipefail

# Detect Flutter root path
if command -v flutter >/dev/null 2>&1; then
    export flutterRoot="$(dirname "$(which flutter)")"
else
    export flutterRoot=""
fi

# Default environment variables
export VERSION_NAME=${VERSION_NAME:-"1.0.22"}
export VERSION_CODE=${VERSION_CODE:-"27"}
export APP_NAME=${APP_NAME:-"Garbcode App"}
export PKG_NAME=${PKG_NAME:-"com.garbcode.garbcodeapp"}
export BUNDLE_ID=${BUNDLE_ID:-"com.garbcode.garbcodeapp"}
export ORG_NAME=${ORG_NAME:-"Garbcode Apparels Private Limited"}
export WEB_URL=${WEB_URL:-"https://garbcode.com/"}
export EMAIL_ID=${EMAIL_ID:-"prasannasrinivasan32@gmail.com"}

# Feature flags
export PUSH_NOTIFY=${PUSH_NOTIFY:-"false"}
export IS_CHATBOT=${IS_CHATBOT:-"false"}
export IS_DOMAIN_URL=${IS_DOMAIN_URL:-"false"}
export IS_SPLASH=${IS_SPLASH:-"false"}
export IS_PULLDOWN=${IS_PULLDOWN:-"false"}
export IS_BOTTOMMENU=${IS_BOTTOMMENU:-"false"}
export IS_LOAD_IND=${IS_LOAD_IND:-"false"}

# Permissions
export IS_CAMERA=${IS_CAMERA:-"false"}
export IS_LOCATION=${IS_LOCATION:-"false"}
export IS_MIC=${IS_MIC:-"false"}
export IS_NOTIFICATION=${IS_NOTIFICATION:-"false"}
export IS_CONTACT=${IS_CONTACT:-"false"}
export IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
export IS_CALENDAR=${IS_CALENDAR:-"false"}
export IS_STORAGE=${IS_STORAGE:-"false"}

# UI/Branding
export LOGO_URL=${LOGO_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"}
export SPLASH_URL=${SPLASH_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"}
export SPLASH_BG=${SPLASH_BG:-""}
export SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-"#cbdbf5"}
export SPLASH_TAGLINE=${SPLASH_TAGLINE:-"Welcome to Garbcode"}
export SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-"#a30237"}
export SPLASH_ANIMATION=${SPLASH_ANIMATION:-"zoom"}
export SPLASH_DURATION=${SPLASH_DURATION:-"4"}

# Bottom Menu
export BOTTOMMENU_ITEMS=${BOTTOMMENU_ITEMS:-"[]"}
export BOTTOMMENU_BG_COLOR=${BOTTOMMENU_BG_COLOR:-"#FFFFFF"}
export BOTTOMMENU_ICON_COLOR=${BOTTOMMENU_ICON_COLOR:-"#000000"}
export BOTTOMMENU_TEXT_COLOR=${BOTTOMMENU_TEXT_COLOR:-"#000000"}
export BOTTOMMENU_FONT=${BOTTOMMENU_FONT:-"Roboto"}
export BOTTOMMENU_FONT_SIZE=${BOTTOMMENU_FONT_SIZE:-"12"}
export BOTTOMMENU_FONT_BOLD=${BOTTOMMENU_FONT_BOLD:-"false"}
export BOTTOMMENU_FONT_ITALIC=${BOTTOMMENU_FONT_ITALIC:-"false"}
export BOTTOMMENU_ACTIVE_TAB_COLOR=${BOTTOMMENU_ACTIVE_TAB_COLOR:-"#000000"}
export BOTTOMMENU_ICON_POSITION=${BOTTOMMENU_ICON_POSITION:-"above"}
export BOTTOMMENU_VISIBLE_ON=${BOTTOMMENU_VISIBLE_ON:-"all"}

# Firebase
export firebase_config_android=${firebase_config_android:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services%20(gc).json"}
export firebase_config_ios=${firebase_config_ios:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/GoogleService-Info-gc.plist"}

# Android Keystore
export KEY_STORE=${KEY_STORE:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"}
export CM_KEYSTORE_PASSWORD=${CM_KEYSTORE_PASSWORD:-"opeN@1234"}
export CM_KEY_ALIAS=${CM_KEY_ALIAS:-"my_key_alias"}
export CM_KEY_PASSWORD=${CM_KEY_PASSWORD:-"opeN@1234"}

# iOS Signing
export APPLE_TEAM_ID=${APPLE_TEAM_ID:-"9H2AD7NQ49"}
export APNS_KEY_ID=${APNS_KEY_ID:-"V566SWNF69"}
export APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_V566SWNF69.p8"}
export CERT_PASSWORD=${CERT_PASSWORD:-"User@54321"}
export PROFILE_URL=${PROFILE_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/Garbcode_App_Store.mobileprovision"}
export CERT_CER_URL=${CERT_CER_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/apple_distribution.cer"}
export CERT_KEY_URL=${CERT_KEY_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"}
export APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-"F5229W2Q8S"}

# SMTP Configuration
export SMTP_SERVER=${SMTP_SERVER:-"smtp.gmail.com"}
export SMTP_PORT=${SMTP_PORT:-"587"}
export SMTP_USER=${SMTP_USER:-"prasannasrie@gmail.com"}
export SMTP_PASS=${SMTP_PASS:-"jbbf nzhm zoay lbwb"}

# Project paths
export PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
export ANDROID_ROOT="$PROJECT_ROOT/android"
export ASSETS_DIR="$PROJECT_ROOT/assets"
export OUTPUT_DIR="$PROJECT_ROOT/output"
export TEMP_DIR="$PROJECT_ROOT/temp"

# Android specific paths
export ANDROID_MANIFEST_PATH="$ANDROID_ROOT/app/src/main/AndroidManifest.xml"
export ANDROID_BUILD_GRADLE_PATH="$ANDROID_ROOT/app/build.gradle"
export ANDROID_KEY_PROPERTIES_PATH="$ANDROID_ROOT/key.properties"
export ANDROID_FIREBASE_CONFIG_PATH="$ANDROID_ROOT/app/google-services.json"
export ANDROID_MIPMAP_DIR="$ANDROID_ROOT/app/src/main/res/mipmap"
export ANDROID_DRAWABLE_DIR="$ANDROID_ROOT/app/src/main/res/drawable"

# Output paths
export APK_OUTPUT_PATH="$OUTPUT_DIR/android"
export AAB_OUTPUT_PATH="$OUTPUT_DIR/android"

# Create necessary directories
mkdir -p "$OUTPUT_DIR/android"
mkdir -p "$TEMP_DIR"

# Add Kotlin version here
export KOTLIN_VERSION=${KOTLIN_VERSION:-"2.1.0"}

# Function to send email notifications
send_email_notification() {
    local status="$1"
    local message="$2"
    local log_file="$3"
    
    if [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASS" ]; then
        echo "SMTP credentials not configured. Skipping email notification."
        return
    fi
    
    local subject="QuikApp Build: $status"
    local body="Build Status: $status\n\nMessage: $message\n\nLog file: $log_file"
    
    # Use a simpler approach that works across different systems
    echo -e "$body" > /tmp/email_body.txt
    
    # Try different mail approaches
    if command -v sendmail >/dev/null 2>&1; then
        # Use sendmail if available
        (
            echo "To: $EMAIL_ID"
            echo "Subject: $subject"
            echo ""
            cat /tmp/email_body.txt
        ) | sendmail "$EMAIL_ID"
    elif command -v mail >/dev/null 2>&1; then
        # Use basic mail command
        mail -s "$subject" "$EMAIL_ID" < /tmp/email_body.txt
    else
        echo "No mail system available. Email notification skipped."
    fi
    
    # Clean up
    rm -f /tmp/email_body.txt
}

# Function to get project configurations for email
get_project_configurations() {
    local configs=(
        "APP_NAME:${APP_NAME}"
        "ORG_NAME:${ORG_NAME}"
        "WEB_URL:${WEB_URL}"
        "VERSION_NAME:${VERSION_NAME}"
        "VERSION_CODE:${VERSION_CODE}"
        "PKG_NAME:${PKG_NAME}"
        "BUNDLE_ID:${BUNDLE_ID}"
        "EMAIL_ID:${EMAIL_ID}"
        "PUSH_NOTIFY:${PUSH_NOTIFY}"
        "IS_CHATBOT:${IS_CHATBOT}"
        "IS_DOMAIN_URL:${IS_DOMAIN_URL}"
        "IS_SPLASH:${IS_SPLASH}"
        "IS_PULLDOWN:${IS_PULLDOWN}"
        "IS_BOTTOMMENU:${IS_BOTTOMMENU}"
        "IS_LOAD_IND:${IS_LOAD_IND}"
        "IS_CAMERA:${IS_CAMERA}"
        "IS_LOCATION:${IS_LOCATION}"
        "IS_MIC:${IS_MIC}"
        "IS_NOTIFICATION:${IS_NOTIFICATION}"
        "IS_CONTACT:${IS_CONTACT}"
        "IS_BIOMETRIC:${IS_BIOMETRIC}"
        "IS_CALENDAR:${IS_CALENDAR}"
        "IS_STORAGE:${IS_STORAGE}"
        "LOGO_URL:${LOGO_URL}"
        "SPLASH_URL:${SPLASH_URL}"
        "SPLASH_BG:${SPLASH_BG}"
        "SPLASH_BG_COLOR:${SPLASH_BG_COLOR}"
        "SPLASH_TAGLINE:${SPLASH_TAGLINE}"
        "SPLASH_TAGLINE_COLOR:${SPLASH_TAGLINE_COLOR}"
        "SPLASH_ANIMATION:${SPLASH_ANIMATION}"
        "SPLASH_DURATION:${SPLASH_DURATION}"
        "BOTTOMMENU_ITEMS:${BOTTOMMENU_ITEMS}"
        "BOTTOMMENU_BG_COLOR:${BOTTOMMENU_BG_COLOR}"
        "BOTTOMMENU_ICON_COLOR:${BOTTOMMENU_ICON_COLOR}"
        "BOTTOMMENU_TEXT_COLOR:${BOTTOMMENU_TEXT_COLOR}"
        "BOTTOMMENU_FONT:${BOTTOMMENU_FONT}"
        "BOTTOMMENU_FONT_SIZE:${BOTTOMMENU_FONT_SIZE}"
        "BOTTOMMENU_FONT_BOLD:${BOTTOMMENU_FONT_BOLD}"
        "BOTTOMMENU_FONT_ITALIC:${BOTTOMMENU_FONT_ITALIC}"
        "BOTTOMMENU_ACTIVE_TAB_COLOR:${BOTTOMMENU_ACTIVE_TAB_COLOR}"
        "BOTTOMMENU_ICON_POSITION:${BOTTOMMENU_ICON_POSITION}"
        "BOTTOMMENU_VISIBLE_ON:${BOTTOMMENU_VISIBLE_ON}"
        "firebase_config_android:${firebase_config_android}"
        "firebase_config_ios:${firebase_config_ios}"
        "KEY_STORE:${KEY_STORE}"
        "CM_KEYSTORE_PASSWORD:${CM_KEYSTORE_PASSWORD}"
        "CM_KEY_ALIAS:${CM_KEY_ALIAS}"
        "CM_KEY_PASSWORD:${CM_KEY_PASSWORD}"
        "EMAIL_SMTP_SERVER:${EMAIL_SMTP_SERVER}"
        "EMAIL_SMTP_PORT:${EMAIL_SMTP_PORT}"
        "EMAIL_SMTP_USER:${EMAIL_SMTP_USER}"
        "EMAIL_SMTP_PASS:********"
    )

    local config_list=""
    for config in "${configs[@]}"; do
        config_list+="<li>${config}</li>"
    done
    echo "$config_list"
}

# Function to generate environment.dart
generate_environment_dart() {
    cat > lib/config/env_config.dart << EOF
class EnvConfig {
  static const String appName = '${APP_NAME}';
  static const String orgName = '${ORG_NAME}';
  static const String webUrl = '${WEB_URL}';
  static const String pkgName = '${PKG_NAME}';
  static const String bundleId = '${BUNDLE_ID}';
  static const String emailId = '${EMAIL_ID}';
  static const bool isChatbot = ${IS_CHATBOT};
  static const bool isDomainUrl = ${IS_DOMAIN_URL};
  static const bool isSplash = ${IS_SPLASH};
  static const bool isPulldown = ${IS_PULLDOWN};
  static const bool isBottommenu = ${IS_BOTTOMMENU};
  static const bool isLoadIndicator = ${IS_LOAD_IND};
  static const bool isCamera = ${IS_CAMERA};
  static const bool isLocation = ${IS_LOCATION};
  static const bool isMic = ${IS_MIC};
  static const bool isNotification = ${IS_NOTIFICATION};
  static const bool isContact = ${IS_CONTACT};
  static const bool isBiometric = ${IS_BIOMETRIC};
  static const bool isCalendar = ${IS_CALENDAR};
  static const bool isStorage = ${IS_STORAGE};
  static const String logoUrl = '${LOGO_URL}';
  static const String splashUrl = '${SPLASH_URL}';
  static const String splashBg = '${SPLASH_BG}';
  static const String splashBgColor = '${SPLASH_BG_COLOR}';
  static const String splashTagline = '${SPLASH_TAGLINE}';
  static const String splashTaglineColor = '${SPLASH_TAGLINE_COLOR}';
  static const String splashAnimation = '${SPLASH_ANIMATION}';
  static const int splashDuration = ${SPLASH_DURATION};
  static const String bottommenuItems = r'''${BOTTOMMENU_ITEMS}''';
  static const String bottommenuBgColor = '${BOTTOMMENU_BG_COLOR}';
  static const String bottommenuIconColor = '${BOTTOMMENU_ICON_COLOR}';
  static const String bottommenuTextColor = '${BOTTOMMENU_TEXT_COLOR}';
  static const String bottommenuFont = '${BOTTOMMENU_FONT}';
  static const double bottommenuFontSize = ${BOTTOMMENU_FONT_SIZE};
  static const bool bottommenuFontBold = ${BOTTOMMENU_FONT_BOLD};
  static const bool bottommenuFontItalic = ${BOTTOMMENU_FONT_ITALIC};
  static const String bottommenuActiveTabColor = '${BOTTOMMENU_ACTIVE_TAB_COLOR}';
  static const String bottommenuIconPosition = '${BOTTOMMENU_ICON_POSITION}';
  static const String bottommenuVisibleOn = '${BOTTOMMENU_VISIBLE_ON}';
  static const bool pushNotify = ${PUSH_NOTIFY};
}
EOF
}

# Function to generate AndroidManifest.xml
generate_android_manifest() {
    cat > android/app/src/main/AndroidManifest.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- PERMISSIONS_PLACEHOLDER -->

    <application
        android:label="${APP_NAME}"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"/>
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            
            <!-- DEEPLINK_INTENT_FILTER_PLACEHOLDER -->
            
            <!-- FIREBASE_NOTIFICATION_INTENT_FILTER_PLACEHOLDER -->
        </activity>
        
        <!-- FIREBASE_SERVICES_PLACEHOLDER -->
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
EOF
}

# Function to generate build.gradle
generate_build_gradle() {
    cat > android/app/build.gradle << EOF
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
// FIREBASE_GRADLE_PLUGIN_PLACEHOLDER

android {
    namespace "${PKG_NAME}"
    compileSdkVersion flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "${PKG_NAME}"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode ${VERSION_CODE}
        versionName "${VERSION_NAME}"
    }

    signingConfigs {
        // SIGNING_CONFIGS_BLOCK_PLACEHOLDER
    }

    buildTypes {
        release {
            // BUILD_TYPES_SIGNING_CONFIG_PLACEHOLDER
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}

flutter {
    source '../../'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$KOTLIN_VERSION"
    // FIREBASE_BOM_DEPENDENCY_PLACEHOLDER
    // FIREBASE_MESSAGING_DEPENDENCY_PLACEHOLDER
}
EOF
}

# Function to generate pubspec.yaml
generate_pubspec_yaml() {
    cat > pubspec.yaml << EOF
name: quikapp
description: "A new Flutter project."
publish_to: 'none'
version: ${VERSION_NAME}+${VERSION_CODE}

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  # FIREBASE_CORE_DEPENDENCY_PLACEHOLDER
  # FIREBASE_MESSAGING_PUBSPEC_DEPENDENCY_PLACEHOLDER
  flutter_inappwebview: ^5.8.0
  url_launcher: ^6.2.2
  package_info_plus: ^5.0.1
  shared_preferences: ^2.2.2
  flutter_local_notifications: ^16.2.0
  permission_handler: ^11.1.0
  # CAMERA_DEPENDENCY_PLACEHOLDER
  # GEOLOCATOR_DEPENDENCY_PLACEHOLDER
  # SPEECH_TO_TEXT_DEPENDENCY_PLACEHOLDER
  # CONTACTS_SERVICE_DEPENDENCY_PLACEHOLDER
  # LOCAL_AUTH_DEPENDENCY_PLACEHOLDER
  # CALENDAR_EVENTS_DEPENDENCY_PLACEHOLDER
  # FILE_PICKER_DEPENDENCY_PLACEHOLDER
  # FLUTTER_CHAT_UI_DEPENDENCY_PLACEHOLDER
  # UNI_LINKS_DEPENDENCY_PLACEHOLDER
  # FLUTTER_NATIVE_SPLASH_DEPENDENCY_PLACEHOLDER
  # PULL_TO_REFRESH_DEPENDENCY_PLACEHOLDER
  # FLUTTER_SVG_DEPENDENCY_PLACEHOLDER
  # LOADING_ANIMATION_WIDGET_DEPENDENCY_PLACEHOLDER

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
EOF
}

# Generate all configuration files
generate_environment_dart
generate_android_manifest
generate_build_gradle
generate_pubspec_yaml

# Send build start notification
# This call is moved to main.sh or combined.sh to be part of the build flow
# send_email_notification "started"

echo "Configuration generated successfully!" 