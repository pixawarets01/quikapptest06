#!/bin/bash
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"

# Cross-platform sed function
cross_platform_sed() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Function to update pubspec.yaml with environment variables
update_pubspec() {
    local pubspec_file="$PROJECT_ROOT/pubspec.yaml"

    # Create a backup
    cp "$pubspec_file" "${pubspec_file}.bak"

    # Update version
    cross_platform_sed "s/version: .*/version: ${VERSION_NAME}+${VERSION_CODE}/" "$pubspec_file"

    # Replace placeholders with actual dependencies based on feature flags
    if [ "${PUSH_NOTIFY:-}" = "true" ]; then
        cross_platform_sed "s/# FIREBASE_CORE_DEPENDENCY_PLACEHOLDER/firebase_core: ^2.24.2/" "$pubspec_file"
        cross_platform_sed "s/# FIREBASE_MESSAGING_PUBSPEC_DEPENDENCY_PLACEHOLDER/firebase_messaging: ^14.7.9/" "$pubspec_file"
    else
        # Remove the placeholder lines if feature is disabled
        cross_platform_sed "/# FIREBASE_CORE_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
        cross_platform_sed "/# FIREBASE_MESSAGING_PUBSPEC_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi

    # Handle other conditional dependencies
    if [ "${IS_CAMERA:-}" = "true" ]; then
        cross_platform_sed "s/# CAMERA_DEPENDENCY_PLACEHOLDER/camera: ^0.10.5+9/" "$pubspec_file"
    else
        cross_platform_sed "/# CAMERA_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_LOCATION:-}" = "true" ]; then
        cross_platform_sed "s/# GEOLOCATOR_DEPENDENCY_PLACEHOLDER/geolocator: ^10.1.0/" "$pubspec_file"
    else
        cross_platform_sed "/# GEOLOCATOR_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_MIC:-}" = "true" ]; then
        cross_platform_sed "s/# SPEECH_TO_TEXT_DEPENDENCY_PLACEHOLDER/speech_to_text: ^6.5.1/" "$pubspec_file"
    else
        cross_platform_sed "/# SPEECH_TO_TEXT_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_CONTACT:-}" = "true" ]; then
        cross_platform_sed "s/# CONTACTS_SERVICE_DEPENDENCY_PLACEHOLDER/contacts_service: ^0.6.3/" "$pubspec_file"
    else
        cross_platform_sed "/# CONTACTS_SERVICE_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_BIOMETRIC:-}" = "true" ]; then
        cross_platform_sed "s/# LOCAL_AUTH_DEPENDENCY_PLACEHOLDER/local_auth: ^2.1.8/" "$pubspec_file"
    else
        cross_platform_sed "/# LOCAL_AUTH_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_CALENDAR:-}" = "true" ]; then
        cross_platform_sed "s/# CALENDAR_EVENTS_DEPENDENCY_PLACEHOLDER/calendar_events: ^1.0.5/" "$pubspec_file"
    else
        cross_platform_sed "/# CALENDAR_EVENTS_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_STORAGE:-}" = "true" ]; then
        cross_platform_sed "s/# FILE_PICKER_DEPENDENCY_PLACEHOLDER/file_picker: ^6.1.1/" "$pubspec_file"
    else
        cross_platform_sed "/# FILE_PICKER_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_CHATBOT:-}" = "true" ]; then
        cross_platform_sed "s/# FLUTTER_CHAT_UI_DEPENDENCY_PLACEHOLDER/flutter_chat_ui: ^1.6.10/" "$pubspec_file"
    else
        cross_platform_sed "/# FLUTTER_CHAT_UI_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_DOMAIN_URL:-}" = "true" ]; then
        cross_platform_sed "s/# UNI_LINKS_DEPENDENCY_PLACEHOLDER/uni_links: ^0.5.1/" "$pubspec_file"
    else
        cross_platform_sed "/# UNI_LINKS_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_SPLASH:-}" = "true" ]; then
        cross_platform_sed "s/# FLUTTER_NATIVE_SPLASH_DEPENDENCY_PLACEHOLDER/flutter_native_splash: ^2.3.9/" "$pubspec_file"
    else
        cross_platform_sed "/# FLUTTER_NATIVE_SPLASH_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_PULLDOWN:-}" = "true" ]; then
        cross_platform_sed "s/# PULL_TO_REFRESH_DEPENDENCY_PLACEHOLDER/pull_to_refresh: ^2.0.0/" "$pubspec_file"
    else
        cross_platform_sed "/# PULL_TO_REFRESH_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_BOTTOMMENU:-}" = "true" ]; then
        cross_platform_sed "s/# FLUTTER_SVG_DEPENDENCY_PLACEHOLDER/flutter_svg: ^2.0.9/" "$pubspec_file"
    else
        cross_platform_sed "/# FLUTTER_SVG_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi
    
    if [ "${IS_LOAD_IND:-}" = "true" ]; then
        cross_platform_sed "s/# LOADING_ANIMATION_WIDGET_DEPENDENCY_PLACEHOLDER/loading_animation_widget: ^1.2.0+4/" "$pubspec_file"
    else
        cross_platform_sed "/# LOADING_ANIMATION_WIDGET_DEPENDENCY_PLACEHOLDER/d" "$pubspec_file"
    fi

    # Clean up backup files
    rm -f "${pubspec_file}.bak"
    
    # Ensure flutter_launcher_icons is in dev_dependencies for branding
    if ! grep -q "flutter_launcher_icons:" "$pubspec_file"; then
        # Use a simpler approach with echo and temporary file
        while IFS= read -r line; do
            echo "$line"
            if [[ "$line" == *"flutter_lints:"* ]]; then
                echo "  flutter_launcher_icons: ^0.13.1"
            fi
        done < "$pubspec_file" > "${pubspec_file}.tmp" && mv "${pubspec_file}.tmp" "$pubspec_file"
    fi
}

# Main execution
update_pubspec 