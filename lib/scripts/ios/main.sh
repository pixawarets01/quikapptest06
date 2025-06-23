#!/bin/bash
set -euo pipefail

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Error handling
trap 'handle_error $LINENO $?' ERR
handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit $exit_code
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "iOS" "${CM_BUILD_ID:-unknown}" || true
fi

log "🚀 Starting iOS Universal IPA Build Process..."

# 🔧 Initial Setup
log "🔧 Initial Setup - Installing CocoaPods..."

# Check if CocoaPods is already installed
if command -v pod >/dev/null 2>&1; then
    log "✅ CocoaPods is already installed"
else
    log "📦 Installing CocoaPods..."
    
    # Try different installation methods
    if command -v brew >/dev/null 2>&1; then
        log "🍺 Installing CocoaPods via Homebrew..."
        brew install cocoapods
    elif command -v gem >/dev/null 2>&1; then
        log "💎 Installing CocoaPods via gem (user installation)..."
        gem install --user-install cocoapods
        # Add user gem bin to PATH
        export PATH="$HOME/.gem/ruby/$(ruby -e 'puts RUBY_VERSION')/bin:$PATH"
    else
        log "❌ No suitable package manager found for CocoaPods installation"
        exit 1
    fi
    
    # Verify installation
    if command -v pod >/dev/null 2>&1; then
        log "✅ CocoaPods installed successfully"
    else
        log "❌ CocoaPods installation failed"
        exit 1
    fi
fi

log "📦 Installing Flutter Dependencies..."
flutter pub get

# 🎯 CRITICAL: Generate Environment Configuration FIRST
log "🎯 Generating Environment Configuration from API Variables..."
if [ -f "lib/scripts/utils/gen_env_config.sh" ]; then
    chmod +x lib/scripts/utils/gen_env_config.sh
    source lib/scripts/utils/gen_env_config.sh
    if generate_env_config; then
        log "✅ Environment configuration generated successfully"
        
        # Show generated config summary
        log "📋 Generated Config Summary:"
        log "   App: ${APP_NAME:-QuikApp} v${VERSION_NAME:-1.0.0}"
        log "   Workflow: ${WORKFLOW_ID:-unknown}"
        log "   Bundle ID: ${BUNDLE_ID:-not_set}"
        log "   Firebase: ${PUSH_NOTIFY:-false}"
        log "   iOS Signing: ${CERT_PASSWORD:+true}"
        log "   Profile Type: ${PROFILE_TYPE:-app-store}"
    else
        log "❌ Failed to generate environment configuration"
        exit 1
    fi
else
    log "❌ Environment configuration generator not found"
    exit 1
fi

# Create necessary directories
mkdir -p ios/certificates
mkdir -p output/ios
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles

# 📥 Download Required Configuration Files
log "📥 Downloading Required Configuration Files..."

# 🔥 Firebase Configuration (Conditional based on PUSH_NOTIFY)
log "🔥 Configuring Firebase (PUSH_NOTIFY: ${PUSH_NOTIFY:-false})..."
if [ -f "lib/scripts/ios/firebase.sh" ]; then
    chmod +x lib/scripts/ios/firebase.sh
    if ./lib/scripts/ios/firebase.sh; then
        if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
            log "✅ Firebase configured successfully for push notifications"
        else
            log "✅ Firebase setup skipped (push notifications disabled)"
        fi
    else
        log "❌ Firebase configuration failed"
        exit 1
    fi
else
    log "❌ Firebase script not found"
    exit 1
fi

# APNS Key
if [ -n "${APNS_AUTH_KEY_URL:-}" ]; then
    log "🔑 Downloading APNS Key..."
    if curl -L --fail --silent --show-error --output "ios/certificates/AuthKey.p8" "$APNS_AUTH_KEY_URL"; then
        log "✅ APNS key downloaded successfully"
    else
        log "❌ Failed to download APNS key"
        exit 1
    fi
else
    log "⚠️ No APNS key URL provided"
fi

