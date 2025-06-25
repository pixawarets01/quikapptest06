#!/bin/bash
set -euo pipefail

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

# Error handling
trap 'handle_error $LINENO $?' ERR
handle_error() {
    local line_no="$1"
    local exit_code="$2"
    local error_msg="Error occurred at line ${line_no}. Exit code: ${exit_code}"
    
    log "❌ ${error_msg}"
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Auto-iOS" "${CM_BUILD_ID:-unknown}" "${error_msg}" || true
    fi
    
    exit "${exit_code}"
}

# Function to validate minimal environment variables
validate_minimal_variables() {
    log "🔍 Validating minimal environment variables for auto-ios-workflow..."
    
    # Required variables for auto-ios-workflow
    local required_vars=(
        "BUNDLE_ID" 
        "VERSION_NAME" 
        "VERSION_CODE" 
        "APP_NAME"
        "APPLE_ID"
        "PROFILE_TYPE"
        "APP_STORE_CONNECT_KEY_IDENTIFIER"
        "APP_STORE_CONNECT_API_KEY_PATH"
        "APP_STORE_CONNECT_ISSUER_ID"
    )
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "❌ Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log "   - ${var}"
        done
        return 1
    fi
    
    log "✅ All required environment variables are present"
    return 0
}

# Function to setup Fastlane environment
setup_fastlane_environment() {
    log "🚀 Setting up Fastlane environment..."
    
    # Create Fastfile if it doesn't exist
    if [ ! -f "fastlane/Fastfile" ]; then
        log "📝 Creating Fastfile..."
        mkdir -p fastlane
        cat > fastlane/Fastfile <<EOF
default_platform(:ios)

platform :ios do
  desc "Auto iOS Build with Dynamic Signing"
  
  lane :auto_build do
    # This lane will be called by our script
    # The actual work is done in the shell script for better control
    UI.message "Auto iOS build initiated"
  end
  
  lane :create_app_identifier do
    produce(
      username: ENV["APPLE_ID"],
      app_identifier: ENV["BUNDLE_ID"],
      app_name: ENV["APP_NAME"],
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      skip_itc: true
    )
  end
  
  lane :setup_signing do
    match(
      type: ENV["PROFILE_TYPE"],
      app_identifier: ENV["BUNDLE_ID"],
      readonly: false,
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      api_key_path: ENV["APP_STORE_CONNECT_API_KEY_PATH"],
      username: ENV["APPLE_ID"],
      skip_confirmation: true,
      verbose: true
    )
  end
end
EOF
    fi
    
    # Create Matchfile for certificate management
    if [ ! -f "fastlane/Matchfile" ]; then
        log "📝 Creating Matchfile..."
        cat > fastlane/Matchfile <<EOF
git_url("https://github.com/your-org/certificates.git") # Replace with your cert repo
storage_mode("git")

type("development") # default type

app_identifier(["#{ENV['BUNDLE_ID']}"])
team_id("#{ENV['APP_STORE_CONNECT_KEY_IDENTIFIER']}")

# For App Store Connect API
api_key_path("#{ENV['APP_STORE_CONNECT_API_KEY_PATH']}")
api_key_id("#{ENV['APP_STORE_CONNECT_KEY_IDENTIFIER']}")
issuer_id("#{ENV['APP_STORE_CONNECT_ISSUER_ID']}")

# Additional options
readonly(false)
skip_confirmation(true)
verbose(true)
EOF
    fi
    
    log "✅ Fastlane environment setup completed"
}

# Function to create App Identifier
create_app_identifier() {
    log "🏷️ Creating App Identifier..."
    
    # Set team ID from App Store Connect key identifier
    export APPLE_TEAM_ID="${APP_STORE_CONNECT_KEY_IDENTIFIER}"
    
    log "📋 App Identifier Details:"
    log "   Bundle ID: ${BUNDLE_ID}"
    log "   App Name: ${APP_NAME}"
    log "   Team ID: ${APPLE_TEAM_ID}"
    log "   Apple ID: ${APPLE_ID}"
    
    # Create App Identifier using fastlane produce
    fastlane produce \
        -u "${APPLE_ID}" \
        -a "${BUNDLE_ID}" \
        --skip_itc \
        --app_name "${APP_NAME}" \
        --team_id "${APPLE_TEAM_ID}" || {
        log "⚠️ App identifier may already exist or creation failed, continuing..."
    }
    
    log "✅ App Identifier setup completed"
}

