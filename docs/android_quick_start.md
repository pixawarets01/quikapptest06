# QuikApp Android Build Quick Start Guide

## Common Use Cases

### 1. Android Free Build (Basic APK)

```yaml
# Required Variables
APP_ID: "com.example.myapp"
PKG_NAME: "com.example.myapp"
APP_NAME: "My App"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
ORG_NAME: "My Company"
WEB_URL: "https://example.com"
EMAIL_ID: "developer@example.com"
USER_NAME: "Developer Name"

# Fixed Values (Cannot be changed)
PUSH_NOTIFY: "false"
IS_DOMAIN_URL: "false"

# Optional Features
IS_CHATBOT: "true"
IS_SPLASH: "true"
IS_PULLDOWN: "true"
IS_BOTTOMMENU: "true"
IS_LOAD_IND: "true"

# Optional Permissions
IS_CAMERA: "false"
IS_LOCATION: "false"
IS_MIC: "false"
IS_NOTIFICATION: "false"
IS_CONTACT: "false"
IS_BIOMETRIC: "false"
IS_CALENDAR: "false"
IS_STORAGE: "false"

# Branding
LOGO_URL: "https://example.com/logo.png"
SPLASH_URL: "https://example.com/splash.png"
SPLASH_BG_URL: "https://example.com/splash_bg.png"
SPLASH_BG_COLOR: "#FFFFFF"
SPLASH_TAGLINE: "Welcome to My App"
SPLASH_TAGLINE_COLOR: "#000000"
SPLASH_ANIMATION: "fade"
SPLASH_DURATION: "3000"
```

### 2. Android Paid Build (APK with Firebase)

```yaml
# Required Variables (Same as Free Build)
APP_ID: "com.example.myapp"
PKG_NAME: "com.example.myapp"
APP_NAME: "My App"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
# ... other basic variables ...

# Firebase Configuration
PUSH_NOTIFY: "true"
FIREBASE_CONFIG_ANDROID: "https://example.com/google-services.json"

# Deep Linking (Available in Paid)
IS_DOMAIN_URL: "true"
# Optional Features & Permissions
# ... same as Free Build ...
```

### 3. Android Publish Build (Signed APK/AAB)

```yaml
# Required Variables (Same as Paid Build)
APP_ID: "com.example.myapp"
PKG_NAME: "com.example.myapp"
# ... other basic variables ...

# Firebase Configuration
PUSH_NOTIFY: "true"
FIREBASE_CONFIG_ANDROID: "https://example.com/google-services.json"

# Keystore Configuration
KEY_STORE_URL: "https://example.com/keystore.jks"
CM_KEYSTORE_PASSWORD: "your_keystore_password"
CM_KEY_ALIAS: "key_alias"
CM_KEY_PASSWORD: "key_password"
```

## Firebase Configuration

### When PUSH_NOTIFY is "true":

- Requires valid `FIREBASE_CONFIG_ANDROID` URL
- Downloads and configures google-services.json
- Adds Firebase dependencies to build.gradle
- Configures Firebase in the app
- Enables FCM for push notifications

### When PUSH_NOTIFY is "false":

- Firebase configuration is skipped
- No Firebase dependencies added
- Smaller APK size and faster builds

## Keystore Configuration

### Required Variables for Release Signing

| Variable               | Required | Description          | Example                            |
| ---------------------- | -------- | -------------------- | ---------------------------------- |
| `KEY_STORE_URL`        | Yes      | URL to keystore file | "https://example.com/keystore.jks" |
| `CM_KEYSTORE_PASSWORD` | Yes      | Keystore password    | "password123"                      |
| `CM_KEY_ALIAS`         | Yes      | Key alias name       | "key0"                             |
| `CM_KEY_PASSWORD`      | Yes      | Key password         | "password123"                      |

### Signing Process

When keystore is configured:

1. Downloads keystore file
2. Creates keystore.properties
3. Configures signing in build.gradle.kts
4. Enables AAB generation
5. Signs both APK and AAB

### Signing Requirements

1. Valid keystore file (.jks)
2. Correct keystore credentials
3. Proper key alias
4. Matching key password

## Quick Steps

