#!/bin/bash
set -euo pipefail

# Dynamic Package Name Update Script for QuikApp Platform
# This script updates any old package names to the user's specified PKG_NAME

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [PKG_UPDATE] $1"; }

# Get the new package name from environment variable
NEW_PACKAGE_NAME="${PKG_NAME:-com.example.quikapptest06}"

# Define possible old package names to replace
OLD_PACKAGE_NAMES=(
    "com.example.quikapptest06"
    "com.example.myapp"
    "com.myapp.app"
    "com.mynewapp.app"
    "com.example.flutter_app"
    "com.example.app"
)

log "🔄 Starting dynamic package name update for QuikApp platform"
log "📦 Target package name: ${NEW_PACKAGE_NAME}"
log "🔍 Scanning for old package names to replace..."

# Function to update package name in a file
update_package_in_file() {
    local file_path="$1"
    local old_pkg="$2"
    local new_pkg="$3"
    local description="$4"
    
    if [ -f "$file_path" ]; then
        if grep -q "$old_pkg" "$file_path"; then
            log "🔧 Updating $description: $file_path"
            # Use | as delimiter to avoid issues with slashes in package names
            # Handle both macOS and Linux sed syntax
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS requires empty string after -i
                sed -i '' "s|${old_pkg}|${new_pkg}|g" "$file_path"
            else
                # Linux (Codemagic) doesn't need empty string
                sed -i "s|${old_pkg}|${new_pkg}|g" "$file_path"
            fi
            log "   ✅ Updated $old_pkg → $new_pkg"
        fi
    fi
}

# Function to update Android manifest files
update_android_manifests() {
    local old_pkg="$1"
    local new_pkg="$2"
    
    # Update main AndroidManifest.xml
    update_package_in_file "android/app/src/main/AndroidManifest.xml" "package=\"${old_pkg}\"" "package=\"${new_pkg}\"" "main AndroidManifest.xml"
    
    # Update debug AndroidManifest.xml if exists
    update_package_in_file "android/app/src/debug/AndroidManifest.xml" "package=\"${old_pkg}\"" "package=\"${new_pkg}\"" "debug AndroidManifest.xml"
    
    # Update profile AndroidManifest.xml if exists  
    update_package_in_file "android/app/src/profile/AndroidManifest.xml" "package=\"${old_pkg}\"" "package=\"${new_pkg}\"" "profile AndroidManifest.xml"
}

# Function to update build.gradle files
update_build_gradle() {
    local old_pkg="$1"
    local new_pkg="$2"
    
    # Update build.gradle (Groovy syntax)
    update_package_in_file "android/app/build.gradle" "applicationId \"${old_pkg}\"" "applicationId \"${new_pkg}\"" "build.gradle applicationId"
    update_package_in_file "android/app/build.gradle" "applicationId '${old_pkg}'" "applicationId '${new_pkg}'" "build.gradle applicationId (single quotes)"
    
    # Update build.gradle.kts (Kotlin syntax)
    update_package_in_file "android/app/build.gradle.kts" "applicationId = \"${old_pkg}\"" "applicationId = \"${new_pkg}\"" "build.gradle.kts applicationId"
    update_package_in_file "android/app/build.gradle.kts" "namespace = \"${old_pkg}\"" "namespace = \"${new_pkg}\"" "build.gradle.kts namespace"
}

