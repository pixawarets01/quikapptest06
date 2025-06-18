#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"

# Set default values for required variables
export APP_NAME=${APP_NAME:-"Flutter App"}
export PKG_NAME=${PKG_NAME:-"com.example.app"}
export VERSION_NAME=${VERSION_NAME:-"1.0.0"}
export VERSION_CODE=${VERSION_CODE:-"1"}
export ORG_NAME=${ORG_NAME:-"Example Organization"}
export WEB_URL=${WEB_URL:-"https://example.com"}
export EMAIL_ID=${EMAIL_ID:-"example@example.com"}

# Feature flags
export PUSH_NOTIFY=${PUSH_NOTIFY:-"false"}
export IS_CHATBOT=${IS_CHATBOT:-"false"}
export IS_DEEPLINK=${IS_DEEPLINK:-"false"}
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
export LOGO_URL=${LOGO_URL:-""}
export SPLASH=${SPLASH:-""}
export SPLASH_BG=${SPLASH_BG:-""}
export SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-"#FFFFFF"}
export SPLASH_TAGLINE=${SPLASH_TAGLINE:-""}
export SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-"#000000"}
export SPLASH_ANIMATION=${SPLASH_ANIMATION:-"fade"}
export SPLASH_DURATION=${SPLASH_DURATION:-"3"}

# Bottom Menu
export BOTTOMMENU_ITEMS=${BOTTOMMENU_ITEMS:-"[]"}
export BOTTOMMENU_BG_COLOR=${BOTTOMMENU_BG_COLOR:-"#FFFFFF"}
export BOTTOMMENU_ICON_COLOR=${BOTTOMMENU_ICON_COLOR:-"#000000"}
export BOTTOMMENU_TEXT_COLOR=${BOTTOMMENU_TEXT_COLOR:-"#000000"}
export BOTTOMMENU_FONT=${BOTTOMMENU_FONT:-"Roboto"}
export BOTTOMMENU_FONT_SIZE=${BOTTOMMENU_FONT_SIZE:-"12"}
export BOTTOMMENU_FONT_BOLD=${BOTTOMMENU_FONT_BOLD:-"false"}
export BOTTOMMENU_FONT_ITALIC=${BOTTOMMENU_FONT_ITALIC:-"false"}
export BOTTOMMENU_ACTIVE_TAB_COLOR=${BOTTOMMENU_ACTIVE_TAB_COLOR:-"#007AFF"}
export BOTTOMMENU_ICON_POSITION=${BOTTOMMENU_ICON_POSITION:-"above"}
export BOTTOMMENU_VISIBLE_ON=${BOTTOMMENU_VISIBLE_ON:-"all"}

# Firebase
export firebase_config_android=${firebase_config_android:-""}
export firebase_config_ios=${firebase_config_ios:-""}

# iOS Signing
export APPLE_TEAM_ID=${APPLE_TEAM_ID:-""}
export APNS_KEY_ID=${APNS_KEY_ID:-""}
export APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL:-""}
export CERT_PASSWORD=${CERT_PASSWORD:-""}
export PROFILE_URL=${PROFILE_URL:-""}
export CERT_CER_URL=${CERT_CER_URL:-""}
export CERT_KEY_URL=${CERT_KEY_URL:-""}
export APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-""}

# Android Keystore
export KEY_STORE=${KEY_STORE:-""}
export CM_KEYSTORE_PASSWORD=${CM_KEYSTORE_PASSWORD:-""}
export CM_KEY_ALIAS=${CM_KEY_ALIAS:-""}
export CM_KEY_PASSWORD=${CM_KEY_PASSWORD:-""}

# SMTP Configuration
export SMTP_SERVER=${SMTP_SERVER:-"smtp.gmail.com"}
export SMTP_PORT=${SMTP_PORT:-"587"}
export SMTP_USER=${SMTP_USER:-"prasannasrie@gmail.com"}
export SMTP_PASS=${SMTP_PASS:-"jbbf nzhm zoay lbwb"}
export NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL:-"${EMAIL_ID}"}

# Build Info
export BUILD_URL=${BUILD_URL:-""}
export BUILD_NUMBER=${BUILD_NUMBER:-"0"}
export BUILD_ID=${BUILD_ID:-"0"}
export PROJECT_NAME=${PROJECT_NAME:-"${APP_NAME}"}

# Default notification email addresses
NOTIFICATION_EMAIL_TO="prasannasrinivasan32@gmail.com"
NOTIFICATION_EMAIL_FROM="noreply@quikapp.co"

# QuikApp required variables for local/dev builds

export BUNDLE_ID="com.garbcode.garbcodeapp"
export OUTPUT_DIR="output"
export IS_CHATBOT="true"
export IS_DEEPLINK="true"
export IS_SPLASH="true"
export IS_PULLDOWN="true"
export IS_BOTTOMMENU="false"
export IS_LOAD_IND="true"
export IS_CAMERA="false"
export IS_LOCATION="false"
export IS_MIC="true"
export IS_NOTIFICATION="true"
export IS_CONTACT="false"
export IS_BIOMETRIC="false"
export IS_CALENDAR="false"
export IS_STORAGE="true"
export LOGO_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"
export SPLASH="https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"
export SPLASH_BG=""
export SPLASH_BG_COLOR="#cbdbf5"
export SPLASH_TAGLINE="Welcome to Garbcode"
export SPLASH_TAGLINE_COLOR="#a30237"
export SPLASH_ANIMATION="zoom"
export SPLASH_DURATION="4"
export BOTTOMMENU_ITEMS='[{"label": "Home", "icon": "home", "url": "https://pixaware.co/"}, {"label": "services", "icon": "services", "url": "https://pixaware.co/solutions/"}, {"label": "About", "icon": "info", "url": "https://pixaware.co/who-we-are/"}, {"label": "Contact", "icon": "phone", "url": "https://pixaware.co/lets-talk/"}]'
export BOTTOMMENU_BG_COLOR="#FFFFFF"
export BOTTOMMENU_ICON_COLOR="#6d6e8c"
export BOTTOMMENU_TEXT_COLOR="#6d6e8c"
export BOTTOMMENU_FONT="DM Sans"
export BOTTOMMENU_FONT_SIZE="12"
export BOTTOMMENU_FONT_BOLD="false"
export BOTTOMMENU_FONT_ITALIC="false"
export BOTTOMMENU_ACTIVE_TAB_COLOR="#a30237"
export BOTTOMMENU_ICON_POSITION="above"
export BOTTOMMENU_VISIBLE_ON="home,settings,profile"
export firebase_config_android="https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services-gc.json"
export firebase_config_ios="https://raw.githubusercontent.com/prasanna91/QuikApp/main/GoogleService-Info-gc.plist"
export APPLE_TEAM_ID="9H2AD7NQ49"
export APNS_KEY_ID="V566SWNF69"
export APNS_AUTH_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_V566SWNF69.p8"
export CERT_PASSWORD="User@54321"
export PROFILE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/Garbcode_App_Store.mobileprovision"
export CERT_CER_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/apple_distribution.cer"
export CERT_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"
export APP_STORE_CONNECT_KEY_IDENTIFIER="F5229W2Q8S"
export CM_KEYSTORE_PASSWORD="opeN@1234"
export CM_KEY_ALIAS="my_key_alias"
export CM_KEY_PASSWORD="opeN@1234"
 