#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
APP_NAME=${APP_NAME}
LOGO_URL=${LOGO_URL}
SPLASH_URL=${SPLASH_URL}
SPLASH_BG_URL=${SPLASH_BG_URL}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR}
SPLASH_TAGLINE=${SPLASH_TAGLINE}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR}
SPLASH_ANIMATION=${SPLASH_ANIMATION}
SPLASH_DURATION=${SPLASH_DURATION}

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

# Start branding process
log "Starting branding process for $APP_NAME"

# Create necessary directories
mkdir -p android/app/src/main/res/mipmap-hdpi
mkdir -p android/app/src/main/res/mipmap-mdpi
mkdir -p android/app/src/main/res/mipmap-xhdpi
mkdir -p android/app/src/main/res/mipmap-xxhdpi
mkdir -p android/app/src/main/res/mipmap-xxxhdpi
mkdir -p android/app/src/main/res/drawable

# Download and process app icon
if [ -n "$LOGO_URL" ]; then
    log "Downloading app icon from $LOGO_URL"
    curl -L "$LOGO_URL" -o temp_icon.png || handle_error "Failed to download app icon"

    # Convert icon to different sizes
    convert temp_icon.png -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
    convert temp_icon.png -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
    convert temp_icon.png -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
    convert temp_icon.png -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
    convert temp_icon.png -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

    rm temp_icon.png
    log "App icon processed successfully"
fi

# Handle splash screen if enabled
if [ "$IS_SPLASH" = "true" ]; then
    log "Setting up splash screen"
    
    # Download splash image
    if [ -n "$SPLASH_URL" ]; then
        log "Downloading splash image from $SPLASH_URL"
        curl -L "$SPLASH_URL" -o android/app/src/main/res/drawable/splash.png || handle_error "Failed to download splash image"
    fi

    # Download splash background if provided
    if [ -n "$SPLASH_BG_URL" ]; then
        log "Downloading splash background from $SPLASH_BG_URL"
        curl -L "$SPLASH_BG_URL" -o android/app/src/main/res/drawable/splash_bg.png || handle_error "Failed to download splash background"
    fi

    # Create splash screen drawable XML
    cat > android/app/src/main/res/drawable/splash.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_bg_color"/>
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash"/>
    </item>
</layer-list>
EOF

    # Create colors.xml for splash background color
    mkdir -p android/app/src/main/res/values
    cat > android/app/src/main/res/values/colors.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_bg_color">$SPLASH_BG_COLOR</color>
</resources>
EOF
fi

# Update AndroidManifest.xml with app name
sed -i '' "s/android:label=\".*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml

log "Branding process completed successfully"
exit 0 