#!/bin/bash
set -euo pipefail

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

# Set WORKFLOW_ID for ios-appstore workflow immediately
export WORKFLOW_ID="ios-appstore"
log "🚀 iOS App Store Workflow initialized (WORKFLOW_ID: ${WORKFLOW_ID})"

# Error handling
trap 'handle_error $LINENO $?' ERR

# Function to handle errors
handle_error() {
    local line_no=$1
    local exit_code=$2
    log "❌ Error occurred at line ${line_no}. Exit code: ${exit_code}"
    
    # Send failure email notification
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" == "true" ]]; then
        log "📧 Sending build failure email notification..."
        if command -v python3 &> /dev/null; then
            python3 lib/scripts/utils/send_email.py "build_failed" "iOS App Store Build Failed" "Error at line ${line_no}, exit code: ${exit_code}"
        else
            log "⚠️ Python3 not available, skipping email notification"
        fi
    fi
    
    exit $exit_code
}

# Function to validate environment variables
validate_environment_variables() {
    log "🔍 Validating environment variables..."
    
    # Required variables for App Store build
    local required_vars=(
        "BUNDLE_ID"
        "VERSION_NAME"
        "VERSION_CODE"
        "APP_NAME"
        "ORG_NAME"
        "WEB_URL"
        "EMAIL_ID"
        "USER_NAME"
    )
    
    # Check required variables
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log "❌ Missing required variable: $var"
            return 1
        fi
    done
    
    # Validate App Store specific requirements
    if [[ "${PROFILE_TYPE:-}" != "app-store" ]]; then
        log "❌ Invalid profile type for App Store workflow: ${PROFILE_TYPE:-not_set}"
        log "   This workflow only supports app-store profile type"
        return 1
    fi
    
    # Validate Firebase configuration if push notifications are enabled
    if [[ "${PUSH_NOTIFY:-false}" == "true" ]]; then
        if [[ -z "${FIREBASE_CONFIG_IOS:-}" ]]; then
            log "❌ FIREBASE_CONFIG_IOS is required when PUSH_NOTIFY is true"
            return 1
        fi
    fi
    
    log "✅ Environment variables validation passed"
    return 0
}

# Function to send build started email
send_build_started_email() {
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" == "true" ]]; then
        log "📧 Sending build started email notification..."
        if command -v python3 &> /dev/null; then
            python3 lib/scripts/utils/send_email.py "build_started" "iOS App Store Build Started" "App Store build process initiated"
        else
            log "⚠️ Python3 not available, skipping email notification"
        fi
    fi
}

# Function to send build success email
send_build_success_email() {
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" == "true" ]]; then
        log "📧 Sending build success email notification..."
        if command -v python3 &> /dev/null; then
            python3 lib/scripts/utils/send_email.py "build_success" "iOS App Store Build Successful" "App Store IPA ready for upload"
        else
            log "⚠️ Python3 not available, skipping email notification"
        fi
    fi
}

