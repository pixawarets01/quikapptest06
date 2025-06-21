# QuikApp Platform - Dynamic User Build Configuration

## 🚀 **Platform Overview**

**QuikApp** (`app.quikapp.co`) is a platform that converts user websites into native mobile apps (Android & iOS) using **Codemagic CI/CD** as the build backend.

### **How It Works:**

1. **User Input**: Users provide their website URL, app details, certificates, and preferences
2. **Dynamic Configuration**: QuikApp platform injects user-specific variables into Codemagic
3. **Automated Build**: Codemagic builds custom Android APK/AAB and iOS IPA files
4. **Delivery**: Users receive download links via email notifications

---

## 📋 **Supported Workflows**

### **Android Workflows:**

- **`android-free`**: Basic APK (no Firebase, debug signing)
- **`android-paid`**: APK with Firebase (debug signing)
- **`android-publish`**: APK + AAB with Firebase and custom keystore (production ready)

### **iOS Workflows:**

- **`ios-appstore`**: App Store distribution IPA
- **`ios-adhoc`**: Ad Hoc distribution IPA

### **Universal Workflow:**

- **`combined`**: Builds both Android (APK+AAB) and iOS (IPA) simultaneously

---

## 🔧 **Dynamic Environment Variables**

All user-specific configuration is passed via **Codemagic environment variables**:

### **📱 App Metadata**

```yaml
APP_ID: $APP_ID # Unique app identifier
APP_NAME: $APP_NAME # Display name (e.g., "My Business App")
ORG_NAME: $ORG_NAME # Organization name
WEB_URL: $WEB_URL # Website URL to convert
VERSION_NAME: $VERSION_NAME # App version (e.g., "1.0.0")
VERSION_CODE: $VERSION_CODE # Build number
EMAIL_ID: $EMAIL_ID # User email for notifications
USER_NAME: $USER_NAME # User name
```

### **📦 Package Identifiers**

```yaml
PKG_NAME: $PKG_NAME # Android package (e.g., "com.company.app")
BUNDLE_ID: $BUNDLE_ID # iOS bundle ID (e.g., "com.company.app")
```

### **🎨 UI/Branding Configuration**

```yaml
LOGO_URL: $LOGO_URL # App icon URL
SPLASH_URL: $SPLASH_URL # Splash screen image URL
SPLASH_BG_URL: $SPLASH_BG_URL # Splash background image URL
SPLASH_BG_COLOR: $SPLASH_BG_COLOR # Splash background color
SPLASH_TAGLINE: $SPLASH_TAGLINE # Splash screen tagline
SPLASH_TAGLINE_COLOR: $SPLASH_TAGLINE_COLOR
SPLASH_ANIMATION: $SPLASH_ANIMATION # Animation type
SPLASH_DURATION: $SPLASH_DURATION # Animation duration
```

### **⚡ Feature Toggles**

```yaml
PUSH_NOTIFY: $PUSH_NOTIFY # Enable Firebase push notifications
IS_CHATBOT: $IS_CHATBOT # Enable chatbot feature
IS_DOMAIN_URL: $IS_DOMAIN_URL # Enable deep linking
IS_SPLASH: $IS_SPLASH # Enable splash screen
IS_PULLDOWN: $IS_PULLDOWN # Enable pull-to-refresh
IS_BOTTOMMENU: $IS_BOTTOMMENU # Enable bottom navigation
IS_LOAD_IND: $IS_LOAD_IND # Enable loading indicators
```

### **🔐 Permissions**

```yaml
IS_CAMERA: $IS_CAMERA # Camera access
IS_LOCATION: $IS_LOCATION # GPS location access
IS_MIC: $IS_MIC # Microphone access
IS_NOTIFICATION: $IS_NOTIFICATION # Push notification permission
IS_CONTACT: $IS_CONTACT # Contacts access
IS_BIOMETRIC: $IS_BIOMETRIC # Fingerprint/Face ID
IS_CALENDAR: $IS_CALENDAR # Calendar access
IS_STORAGE: $IS_STORAGE # File storage access
```

### **🔥 Firebase Configuration**

```yaml
FIREBASE_CONFIG_ANDROID: $FIREBASE_CONFIG_ANDROID # Android google-services.json (Base64)
FIREBASE_CONFIG_IOS: $FIREBASE_CONFIG_IOS # iOS GoogleService-Info.plist (Base64)
```

### **🔐 Android Signing (Production)**

```yaml
KEY_STORE_URL: $KEY_STORE_URL # Keystore file URL
CM_KEYSTORE_PASSWORD: $CM_KEYSTORE_PASSWORD # Keystore password
CM_KEY_ALIAS: $CM_KEY_ALIAS # Key alias
CM_KEY_PASSWORD: $CM_KEY_PASSWORD # Key password
```

### **🍎 iOS Signing**

```yaml
APPLE_TEAM_ID: $APPLE_TEAM_ID # Apple Developer Team ID
CERT_PASSWORD: $CERT_PASSWORD # Certificate password
PROFILE_URL: $PROFILE_URL # Provisioning profile URL
CERT_P12_URL: $CERT_P12_URL # P12 certificate URL (Option 1)
# OR
CERT_CER_URL: $CERT_CER_URL # CER certificate URL (Option 2)
CERT_KEY_URL: $CERT_KEY_URL # Private key URL (Option 2)
PROFILE_TYPE: "app-store" # Profile type (app-store/ad-hoc)
```

