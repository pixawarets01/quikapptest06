#!/bin/bash
set -euo pipefail

STATUS=$1
MESSAGE=$2

# Email configuration with provided Gmail credentials
EMAIL_SMTP_SERVER="smtp.gmail.com"
EMAIL_SMTP_PORT="587"
EMAIL_SMTP_USER="prasannasrie@gmail.com"
EMAIL_SMTP_PASS="jbbf nzhm zoay lbwb"
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

# Determine signing status
ANDROID_SIGNING="N/A"
IOS_SIGNING="N/A"

# Check if this is an Android build
if [ -f android/app/build.gradle.kts ] || [ -f android/app/build.gradle ]; then
    ANDROID_SIGNING="Debug"
    if [ -n "$KEY_STORE_URL" ] && [ -f android/app/keystore.properties ] && [ -f android/app/keystore.jks ]; then
        ANDROID_SIGNING="Release (Production)"
    elif [ -n "$KEY_STORE_URL" ]; then
        ANDROID_SIGNING="Release (Failed)"
    fi
fi

# Check if this is an iOS build
if [ -f ios/Runner.xcodeproj/project.pbxproj ] || [ -f ios/Runner.xcworkspace/contents.xcworkspacedata ]; then
    IOS_SIGNING="Unsigned"
    if [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ] && [ -n "${PROFILE_URL:-}" ] && [ -n "${CERT_PASSWORD:-}" ]; then
        if [ -f ios/certificates/cert.p12 ] || [ -f certs/cert.p12 ]; then
            IOS_SIGNING="Signed (Production)"
        else
            IOS_SIGNING="Signed (Failed)"
        fi
    fi
fi

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

# Function to get feature status
get_feature_status() {
    local feature="$1"
    if [ "${feature:-false}" = "true" ]; then
        echo "✅ Enabled"
    else
        echo "❌ Disabled"
    fi
}

# Function to generate app details section
generate_app_details() {
    cat << EOF
<div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #2c3e50; margin-bottom: 15px;">📱 App Details</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">App Name:</td><td>${APP_NAME:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Version:</td><td>${VERSION_NAME:-N/A} (${VERSION_CODE:-N/A})</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Package Name (Android):</td><td>${PKG_NAME:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Bundle ID (iOS):</td><td>${BUNDLE_ID:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Organization:</td><td>${ORG_NAME:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Website:</td><td>${WEB_URL:-N/A}</td></tr>
    </table>
</div>
EOF
}

# Function to generate customization details
generate_customization_details() {
    cat << EOF
<div style="background: #e8f5e8; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #27ae60; margin-bottom: 15px;">🎨 Customization Features</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">Custom Logo:</td><td>$(get_feature_status "${LOGO_URL:+true}")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Splash Screen:</td><td>$(get_feature_status "$IS_SPLASH")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Pull to Refresh:</td><td>$(get_feature_status "$IS_PULLDOWN")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Loading Indicator:</td><td>$(get_feature_status "$IS_LOAD_IND")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Bottom Navigation Bar:</td><td>$(get_feature_status "$IS_BOTTOMMENU")</td></tr>
    </table>
</div>
EOF
}

# Function to generate integration details
generate_integration_details() {
    cat << EOF
<div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #1976d2; margin-bottom: 15px;">🔗 Integration Features</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">Push Notifications:</td><td>$(get_feature_status "$PUSH_NOTIFY")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Chat Bot:</td><td>$(get_feature_status "$IS_CHATBOT")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Deep Linking:</td><td>$(get_feature_status "$IS_DOMAIN_URL")</td></tr>
    </table>
</div>
EOF
}

# Function to generate permissions details
generate_permissions_details() {
    cat << EOF
<div style="background: #fff3e0; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #f57c00; margin-bottom: 15px;">🔐 Permissions</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">Notifications:</td><td>$(get_feature_status "$IS_NOTIFICATION")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Microphone:</td><td>$(get_feature_status "$IS_MIC")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Camera:</td><td>$(get_feature_status "$IS_CAMERA")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">GPS (Location):</td><td>$(get_feature_status "$IS_LOCATION")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Biometric:</td><td>$(get_feature_status "$IS_BIOMETRIC")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Contacts:</td><td>$(get_feature_status "$IS_CONTACT")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Calendar:</td><td>$(get_feature_status "$IS_CALENDAR")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Storage:</td><td>$(get_feature_status "$IS_STORAGE")</td></tr>
    </table>
</div>
EOF
}