# Main execution
main() {
    log "🚀 Starting iOS App Store Build Process..."
    
    # Send build started email
    send_build_started_email
    
    # Validate environment variables
    if ! validate_environment_variables; then
        log "❌ Environment validation failed"
        exit 1
    fi
    
    log "📋 Build Configuration:"
    log "   App Name: ${APP_NAME}"
    log "   Bundle ID: ${BUNDLE_ID}"
    log "   Version: ${VERSION_NAME} (${VERSION_CODE})"
    log "   Profile Type: ${PROFILE_TYPE}"
    log "   Push Notifications: ${PUSH_NOTIFY:-false}"
    log "   Firebase: ${FIREBASE_CONFIG_IOS:+enabled}"
    
    # Step 1: Generate environment configuration
    log "📝 Generating environment configuration..."
    if [[ -f "lib/scripts/utils/gen_env_config.sh" ]]; then
        bash lib/scripts/utils/gen_env_config.sh
        log "✅ Environment configuration generated"
    else
        log "⚠️ Environment config generator not found, skipping"
    fi
    
    # Step 2: Download and setup assets
    log "📥 Downloading Required Configuration Files..."
    if [[ -f "lib/scripts/ios/branding.sh" ]]; then
        bash lib/scripts/ios/branding.sh
        log "✅ Branding assets downloaded"
    else
        log "⚠️ Branding script not found, skipping"
    fi
    
    # Step 3: Configure Firebase if needed
    if [[ "${PUSH_NOTIFY:-false}" == "true" ]]; then
        log "🔥 Configuring Firebase (PUSH_NOTIFY: true)..."
        if [[ -f "lib/scripts/ios/firebase.sh" ]]; then
            bash lib/scripts/ios/firebase.sh
            log "✅ Firebase configured successfully for push notifications"
        else
            log "❌ Firebase script not found"
            exit 1
        fi
    else
        log "🔕 Push notifications disabled, skipping Firebase configuration"
    fi
    
    # Step 4: Setup code signing for App Store
    log "🔐 Setting up App Store code signing..."
    if [[ -f "lib/scripts/ios/code_signing.sh" ]]; then
        bash lib/scripts/ios/code_signing.sh
        log "✅ Code signing setup completed"
    else
        log "❌ Code signing script not found"
        exit 1
    fi
    
    # Step 5: Configure app customization
    log "🎨 Configuring app customization..."
    if [[ -f "lib/scripts/ios/customization.sh" ]]; then
        bash lib/scripts/ios/customization.sh
        log "✅ App customization completed"
    else
        log "⚠️ Customization script not found, skipping"
    fi
    
    # Step 6: Configure permissions
    log "🔐 Configuring app permissions..."
    if [[ -f "lib/scripts/ios/permissions.sh" ]]; then
        bash lib/scripts/ios/permissions.sh
        log "✅ Permissions configured"
    else
        log "⚠️ Permissions script not found, skipping"
    fi
    
    # Step 7: Generate Podfile
    log "📦 Generating Podfile..."
    if [[ -f "lib/scripts/ios/generate_podfile.sh" ]]; then
        bash lib/scripts/ios/generate_podfile.sh
        log "✅ Podfile generated"
    else
        log "⚠️ Podfile generator not found, using default"
    fi
    
    # Step 8: Build IPA for App Store
    log "🏗️ Building iOS App Store IPA..."
    if [[ -f "lib/scripts/ios/build_ipa.sh" ]]; then
        bash lib/scripts/ios/build_ipa.sh
        log "✅ IPA build completed"
    else
        log "❌ Build IPA script not found"
        exit 1
    fi
    
    # Step 9: Generate artifacts summary
    log "📋 Generating artifacts summary..."
    cat > output/ios/ARTIFACTS_SUMMARY.txt << EOF
iOS App Store Build Summary
===========================

Build Information:
- Workflow: ios-appstore
- App Name: ${APP_NAME}
- Bundle ID: ${BUNDLE_ID}
- Version: ${VERSION_NAME} (${VERSION_CODE})
- Profile Type: ${PROFILE_TYPE}
- Build Date: $(date)

Configuration:
- Push Notifications: ${PUSH_NOTIFY:-false}
- Firebase: ${FIREBASE_CONFIG_IOS:+enabled}
- Features: ${IS_SPLASH:+Splash} ${IS_PULLDOWN:+Pull-to-refresh} ${IS_BOTTOMMENU:+Bottom Menu} ${IS_LOAD_IND:+Loading Indicators}

Permissions:
- Camera: ${IS_CAMERA:-false}
- Location: ${IS_LOCATION:-false}
- Microphone: ${IS_MIC:-false}
- Notifications: ${IS_NOTIFICATION:-false}
- Contacts: ${IS_CONTACT:-false}
- Biometric: ${IS_BIOMETRIC:-false}
- Calendar: ${IS_CALENDAR:-false}
- Storage: ${IS_STORAGE:-false}

Artifacts:
- IPA File: output/ios/Runner.ipa
- Archive: output/ios/Runner.xcarchive
- Export Options: ios/ExportOptions.plist

Next Steps:
1. Upload IPA to App Store Connect
2. Submit for App Store review
3. Monitor review status

Build completed successfully at $(date)
EOF
    
    log "✅ Artifacts summary generated"
    
    # Step 10: Verify IPA was created
    if [[ -f "output/ios/Runner.ipa" ]]; then
        IPA_SIZE=$(du -h output/ios/Runner.ipa | cut -f1)
        log "✅ App Store IPA created successfully!"
        log "📊 IPA Size: ${IPA_SIZE}"
        log "📦 Ready for App Store Connect upload"
        
        # Send success email
        send_build_success_email
        
        log "🎉 iOS App Store build completed successfully!"
        exit 0
    else
        log "❌ IPA file not found after build"
        log "📦 Checking for archive file..."
        
        if [[ -d "output/ios/Runner.xcarchive" ]]; then
            log "✅ Archive found, manual export required"
            log "🔧 Manual export command:"
            log "   xcodebuild -exportArchive -archivePath output/ios/Runner.xcarchive -exportPath output/ios/ -exportOptionsPlist ios/ExportOptions.plist"
        else
            log "❌ Neither IPA nor archive found"
        fi
        
        exit 1
    fi
}

# Execute main function
main "$@" 