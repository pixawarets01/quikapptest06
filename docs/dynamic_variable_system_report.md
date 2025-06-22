# Dynamic Variable System Report

## 🎯 **System Overview**

The QuikApp build system is designed to use **exact environment variables** from your API response, with **no hardcoded values**. All configuration comes dynamically from the API call.

## 📋 **API Variable Mapping**

### **Core App Variables**

```json
{
  "VERSION_NAME": "1.0.6", // Used directly in all scripts
  "VERSION_CODE": "32", // Used directly in all scripts
  "APP_NAME": "Garbcode App", // Used for app display name
  "PKG_NAME": "com.garbcode.garbcodeapp", // Android package name
  "BUNDLE_ID": "com.garbcode.garbcodeapp", // iOS bundle identifier
  "ORG_NAME": "Garbcode Apparels Private Limited",
  "WEB_URL": "https://garbcode.com/",
  "EMAIL_ID": "prasannasrinivasan32@gmail.com",
  "USER_NAME": "prasannasrie"
}
```

### **Feature Flags**

```json
{
  "PUSH_NOTIFY": "true", // Firebase push notifications
  "IS_CHATBOT": "true", // AI chatbot integration
  "IS_DOMAIN_URL": "true", // Deep linking support
  "IS_SPLASH": "true", // Splash screen
  "IS_PULLDOWN": "true", // Pull to refresh
  "IS_BOTTOMMENU": "false", // Bottom navigation
  "IS_LOAD_IND": "true" // Loading indicators
}
```

### **Permission Flags**

```json
{
  "IS_CAMERA": "false", // Camera permission
  "IS_LOCATION": "false", // Location permission
  "IS_MIC": "true", // Microphone permission
  "IS_NOTIFICATION": "true", // Notification permission
  "IS_CONTACT": "false", // Contacts permission
  "IS_BIOMETRIC": "false", // Biometric permission
  "IS_CALENDAR": "false", // Calendar permission
  "IS_STORAGE": "true" // Storage permission
}
```

## 🔧 **How Dynamic Variables Work**

### **1. Version Management Flow**

```bash
# API provides:
VERSION_NAME="1.0.6"
VERSION_CODE="32"

# Scripts use these exactly:
lib/scripts/android/version_management.sh:
├── final_version_name="$VERSION_NAME"     # 1.0.6
├── final_version_code="$VERSION_CODE"     # 32
└── Updates pubspec.yaml: version: 1.0.6+32

lib/scripts/android/main.sh:
├── Generates build.gradle.kts with:
├── versionCode = ${VERSION_CODE:-1}       # 32
└── versionName = "${VERSION_NAME:-1.0.0}" # "1.0.6"
```

### **2. Package Name Flow**

```bash
# API provides:
PKG_NAME="com.garbcode.garbcodeapp"

# Scripts use this exactly:
lib/scripts/android/main.sh:
├── applicationId = "${PKG_NAME:-com.example.quikapptest06}"
└── namespace = "${PKG_NAME:-com.example.quikapptest06}"

lib/scripts/android/update_package_name.sh:
├── NEW_PACKAGE_NAME="${PKG_NAME:-com.example.quikapptest06}"
└── Updates AndroidManifest.xml with exact value
```

### **3. Build Process with Dynamic Variables**

#### **Step 1: Environment Setup**

```bash
# All variables from API are set as environment variables
export VERSION_NAME="1.0.6"
export VERSION_CODE="32"
export PKG_NAME="com.garbcode.garbcodeapp"
# ... all other API variables
```

#### **Step 2: Version Management**

```bash
# lib/scripts/android/version_management.sh
├── Reads exact API values
├── Updates pubspec.yaml: version: 1.0.6+32
└── Updates build.gradle.kts with exact values
```

#### **Step 3: Build Script Generation**

```bash
# lib/scripts/android/main.sh
├── Generates build.gradle.kts using ${PKG_NAME}, ${VERSION_CODE}, ${VERSION_NAME}
├── No hardcoded values - all from API
└── Falls back to defaults only if API values missing
```

#### **Step 4: Package Name Updates**

```bash
# lib/scripts/android/update_package_name.sh
├── Uses ${PKG_NAME} from API
├── Updates all Android files with exact package name
└── Ensures AndroidManifest.xml has correct package attribute
```

## 📊 **Variable Usage Matrix**

