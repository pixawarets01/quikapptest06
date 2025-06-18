#!/bin/bash
set -euo pipefail

# API Variables with defaults
VERSION_NAME=${VERSION_NAME:-"1.0.0"}
VERSION_CODE=${VERSION_CODE:-"1"}
APP_NAME=${APP_NAME:-"QuikApp"}
ORG_NAME=${ORG_NAME:-"QuikApp"}
WEB_URL=${WEB_URL:-"https://quikapp.co"}
PKG_NAME=${PKG_NAME:-"com.quikapp.app"}
BUNDLE_ID=${BUNDLE_ID:-"com.quikapp.app"}
EMAIL_ID=${EMAIL_ID:-"admin@quikapp.co"}
PUSH_NOTIFY=${PUSH_NOTIFY:-"false"}
IS_CHATBOT=${IS_CHATBOT:-"false"}
IS_DOMAIN_URL=${IS_DOMAIN_URL:-"false"}
IS_SPLASH=${IS_SPLASH:-"false"}
IS_PULLDOWN=${IS_PULLDOWN:-"false"}
IS_BOTTOMMENU=${IS_BOTTOMMENU:-"false"}
IS_LOAD_IND=${IS_LOAD_IND:-"false"}
IS_CAMERA=${IS_CAMERA:-"false"}
IS_LOCATION=${IS_LOCATION:-"false"}
IS_MIC=${IS_MIC:-"false"}
IS_NOTIFICATION=${IS_NOTIFICATION:-"false"}
IS_CONTACT=${IS_CONTACT:-"false"}
IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
IS_CALENDAR=${IS_CALENDAR:-"false"}
IS_STORAGE=${IS_STORAGE:-"false"}
LOGO_URL=${LOGO_URL:-""}
SPLASH_URL=${SPLASH_URL:-""}
SPLASH_BG=${SPLASH_BG:-""}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-"#FFFFFF"}
SPLASH_TAGLINE=${SPLASH_TAGLINE:-""}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-"#000000"}
SPLASH_ANIMATION=${SPLASH_ANIMATION:-"fade"}
SPLASH_DURATION=${SPLASH_DURATION:-"3"}
BOTTOMMENU_ITEMS=${BOTTOMMENU_ITEMS:-"[]"}
BOTTOMMENU_BG_COLOR=${BOTTOMMENU_BG_COLOR:-"#FFFFFF"}
BOTTOMMENU_ICON_COLOR=${BOTTOMMENU_ICON_COLOR:-"#000000"}
BOTTOMMENU_TEXT_COLOR=${BOTTOMMENU_TEXT_COLOR:-"#000000"}
BOTTOMMENU_FONT=${BOTTOMMENU_FONT:-"Roboto"}
BOTTOMMENU_FONT_SIZE=${BOTTOMMENU_FONT_SIZE:-"12"}
BOTTOMMENU_FONT_BOLD=${BOTTOMMENU_FONT_BOLD:-"false"}
BOTTOMMENU_FONT_ITALIC=${BOTTOMMENU_FONT_ITALIC:-"false"}
BOTTOMMENU_ACTIVE_TAB_COLOR=${BOTTOMMENU_ACTIVE_TAB_COLOR:-"#0000FF"}
BOTTOMMENU_ICON_POSITION=${BOTTOMMENU_ICON_POSITION:-"above"}
BOTTOMMENU_VISIBLE_ON=${BOTTOMMENU_VISIBLE_ON:-"all"}

# Email Configuration
export EMAIL_SMTP_SERVER="smtp.gmail.com"
export EMAIL_SMTP_PORT="587"
export EMAIL_SMTP_USER="${Notifi_E_ID:-prasannasrie@gmail.com}"
export EMAIL_SMTP_PASS="jbbf nzhm zoay lbwb"

# Automatically determine settings based on variable presence
if [ -n "${KEY_STORE:-}" ] && [ -n "${CM_KEYSTORE_PASSWORD:-}" ] && [ -n "${CM_KEY_ALIAS:-}" ] && [ -n "${CM_KEY_PASSWORD:-}" ]; then
    USE_KEYSTORE="true"
    BUILD_AAB="true"
else
    USE_KEYSTORE="false"
    BUILD_AAB="false"
fi

