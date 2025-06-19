#!/bin/bash
set -euo pipefail

STATUS=$1
MESSAGE=$2

# Email configuration
EMAIL_SMTP_SERVER=${EMAIL_SMTP_SERVER:-}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT:-}
EMAIL_SMTP_USER=${EMAIL_SMTP_USER:-}
EMAIL_SMTP_PASS=${EMAIL_SMTP_PASS:-}
EMAIL_ID=${EMAIL_ID:-}
ENABLE_EMAIL_NOTIFICATIONS=${ENABLE_EMAIL_NOTIFICATIONS:-"false"}

# App Information
APP_NAME=${APP_NAME:-"Unknown App"}
ORG_NAME=${ORG_NAME:-"Unknown Organization"}
VERSION_NAME=${VERSION_NAME:-"1.0.0"}
VERSION_CODE=${VERSION_CODE:-"1"}
PKG_NAME=${PKG_NAME:-}
BUNDLE_ID=${BUNDLE_ID:-}
USER_NAME=${USER_NAME:-"Unknown User"}

# Feature Flags
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

# Build info
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
CM_BUILD_ID=${CM_BUILD_ID:-"Unknown"}
CM_PROJECT_ID=${CM_PROJECT_ID:-"Unknown"}

# Signing information
KEY_STORE_URL=${KEY_STORE_URL:-}
FIREBASE_CONFIG_ANDROID=${FIREBASE_CONFIG_ANDROID:-}
FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS:-}

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Function to convert status to uppercase (compatible with all shells)
get_status_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Function to get status badge color
get_status_color() {
    case "$1" in
        "success") echo "#28a745" ;;
        "failure") echo "#dc3545" ;;
        *) echo "#6c757d" ;;
    esac
}

# Function to get feature status badge
get_feature_badge() {
    local feature_value=$1
    if [ "$feature_value" = "true" ]; then
        echo '<span style="background-color: #28a745; color: white; padding: 2px 8px; border-radius: 12px; font-size: 12px;">Enabled</span>'
    else
        echo '<span style="background-color: #6c757d; color: white; padding: 2px 8px; border-radius: 12px; font-size: 12px;">Disabled</span>'
    fi
}

# Function to generate artifact URLs (adjust based on your Codemagic setup)
get_artifact_urls() {
    local status=$1
    if [ "$status" = "success" ]; then
        cat << EOF
        <div style="margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-radius: 8px;">
            <h3 style="margin: 0 0 10px 0; color: #28a745;">📦 Build Artifacts</h3>
            <p style="margin: 5px 0;"><strong>APK:</strong> <a href="https://api.codemagic.io/artifacts/${CM_PROJECT_ID}/${CM_BUILD_ID}/app-release.apk" style="color: #007bff;">Download APK</a></p>
EOF
        if [ -n "$KEY_STORE_URL" ]; then
            echo '            <p style="margin: 5px 0;"><strong>AAB:</strong> <a href="https://api.codemagic.io/artifacts/'${CM_PROJECT_ID}'/'${CM_BUILD_ID}'/app-release.aab" style="color: #007bff;">Download AAB</a></p>'
        fi
        echo '        </div>'
    fi
}

