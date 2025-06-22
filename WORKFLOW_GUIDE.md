# QuikApp Workflow Initiation Guide

## 🚀 Quick Start

Your QuikApp project is configured with **6 comprehensive workflows** ready for immediate use in Codemagic:

## 📋 Available Workflows

### Android Workflows

1. **`android-free`** - Basic Android Build

   - ✅ Simple APK generation
   - ❌ No Firebase integration
   - ❌ No signing (debug only)
   - 🎯 **Use for**: Development, testing

2. **`android-paid`** - Firebase-Enabled Android Build

   - ✅ APK with Firebase integration
   - ✅ Push notifications support
   - ❌ No signing (debug only)
   - 🎯 **Use for**: Apps needing push notifications

3. **`android-publish`** - Production Android Build
   - ✅ APK + AAB generation
   - ✅ Firebase integration
   - ✅ Release signing with keystore
   - 🎯 **Use for**: Play Store distribution

### iOS Workflows

4. **`ios-appstore`** - App Store Distribution

   - ✅ Code-signed IPA
   - ✅ App Store provisioning profile
   - ✅ Firebase integration
   - 🎯 **Use for**: App Store submission

5. **`ios-adhoc`** - Ad Hoc Distribution
   - ✅ Code-signed IPA
   - ✅ Ad-hoc provisioning profile
   - ✅ Firebase integration
   - 🎯 **Use for**: Enterprise distribution

### Universal Workflow

6. **`combined`** - Multi-Platform Build
   - ✅ Android APK + AAB
   - ✅ iOS IPA
   - ✅ All integrations
   - 🎯 **Use for**: Simultaneous deployment

## 🔧 How to Initiate Workflows

### Method 1: Codemagic Web Interface

