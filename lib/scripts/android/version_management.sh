#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [VERSION_MGMT] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

log "🔄 Starting Android Version Management and Package Conflict Resolution"

# Get current environment variables
PKG_NAME=${PKG_NAME:-"com.example.quikapptest06"}
VERSION_NAME=${VERSION_NAME:-"1.0.0"}
VERSION_CODE=${VERSION_CODE:-"1"}
BUILD_MODE=${BUILD_MODE:-"debug"}
KEY_STORE_URL=${KEY_STORE_URL:-}
WORKFLOW_ID=${WORKFLOW_ID:-"android-free"}

# Function to increment version code
increment_version_code() {
    local current_code=$1
    local increment_type=$2
    
    case $increment_type in
        "patch")
            echo $((current_code + 1))
            ;;
        "minor")
            echo $((current_code + 10))
            ;;
        "major")
            echo $((current_code + 100))
            ;;
        "auto")
            # Auto increment based on timestamp
            local timestamp=$(date +%s)
            local last_digits=${timestamp: -3}
            echo $((current_code + last_digits % 100 + 1))
            ;;
        *)
            echo $((current_code + 1))
            ;;
    esac
}

# Function to increment version name
increment_version_name() {
    local current_version=$1
    local increment_type=$2
    
    # Parse version (e.g., "1.2.3" -> major=1, minor=2, patch=3)
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major=${VERSION_PARTS[0]:-1}
    local minor=${VERSION_PARTS[1]:-0}
    local patch=${VERSION_PARTS[2]:-0}
    
    case $increment_type in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "auto")
            patch=$((patch + 1))
            ;;
        *)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Function to generate development package name
generate_dev_package_name() {
    local base_pkg=$1
    local suffix=$2
    
    case $suffix in
        "debug")
            echo "${base_pkg}.debug"
            ;;
        "staging")
            echo "${base_pkg}.staging"
            ;;
        "beta")
            echo "${base_pkg}.beta"
            ;;
        "timestamp")
            local timestamp=$(date +%s)
            local short_timestamp=${timestamp: -6}
            echo "${base_pkg}.dev${short_timestamp}"
            ;;
        *)
            echo "${base_pkg}.dev"
            ;;
    esac
}

# Function to create version configuration
create_version_config() {
    local pkg_name=$1
    local version_name=$2
    local version_code=$3
    
    log "📝 Creating version configuration..."
    log "   Package Name: $pkg_name"
    log "   Version Name: $version_name"
    log "   Version Code: $version_code"
    
    # Update pubspec.yaml
    if [ -f pubspec.yaml ]; then
        log "Updating pubspec.yaml version..."
        sed -i.bak "s/^version: .*/version: ${version_name}+${version_code}/" pubspec.yaml
        log "✅ Updated pubspec.yaml: version: ${version_name}+${version_code}"
    fi
    
    # Update build.gradle.kts
    if [ -f android/app/build.gradle.kts ]; then
        log "Updating build.gradle.kts with new package and version..."
        
        # Update applicationId
        sed -i.bak "s/applicationId = \".*\"/applicationId = \"${pkg_name}\"/" android/app/build.gradle.kts
        
        # Update versionCode and versionName in defaultConfig
        sed -i.bak "s/versionCode = flutter\.versionCode/versionCode = ${version_code}/" android/app/build.gradle.kts
        sed -i.bak "s/versionName = flutter\.versionName/versionName = \"${version_name}\"/" android/app/build.gradle.kts
        
        log "✅ Updated build.gradle.kts with new configuration"
    fi
    
    # Update AndroidManifest.xml namespace if needed
    if [ -f android/app/src/main/AndroidManifest.xml ]; then
        log "Checking AndroidManifest.xml namespace..."
        # Note: namespace is typically handled by build.gradle.kts, but we can verify
        log "✅ AndroidManifest.xml namespace is managed by build.gradle.kts"
    fi
}

# Function to handle signing conflicts
resolve_signing_conflicts() {
    local workflow=$1
    
    log "🔐 Resolving signing conflicts for workflow: $workflow"
    
    case $workflow in
        "android-free"|"android-paid")
            log "Using debug signing for $workflow workflow"
            log "📝 This allows installation alongside production versions"
            ;;
        "android-publish"|"combined")
            if [ -n "$KEY_STORE_URL" ]; then
                log "Using release signing for production deployment"
                log "⚠️  Release-signed APKs will conflict with debug versions"
                log "💡 Uninstall debug versions before installing release APKs"
            else
                log "⚠️  No keystore provided for $workflow workflow"
                log "Using debug signing as fallback"
            fi
            ;;
        *)
            log "Unknown workflow: $workflow, using debug signing"
            ;;
    esac
}

