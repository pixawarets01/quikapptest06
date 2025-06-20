#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Branding vars
APP_NAME=${APP_NAME:-"Unknown App"}
WEB_URL=${WEB_URL:-"https://example.com"}
LOGO_URL=${LOGO_URL:-}
SPLASH_URL=${SPLASH_URL:-}
SPLASH_BG_URL=${SPLASH_BG_URL:-}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-}
SPLASH_TAGLINE=${SPLASH_TAGLINE:-}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-}
SPLASH_ANIMATION=${SPLASH_ANIMATION:-}
SPLASH_DURATION=${SPLASH_DURATION:-}

log "Starting branding process for $APP_NAME"

# Ensure directories exist
mkdir -p android/app/src/main/res/mipmap
mkdir -p android/app/src/main/res/drawable
mkdir -p assets/images

# Function to download asset with validation
download_asset() {
    local url="$1"
    local output="$2"
    local name="$3"
    local fallback="$4"
    
    if [ -n "$url" ]; then
        log "Downloading $name from $url"
        if curl -L --fail --silent --show-error --output "$output" "$url"; then
            # Validate file was downloaded and has content
            if [ -f "$output" ] && [ -s "$output" ]; then
                log "✅ $name downloaded successfully"
                return 0
            else
                log "⚠️ $name download failed - file is empty or missing"
            fi
        else
            log "⚠️ Failed to download $name from $url"
        fi
    fi
    
    # Use fallback if provided
    if [ -n "$fallback" ] && [ -f "$fallback" ]; then
        log "Using fallback $name"
        cp "$fallback" "$output"
        return 0
    fi
    
    return 1
}

# Download logo
if [ -z "$LOGO_URL" ]; then
    log "LOGO_URL is empty, trying to download favicon from $WEB_URL"
    if ! download_asset "${WEB_URL}/favicon.ico" "assets/images/logo.png" "favicon" ""; then
        log "⚠️ Failed to download favicon, creating placeholder logo"
        # Create a simple placeholder logo using ImageMagick or fallback
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > assets/images/logo.png 2>/dev/null || {
            # If base64 fails, create a minimal PNG
            printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc```\x00\x00\x00\x04\x00\x01\xf5\xd7\xd4\xc2\x00\x00\x00\x00IEND\xaeB`\x82' > assets/images/logo.png
        }
    fi
else
    if ! download_asset "$LOGO_URL" "assets/images/logo.png" "logo" ""; then
        log "⚠️ Failed to download logo, creating placeholder"
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > assets/images/logo.png 2>/dev/null || {
            printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc```\x00\x00\x00\x04\x00\x01\xf5\xd7\xd4\xc2\x00\x00\x00\x00IEND\xaeB`\x82' > assets/images/logo.png
        }
    fi
fi

# Copy logo to Android mipmap
if [ -f "assets/images/logo.png" ]; then
    cp assets/images/logo.png android/app/src/main/res/mipmap/ic_launcher.png
    log "✅ Logo copied to Android mipmap"
fi

# Download splash image
if [ -n "$SPLASH_URL" ]; then
    if ! download_asset "$SPLASH_URL" "assets/images/splash.png" "splash image" "assets/images/logo.png"; then
        log "⚠️ Failed to download splash image, using logo as splash"
        cp assets/images/logo.png assets/images/splash.png
    fi
else
    log "SPLASH_URL is empty, using logo as splash image"
    cp assets/images/logo.png assets/images/splash.png
fi

# Copy splash to Android drawable
if [ -f "assets/images/splash.png" ]; then
    cp assets/images/splash.png android/app/src/main/res/drawable/splash.png
    log "✅ Splash image copied to Android drawable"
fi

# Download splash background (optional)
if [ -n "$SPLASH_BG_URL" ]; then
    if download_asset "$SPLASH_BG_URL" "assets/images/splash_bg.png" "splash background" ""; then
        cp assets/images/splash_bg.png android/app/src/main/res/drawable/splash_bg.png
        log "✅ Splash background copied to Android drawable"
    else
        log "⚠️ Failed to download splash background, skipping"
    fi
else
    log "SPLASH_BG_URL is empty, skipping splash background"
fi

# Verify all required assets exist
log "Verifying required assets..."
required_assets=("assets/images/logo.png" "assets/images/splash.png")
for asset in "${required_assets[@]}"; do
    if [ -f "$asset" ] && [ -s "$asset" ]; then
        log "✅ $asset exists and has content"
    else
        log "❌ $asset is missing or empty"
        exit 1
    fi
done

log "Branding process completed successfully"
exit 0 