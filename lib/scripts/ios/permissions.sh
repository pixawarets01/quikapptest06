#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
IS_CAMERA=${IS_CAMERA}
IS_LOCATION=${IS_LOCATION}
IS_MIC=${IS_MIC}
IS_NOTIFICATION=${IS_NOTIFICATION}
IS_CONTACT=${IS_CONTACT}
IS_BIOMETRIC=${IS_BIOMETRIC}
IS_CALENDAR=${IS_CALENDAR}
IS_STORAGE=${IS_STORAGE}
APP_NAME=${APP_NAME}

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

# Start permissions setup
log "Starting iOS permissions configuration"

# Create Info.plist if it doesn't exist
if [ ! -f ios/QuikApp/Info.plist ]; then
    log "Creating Info.plist"
    cat > ios/QuikApp/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>\$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>\$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>\$(FLUTTER_BUILD_NUMBER)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIMainStoryboardFile</key>
    <string>Main</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
</dict>
</plist>
EOF
fi

# Add permissions based on feature flags
log "Adding permissions to Info.plist"

# Camera permission
if [ "$IS_CAMERA" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'This app needs access to camera to take photos and videos.'" ios/QuikApp/Info.plist || true
fi

# Location permission
if [ "$IS_LOCATION" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSLocationWhenInUseUsageDescription string 'This app needs access to location when open to show your current location.'" ios/QuikApp/Info.plist || true
    /usr/libexec/PlistBuddy -c "Add :NSLocationAlwaysUsageDescription string 'This app needs access to location when in the background to show your current location.'" ios/QuikApp/Info.plist || true
fi

# Microphone permission
if [ "$IS_MIC" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'This app needs access to microphone to record audio.'" ios/QuikApp/Info.plist || true
fi

# Notification permission
if [ "$IS_NOTIFICATION" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSUserNotificationUsageDescription string 'This app needs access to notifications to send you updates.'" ios/QuikApp/Info.plist || true
fi

# Contacts permission
if [ "$IS_CONTACT" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSContactsUsageDescription string 'This app needs access to contacts to show your contacts list.'" ios/QuikApp/Info.plist || true
fi

# Biometric permission
if [ "$IS_BIOMETRIC" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSFaceIDUsageDescription string 'This app needs access to Face ID to authenticate you.'" ios/QuikApp/Info.plist || true
fi

# Calendar permission
if [ "$IS_CALENDAR" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSCalendarsUsageDescription string 'This app needs access to calendar to show your events.'" ios/QuikApp/Info.plist || true
fi

# Storage permission
if [ "$IS_STORAGE" = "true" ]; then
    /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'This app needs access to photo library to save and load images.'" ios/QuikApp/Info.plist || true
fi

log "Permissions configuration completed successfully"
exit 0 