# Provisioning Profile
if [ -n "${PROFILE_URL:-}" ]; then
    log "📱 Downloading Provisioning Profile..."
    if curl -L --fail --silent --show-error --output "ios/certificates/profile.mobileprovision" "$PROFILE_URL"; then
        log "✅ Provisioning profile downloaded successfully"
        # Install provisioning profile
        cp ios/certificates/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
        log "✅ Provisioning profile installed"
    else
        log "❌ Failed to download provisioning profile"
        exit 1
    fi
else
    log "❌ No provisioning profile URL provided"
    exit 1
fi

# Certificates
if [ -n "${CERT_P12_URL:-}" ]; then
    log "🔐 Downloading P12 Certificate from URL..."
    log "🔍 P12 URL: $CERT_P12_URL"
    log "🔍 Using CERT_PASSWORD for P12 access"
    
    if curl -L --fail --silent --show-error --output "ios/certificates/cert.p12" "$CERT_P12_URL"; then
        log "✅ P12 certificate downloaded successfully"
        
        # Verify the downloaded P12 file
        log "🔍 Verifying downloaded P12 file..."
        if [ -s "ios/certificates/cert.p12" ]; then
            log "✅ P12 file is not empty"
            
            # Test P12 password
            if openssl pkcs12 -in ios/certificates/cert.p12 -noout -passin "pass:$CERT_PASSWORD" 2>/dev/null; then
                log "✅ P12 password verification successful"
            else
                log "❌ P12 password verification failed - CERT_PASSWORD may be incorrect"
                log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
                exit 1
            fi
        else
            log "❌ Downloaded P12 file is empty"
            exit 1
        fi
    else
        log "❌ Failed to download P12 certificate"
        exit 1
    fi