# Function to setup code signing
setup_code_signing() {
    log "🔐 Setting up code signing..."
    
    # Validate profile type
    local valid_types=("app-store" "ad-hoc" "enterprise" "development")
    local is_valid=false
    
    for type in "${valid_types[@]}"; do
        if [[ "${PROFILE_TYPE}" == "${type}" ]]; then
            is_valid=true
            break
        fi
    done
    
    if [[ "${is_valid}" == "false" ]]; then
        log "❌ Invalid PROFILE_TYPE: ${PROFILE_TYPE}"
        log "   Valid types: ${valid_types[*]}"
        return 1
    fi
    
    log "📋 Code Signing Details:"
    log "   Profile Type: ${PROFILE_TYPE}"
    log "   Bundle ID: ${BUNDLE_ID}"
    log "   Team ID: ${APPLE_TEAM_ID}"
    log "   API Key Path: ${APP_STORE_CONNECT_API_KEY_PATH}"
    
    # Setup code signing using fastlane match
    fastlane match "${PROFILE_TYPE}" \
        --type "${PROFILE_TYPE}" \
        --app_identifier "${BUNDLE_ID}" \
        --readonly false \
        --team_id "${APPLE_TEAM_ID}" \
        --api_key_path "${APP_STORE_CONNECT_API_KEY_PATH}" \
        --username "${APPLE_ID}" \
        --skip_confirmation true \
        --verbose || {
        log "❌ Code signing setup failed"
        return 1
    }
    
    log "✅ Code signing setup completed"
}

# Function to inject signing assets into build environment
inject_signing_assets() {
    log "💉 Injecting signing assets into build environment..."
    
    # Set environment variables for the main build script
    export CERT_PASSWORD="match" # fastlane match uses "match" as default password
    export PROFILE_TYPE="${PROFILE_TYPE}"
    export BUNDLE_ID="${BUNDLE_ID}"
    export APP_NAME="${APP_NAME}"
    export APPLE_TEAM_ID="${APPLE_TEAM_ID}"
    
    # Set Firebase configuration if provided
    if [[ -n "${FIREBASE_CONFIG_IOS:-}" ]]; then
        export FIREBASE_CONFIG_IOS="${FIREBASE_CONFIG_IOS}"
    fi
    
    # Set all other required variables
    export VERSION_NAME="${VERSION_NAME}"
    export VERSION_CODE="${VERSION_CODE}"
    export WORKFLOW_ID="auto-ios-workflow"
    export PUSH_NOTIFY="${PUSH_NOTIFY:-false}"
    export IS_CHATBOT="${IS_CHATBOT:-false}"
    export IS_DOMAIN_URL="${IS_DOMAIN_URL:-false}"
    export IS_SPLASH="${IS_SPLASH:-true}"
    export IS_PULLDOWN="${IS_PULLDOWN:-true}"
    export IS_BOTTOMMENU="${IS_BOTTOMMENU:-true}"
    export IS_LOAD_IND="${IS_LOAD_IND:-true}"
    
    # Permissions
    export IS_CAMERA="${IS_CAMERA:-false}"
    export IS_LOCATION="${IS_LOCATION:-false}"
    export IS_MIC="${IS_MIC:-false}"
    export IS_NOTIFICATION="${IS_NOTIFICATION:-false}"
    export IS_CONTACT="${IS_CONTACT:-false}"
    export IS_BIOMETRIC="${IS_BIOMETRIC:-false}"
    export IS_CALENDAR="${IS_CALENDAR:-false}"
    export IS_STORAGE="${IS_STORAGE:-false}"
    
    # UI Configuration
    export LOGO_URL="${LOGO_URL:-}"
    export SPLASH_URL="${SPLASH_URL:-}"
    export SPLASH_BG_URL="${SPLASH_BG_URL:-}"
    export SPLASH_BG_COLOR="${SPLASH_BG_COLOR:-#FFFFFF}"
    export SPLASH_TAGLINE="${SPLASH_TAGLINE:-}"
    export SPLASH_TAGLINE_COLOR="${SPLASH_TAGLINE_COLOR:-#000000}"
    export SPLASH_ANIMATION="${SPLASH_ANIMATION:-none}"
    export SPLASH_DURATION="${SPLASH_DURATION:-3}"
    
    # Bottom Menu Configuration
    export BOTTOMMENU_ITEMS="${BOTTOMMENU_ITEMS:-[]}"
    export BOTTOMMENU_BG_COLOR="${BOTTOMMENU_BG_COLOR:-#FFFFFF}"
    export BOTTOMMENU_ICON_COLOR="${BOTTOMMENU_ICON_COLOR:-#000000}"
    export BOTTOMMENU_TEXT_COLOR="${BOTTOMMENU_TEXT_COLOR:-#000000}"
    export BOTTOMMENU_FONT="${BOTTOMMENU_FONT:-DM Sans}"
    export BOTTOMMENU_FONT_SIZE="${BOTTOMMENU_FONT_SIZE:-14.0}"
    export BOTTOMMENU_FONT_BOLD="${BOTTOMMENU_FONT_BOLD:-false}"
    export BOTTOMMENU_FONT_ITALIC="${BOTTOMMENU_FONT_ITALIC:-false}"
    export BOTTOMMENU_ACTIVE_TAB_COLOR="${BOTTOMMENU_ACTIVE_TAB_COLOR:-#0000FF}"
    export BOTTOMMENU_ICON_POSITION="${BOTTOMMENU_ICON_POSITION:-top}"
    
    # App metadata
    export APP_ID="${APP_ID:-}"
    export ORG_NAME="${ORG_NAME:-}"
    export WEB_URL="${WEB_URL:-}"
    export EMAIL_ID="${EMAIL_ID:-}"
    export USER_NAME="${USER_NAME:-}"
    
    log "✅ Signing assets injected into build environment"
}

