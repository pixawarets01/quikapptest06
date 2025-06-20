# Complete Workflow Summary

## Overview

This document provides a comprehensive overview of all workflows available in the QuikApp Codemagic configuration, featuring the new **Universal Combined Workflow** that automatically detects and configures all Android and iOS build combinations.

## 📱 Android Workflows (3)

### 1. **android-free**

- **Purpose**: Free Android build without Firebase or keystore
- **Entry Point**: `lib/scripts/android/main.sh`
- **Features**:
  - ✅ APK only
  - ❌ No Firebase integration
  - ❌ No keystore signing (debug signing)
  - ✅ Email notifications
  - ✅ Asset customization
  - ✅ Permission configuration
- **Output**: `output/android/app-release.apk`
- **Use Case**: Development testing, free tier apps

### 2. **android-paid**

- **Purpose**: Paid Android build with Firebase integration
- **Entry Point**: `lib/scripts/android/main.sh`
- **Features**:
  - ✅ APK only
  - ✅ Firebase integration
  - ❌ No keystore signing (debug signing)
  - ✅ Email notifications
  - ✅ Asset customization
  - ✅ Permission configuration
- **Output**: `output/android/app-release.apk`
- **Use Case**: Apps with push notifications, Firebase features

### 3. **android-publish**

- **Purpose**: Production Android build with full signing
- **Entry Point**: `lib/scripts/android/main.sh`
- **Features**:
  - ✅ APK + AAB
  - ✅ Firebase integration
  - ✅ Keystore signing
  - ✅ Email notifications
  - ✅ Asset customization
  - ✅ Permission configuration
- **Output**: `output/android/app-release.apk` + `output/android/app-release.aab`
- **Use Case**: Production releases, Google Play Store

## 🍎 iOS Workflows (2)

### 4. **ios-appstore**

- **Purpose**: iOS App Store distribution build
- **Entry Point**: `lib/scripts/ios/main.sh`
- **Features**:
  - ✅ App Store provisioning profile
  - ✅ Distribution certificate signing
  - ✅ Firebase integration (if enabled)
  - ✅ Email notifications
  - ✅ Asset customization
  - ✅ Permission configuration
- **Output**: `output/ios/Runner.ipa`
- **Use Case**: App Store releases, production distribution

### 5. **ios-adhoc**

- **Purpose**: iOS Ad Hoc distribution build
- **Entry Point**: `lib/scripts/ios/main.sh`
- **Features**:
  - ✅ Ad Hoc provisioning profile
  - ✅ Distribution certificate signing
  - ✅ Firebase integration (if enabled)
  - ✅ Email notifications
  - ✅ Asset customization
  - ✅ Permission configuration
- **Output**: `output/ios/Runner.ipa`
- **Use Case**: Beta testing, TestFlight, device-specific distribution

## 🔄 Universal Combined Workflow (1)

### 6. **combined** ⭐ **NEW - UNIVERSAL**

- **Purpose**: **Universal combined build** that automatically detects and configures all Android and iOS combinations
- **Entry Point**: `lib/scripts/combined/main.sh`
- **Features**:
  - ✅ **Smart Android Detection**: APK only vs APK+AAB based on keystore availability
  - ✅ **Smart iOS Detection**: Ad Hoc vs App Store based on profile type
  - ✅ **Smart Firebase Detection**: Enabled/disabled based on PUSH_NOTIFY and config availability
  - ✅ **Smart Feature Detection**: All feature flags automatically configured
  - ✅ **Universal Signing**: Debug vs release signing automatically selected
  - ✅ **Email notifications**
  - ✅ **Asset customization**
  - ✅ **Permission configuration**
- **Output**:
  - Android: `output/android/app-release.apk` (always) + `output/android/app-release.aab` (if keystore)
  - iOS: `output/ios/Runner.ipa` (if iOS prerequisites met)
- **Use Case**: **All use cases** - development, beta, production, with any combination of features

## 📊 Workflow Comparison Matrix

| Workflow          | Platform | Signing      | Firebase | Profile Type | Output  | Use Case                  |
| ----------------- | -------- | ------------ | -------- | ------------ | ------- | ------------------------- |
| `android-free`    | Android  | Debug        | ❌       | N/A          | APK     | Development, free apps    |
| `android-paid`    | Android  | Debug        | ✅       | N/A          | APK     | Beta with Firebase        |
| `android-publish` | Android  | Release      | ✅       | N/A          | APK+AAB | Production, Play Store    |
| `ios-appstore`    | iOS      | Distribution | ✅       | app-store    | IPA     | App Store release         |
| `ios-adhoc`       | iOS      | Distribution | ✅       | ad-hoc       | IPA     | Beta testing, TestFlight  |
| `combined`        | Both     | Auto         | Auto     | Auto         | Auto    | **Universal - All cases** |

## 🎯 Use Case Recommendations

### **For Specific Use Cases:**