# Function to generate QuikApp branding footer
generate_branding_footer() {
    cat << EOF
<div style="background: #263238; color: #ffffff; padding: 30px; border-radius: 8px; margin: 30px 0; text-align: center;">
    <h3 style="color: #4fc3f7; margin-bottom: 20px;">🚀 Powered by QuikApp</h3>
    <p style="margin: 10px 0; color: #b0bec5;">Build mobile apps faster with QuikApp's no-code platform</p>
    
    <div style="margin: 20px 0;">
        <a href="https://quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">🌐 Website</a>
        <a href="https://docs.quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">📚 Documentation</a>
        <a href="https://support.quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">🎧 Support</a>
        <a href="https://community.quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">👥 Community</a>
    </div>
    
    <hr style="border: none; border-top: 1px solid #37474f; margin: 20px 0;">
    
    <p style="margin: 10px 0; font-size: 12px; color: #78909c;">
        © 2024 QuikApp Technologies. All rights reserved.<br>
        This email was sent automatically by the QuikApp Build System.
    </p>
</div>
EOF
}

# Function to generate troubleshooting steps for failures
generate_troubleshooting_steps() {
    local platform="$1"
    local error_type="$2"
    
    cat << EOF
<div style="background: #ffebee; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f44336;">
    <h3 style="color: #c62828; margin-bottom: 15px;">🔧 Troubleshooting Steps</h3>
    
    <h4 style="color: #d32f2f;">Common Solutions:</h4>
    <ol style="color: #424242; line-height: 1.6;">
        <li><strong>Check Environment Variables:</strong>
            <ul>
                <li>Verify all required variables are set correctly</li>
                <li>Ensure URLs are accessible and files are downloadable</li>
                <li>Check API credentials and keys</li>
            </ul>
        </li>
        
        <li><strong>Certificate Issues (iOS):</strong>
            <ul>
                <li>Verify certificate (.cer) and private key (.key) files are valid</li>
                <li>Ensure provisioning profile (.mobileprovision) matches the app</li>
                <li>Check that CERT_PASSWORD is correct</li>
                <li>Verify APPLE_TEAM_ID matches your developer account</li>
            </ul>
        </li>
        
        <li><strong>Keystore Issues (Android):</strong>
            <ul>
                <li>Verify keystore file is accessible at KEY_STORE_URL</li>
                <li>Check CM_KEYSTORE_PASSWORD and CM_KEY_PASSWORD are correct</li>
                <li>Ensure CM_KEY_ALIAS exists in the keystore</li>
            </ul>
        </li>
        
        <li><strong>Firebase Configuration:</strong>
            <ul>
                <li>Verify google-services.json (Android) or GoogleService-Info.plist (iOS) are valid</li>
                <li>Check Firebase project settings match your app</li>
                <li>Ensure package name/bundle ID matches Firebase configuration</li>
            </ul>
        </li>
        
        <li><strong>Build Dependencies:</strong>
            <ul>
                <li>Check Flutter and Dart SDK versions</li>
                <li>Verify Gradle and Android build tools versions</li>
                <li>Clear build cache and regenerate dependencies</li>
            </ul>
        </li>
    </ol>
    
    <h4 style="color: #d32f2f;">Next Steps:</h4>
    <ul style="color: #424242; line-height: 1.6;">
        <li>📋 Check the build logs in Codemagic for detailed error messages</li>
        <li>🔄 Fix the identified issues and restart the build</li>
        <li>📞 Contact support if the issue persists</li>
    </ul>
</div>
EOF
}

# Function to send build started email
send_build_started_email() {
    local platform="$1"
    local build_id="$2"
    
    cat << EOF > /tmp/email_content.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Started</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 30px;">
        <h1 style="margin: 0; font-size: 28px;">🚀 Build Started</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Your QuikApp build process has begun</p>
    </div>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2; margin: 0;">📱 Platform: ${platform}</h3>
        <p style="margin: 10px 0 0 0; color: #424242;">Build ID: ${build_id}</p>
    </div>
    
    $(generate_app_details)
    $(generate_customization_details)
    $(generate_integration_details)
    $(generate_permissions_details)
    
    <div style="background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2;">⏱️ Build Progress</h3>
        <p>Your app is currently being built. You will receive another email when the build completes.</p>
        <p><strong>Estimated Time:</strong> 5-15 minutes</p>
    </div>
    
    $(generate_branding_footer)
    
</body>
</html>
EOF

    send_email_via_msmtp "🚀 QuikApp Build Started - ${APP_NAME:-Your App}" "/tmp/email_content.html"
}