1. **Login to Codemagic**

   - Go to [codemagic.io](https://codemagic.io)
   - Login with your account

2. **Select Project**

   - Choose your QuikApp project
   - Navigate to the builds section

3. **Start Build**
   - Click "Start new build"
   - Select desired workflow from dropdown
   - Choose branch (usually `main`)
   - Click "Start build"

### Method 2: Codemagic API

```bash
# Set your API token
export CM_API_TOKEN="your_codemagic_api_token"

# Start Android Publish workflow
curl -X POST \
  https://api.codemagic.io/builds \
  -H "x-auth-token: $CM_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "appId": "your_app_id",
    "workflowId": "android-publish",
    "branch": "main"
  }'
```

### Method 3: GitHub Integration

1. **Push to Repository**

   - Push code to your GitHub repository
   - Codemagic will automatically detect changes

2. **Webhook Triggers**
   - Configure webhooks for automatic builds
   - Set up branch-specific triggers

## 🔑 Environment Variables Setup

### Required Variables (Set in Codemagic)

```yaml
# App Configuration
APP_ID: "1001"
APP_NAME: "Your App Name"
ORG_NAME: "Your Organization"
WEB_URL: "https://yourwebsite.com"
USER_NAME: "your-username"
EMAIL_ID: "your@email.com"

# Version Management
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
BRANCH: "main"

# Package Identifiers
PKG_NAME: "com.yourcompany.yourapp" # Android
BUNDLE_ID: "com.yourcompany.yourapp" # iOS

# Branding
LOGO_URL: "https://your-cdn.com/logo.png"
SPLASH_URL: "https://your-cdn.com/splash.png"
SPLASH_BG_COLOR: "#ffffff"

# Feature Flags
PUSH_NOTIFY: "true"
IS_CHATBOT: "true"
IS_SPLASH: "true"
IS_PULLDOWN: "true"
IS_BOTTOMMENU: "false"
IS_LOAD_IND: "true"

# Permissions
IS_CAMERA: "false"
IS_LOCATION: "false"
IS_MIC: "true"
IS_NOTIFICATION: "true"
IS_CONTACT: "false"
IS_BIOMETRIC: "false"
IS_CALENDAR: "false"
IS_STORAGE: "true"
```

### Android-Specific Variables

```yaml
# Firebase (for android-paid and android-publish)
FIREBASE_CONFIG_ANDROID: "https://your-cdn.com/google-services.json"

# Keystore (for android-publish only)
KEY_STORE_URL: "https://your-cdn.com/keystore.jks"
CM_KEYSTORE_PASSWORD: "your_keystore_password"
CM_KEY_ALIAS: "your_key_alias"
CM_KEY_PASSWORD: "your_key_password"
```

### iOS-Specific Variables

```yaml
# Firebase
FIREBASE_CONFIG_IOS: "https://your-cdn.com/GoogleService-Info.plist"

# Apple Developer
APPLE_TEAM_ID: "YOUR_TEAM_ID"
APNS_KEY_ID: "YOUR_APNS_KEY_ID"
APNS_AUTH_KEY_URL: "https://your-cdn.com/AuthKey.p8"

# Certificates (Option 1: P12 file)
CERT_P12_URL: "https://your-cdn.com/certificate.p12"
CERT_PASSWORD: "your_cert_password"

# Certificates (Option 2: CER + KEY files)
CERT_CER_URL: "https://your-cdn.com/certificate.cer"
CERT_KEY_URL: "https://your-cdn.com/certificate.key"
CERT_PASSWORD: "your_cert_password"

# Provisioning Profile
PROFILE_URL: "https://your-cdn.com/profile.mobileprovision"
PROFILE_TYPE: "app-store"  # or "ad-hoc"

# App Store Connect
APP_STORE_CONNECT_KEY_IDENTIFIER: "YOUR_KEY_ID"
```

## 📧 Email Notifications

All workflows include automatic email notifications:

- **Build Started**: Notification when build begins
- **Build Success**: Success notification with download links
- **Build Failed**: Failure notification with troubleshooting guide

Email configuration (already set in workflows):

```yaml
ENABLE_EMAIL_NOTIFICATIONS: "true"
EMAIL_SMTP_SERVER: "smtp.gmail.com"
EMAIL_SMTP_PORT: "587"
EMAIL_SMTP_USER: "prasannasrie@gmail.com"
EMAIL_SMTP_PASS: "your_app_password"
```

## 🎯 Workflow Selection Guide

### Choose Your Workflow Based on Need:

| Need                       | Recommended Workflow | Output             |
| -------------------------- | -------------------- | ------------------ |
| Quick testing              | `android-free`       | APK (debug)        |
| Push notifications testing | `android-paid`       | APK with Firebase  |
| Play Store release         | `android-publish`    | APK + AAB (signed) |
| App Store release          | `ios-appstore`       | IPA (App Store)    |
| Enterprise distribution    | `ios-adhoc`          | IPA (Ad Hoc)       |
| Deploy to both platforms   | `combined`           | APK + AAB + IPA    |

## 🔍 Build Monitoring

### Track Your Builds

1. **Codemagic Dashboard**

   - Real-time build logs
   - Build status indicators
   - Artifact download links

2. **Email Notifications**

   - Instant build status updates
   - Direct download links
   - Troubleshooting guides

3. **Build Artifacts**
   - Automatic artifact storage
   - Public download URLs
   - Build verification reports

## 🚨 Troubleshooting

### Common Issues

1. **Missing Environment Variables**

   - Check all required variables are set
   - Verify variable names match exactly
   - Ensure no typos in variable values

2. **Signing Issues (iOS)**

   - Verify certificate and provisioning profile URLs
   - Check certificate password
   - Ensure Apple Team ID is correct

3. **Keystore Issues (Android)**

   - Verify keystore URL is accessible
   - Check keystore password and alias
   - Ensure keystore is valid

4. **Firebase Issues**
   - Verify Firebase config file URLs
   - Check package name matches Firebase project
   - Ensure Firebase project is properly configured

### Getting Help

- Check build logs in Codemagic dashboard
- Review email notifications for specific error details
- Verify all environment variables are correctly set
- Test individual components (signing, Firebase) separately

## ✅ Pre-Launch Checklist

Before initiating your first production build:

- [ ] All environment variables configured
- [ ] Signing certificates uploaded and accessible
- [ ] Firebase projects configured (if using push notifications)
- [ ] App icons and splash screens uploaded
- [ ] Version numbers incremented appropriately
- [ ] Test builds completed successfully
- [ ] Email notifications working correctly

## 🎉 Ready to Build!

Your QuikApp workflows are fully configured and ready for production use. Simply:

1. Set your environment variables in Codemagic
2. Choose your desired workflow
3. Start the build
4. Monitor progress via dashboard or email
5. Download your artifacts when complete

**Happy building!** 🚀
