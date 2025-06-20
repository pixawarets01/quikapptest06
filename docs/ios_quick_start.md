# QuikApp iOS Build Quick Start Guide

## Common Use Cases

### 1. App Store Build with TestFlight Upload

```yaml
# Required Variables
PROFILE_TYPE: "app-store"
BUNDLE_ID: "com.company.appname"
APP_NAME: "My App"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
APPLE_TEAM_ID: "ABCD12345E"
CERT_PASSWORD: "your_password"
PROFILE_URL: "https://example.com/appstore.mobileprovision"

# Certificate (Option 1 - P12)
CERT_P12_URL: "https://example.com/cert.p12"

# TestFlight Configuration
IS_TESTFLIGHT: "true"
APP_STORE_CONNECT_KEY_IDENTIFIER: "F5229W2Q8S"
APNS_KEY_ID: "your_apns_key_id"
APNS_AUTH_KEY_URL: "https://example.com/AuthKey.p8"

# Optional: Push Notifications
PUSH_NOTIFY: "true"
FIREBASE_CONFIG_IOS: "https://example.com/GoogleService-Info.plist"
```

### 2. App Store Build (Production) without Push Notifications

```yaml
# Required Variables
PROFILE_TYPE: "app-store"
BUNDLE_ID: "com.company.appname"
APP_NAME: "My App"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
APPLE_TEAM_ID: "ABCD12345E"
CERT_PASSWORD: "your_password"
PROFILE_URL: "https://example.com/appstore.mobileprovision"

# Certificate (Option 1 - P12)
CERT_P12_URL: "https://example.com/cert.p12"

# Disable Push Notifications
PUSH_NOTIFY: "false"
# Note: FIREBASE_CONFIG_IOS not required when PUSH_NOTIFY is false
```

### 3. Ad-Hoc Build with OTA Installation and Push Notifications

```yaml
# Required Variables
PROFILE_TYPE: "ad-hoc"
BUNDLE_ID: "com.company.appname"
APP_NAME: "My App"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
APPLE_TEAM_ID: "ABCD12345E"
CERT_PASSWORD: "your_password"
PROFILE_URL: "https://example.com/adhoc.mobileprovision"

# Certificate (P12 recommended)
CERT_P12_URL: "https://example.com/cert.p12"

# Push Notifications
PUSH_NOTIFY: "true"
FIREBASE_CONFIG_IOS: "https://example.com/GoogleService-Info.plist"

# OTA Installation
INSTALL_URL: "https://example.com/app.ipa"
DISPLAY_IMAGE_URL: "https://example.com/icon.png"
FULL_SIZE_IMAGE_URL: "https://example.com/image.png"

# Optional: Device-Specific Builds
ENABLE_DEVICE_SPECIFIC_BUILDS: "true"
THINNING: "thin-for-all-variants"
```

### 4. Development Build (Ad-Hoc without Push)

```yaml
# Required Variables
PROFILE_TYPE: "ad-hoc"
BUNDLE_ID: "com.company.appname"
APP_NAME: "My App Dev"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
APPLE_TEAM_ID: "ABCD12345E"
CERT_PASSWORD: "your_password"
PROFILE_URL: "https://example.com/dev.mobileprovision"

# Certificate (Either option works)
CERT_P12_URL: "https://example.com/cert.p12"

# Explicitly disable push notifications
PUSH_NOTIFY: "false"
```

## Push Notification Configuration

### When PUSH_NOTIFY is "true":

- Requires valid `FIREBASE_CONFIG_IOS` URL
- Configures Firebase in the app
- Adds push notification capabilities
- Updates Info.plist for background modes
- Adds Firebase dependencies to Podfile

### When PUSH_NOTIFY is "false":

- Firebase configuration is skipped
- No push notification capabilities added
- No Firebase dependencies in Podfile
- Smaller app size and faster builds

## TestFlight Configuration

### Required Variables for TestFlight

| Variable                           | Required | Description                      | Example                          |
| ---------------------------------- | -------- | -------------------------------- | -------------------------------- |
| `IS_TESTFLIGHT`                    | Yes      | Enable TestFlight upload         | "true"                           |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Yes      | App Store Connect API Key ID     | "F5229W2Q8S"                     |
| `APPLE_TEAM_ID`                    | Yes      | Apple Developer Team ID          | "ABCD12345E"                     |
| `APNS_KEY_ID`                      | Yes      | APNs Key ID                      | "ABC123DEF"                      |
| `APNS_AUTH_KEY_URL`                | Yes      | URL to App Store Connect API Key | "https://example.com/AuthKey.p8" |

### TestFlight Upload Process

When `IS_TESTFLIGHT="true"` and `PROFILE_TYPE="app-store"`:

1. Validates required TestFlight variables
2. Downloads App Store Connect API Key
3. Configures API credentials
4. Uploads IPA to TestFlight
5. Cleans up temporary files

### TestFlight Requirements

1. App Store provisioning profile
2. App Store Connect API Key
3. Valid bundle identifier
4. Proper version and build numbers

## Quick Steps

1. **Prepare Certificates**

   ```bash
   # Export P12 from Keychain Access
   # OR
   # Export Certificate and Key files
   ```

2. **Host Files**

   - Upload certificates and profiles to secure URL
   - Ensure files are accessible via HTTPS
   - If using push notifications, host Firebase config file

3. **Configure Variables**

   - Copy appropriate template from above
   - Replace placeholder values
   - Add to Codemagic environment variables
   - Set PUSH_NOTIFY based on requirements

4. **Run Build**

   - Select appropriate workflow
   - Start build
   - Monitor progress via email notifications

5. **TestFlight Upload** (if enabled)
   - Ensure `IS_TESTFLIGHT="true"`
   - Configure App Store Connect API Key
   - Set required TestFlight variables
   - Monitor upload progress in logs

## Common Commands

### Check Certificate Info

```bash
# View certificate details
openssl x509 -in cert.cer -inform DER -text

# Verify P12 file
openssl pkcs12 -info -in cert.p12 -noout
```

### Generate Installation URL

```bash
# For Ad-Hoc builds with OTA
echo "itms-services://?action=download-manifest&url=https://example.com/manifest.plist"
```

### Verify Provisioning Profile

```bash
# View profile details
security cms -D -i profile.mobileprovision
```

### Check Push Notification Setup

```bash
# Verify Firebase config
plutil -p ios/Runner/GoogleService-Info.plist

# Check push capabilities in Info.plist
plutil -p ios/Runner/Info.plist | grep UIBackgroundModes
```

### Check TestFlight Configuration

```bash
# Verify API Key
cat ios/keys/AuthKey_*.p8

# Check upload status
xcrun altool --list-apps \
  --apiKey "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
  --apiIssuer "$APPLE_TEAM_ID"
```

## Next Steps

1. Read the full [iOS Build Guide](ios_build_guide.md)
2. Set up email notifications
3. Configure Firebase (if using push notifications)
4. Test OTA installation (for Ad-Hoc)
5. Test push notifications (if enabled)
6. Monitor TestFlight upload (if enabled)
