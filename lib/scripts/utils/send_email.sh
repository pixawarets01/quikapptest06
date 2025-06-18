#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
EMAIL_SMTP_SERVER=${EMAIL_SMTP_SERVER}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT}
EMAIL_SMTP_USER=${EMAIL_SMTP_USER}
EMAIL_SMTP_PASS=${EMAIL_SMTP_PASS}
EMAIL_ID=${EMAIL_ID}
APP_NAME=${APP_NAME}
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

# Validate required email configuration
if [ -z "$EMAIL_SMTP_SERVER" ] || [ -z "$EMAIL_SMTP_PORT" ] || [ -z "$EMAIL_SMTP_USER" ] || [ -z "$EMAIL_SMTP_PASS" ] || [ -z "$EMAIL_ID" ]; then
    log "WARNING: Email configuration is incomplete. Skipping email notification."
    exit 0
fi

# Parse arguments
BUILD_STATUS=$1
MESSAGE=$2

# Set email subject and body based on build status
case $BUILD_STATUS in
    "started")
        SUBJECT="Build Started: $APP_NAME v$VERSION_NAME"
        BODY="Build process has started for $APP_NAME (v$VERSION_NAME, build $VERSION_CODE)."
        ;;
    "success")
        SUBJECT="Build Success: $APP_NAME v$VERSION_NAME"
        BODY="Build completed successfully for $APP_NAME (v$VERSION_NAME, build $VERSION_CODE)."
        ;;
    "failure")
        SUBJECT="Build Failed: $APP_NAME v$VERSION_NAME"
        BODY="Build failed for $APP_NAME (v$VERSION_NAME, build $VERSION_CODE). Error: $MESSAGE"
        ;;
    *)
        handle_error "Invalid build status: $BUILD_STATUS"
        ;;
esac

# Send email using curl
log "Sending $BUILD_STATUS notification email..."
curl --url "smtp://$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" \
     --mail-from "$EMAIL_SMTP_USER" \
     --mail-rcpt "$EMAIL_ID" \
     --ssl-reqd \
     --user "$EMAIL_SMTP_USER:$EMAIL_SMTP_PASS" \
     --upload-file - <<EOF
From: $EMAIL_SMTP_USER
To: $EMAIL_ID
Subject: $SUBJECT
Content-Type: text/html; charset=UTF-8

<html>
<body>
    <h2>$SUBJECT</h2>
    <p>$BODY</p>
    <p>Build Details:</p>
    <ul>
        <li>App: $APP_NAME</li>
        <li>Version: $VERSION_NAME ($VERSION_CODE)</li>
        <li>Status: $BUILD_STATUS</li>
    </ul>
</body>
</html>
EOF

log "Email notification sent successfully"
exit 0 