# Function to send build success email
send_build_success_email() {
    local platform="$1"
    local build_id="$2"
    local artifacts_url="$3"
    
    cat << EOF > /tmp/email_content.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Successful</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 30px;">
        <h1 style="margin: 0; font-size: 28px;">🎉 Build Successful!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Your QuikApp has been built successfully</p>
    </div>
    
    <div style="background: #e8f5e8; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #27ae60; margin: 0;">✅ Platform: ${platform}</h3>
        <p style="margin: 10px 0 0 0; color: #424242;">Build ID: ${build_id}</p>
    </div>
    
    $(generate_app_details)
    $(generate_customization_details)
    $(generate_integration_details)
    $(generate_permissions_details)
    
    <div style="background: #e8f5e8; padding: 25px; border-radius: 8px; margin: 20px 0; text-align: center; border: 2px solid #27ae60;">
        <h3 style="color: #27ae60; margin-bottom: 20px;">📦 Download Your App</h3>
        <p style="margin-bottom: 20px;">Your app artifacts are ready for download:</p>
        <a href="${artifacts_url}" style="display: inline-block; background: #27ae60; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">📱 Download App Files</a>
        <p style="margin-top: 15px; font-size: 14px; color: #666;">Files include: APK/AAB (Android) or IPA (iOS)</p>
    </div>
    
    <div style="background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
        <h3 style="color: #856404;">📋 Next Steps</h3>
        <ul style="color: #856404; line-height: 1.8;">
            <li><strong>Android (APK):</strong> Install directly on device or distribute</li>
            <li><strong>Android (AAB):</strong> Upload to Google Play Store</li>
            <li><strong>iOS (IPA):</strong> Upload to App Store Connect or TestFlight</li>
            <li><strong>Testing:</strong> Test the app thoroughly before publishing</li>
        </ul>
    </div>
    
    $(generate_branding_footer)
    
</body>
</html>
EOF

    send_email_via_msmtp "🎉 QuikApp Build Successful - ${APP_NAME:-Your App}" "/tmp/email_content.html"
}

# Function to send build failed email
send_build_failed_email() {
    local platform="$1"
    local build_id="$2"
    local error_message="$3"
    
    cat << EOF > /tmp/email_content.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Failed</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 30px;">
        <h1 style="margin: 0; font-size: 28px;">❌ Build Failed</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">There was an issue with your QuikApp build</p>
    </div>
    
    <div style="background: #ffebee; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #c62828; margin: 0;">🔴 Platform: ${platform}</h3>
        <p style="margin: 10px 0 0 0; color: #424242;">Build ID: ${build_id}</p>
    </div>
    
    $(generate_app_details)
    
    <div style="background: #ffebee; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f44336;">
        <h3 style="color: #c62828; margin-bottom: 15px;">⚠️ Error Details</h3>
        <div style="background: #fff; padding: 15px; border-radius: 4px; border: 1px solid #e0e0e0;">
            <code style="color: #d32f2f; font-family: 'Courier New', monospace; white-space: pre-wrap;">${error_message}</code>
        </div>
    </div>
    
    $(generate_troubleshooting_steps "$platform" "build_failed")
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2;">🔄 Ready to Try Again?</h3>
        <p>After fixing the issues above, you can restart your build.</p>
        <a href="https://codemagic.io" style="display: inline-block; background: #1976d2; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">🚀 Restart Build</a>
        <a href="https://codemagic.io/builds/${build_id}" style="display: inline-block; background: #757575; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">📋 View Logs</a>
    </div>
    
    $(generate_branding_footer)
    
</body>
</html>
EOF

    send_email_via_msmtp "❌ QuikApp Build Failed - ${APP_NAME:-Your App}" "/tmp/email_content.html"
}

# Function to send email using msmtp
send_email_via_msmtp() {
    local subject="$1"
    local html_file="$2"
    
    if ! command -v msmtp &> /dev/null; then
        log "❌ msmtp not found. Installing..."
        
        # Try to install msmtp based on the system
        if command -v brew &> /dev/null; then
            brew install msmtp
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y msmtp msmtp-mta
        elif command -v yum &> /dev/null; then
            sudo yum install -y msmtp
        else
            log "❌ Cannot install msmtp. Please install it manually."
            return 1
        fi
    fi
    
    # Create msmtp configuration
    cat > ~/.msmtprc << EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account        gmail
host           $EMAIL_SMTP_SERVER
port           $EMAIL_SMTP_PORT
from           $EMAIL_SMTP_USER
user           $EMAIL_SMTP_USER
password       $EMAIL_SMTP_PASS

account default : gmail
EOF
    
    chmod 600 ~/.msmtprc
    
    # Send email
    {
        echo "To: ${EMAIL_ID:-$EMAIL_SMTP_USER}"
        echo "From: $EMAIL_SMTP_USER"
        echo "Subject: $subject"
        echo "Content-Type: text/html; charset=UTF-8"
        echo ""
        cat "$html_file"
    } | msmtp --account=gmail "${EMAIL_ID:-$EMAIL_SMTP_USER}"
    
    if [ $? -eq 0 ]; then
        log "✅ Email sent successfully to ${EMAIL_ID:-$EMAIL_SMTP_USER}"
    else
        log "❌ Failed to send email"
        return 1
    fi
    
    # Clean up
    rm -f "$html_file"
}

# Main function to handle different email types
send_notification_email() {
    local email_type="$1"
    shift
    
    case "$email_type" in
        "build_started")
            send_build_started_email "$@"
            ;;
        "build_success")
            send_build_success_email "$@"
            ;;
        "build_failed")
            send_build_failed_email "$@"
            ;;
        *)
            log "❌ Unknown email type: $email_type"
            return 1
            ;;
    esac
}

# If script is called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <email_type> [arguments...]"
        echo "Email types: build_started, build_success, build_failed"
        exit 1
    fi
    
    send_notification_email "$@"
fi 