else
    log "🔐 CERT_P12_URL not provided, generating P12 from CER/KEY files..."
    
    # Download CER and KEY files
    if [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ]; then
        log "🔐 Downloading Certificate and Key..."
        log "🔍 CER URL: $CERT_CER_URL"
        log "🔍 KEY URL: $CERT_KEY_URL"
        log "🔍 Using CERT_PASSWORD for P12 generation"
        
        if curl -L --fail --silent --show-error --output "ios/certificates/cert.cer" "$CERT_CER_URL"; then
            log "✅ Certificate downloaded successfully"
        else
            log "❌ Failed to download certificate"
            exit 1
        fi
        
        if curl -L --fail --silent --show-error --output "ios/certificates/cert.key" "$CERT_KEY_URL"; then
            log "✅ Private key downloaded successfully"
        else
            log "❌ Failed to download private key"
            exit 1
        fi
        
        # Verify downloaded files
        log "🔍 Verifying downloaded certificate files..."
        if [ -s "ios/certificates/cert.cer" ] && [ -s "ios/certificates/cert.key" ]; then
            log "✅ Certificate files are not empty"
        else
            log "❌ Certificate files are empty"
            exit 1
        fi
        
        # Convert CER to PEM
        log "🔄 Converting certificate to PEM format..."
        if openssl x509 -in ios/certificates/cert.cer -inform DER -out ios/certificates/cert.pem -outform PEM; then
            log "✅ Certificate converted to PEM"
        else
            log "❌ Failed to convert certificate to PEM"
            exit 1
        fi
        
        # Generate P12 with compatible password handling
        # Try with CERT_PASSWORD first, then without password as fallback
        
        # Verify PEM and KEY files before P12 generation
        log "🔍 Verifying PEM and KEY files before P12 generation..."
        if [ ! -f "ios/certificates/cert.pem" ] || [ ! -f "ios/certificates/cert.key" ]; then
            log "❌ PEM or KEY file missing"
            log "   PEM exists: $([ -f ios/certificates/cert.pem ] && echo 'yes' || echo 'no')"
            log "   KEY exists: $([ -f ios/certificates/cert.key ] && echo 'yes' || echo 'no')"
            exit 1
        fi
        
        # Check PEM file content
        if openssl x509 -in ios/certificates/cert.pem -text -noout >/dev/null 2>&1; then
            log "✅ PEM file is valid certificate"
        else
            log "❌ PEM file is not a valid certificate"
            exit 1
        fi
        
        # Check KEY file content
        if openssl rsa -in ios/certificates/cert.key -check -noout >/dev/null 2>&1; then
            log "✅ KEY file is valid private key"
        else
            log "❌ KEY file is not a valid private key"
            exit 1
        fi
        
        log "🔍 Attempting P12 generation with CERT_PASSWORD..."
        if openssl pkcs12 -export \
            -inkey ios/certificates/cert.key \
            -in ios/certificates/cert.pem \
            -out ios/certificates/cert.p12 \
            -password "pass:$CERT_PASSWORD" \
            -name "iOS Distribution Certificate" \
            -legacy; then
            log "✅ P12 certificate generated successfully (with password)"
            
            # Verify the generated P12 with password
            log "🔍 Verifying generated P12 file with password..."
            if openssl pkcs12 -in ios/certificates/cert.p12 -noout -passin "pass:$CERT_PASSWORD" -legacy 2>/dev/null; then
                log "✅ Generated P12 verification successful (with password)"
                log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
            else
                log "⚠️ P12 verification with password failed, trying without password..."
                
                # Try generating without password as fallback
                if openssl pkcs12 -export \
                    -inkey ios/certificates/cert.key \
                    -in ios/certificates/cert.pem \
                    -out ios/certificates/cert.p12 \
                    -password "pass:" \
                    -name "iOS Distribution Certificate" \
                    -legacy; then
                    log "✅ P12 certificate generated successfully (no password)"
                    
                    # Verify the generated P12 without password
                    log "🔍 Verifying generated P12 file without password..."
                    if openssl pkcs12 -in ios/certificates/cert.p12 -noout -legacy 2>/dev/null; then
                        log "✅ Generated P12 verification successful (no password)"
                        log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
                    else
                        log "❌ Generated P12 verification failed (no password)"
                        log "🔍 Attempting to debug P12 file..."
                        file ios/certificates/cert.p12
                        log "🔍 P12 file content (first 100 chars):"
                        head -c 100 ios/certificates/cert.p12 | xxd
                        exit 1
                    fi
                else
                    log "❌ Failed to generate P12 certificate (both with and without password)"
                    exit 1
                fi
            fi
        else
            log "❌ Failed to generate P12 certificate with password"
            log "🔍 Debug info:"
            log "   CERT_PASSWORD length: ${#CERT_PASSWORD}"
            log "   CERT_PASSWORD starts with: ${CERT_PASSWORD:0:3}***"
            log "   PEM file exists: $([ -f ios/certificates/cert.pem ] && echo 'yes' || echo 'no')"
            log "   KEY file exists: $([ -f ios/certificates/cert.key ] && echo 'yes' || echo 'no')"
            exit 1
        fi
    else
        log "❌ No certificate URLs provided (CERT_CER_URL and CERT_KEY_URL required when CERT_P12_URL is not provided)"
        exit 1
    fi
fi

# ⚙️ iOS Project Configuration
log "⚙️ Configuring iOS Project..."

# Update Info.plist
log "📝 Updating Info.plist..."
if [ -f "ios/Runner/Info.plist" ]; then
    # Update bundle version and short version
    plutil -replace CFBundleVersion -string "$VERSION_CODE" ios/Runner/Info.plist
    plutil -replace CFBundleShortVersionString -string "$VERSION_NAME" ios/Runner/Info.plist
    plutil -replace CFBundleDisplayName -string "$APP_NAME" ios/Runner/Info.plist
    plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" ios/Runner/Info.plist
    
    log "✅ Info.plist updated successfully"
else
    log "❌ Info.plist not found"
    exit 1
fi

# Add privacy descriptions based on permissions
log "🔐 Adding privacy descriptions..."
if [ -f "lib/scripts/ios/permissions.sh" ]; then
    chmod +x lib/scripts/ios/permissions.sh
    if ./lib/scripts/ios/permissions.sh; then
        log "✅ iOS permissions configuration completed"
    else
        log "❌ iOS permissions configuration failed"
        exit 1
    fi
