#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS}
BUNDLE_ID=${BUNDLE_ID}

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

# Start Firebase setup
log "Starting Firebase configuration"

# Validate required variables
if [ -z "$FIREBASE_CONFIG_IOS" ]; then
    handle_error "Missing Firebase configuration URL"
fi

# Create necessary directories
mkdir -p ios/QuikApp/Supporting\ Files

# Download Firebase configuration
log "Downloading Firebase configuration from $FIREBASE_CONFIG_IOS"
curl -L "$FIREBASE_CONFIG_IOS" -o ios/QuikApp/Supporting\ Files/GoogleService-Info.plist || handle_error "Failed to download Firebase configuration"

# Verify Firebase configuration
if ! plutil -lint ios/QuikApp/Supporting\ Files/GoogleService-Info.plist > /dev/null 2>&1; then
    handle_error "Invalid Firebase configuration file"
fi

# Verify bundle ID matches
CONFIG_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" ios/QuikApp/Supporting\ Files/GoogleService-Info.plist)
if [ "$CONFIG_BUNDLE_ID" != "$BUNDLE_ID" ]; then
    handle_error "Firebase configuration bundle ID ($CONFIG_BUNDLE_ID) does not match app bundle ID ($BUNDLE_ID)"
fi

# Update project.pbxproj with Firebase configuration
log "Updating project configuration"
cat > ios/QuikApp.xcodeproj/project.pbxproj << EOF
// !$*UTF8*$!
{
    archiveVersion = 1;
    classes = {
    };
    objectVersion = 56;
    objects = {
        /* Begin PBXBuildFile section */
        1A2B3C4D5E6F7G8H9I0J1K2L /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = 9I8H7G6F5E4D3C2B1A0J9K8L7M6N5O4P /* GoogleService-Info.plist */; };
        /* End PBXBuildFile section */

        /* Begin PBXFileReference section */
        9I8H7G6F5E4D3C2B1A0J9K8L7M6N5O4P /* GoogleService-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
        /* End PBXFileReference section */

        /* Begin PBXGroup section */
        1A2B3C4D5E6F7G8H9I0J1K2L /* Supporting Files */ = {
            isa = PBXGroup;
            children = (
                9I8H7G6F5E4D3C2B1A0J9K8L7M6N5O4P /* GoogleService-Info.plist */,
            );
            name = "Supporting Files";
            sourceTree = "<group>";
        };
        /* End PBXGroup section */
    };
    rootObject = 1A2B3C4D5E6F7G8H9I0J1K2L /* Project object */;
}
EOF

log "Firebase configuration completed successfully"
exit 0 