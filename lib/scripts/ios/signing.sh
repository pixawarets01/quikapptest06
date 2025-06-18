#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
APPLE_TEAM_ID=${APPLE_TEAM_ID}
APNS_KEY_ID=${APNS_KEY_ID}
APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL}
CERT_PASSWORD=${CERT_PASSWORD}
PROFILE_URL=${PROFILE_URL}
CERT_CER_URL=${CERT_CER_URL}
CERT_KEY_URL=${CERT_KEY_URL}
APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER}
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

# Start signing setup
log "Starting iOS signing configuration"

# Validate required variables
if [ -z "$CERT_CER_URL" ] || [ -z "$CERT_KEY_URL" ] || [ -z "$CERT_PASSWORD" ] || [ -z "$PROFILE_URL" ]; then
    handle_error "Missing required signing variables"
fi

# Create necessary directories
mkdir -p ios/QuikApp/Supporting\ Files
mkdir -p ios/QuikApp/Provisioning\ Profiles

# Download certificates and profiles
log "Downloading certificates and profiles"

# Download distribution certificate
curl -L "$CERT_CER_URL" -o ios/QuikApp/Supporting\ Files/distribution.cer || handle_error "Failed to download distribution certificate"

# Download private key
curl -L "$CERT_KEY_URL" -o ios/QuikApp/Supporting\ Files/private.key || handle_error "Failed to download private key"

# Download provisioning profile
curl -L "$PROFILE_URL" -o ios/QuikApp/Provisioning\ Profiles/profile.mobileprovision || handle_error "Failed to download provisioning profile"

# Create keychain
log "Creating keychain"
security create-keychain -p "$CERT_PASSWORD" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "$CERT_PASSWORD" build.keychain
security set-keychain-settings -t 3600 -u build.keychain

# Import certificates
log "Importing certificates"
security import ios/QuikApp/Supporting\ Files/distribution.cer -k build.keychain -T /usr/bin/codesign
security import ios/QuikApp/Supporting\ Files/private.key -k build.keychain -P "$CERT_PASSWORD" -T /usr/bin/codesign

# Install provisioning profile
log "Installing provisioning profile"
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp ios/QuikApp/Provisioning\ Profiles/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

# Update project configuration
log "Updating project configuration"
cat > ios/QuikApp.xcodeproj/project.pbxproj << EOF
// !$*UTF8*$!
{
    archiveVersion = 1;
    classes = {
    };
    objectVersion = 56;
    objects = {
        /* Begin PBXProject section */
        1A2B3C4D5E6F7G8H9I0J1K2L /* Project object */ = {
            isa = PBXProject;
            attributes = {
                LastSwiftUpdateCheck = 1500;
                LastUpgradeCheck = 1500;
                TargetAttributes = {
                    9I8H7G6F5E4D3C2B1A0J9K8L7M6N5O4P = {
                        DevelopmentTeam = $APPLE_TEAM_ID;
                        ProvisioningStyle = Manual;
                    };
                };
            };
            buildConfigurationList = 1A2B3C4D5E6F7G8H9I0J1K2L /* Build configuration list for PBXProject */;
            compatibilityVersion = "Xcode 14.0";
            developmentRegion = en;
            hasScannedForEncodings = 0;
            knownRegions = (
                en,
                Base,
            );
            mainGroup = 1A2B3C4D5E6F7G8H9I0J1K2L;
            productRefGroup = 1A2B3C4D5E6F7G8H9I0J1K2L /* Products */;
            projectDirPath = "";
            projectRoot = "";
            targets = (
                9I8H7G6F5E4D3C2B1A0J9K8L7M6N5O4P /* QuikApp */,
            );
        };
        /* End PBXProject section */
    };
    rootObject = 1A2B3C4D5E6F7G8H9I0J1K2L /* Project object */;
}
EOF

# Update export options
log "Creating export options"
cat > ios/exportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>profile</string>
    </dict>
</dict>
</plist>
EOF

log "Signing configuration completed successfully"
exit 0 