else
    log "⚠️ iOS permissions script not found, using inline permission handling..."
    
    # Fallback inline permission handling
    if [ "${IS_CAMERA:-false}" = "true" ]; then
        plutil -replace NSCameraUsageDescription -string "This app needs camera access to take photos" ios/Runner/Info.plist
    fi

    if [ "${IS_LOCATION:-false}" = "true" ]; then
        plutil -replace NSLocationWhenInUseUsageDescription -string "This app needs location access to provide location-based services" ios/Runner/Info.plist
        plutil -replace NSLocationAlwaysAndWhenInUseUsageDescription -string "This app needs location access to provide location-based services" ios/Runner/Info.plist
    fi

    if [ "${IS_MIC:-false}" = "true" ]; then
        plutil -replace NSMicrophoneUsageDescription -string "This app needs microphone access for voice features" ios/Runner/Info.plist
    fi

    if [ "${IS_CONTACT:-false}" = "true" ]; then
        plutil -replace NSContactsUsageDescription -string "This app needs contacts access to manage contacts" ios/Runner/Info.plist
    fi

    if [ "${IS_BIOMETRIC:-false}" = "true" ]; then
        plutil -replace NSFaceIDUsageDescription -string "This app uses Face ID for secure authentication" ios/Runner/Info.plist
    fi

    if [ "${IS_CALENDAR:-false}" = "true" ]; then
        plutil -replace NSCalendarsUsageDescription -string "This app needs calendar access to manage events" ios/Runner/Info.plist
    fi

    if [ "${IS_STORAGE:-false}" = "true" ]; then
        plutil -replace NSPhotoLibraryUsageDescription -string "This app needs photo library access to save and manage photos" ios/Runner/Info.plist
        plutil -replace NSPhotoLibraryAddUsageDescription -string "This app needs photo library access to save photos" ios/Runner/Info.plist
    fi

    # Always add network security
    plutil -replace NSAppTransportSecurity -json '{"NSAllowsArbitraryLoads": true}' ios/Runner/Info.plist

    log "✅ Privacy descriptions added"
fi

# 🔐 Code Signing Preparation
log "🔐 Setting up Code Signing..."

# Use enhanced code signing script
if [ -f "lib/scripts/ios/code_signing.sh" ]; then
    chmod +x lib/scripts/ios/code_signing.sh
    if ./lib/scripts/ios/code_signing.sh; then
        log "✅ Enhanced code signing setup completed"
    else
        log "❌ Enhanced code signing setup failed"
        exit 1
    fi
else
    log "❌ Enhanced code signing script not found"
    exit 1
fi

# 🛠️ Build Process
log "🛠️ Starting Build Process..."

# Use enhanced build script
if [ -f "lib/scripts/ios/build_ipa.sh" ]; then
    chmod +x lib/scripts/ios/build_ipa.sh
    if ./lib/scripts/ios/build_ipa.sh; then
        log "✅ Enhanced IPA build completed successfully"
    else
        log "❌ Enhanced IPA build failed"
        exit 1
    fi
else
    log "❌ Enhanced build script not found"
    exit 1
fi

# 📤 Post-Build Actions
log "📤 Processing Post-Build Actions..."

# App Store Connect Publishing (if applicable)
if [ "${IS_TESTFLIGHT:-false}" = "true" ] && [ "${PROFILE_TYPE:-app-store}" = "app-store" ]; then
    log "📤 Preparing for App Store Connect upload..."
    # Note: This would typically be done through fastlane or xcrun altool
    log "ℹ️ App Store Connect upload would be configured here"
fi

# Process artifact URLs for email
log "📦 Processing artifact URLs for email notification..."
if [ -f "lib/scripts/utils/process_artifacts.sh" ]; then
    source "lib/scripts/utils/process_artifacts.sh"
    artifact_urls=$(process_artifacts)
    log "Artifact URLs: $artifact_urls"
else
    artifact_urls=""
fi

# Send build success email
log "🎉 Build successful! Sending success email..."
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "iOS" "${CM_BUILD_ID:-unknown}" "Build successful" "$artifact_urls"
fi

log "✅ iOS Universal IPA Build Process completed successfully!"
exit 0 