# Create HTML email content
create_email_content() {
    local status=$1
    local message=$2
    local status_color=$(get_status_color "$status")
    local status_icon
    
    case "$status" in
        "success") status_icon="✅" ;;
        "failure") status_icon="❌" ;;
        *) status_icon="ℹ️" ;;
    esac

    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Notification</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; border-radius: 10px 10px 0 0; text-align: center;">
        <h1 style="color: white; margin: 0; font-size: 24px;">🚀 QuikApp Build Notification</h1>
    </div>
    
    <!-- Status Banner -->
    <div style="background-color: ${status_color}; color: white; padding: 15px; text-align: center; font-size: 18px; font-weight: bold;">
        ${status_icon} Build Status: $(get_status_upper "$status")
    </div>
    
    <!-- App Information -->
    <div style="background-color: #f8f9fa; padding: 20px; border-left: 4px solid #007bff;">
        <h2 style="margin: 0 0 15px 0; color: #007bff;">📱 App Information</h2>
        <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 5px 0; font-weight: bold;">App Name:</td><td style="padding: 5px 0;">${APP_NAME}</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Organization:</td><td style="padding: 5px 0;">${ORG_NAME}</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Version:</td><td style="padding: 5px 0;">${VERSION_NAME} (${VERSION_CODE})</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Package Name:</td><td style="padding: 5px 0;">${PKG_NAME}</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Bundle ID:</td><td style="padding: 5px 0;">${BUNDLE_ID}</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Built by:</td><td style="padding: 5px 0;">${USER_NAME}</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Build Date:</td><td style="padding: 5px 0;">${BUILD_DATE}</td></tr>
            <tr><td style="padding: 5px 0; font-weight: bold;">Build ID:</td><td style="padding: 5px 0;">${CM_BUILD_ID}</td></tr>
        </table>
    </div>
    
    <!-- Signing Information -->
    <div style="background-color: #fff3cd; padding: 20px; border-left: 4px solid #ffc107;">
        <h2 style="margin: 0 0 15px 0; color: #856404;">🔐 Signing Configuration</h2>
        <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 8px 0; font-weight: bold; color: #856404;">Android Signing:</td><td style="padding: 8px 0;">${ANDROID_SIGNING}</td></tr>
            <tr><td style="padding: 8px 0; font-weight: bold; color: #856404;">Keystore Configured:</td><td style="padding: 8px 0;">${KEY_STORE_URL:+Yes}</td></tr>
            <tr><td style="padding: 8px 0; font-weight: bold; color: #856404;">Firebase Android:</td><td style="padding: 8px 0;">${FIREBASE_CONFIG_ANDROID:+Configured}</td></tr>
            <tr><td style="padding: 8px 0; font-weight: bold; color: #856404;">Firebase iOS:</td><td style="padding: 8px 0;">${FIREBASE_CONFIG_IOS:+Configured}</td></tr>
        </table>
        
        $(if [ "$ANDROID_SIGNING" = "Debug" ] && [ -n "$KEY_STORE_URL" ]; then
            echo "<div style='background-color: #f8d7da; color: #721c24; padding: 15px; border-radius: 5px; margin-top: 15px;'>
                <strong>⚠️ Warning:</strong> Keystore was provided but Android signing is still in Debug mode. This usually indicates a keystore configuration issue. Debug-signed APKs cannot be uploaded to Google Play Store.
            </div>"
        elif [ "$ANDROID_SIGNING" = "Debug" ]; then
            echo "<div style='background-color: #d1ecf1; color: #0c5460; padding: 15px; border-radius: 5px; margin-top: 15px;'>
                <strong>ℹ️ Info:</strong> Using debug signing as no keystore was provided. Debug-signed APKs are for testing only and cannot be uploaded to Google Play Store.
            </div>"
        fi)
    </div>
    
    <!-- Feature Status -->
    <div style="background-color: white; padding: 20px; border: 1px solid #dee2e6;">
        <h2 style="margin: 0 0 15px 0; color: #6f42c1;">⚙️ Feature Configuration</h2>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Push Notifications:</strong></span>
                $(get_feature_badge "$PUSH_NOTIFY")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Chatbot:</strong></span>
                $(get_feature_badge "$IS_CHATBOT")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Domain URL:</strong></span>
                $(get_feature_badge "$IS_DOMAIN_URL")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Splash Screen:</strong></span>
                $(get_feature_badge "$IS_SPLASH")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Pull to Refresh:</strong></span>
                $(get_feature_badge "$IS_PULLDOWN")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Bottom Menu:</strong></span>
                $(get_feature_badge "$IS_BOTTOMMENU")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Load Indicator:</strong></span>
                $(get_feature_badge "$IS_LOAD_IND")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Camera:</strong></span>
                $(get_feature_badge "$IS_CAMERA")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Location:</strong></span>
                $(get_feature_badge "$IS_LOCATION")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Microphone:</strong></span>
                $(get_feature_badge "$IS_MIC")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Notifications:</strong></span>
                $(get_feature_badge "$IS_NOTIFICATION")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Contacts:</strong></span>
                $(get_feature_badge "$IS_CONTACT")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Biometric:</strong></span>
                $(get_feature_badge "$IS_BIOMETRIC")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Calendar:</strong></span>
                $(get_feature_badge "$IS_CALENDAR")
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; background-color: #f8f9fa; border-radius: 4px;">
                <span><strong>Storage:</strong></span>
                $(get_feature_badge "$IS_STORAGE")
            </div>
        </div>
    </div>
    
    <!-- Build Message -->
    <div style="background-color: #e9ecef; padding: 20px; border: 1px solid #dee2e6;">
        <h3 style="margin: 0 0 10px 0; color: #495057;">📝 Build Details</h3>
        <p style="margin: 0; font-family: monospace; background-color: white; padding: 10px; border-radius: 4px;">${message}</p>
    </div>
    
    $(get_artifact_urls "$status")
    
    <!-- Action Buttons -->
    <div style="background-color: #f8f9fa; padding: 20px; text-align: center; border-radius: 0 0 10px 10px;">
        <a href="https://codemagic.io/app/${CM_PROJECT_ID}/build/${CM_BUILD_ID}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin: 0 5px; display: inline-block;">View Build Logs</a>
        <a href="https://codemagic.io/app/${CM_PROJECT_ID}" style="background-color: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin: 0 5px; display: inline-block;">View Project</a>
    </div>
    
    <!-- Footer -->
    <div style="text-align: center; padding: 15px; color: #6c757d; font-size: 12px;">
        <p style="margin: 0;">Generated by QuikApp Build System</p>
        <p style="margin: 5px 0 0 0;">© 2025 QuikApp. All rights reserved.</p>
    </div>
    