# Function to send email notification
send_email_notification() {
    local status
    status=$1
    local subject="[${status}] ${APP_NAME} Build Notification"
    local body="
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; }
            .content { padding: 20px; }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
            .button { display: inline-block; padding: 10px 20px; background-color: #007bff; color: white; text-decoration: none; border-radius: 5px; }
            .status-success { color: #28a745; }
            .status-failure { color: #dc3545; }
            .artifacts { margin: 20px 0; }
            .artifact-link { display: block; margin: 10px 0; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='header'>
                <h2>${APP_NAME} Build Notification</h2>
                <p>Organization: ${ORG_NAME}</p>
            </div>
            <div class='content'>
                <h3 class='status-${status}'>Build Status: ${status}</h3>
                <p>Version: ${VERSION_NAME} (${VERSION_CODE})</p>
                <p>Build Date: $(date '+%Y-%m-%d %H:%M:%S')</p>
                
                <div class='artifacts'>
                    <h4>Build Artifacts:</h4>
                    $( [ "${BUILD_AAB}" = "true" ] && echo "<a href='#' class='artifact-link'>📦 Download AAB</a>" )
                    <a href='#' class='artifact-link'>📱 Download APK</a>
                </div>
                
                <div class='actions'>
                    <a href='#' class='button'>View Build Logs</a>
                    <a href='#' class='button'>Resume Build</a>
                </div>
            </div>
            <div class='footer'>
                <p>This is an automated message from ${APP_NAME} Build System</p>
                <p>© $(date '+%Y') ${ORG_NAME}. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    "

    # Create temporary file for email content
    local email_file
    email_file=$(mktemp)
    echo "${body}" > "${email_file}"
    
    # Call Python script to send email
    python3 lib/scripts/utils/send_email_python.py \
        "${EMAIL_SMTP_SERVER}" \
        "${EMAIL_SMTP_PORT}" \
        "${EMAIL_SMTP_USER}" \
        "${EMAIL_SMTP_PASS}" \
        "${EMAIL_SMTP_USER}" \
        "${EMAIL_ID}" \
        "${subject}" \
        "${email_file}"
    
    # Clean up temporary file
    rm -f "${email_file}"
}

# Generate environment.dart
generate_environment_dart() {
    cat > lib/config/environment.dart << EOF
class Environment {
  static const String versionName = '${VERSION_NAME}';
  static const String versionCode = '${VERSION_CODE}';
  static const String appName = '${APP_NAME}';
  static const String orgName = '${ORG_NAME}';
  static const String webUrl = '${WEB_URL}';
  static const String pkgName = '${PKG_NAME}';
  static const String bundleId = '${BUNDLE_ID}';
  static const String emailId = '${EMAIL_ID}';
  static const bool pushNotify = ${PUSH_NOTIFY};
  static const bool isChatbot = ${IS_CHATBOT};
  static const bool isDomainUrl = ${IS_DOMAIN_URL};
  static const bool isSplash = ${IS_SPLASH};
  static const bool isPulldown = ${IS_PULLDOWN};
  static const bool isBottomMenu = ${IS_BOTTOMMENU};
  static const bool isLoadInd = ${IS_LOAD_IND};
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
  static const String splashDuration = '${SPLASH_DURATION}';
  static const String bottomMenuItems = '${BOTTOMMENU_ITEMS}';
  static const String bottomMenuBgColor = '${BOTTOMMENU_BG_COLOR}';
  static const String bottomMenuIconColor = '${BOTTOMMENU_ICON_COLOR}';
  static const String bottomMenuTextColor = '${BOTTOMMENU_TEXT_COLOR}';
  static const String bottomMenuFont = '${BOTTOMMENU_FONT}';
  static const String bottomMenuFontSize = '${BOTTOMMENU_FONT_SIZE}';
  static const bool bottomMenuFontBold = ${BOTTOMMENU_FONT_BOLD};
  static const bool bottomMenuFontItalic = ${BOTTOMMENU_FONT_ITALIC};
  static const String bottomMenuActiveTabColor = '${BOTTOMMENU_ACTIVE_TAB_COLOR}';
  static const String bottomMenuIconPosition = '${BOTTOMMENU_ICON_POSITION}';
  static const String bottomMenuVisibleOn = '${BOTTOMMENU_VISIBLE_ON}';
}
EOF
}

# Function to generate AndroidManifest.xml
generate_android_manifest() {
    cat > android/app/src/main/AndroidManifest.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    $( [ "${PUSH_NOTIFY}" = "true" ] && echo '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>' )
    $( [ "${PUSH_NOTIFY}" = "true" ] && echo '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>' )
    $( [ "${PUSH_NOTIFY}" = "true" ] && echo '    <uses-permission android:name="android.permission.VIBRATE"/>' )
    $( [ "${PUSH_NOTIFY}" = "true" ] && echo '    <uses-permission android:name="android.permission.WAKE_LOCK"/>' )
    $( [ "${IS_CAMERA}" = "true" ] && echo '    <uses-permission android:name="android.permission.CAMERA"/>' )
    $( [ "${IS_LOCATION}" = "true" ] && echo '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>' )
    $( [ "${IS_LOCATION}" = "true" ] && echo '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>' )
    $( [ "${IS_MIC}" = "true" ] && echo '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>' )
    $( [ "${IS_NOTIFICATION}" = "true" ] && echo '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>' )
    $( [ "${IS_CONTACT}" = "true" ] && echo '    <uses-permission android:name="android.permission.READ_CONTACTS"/>' )
    $( [ "${IS_BIOMETRIC}" = "true" ] && echo '    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>' )
    $( [ "${IS_CALENDAR}" = "true" ] && echo '    <uses-permission android:name="android.permission.READ_CALENDAR"/>' )
    $( [ "${IS_CALENDAR}" = "true" ] && echo '    <uses-permission android:name="android.permission.WRITE_CALENDAR"/>' )
    $( [ "${IS_STORAGE}" = "true" ] && echo '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>' )
    $( [ "${IS_STORAGE}" = "true" ] && echo '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>' )
    
    <application
        android:label="${APP_NAME}"
        android:name="\\${applicationName}"
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
            
            $( [ "${IS_DOMAIN_URL}" = "true" ] && echo '
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="${WEB_URL}" />
            </intent-filter>' )
            
            $( [ "${PUSH_NOTIFY}" = "true" ] && echo '
            <intent-filter>
                <action android:name="FLUTTER_NOTIFICATION_CLICK" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>' )
        </activity>
        
        $( [ "${PUSH_NOTIFY}" = "true" ] && echo '
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <receiver
            android:name="com.google.firebase.iid.FirebaseInstanceIdReceiver"
            android:exported="true"
            android:permission="com.google.android.c2dm.permission.SEND">
            <intent-filter>
                <action android:name="com.google.android.c2dm.intent.RECEIVE" />
            </intent-filter>
        </receiver>' )
        
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
$( [ "${PUSH_NOTIFY}" = "true" ] && echo "apply plugin: 'com.google.gms.google-services'" )

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
        $( [ "${USE_KEYSTORE}" = "true" ] && echo '
        release {
            storeFile file("keystore.jks")
            storePassword "${CM_KEYSTORE_PASSWORD}"
            keyAlias "${CM_KEY_ALIAS}"
            keyPassword "${CM_KEY_PASSWORD}"
        }' )
    }

    buildTypes {
        release {
            $( [ "${USE_KEYSTORE}" = "true" ] && echo 'signingConfig signingConfigs.release' )
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}

flutter {
    source '../../'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    $( [ "${PUSH_NOTIFY}" = "true" ] && echo "implementation platform('com.google.firebase:firebase-bom:32.7.0')" )
    $( [ "${PUSH_NOTIFY}" = "true" ] && echo "implementation 'com.google.firebase:firebase-messaging'" )
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
  $( [ "${PUSH_NOTIFY}" = "true" ] && echo "  firebase_core: ^2.24.2" )
  $( [ "${PUSH_NOTIFY}" = "true" ] && echo "  firebase_messaging: ^14.7.9" )
  flutter_inappwebview: ^5.8.0
  url_launcher: ^6.2.2
  package_info_plus: ^5.0.1
  shared_preferences: ^2.2.2
  flutter_local_notifications: ^16.2.0
  permission_handler: ^11.1.0
  $( [ "${IS_CAMERA}" = "true" ] && echo "  camera: ^0.10.5+9" )
  $( [ "${IS_LOCATION}" = "true" ] && echo "  geolocator: ^10.1.0" )
  $( [ "${IS_MIC}" = "true" ] && echo "  speech_to_text: ^6.5.1" )
  $( [ "${IS_CONTACT}" = "true" ] && echo "  contacts_service: ^0.6.3" )
  $( [ "${IS_BIOMETRIC}" = "true" ] && echo "  local_auth: ^2.1.8" )
  $( [ "${IS_CALENDAR}" = "true" ] && echo "  calendar_events: ^0.0.1" )
  $( [ "${IS_STORAGE}" = "true" ] && echo "  file_picker: ^6.1.1" )
  $( [ "${IS_CHATBOT}" = "true" ] && echo "  flutter_chat_ui: ^1.6.10" )
  $( [ "${IS_DOMAIN_URL}" = "true" ] && echo "  uni_links: ^0.5.1" )
  $( [ "${IS_SPLASH}" = "true" ] && echo "  flutter_native_splash: ^2.3.9" )
  $( [ "${IS_PULLDOWN}" = "true" ] && echo "  pull_to_refresh: ^2.0.0" )
  $( [ "${IS_BOTTOMMENU}" = "true" ] && echo "  flutter_svg: ^2.0.9" )
  $( [ "${IS_LOAD_IND}" = "true" ] && echo "  loading_animation_widget: ^1.2.0+4" )

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
send_email_notification "started"

echo "Configuration generated successfully!" 