- **Android Only Development**: `android-free`
- **Android Only with Firebase**: `android-paid`
- **Android Production**: `android-publish`
- **iOS App Store Release**: `ios-appstore`
- **iOS Beta Testing**: `ios-adhoc`

### **For Universal/Flexible Use Cases:**

- **Any Combination**: `combined` ⭐ **RECOMMENDED**

## 🚀 Universal Combined Workflow - Smart Detection

### **Android Auto-Detection:**

```bash
# Firebase Detection
if PUSH_NOTIFY=true AND FIREBASE_CONFIG_ANDROID exists:
    → Enable Firebase for Android

# Keystore Detection
if KEY_STORE_URL + CM_KEYSTORE_PASSWORD + CM_KEY_ALIAS + CM_KEY_PASSWORD exist:
    → Build APK + AAB with release signing
else:
    → Build APK only with debug signing
```

### **iOS Auto-Detection:**

```bash
# iOS Build Prerequisites
if BUNDLE_ID + APPLE_TEAM_ID + CERT_PASSWORD + PROFILE_URL exist:
    → Enable iOS build

    # Certificate Detection
    if CERT_P12_URL exists OR (CERT_CER_URL + CERT_KEY_URL exist):
        → Proceed with iOS build
    else:
        → Disable iOS build (missing certificates)

# Profile Type Detection
if PROFILE_TYPE is specified:
    → Use specified profile type
elif APP_STORE_CONNECT_KEY_IDENTIFIER exists:
    → Use "app-store" profile type
else:
    → Use "ad-hoc" profile type (default)
```

## 🔧 Technical Features

### All Workflows Include

- ✅ **Safe Environment Variables**: Whitelist approach for Flutter builds
- ✅ **Email Notifications**: Build started, success, and failure emails
- ✅ **Asset Management**: Logo, splash screen, custom icons
- ✅ **Customization**: App name, package/bundle ID, icons
- ✅ **Permissions**: Dynamic permission configuration
- ✅ **Build Optimization**: JVM settings, Gradle optimization
- ✅ **Error Handling**: Comprehensive error recovery
- ✅ **Artifact Management**: Proper copying and verification

### Universal Combined Workflow Features

- ✅ **Smart Configuration Detection**: Automatically detects all build requirements
- ✅ **Flexible Output**: Adapts output based on available resources
- ✅ **Feature Flag Support**: All feature flags automatically configured
- ✅ **Cross-Platform Intelligence**: Handles both platforms intelligently
- ✅ **Fallback Mechanisms**: Graceful degradation when resources unavailable

### iOS-Specific Features

- ✅ **Profile Type Detection**: Automatic workflow-based profile selection
- ✅ **Certificate Handling**: Support for P12 and CER+KEY combinations
- ✅ **Code Signing**: Distribution certificate signing
- ✅ **Provisioning**: App Store and Ad Hoc profile support

### Android-Specific Features

- ✅ **Keystore Management**: Automatic keystore setup and validation
- ✅ **Build Types**: Debug and release signing options
- ✅ **Version Management**: Package conflict resolution
- ✅ **Gradle Optimization**: Enhanced build performance

## 🚀 Getting Started

### Prerequisites

1. **Apple Developer Account**: For iOS workflows
2. **Google Play Console**: For Android production workflows
3. **Firebase Project**: For push notification workflows
4. **Codemagic Account**: For CI/CD execution

### Required Variables

- **Common**: `APP_ID`, `VERSION_NAME`, `VERSION_CODE`, `APP_NAME`
- **Android**: `PKG_NAME`, `KEY_STORE_URL` (for publish)
- **iOS**: `BUNDLE_ID`, `APPLE_TEAM_ID`, `CERT_PASSWORD`, `PROFILE_URL`
- **Firebase**: `FIREBASE_CONFIG_ANDROID`, `FIREBASE_CONFIG_IOS`

### Quick Start Commands

```bash
# Universal build (recommended)
codemagic build --workflow combined

# Specific workflows
codemagic build --workflow android-free
codemagic build --workflow ios-adhoc
codemagic build --workflow android-publish
```

## 📚 Documentation

- **Universal Combined Workflow**: `docs/universal_combined_workflow.md` ⭐
- **iOS Workflow Guide**: `docs/ios_workflow_guide.md`
- **Android Quick Start**: `docs/android_quick_start.md`
- **Build Optimization**: `docs/build_time_optimization_report.md`

## 🎯 Recommendation

**Use the `combined` workflow for maximum flexibility!**

It automatically adapts to your app's requirements and can handle:

- ✅ Development builds
- ✅ Beta testing builds
- ✅ Production releases
- ✅ Any combination of features
- ✅ Cross-platform builds
- ✅ Single platform builds

The universal workflow eliminates the need to choose between multiple workflows and automatically configures everything based on your environment variables.

---

_This configuration follows Apple's official documentation for iOS distribution and Google's guidelines for Android app publishing, with the universal combined workflow providing maximum flexibility and automation._