# Function to run the main iOS build
run_ios_build() {
    log "🚀 Running main iOS build process..."
    
    # Make sure the main script is executable
    chmod +x lib/scripts/ios/main.sh
    chmod +x lib/scripts/utils/*.sh
    
    # Run the main iOS build script
    bash lib/scripts/ios/main.sh
    
    log "✅ Main iOS build completed"
}

# Function to create artifacts summary
create_artifacts_summary() {
    log "📋 Creating artifacts summary..."
    
    local summary_file="output/ios/ARTIFACTS_SUMMARY.txt"
    mkdir -p output/ios
    
    cat > "${summary_file}" <<EOF
🚀 Auto iOS Workflow Build Summary
==================================

📱 App Information:
   App Name: ${APP_NAME}
   Bundle ID: ${BUNDLE_ID}
   Version: ${VERSION_NAME} (${VERSION_CODE})
   Profile Type: ${PROFILE_TYPE}

🔐 Signing Information:
   Team ID: ${APPLE_TEAM_ID}
   Apple ID: ${APPLE_ID}
   Certificate: Auto-generated via fastlane match
   Provisioning Profile: Auto-generated via fastlane match

🎨 Customization:
   Logo: ${LOGO_URL:+✅} ${LOGO_URL:-❌}
   Splash Screen: ${SPLASH_URL:+✅} ${SPLASH_URL:-❌}
   Bottom Menu: ${IS_BOTTOMMENU:+✅} ${IS_BOTTOMMENU:-❌}
   Firebase: ${FIREBASE_CONFIG_IOS:+✅} ${FIREBASE_CONFIG_IOS:-❌}

🔧 Features:
   Push Notifications: ${PUSH_NOTIFY:+✅} ${PUSH_NOTIFY:-❌}
   Chat Bot: ${IS_CHATBOT:+✅} ${IS_CHATBOT:-❌}
   Deep Linking: ${IS_DOMAIN_URL:+✅} ${IS_DOMAIN_URL:-❌}
   Pull to Refresh: ${IS_PULLDOWN:+✅} ${IS_PULLDOWN:-❌}
   Loading Indicators: ${IS_LOAD_IND:+✅} ${IS_LOAD_IND:-❌}

🔐 Permissions:
   Camera: ${IS_CAMERA:+✅} ${IS_CAMERA:-❌}
   Location: ${IS_LOCATION:+✅} ${IS_LOCATION:-❌}
   Microphone: ${IS_MIC:+✅} ${IS_MIC:-❌}
   Notifications: ${IS_NOTIFICATION:+✅} ${IS_NOTIFICATION:-❌}
   Contacts: ${IS_CONTACT:+✅} ${IS_CONTACT:-❌}
   Biometric: ${IS_BIOMETRIC:+✅} ${IS_BIOMETRIC:-❌}
   Calendar: ${IS_CALENDAR:+✅} ${IS_CALENDAR:-❌}
   Storage: ${IS_STORAGE:+✅} ${IS_STORAGE:-❌}

📦 Build Artifacts:
   IPA Files: output/ios/*.ipa
   Archive Files: output/ios/*.xcarchive
   Export Options: ios/ExportOptions.plist
   Build Logs: output/ios/logs/

🔄 Workflow: auto-ios-workflow
📅 Build Date: $(date)
🏗️ Build ID: ${CM_BUILD_ID:-unknown}

EOF

    log "✅ Artifacts summary created: ${summary_file}"
}

# Main execution flow
main() {
    log "🚀 Starting Auto iOS Workflow..."
    
    # Send build started email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_started" "Auto-iOS" "${CM_BUILD_ID:-unknown}" || true
    fi
    
    # Step 1: Validate minimal variables
    if ! validate_minimal_variables; then
        log "❌ Minimal variable validation failed"
        exit 1
    fi
    
    # Step 2: Setup Fastlane environment
    setup_fastlane_environment
    
    # Step 3: Create App Identifier
    create_app_identifier
    
    # Step 4: Setup code signing
    if ! setup_code_signing; then
        log "❌ Code signing setup failed"
        exit 1
    fi
    
    # Step 5: Inject signing assets
    inject_signing_assets
    
    # Step 6: Run main iOS build
    run_ios_build
    
    # Step 7: Create artifacts summary
    create_artifacts_summary
    
    log "🎉 Auto iOS Workflow completed successfully!"
    
    # Send success email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        lib/scripts/utils/send_email.sh "build_success" "Auto-iOS" "${CM_BUILD_ID:-unknown}" || true
    fi
}

# Run main function
main "$@" 