# Function to update Java/Kotlin package directories and files
update_java_kotlin_files() {
    local old_pkg="$1"
    local new_pkg="$2"
    
    local java_src_main_dir="android/app/src/main/java"
    local kotlin_src_main_dir="android/app/src/main/kotlin"
    
    # Convert package names to directory paths
    local old_dir_path=$(echo "$old_pkg" | tr '.' '/')
    local new_dir_path=$(echo "$new_pkg" | tr '.' '/')
    
    # Update Java files
    if [ -d "$java_src_main_dir" ]; then
        local old_java_dir="${java_src_main_dir}/${old_dir_path}"
        local new_java_dir="${java_src_main_dir}/${new_dir_path}"
        
        if [ -d "$old_java_dir" ]; then
            log "🔧 Updating Java package directory: $old_java_dir → $new_java_dir"
            
            # Create new directory structure
            mkdir -p "$(dirname "$new_java_dir")"
            mkdir -p "$new_java_dir"
            
            # Move files and update package declarations
            if [ "$(ls -A "$old_java_dir" 2>/dev/null)" ]; then
                for file in "$old_java_dir"/*; do
                    if [ -f "$file" ]; then
                        # Update package declaration in the file
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            sed -i '' "s|package ${old_pkg};|package ${new_pkg};|g" "$file"
                        else
                            sed -i "s|package ${old_pkg};|package ${new_pkg};|g" "$file"
                        fi
                        # Move file to new location
                        mv "$file" "$new_java_dir/"
                    fi
                done
                
                # Clean up empty old directories
                cleanup_empty_dirs "$old_java_dir" "$java_src_main_dir"
            fi
        fi
    fi
    
    # Update Kotlin files (similar process)
    if [ -d "$kotlin_src_main_dir" ]; then
        local old_kotlin_dir="${kotlin_src_main_dir}/${old_dir_path}"
        local new_kotlin_dir="${kotlin_src_main_dir}/${new_dir_path}"
        
        if [ -d "$old_kotlin_dir" ]; then
            log "🔧 Updating Kotlin package directory: $old_kotlin_dir → $new_kotlin_dir"
            
            # Create new directory structure
            mkdir -p "$(dirname "$new_kotlin_dir")"
            mkdir -p "$new_kotlin_dir"
            
            # Move files and update package declarations
            if [ "$(ls -A "$old_kotlin_dir" 2>/dev/null)" ]; then
                for file in "$old_kotlin_dir"/*; do
                    if [ -f "$file" ]; then
                        # Update package declaration in the file
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            sed -i '' "s|package ${old_pkg}|package ${new_pkg}|g" "$file"
                        else
                            sed -i "s|package ${old_pkg}|package ${new_pkg}|g" "$file"
                        fi
                        # Move file to new location
                        mv "$file" "$new_kotlin_dir/"
                    fi
                done
                
                # Clean up empty old directories
                cleanup_empty_dirs "$old_kotlin_dir" "$kotlin_src_main_dir"
            fi
        fi
    fi
}

# Function to clean up empty directories
cleanup_empty_dirs() {
    local start_dir="$1"
    local stop_dir="$2"
    
    local current_dir="$start_dir"
    while [ "$current_dir" != "$stop_dir" ] && [ -d "$current_dir" ]; do
        if [ -z "$(ls -A "$current_dir" 2>/dev/null)" ]; then
            log "🧹 Removing empty directory: $current_dir"
            rmdir "$current_dir"
            current_dir=$(dirname "$current_dir")
        else
            break
        fi
    done
}

# Function to update iOS files (for combined workflows)
update_ios_files() {
    local old_pkg="$1"
    local new_pkg="$2"
    
    if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
        update_package_in_file "ios/Runner.xcodeproj/project.pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = ${old_pkg}" "PRODUCT_BUNDLE_IDENTIFIER = ${new_pkg}" "iOS project.pbxproj"
    fi
    
    if [ -f "ios/Runner/Info.plist" ]; then
        update_package_in_file "ios/Runner/Info.plist" "<string>${old_pkg}</string>" "<string>${new_pkg}</string>" "iOS Info.plist"
    fi
}

# Main execution
log "🚀 Starting package name update process..."

# Check if we need to do anything
CHANGES_MADE=false

# Process each old package name
for old_package in "${OLD_PACKAGE_NAMES[@]}"; do
    if [ "$old_package" != "$NEW_PACKAGE_NAME" ]; then
        log "🔍 Checking for package name: $old_package"
        
        # Check if this old package name exists in any files
        if grep -r "$old_package" android/ 2>/dev/null | grep -v ".git" | grep -v "build/" >/dev/null; then
            log "📦 Found $old_package - updating to $NEW_PACKAGE_NAME"
            
            # Update Android files
            update_android_manifests "$old_package" "$NEW_PACKAGE_NAME"
            update_build_gradle "$old_package" "$NEW_PACKAGE_NAME"
            update_java_kotlin_files "$old_package" "$NEW_PACKAGE_NAME"
            
            # Update iOS files if this is a combined workflow
            if [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
                update_ios_files "$old_package" "$NEW_PACKAGE_NAME"
            fi
            
            CHANGES_MADE=true
        fi
    fi
done

# Clean up and refresh if changes were made
if [ "$CHANGES_MADE" = true ]; then
    log "🧹 Cleaning up build artifacts after package name changes..."
    
    # Remove build artifacts
    rm -rf build/ 2>/dev/null || true
    rm -rf android/app/build/ 2>/dev/null || true
    rm -rf .dart_tool/ 2>/dev/null || true
    
    # Remove iOS Podfile.lock if it exists (for combined workflows)
    if [[ "${WORKFLOW_ID:-}" == "combined" ]] && [ -f "ios/Podfile.lock" ]; then
        rm -f ios/Podfile.lock
        log "🧹 Removed iOS Podfile.lock for bundle ID update"
    fi
    
    log "✅ Package name update completed successfully"
    log "📦 All references updated to: $NEW_PACKAGE_NAME"
else
    log "ℹ️ No package name changes needed - already using: $NEW_PACKAGE_NAME"
fi

log "🎉 Package name update process completed" 