1. **Prepare Keystore** (for Publish Build)

   ```bash
   # Generate keystore
   keytool -genkey -v -keystore my-release-key.jks -keyalg RSA \
           -keysize 2048 -validity 10000 -alias my-key-alias

   # View keystore details
   keytool -list -v -keystore my-release-key.jks
   ```

2. **Host Files**

   - Upload keystore to secure URL (for Publish Build)
   - Host google-services.json (if using Firebase)
   - Ensure files are accessible via HTTPS
   - Keep credentials secure

3. **Configure Variables**

   - Copy appropriate template from above
   - Replace placeholder values
   - Add to Codemagic environment variables
   - Set PUSH_NOTIFY based on requirements

4. **Run Build**

   - Select appropriate workflow
   - Start build
   - Monitor progress via email notifications

## Common Commands

### Check APK Signing

```bash
# View APK signing info
jarsigner -verify -verbose -certs app-release.apk

# Check APK contents
unzip -l app-release.apk

# Verify APK
apksigner verify app-release.apk
```

### Check Firebase Setup

```bash
# Verify google-services.json
cat android/app/google-services.json | jq .

# Check Firebase dependencies
grep -r "com.google.firebase" android/app/build.gradle.kts
```

### Check App Configuration

```bash
# View AndroidManifest.xml
cat android/app/src/main/AndroidManifest.xml

# Check package name
grep applicationId android/app/build.gradle.kts

# View permissions
grep "uses-permission" android/app/src/main/AndroidManifest.xml
```

### Build Commands

```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

## Environment Setup

### Flutter Configuration

```bash
# Flutter version: 3.32.2
flutter --version

# Set Java version
export JAVA_HOME=/path/to/java-17
java -version  # Should show version 17
```

### Build Machine Specs

- Instance Type: mac_mini_m2
- Build Duration: 60 minutes max
- Flutter: 3.32.2
- Java: 17

## Build Process Details

### 1. Environment Setup

```bash
# Set execution permissions
chmod +x lib/scripts/android/*.sh
chmod +x lib/scripts/utils/*.sh

# Run main script
./lib/scripts/android/main.sh
```

### 2. Build Steps

1. **Asset Management**

   - Downloads app icon
   - Configures splash screen
   - Sets up branding elements

2. **App Customization**

   - Updates package name
   - Configures app name
   - Sets up app icon

3. **Permissions Setup**

   - Configures AndroidManifest.xml
   - Adds required permissions
   - Sets up features

4. **Firebase Integration**

   - Downloads google-services.json
   - Updates build.gradle.kts
   - Configures Firebase

5. **Keystore Setup**

   - Downloads keystore
   - Creates keystore.properties
   - Configures signing

6. **Build Generation**
   - Builds release APK
   - Generates AAB (if keystore configured)
   - Copies to output directory

## Output Artifacts

### Android Free & Paid

- Location: `build/app/outputs/flutter-apk/app-release.apk`
- Signing: Debug signing only
- Size: ~15-20MB (varies with features)

### Android Publish

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- Signing: Release signing with provided keystore
- Size: ~15-30MB (varies with features)

## Email Notifications

### Configuration

```yaml
ENABLE_EMAIL_NOTIFICATIONS: "true"
EMAIL_SMTP_SERVER: "smtp.gmail.com"
EMAIL_SMTP_PORT: "587"
EMAIL_SMTP_USER: "your-email@gmail.com"
EMAIL_SMTP_PASS: "your-app-password"
```

### Notification Types

1. Build Started
2. Build Success (with artifact links)
3. Build Failed (with error details)

## Next Steps

1. Set up Firebase project (if using push notifications)
2. Generate and secure keystore (for Publish builds)
3. Configure email notifications
4. Test debug builds
5. Verify release signing
6. Submit to Play Store (for Publish builds)

## Common Issues

### 1. Keystore Issues

- Verify keystore URL is accessible
- Check keystore credentials
- Ensure keystore format is valid
- Verify key alias exists

### 2. Firebase Issues

- Validate google-services.json
- Check package name matches
- Verify Firebase project setup
- Confirm dependencies in build.gradle

### 3. Build Issues

- Check Flutter version (3.32.2)
- Verify Java version (17)
- Validate all required variables
- Check script permissions

### 4. Permission Issues

- Verify AndroidManifest.xml
- Check permission flags
- Validate feature declarations
- Test runtime permissions