---

## 🏗️ **Build Process Flow**

### **1. Environment Setup**

- Codemagic receives user variables from QuikApp platform
- Scripts validate required variables for selected workflow
- Dynamic configuration files are generated

### **2. Asset Download**

- Downloads user logos, splash screens, icons from provided URLs
- Validates file integrity and formats
- Optimizes images for mobile platforms

### **3. Dynamic Configuration**

- **Android**: Generates `build.gradle.kts` with user's `PKG_NAME`
- **iOS**: Updates `Info.plist` with user's `BUNDLE_ID` and `APP_NAME`
- **Permissions**: Configures AndroidManifest.xml and Info.plist based on feature flags

### **4. Platform-Specific Setup**

- **Firebase**: Decodes and installs user's Firebase config files
- **Signing**: Downloads and configures user's certificates/keystores
- **Customization**: Applies user branding and feature settings

### **5. Build Execution**

- **Android**: Builds APK (free/paid) or APK+AAB (publish)
- **iOS**: Builds signed IPA for App Store or Ad Hoc distribution
- **Combined**: Builds both platforms sequentially

### **6. Artifact Delivery**

- Copies built files to output directory
- Generates public download URLs (if enabled)
- Sends email notification with download links

---

## 📧 **Email Notification System**

### **Professional Email Templates:**

- **Build Started**: Confirmation with app details and configuration summary
- **Build Success**: Download links to APK/AAB/IPA files + deployment instructions
- **Build Failed**: Detailed troubleshooting guide with specific error context

### **Email Content Includes:**

- App configuration summary (features, permissions, integrations)
- Platform-specific details (package names, signing status)
- Download links with file sizes
- Next steps for app deployment
- Professional QuikApp branding

---

## 🔄 **Workflow Selection Logic**

The platform automatically selects the appropriate workflow based on user inputs:

```bash
# Android Workflow Selection
if [ "$PUSH_NOTIFY" = "false" ] && [ -z "$KEY_STORE_URL" ]; then
    WORKFLOW="android-free"      # Basic APK
elif [ "$PUSH_NOTIFY" = "true" ] && [ -z "$KEY_STORE_URL" ]; then
    WORKFLOW="android-paid"      # APK with Firebase
elif [ "$PUSH_NOTIFY" = "true" ] && [ -n "$KEY_STORE_URL" ]; then
    WORKFLOW="android-publish"   # Production APK+AAB
fi

# iOS Workflow Selection
if [ "$PROFILE_TYPE" = "app-store" ]; then
    WORKFLOW="ios-appstore"      # App Store distribution
elif [ "$PROFILE_TYPE" = "ad-hoc" ]; then
    WORKFLOW="ios-adhoc"         # Ad Hoc distribution
fi

# Universal Build
if [ -n "$PKG_NAME" ] && [ -n "$BUNDLE_ID" ]; then
    WORKFLOW="combined"          # Both Android + iOS
fi
```

---

## ✅ **Quality Assurance**

### **Automated Validation:**

- ✅ Required variables validation before build starts
- ✅ Asset integrity checking (file size, format, accessibility)
- ✅ Certificate/keystore validation with detailed error reporting
- ✅ Build artifact verification (APK/AAB/IPA file integrity)
- ✅ Signing verification for production builds

### **Error Handling:**

- ✅ Graceful fallbacks (debug signing if keystore fails)
- ✅ Detailed error reporting with troubleshooting steps
- ✅ Emergency cleanup on build failures
- ✅ Email notifications for all build outcomes

---

## 🚀 **Production Ready Features**

### **Performance Optimizations:**

- ✅ Parallel asset downloads and processing
- ✅ Gradle build acceleration with optimized JVM settings
- ✅ Flutter build caching and dependency management
- ✅ Xcode build optimizations for iOS

### **Security:**

- ✅ Base64 encoding for sensitive files (certificates, keystores)
- ✅ Secure credential handling with environment variables
- ✅ No hardcoded values - fully dynamic configuration
- ✅ Temporary file cleanup after builds

### **Reliability:**

- ✅ Comprehensive error handling and recovery
- ✅ Build timeout management (60-120 minutes)
- ✅ Resource optimization (memory, CPU, disk usage)
- ✅ Artifact URL generation with public access support

---

## 🎯 **Usage Example**

When a user submits their app configuration through `app.quikapp.co`, the platform:

1. **Collects user input**: Website URL, app name, package name, certificates, etc.
2. **Triggers Codemagic build** with user-specific environment variables
3. **Monitors build progress** and handles any errors gracefully
4. **Delivers results** via professional email with download links

**Result**: User receives a fully customized, production-ready mobile app built from their website!

---

## 📞 **Support & Documentation**

- **Platform**: https://app.quikapp.co
- **Website**: https://quikapp.co
- **Build System**: Fully automated via Codemagic CI/CD
- **Email Support**: Automated notifications with troubleshooting guides
