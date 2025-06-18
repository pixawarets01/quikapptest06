#!/bin/bash
set -e
set -x  # Enable verbose output

# Source admin_config.env to load all required variables
source "$(dirname "$0")/../config/admin_config.env"

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
# App Metadata
APP_ID=${APP_ID}
VERSION_NAME=${VERSION_NAME}
VERSION_CODE=${VERSION_CODE}
APP_NAME=${APP_NAME}
ORG_NAME=${ORG_NAME}
WEB_URL=${WEB_URL}
PKG_NAME=${PKG_NAME}
EMAIL_ID=${EMAIL_ID}
USER_NAME=${USER_NAME}

# Feature Flags
PUSH_NOTIFY=${PUSH_NOTIFY}
IS_CHATBOT=${IS_CHATBOT}
IS_DOMAIN_URL=${IS_DOMAIN_URL}
IS_SPLASH=${IS_SPLASH}
IS_PULLDOWN=${IS_PULLDOWN}
IS_BOTTOMMENU=${IS_BOTTOMMENU}
IS_LOAD_IND=${IS_LOAD_IND}
IS_CAMERA=${IS_CAMERA}
IS_LOCATION=${IS_LOCATION}
IS_MIC=${IS_MIC}
IS_NOTIFICATION=${IS_NOTIFICATION}
IS_CONTACT=${IS_CONTACT}
IS_BIOMETRIC=${IS_BIOMETRIC}
IS_CALENDAR=${IS_CALENDAR}
IS_STORAGE=${IS_STORAGE}

# Branding
LOGO_URL=${LOGO_URL}
SPLASH_URL=${SPLASH_URL}
SPLASH_BG_URL=${SPLASH_BG}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR}
SPLASH_TAGLINE=${SPLASH_TAGLINE}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR}
SPLASH_ANIMATION=${SPLASH_ANIMATION}
SPLASH_DURATION=${SPLASH_DURATION}

# Bottom Menu (if enabled)
if [ "$IS_BOTTOMMENU" = "true" ]; then
    BOTTOMMENU_ITEMS=${BOTTOMMENU_ITEMS}
    BOTTOMMENU_BG_COLOR=${BOTTOMMENU_BG_COLOR}
    BOTTOMMENU_ICON_COLOR=${BOTTOMMENU_ICON_COLOR}
    BOTTOMMENU_TEXT_COLOR=${BOTTOMMENU_TEXT_COLOR}
    BOTTOMMENU_FONT=${BOTTOMMENU_FONT}
    BOTTOMMENU_FONT_SIZE=${BOTTOMMENU_FONT_SIZE}
    BOTTOMMENU_FONT_BOLD=${BOTTOMMENU_FONT_BOLD}
    BOTTOMMENU_FONT_ITALIC=${BOTTOMMENU_FONT_ITALIC}
    BOTTOMMENU_ACTIVE_TAB_COLOR=${BOTTOMMENU_ACTIVE_TAB_COLOR}
    BOTTOMMENU_ICON_POSITION=${BOTTOMMENU_ICON_POSITION}
    BOTTOMMENU_VISIBLE_ON=${BOTTOMMENU_VISIBLE_ON}
fi

# Firebase Configuration
FIREBASE_CONFIG_ANDROID=${FIREBASE_CONFIG_ANDROID}

# Android Credentials
KEY_STORE_URL=${KEY_STORE}
CM_KEYSTORE_PASSWORD=${CM_KEYSTORE_PASSWORD}
CM_KEY_ALIAS=${CM_KEY_ALIAS}
CM_KEY_PASSWORD=${CM_KEY_PASSWORD}

# Email Configuration
EMAIL_SMTP_SERVER=${EMAIL_SMTP_SERVER}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT}
EMAIL_SMTP_USER=${EMAIL_SMTP_USER}
EMAIL_SMTP_PASS=${EMAIL_SMTP_PASS}

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    ./lib/scripts/utils/send_email.sh "failure" "Build failed: $1"
    exit 1
}

# Set up error handling
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Start build process
log "Starting Android build workflow"
log "App: $APP_NAME ($PKG_NAME)"
log "Version: $VERSION_NAME ($VERSION_CODE)"

# Validate required variables
if [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ] || [ -z "$APP_NAME" ] || [ -z "$PKG_NAME" ]; then
    handle_error "Required variables are missing"
fi

# Create output directory
mkdir -p build/app/outputs/flutter-apk
mkdir -p build/app/outputs/bundle/release

# Run sub-scripts
log "Running branding script..."
./lib/scripts/android/branding.sh || handle_error "Branding script failed"

if [ "$PUSH_NOTIFY" = "true" ]; then
    log "Running Firebase script..."
    ./lib/scripts/android/firebase.sh || handle_error "Firebase script failed"
fi

if [ -n "$KEY_STORE_URL" ]; then
    log "Running keystore script..."
    ./lib/scripts/android/keystore.sh || handle_error "Keystore script failed"
fi

# Ensure repositories are defined in settings.gradle.kts
if ! grep -q "dependencyResolutionManagement" android/settings.gradle.kts; then
    echo "dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral(); } }" >> android/settings.gradle.kts
fi

# Build APK
log "Building APK..."
flutter build apk --release || handle_error "APK build failed"

# Build AAB if keystore is provided
if [ -n "$KEY_STORE_URL" ]; then
    log "Building AAB..."
    flutter build appbundle --release || handle_error "AAB build failed"
fi

# Copy artifacts
log "Copying artifacts..."
cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/
if [ -n "$KEY_STORE_URL" ]; then
    cp build/app/outputs/bundle/release/app-release.aab build/app/outputs/bundle/release/
fi

# Send success email
./lib/scripts/utils/send_email.sh "success" "Build completed successfully"

log "Build completed successfully"
exit 0 