| API Variable | Used In                         | Purpose          | Example Value              |
| ------------ | ------------------------------- | ---------------- | -------------------------- |
| VERSION_NAME | version_management.sh, main.sh  | App version      | "1.0.6"                    |
| VERSION_CODE | version_management.sh, main.sh  | Build number     | "32"                       |
| PKG_NAME     | main.sh, update_package_name.sh | Android package  | "com.garbcode.garbcodeapp" |
| BUNDLE_ID    | ios scripts, combined workflow  | iOS bundle       | "com.garbcode.garbcodeapp" |
| APP_NAME     | customization.sh                | App display name | "Garbcode App"             |
| WORKFLOW_ID  | All scripts                     | Build type       | "android-publish"          |

## 🔄 **Execution Flow**

### **Android Workflows (android-free, android-paid, android-publish)**

```bash
1. API Call → Environment Variables Set
2. version_management.sh → Uses exact VERSION_NAME, VERSION_CODE
3. main.sh → Generates build.gradle.kts with ${VERSION_CODE}, ${VERSION_NAME}
4. update_package_name.sh → Uses exact PKG_NAME
5. Build → APK/AAB with correct values from API
```

### **iOS Workflows (ios-appstore, ios-adhoc)**

```bash
1. API Call → Environment Variables Set
2. pubspec.yaml → Updated with VERSION_NAME+VERSION_CODE
3. iOS build → Uses pubspec.yaml version
4. Build → IPA with correct values from API
```

### **Combined Workflow**

```bash
1. API Call → Environment Variables Set
2. Android: Uses exact PKG_NAME, VERSION_NAME, VERSION_CODE
3. iOS: Uses exact BUNDLE_ID, VERSION_NAME, VERSION_CODE
4. Build → Both APK/AAB and IPA with correct values from API
```

## ✅ **No Hardcoded Values**

### **What's Dynamic (from API):**

- ✅ VERSION_NAME (1.0.6)
- ✅ VERSION_CODE (32)
- ✅ PKG_NAME (com.garbcode.garbcodeapp)
- ✅ BUNDLE_ID (com.garbcode.garbcodeapp)
- ✅ APP_NAME (Garbcode App)
- ✅ All feature flags (PUSH_NOTIFY, IS_CHATBOT, etc.)
- ✅ All permission flags (IS_CAMERA, IS_MIC, etc.)
- ✅ All branding URLs (LOGO_URL, SPLASH_URL, etc.)

### **What's Static (fallback defaults only):**

- ✅ Default values if API doesn't provide them
- ✅ Flutter SDK versions
- ✅ Android SDK versions
- ✅ Build tool configurations

## 🎯 **Expected Results with Your API**

### **API Input:**

```json
{
  "VERSION_NAME": "1.0.6",
  "VERSION_CODE": "32",
  "PKG_NAME": "com.garbcode.garbcodeapp",
  "APP_NAME": "Garbcode App"
}
```

### **Build Output:**

```bash
[PKG_VERIFY] 📊 Additional APK Information:
[PKG_VERIFY]    📋 Version Name: 1.0.6  ✅ (Exact from API)
[PKG_VERIFY]    📋 Version Code: 32     ✅ (Exact from API)
[PKG_VERIFY]    📋 App Label: Garbcode App ✅ (Exact from API)
[PKG_VERIFY]    📋 Package Name: com.garbcode.garbcodeapp ✅ (Exact from API)
```

## 🔧 **Variable Processing**

### **Environment Variable Pattern:**

```bash
# All scripts use this pattern:
VARIABLE_NAME="${API_VARIABLE_NAME:-default_fallback}"

# Examples:
PKG_NAME="${PKG_NAME:-com.example.quikapptest06}"
VERSION_NAME="${VERSION_NAME:-1.0.0}"
VERSION_CODE="${VERSION_CODE:-1}"
```

### **Build.gradle.kts Generation:**

```kotlin
// Generated dynamically with API values:
defaultConfig {
    applicationId = "${PKG_NAME:-com.example.quikapptest06}"  // com.garbcode.garbcodeapp
    versionCode = ${VERSION_CODE:-1}                         // 32
    versionName = "${VERSION_NAME:-1.0.0}"                   // "1.0.6"
}
```

## 🎉 **Conclusion**

The QuikApp build system is **100% dynamic** and uses **exact values from your API**:

1. **No Hardcoding**: All values come from API environment variables
2. **Exact Values**: VERSION_NAME=1.0.6 and VERSION_CODE=32 are used exactly
3. **Fallback Safety**: Default values only used if API doesn't provide them
4. **Cross-Platform**: Same API variables work for Android and iOS
5. **All Workflows**: android-free, android-paid, android-publish, ios-appstore, ios-adhoc, combined

Your next build will show **exactly** the values you specify in your API call! 🚀

---

**Status**: ✅ **FULLY DYNAMIC SYSTEM**  
**Date**: 2025-06-21  
**Impact**: Perfect - All values from API, no hardcoding