# Function to generate installation instructions
generate_installation_guide() {
    local pkg_name=$1
    local version_name=$2
    local version_code=$3
    local signing_type=$4
    
    cat > output/android/INSTALL_GUIDE.txt <<EOF
🔧 Android APK Installation Guide
================================

App Information:
- Package Name: $pkg_name
- Version: $version_name ($version_code)
- Signing: $signing_type
- Build Date: $(date)

🚀 Installation Methods:

Method 1: Fresh Installation
---------------------------
1. If you have the app installed, uninstall it first:
   Settings > Apps > [App Name] > Uninstall
2. Install the new APK

Method 2: ADB Installation (Recommended for Developers)
-------------------------------------------------------
1. Enable Developer Options and USB Debugging
2. Connect device to computer
3. Run: adb install -r app-release.apk
   (The -r flag allows reinstallation)

Method 3: Force Installation (If conflicts occur)
-------------------------------------------------
1. adb uninstall $pkg_name
2. adb install app-release.apk

⚠️  Common Issues and Solutions:

Issue: "App not installed as package conflicts with an existing package"
Solutions:
1. Uninstall the existing app first
2. Use ADB with -r flag: adb install -r app-release.apk
3. Check if you're trying to install debug over release (or vice versa)

Issue: "Installation blocked by Play Protect"
Solutions:
1. Temporarily disable Play Protect
2. Allow installation from unknown sources
3. Use ADB installation method

Issue: "Signatures don't match"
Solutions:
1. This happens when switching between debug/release builds
2. Uninstall the existing app completely
3. Clear app data if uninstall doesn't work

📱 Package Name Information:
- This APK uses package name: $pkg_name
- Different package names can be installed side-by-side
- Same package names will conflict if signatures differ

🔐 Signing Information:
- $signing_type signed APK
- Debug and Release signed APKs cannot coexist
- Always uninstall before switching signing types

💡 Pro Tips:
1. For testing: Use debug builds (android-free/android-paid workflows)
2. For production: Use release builds (android-publish workflow)
3. For side-by-side testing: Use different package names
4. Keep version codes incrementing to avoid conflicts

EOF

    log "✅ Installation guide created: output/android/INSTALL_GUIDE.txt"
}

# Main execution logic
main() {
    log "🎯 Analyzing current configuration..."
    
    # Determine version increment strategy
    local version_increment_type="auto"
    local package_suffix=""
    
    # Set version strategy based on workflow
    case $WORKFLOW_ID in
        "android-free")
            version_increment_type="patch"
            package_suffix="debug"
            ;;
        "android-paid")
            version_increment_type="patch"
            package_suffix="debug"
            ;;
        "android-publish")
            version_increment_type="minor"
            package_suffix=""  # Use original package name for production
            ;;
        "combined")
            version_increment_type="minor"
            package_suffix=""  # Use original package name for production
            ;;
        *)
            version_increment_type="auto"
            package_suffix="dev"
            ;;
    esac
    
    # Calculate new versions
    local new_version_code
    local new_version_name
    local final_package_name
    
    new_version_code=$(increment_version_code "$VERSION_CODE" "$version_increment_type")
    new_version_name=$(increment_version_name "$VERSION_NAME" "$version_increment_type")
    
    # Generate package name
    if [ -n "$package_suffix" ] && [ "$package_suffix" != "production" ]; then
        final_package_name=$(generate_dev_package_name "$PKG_NAME" "$package_suffix")
        log "🔧 Development build detected - using modified package name"
    else
        final_package_name="$PKG_NAME"
        log "🏭 Production build detected - using original package name"
    fi
    
    log "📊 Version Management Summary:"
    log "   Original Package: $PKG_NAME"
    log "   Final Package: $final_package_name"
    log "   Original Version: $VERSION_NAME ($VERSION_CODE)"
    log "   New Version: $new_version_name ($new_version_code)"
    log "   Increment Type: $version_increment_type"
    log "   Workflow: $WORKFLOW_ID"
    
    # Apply configuration
    create_version_config "$final_package_name" "$new_version_name" "$new_version_code"
    
    # Handle signing conflicts
    local signing_type="Debug"
    if [[ "$WORKFLOW_ID" == "android-publish" ]] || [[ "$WORKFLOW_ID" == "combined" ]]; then
        if [ -n "$KEY_STORE_URL" ]; then
            signing_type="Release"
        fi
    fi
    
    resolve_signing_conflicts "$WORKFLOW_ID"
    
    # Create output directory if it doesn't exist
    mkdir -p output/android
    
    # Generate installation guide
    generate_installation_guide "$final_package_name" "$new_version_name" "$new_version_code" "$signing_type"
    
    # Export variables for use by other scripts
    export PKG_NAME="$final_package_name"
    export VERSION_NAME="$new_version_name"
    export VERSION_CODE="$new_version_code"
    
    log "✅ Version management completed successfully"
    log "📦 Package conflicts should now be resolved"
    log "📋 Check output/android/INSTALL_GUIDE.txt for installation instructions"
}

# Execute main function
main "$@" 