</body>
</html>
EOF
}

# Check if email notifications are enabled
if [ "$ENABLE_EMAIL_NOTIFICATIONS" != "true" ]; then
    log "Email notifications are disabled. Status: $STATUS - $MESSAGE"
    exit 0
fi

# Check if required email configuration is available
if [ -z "$EMAIL_SMTP_SERVER" ] || [ -z "$EMAIL_SMTP_PORT" ] || [ -z "$EMAIL_SMTP_USER" ] || [ -z "$EMAIL_SMTP_PASS" ] || [ -z "$EMAIL_ID" ]; then
    log "Email configuration incomplete. Status: $STATUS - $MESSAGE"
    exit 0
fi

SUBJECT="[QuikApp Build] $APP_NAME - $(get_status_upper "$STATUS")"
TO="$EMAIL_ID"

# Try using curl for email sending (more reliable than msmtp)
send_email_curl() {
    local html_content=$(create_email_content "$STATUS" "$MESSAGE")
    local temp_file=$(mktemp)
    
    cat > "$temp_file" << EOF
To: $TO
From: $EMAIL_SMTP_USER
Subject: $SUBJECT
Content-Type: text/html; charset=UTF-8

$html_content
EOF

    if command -v curl >/dev/null 2>&1; then
        curl --url "smtps://$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" \
             --ssl-reqd \
             --mail-from "$EMAIL_SMTP_USER" \
             --mail-rcpt "$TO" \
             --upload-file "$temp_file" \
             --user "$EMAIL_SMTP_USER:$EMAIL_SMTP_PASS" \
             --silent
        local exit_code=$?
        rm -f "$temp_file"
        return $exit_code
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Try using msmtp as fallback
send_email_msmtp() {
    local html_content=$(create_email_content "$STATUS" "$MESSAGE")

if command -v msmtp >/dev/null 2>&1; then
        echo -e "Content-Type: text/html; charset=UTF-8\nSubject: $SUBJECT\nTo: $TO\n\n$html_content" | \
        msmtp --host="$EMAIL_SMTP_SERVER" \
              --port="$EMAIL_SMTP_PORT" \
              --auth=on \
              --user="$EMAIL_SMTP_USER" \
              --passwordeval="echo $EMAIL_SMTP_PASS" \
              --from="$EMAIL_SMTP_USER" \
              --tls=on \
              "$TO"
        return $?
    else
        return 1
    fi
}

# Attempt to send email
log "Attempting to send email notification to $TO"

if send_email_curl; then
    log "✅ Email notification sent successfully via curl"
elif send_email_msmtp; then
    log "✅ Email notification sent successfully via msmtp"
else
    log "❌ Failed to send email notification. Both curl and msmtp failed."
    log "Email would have been sent to: $TO"
    log "Subject: $SUBJECT"
    log "Status: $STATUS - $MESSAGE"
fi

exit 0 