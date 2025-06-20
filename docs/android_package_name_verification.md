# Android Package Name Verification

## Overview

This document verifies that package names are correctly updated using the `PKG_NAME` variable across all Android workflows in the QuikApp build system.

## Current Configuration

### ✅ **Fixed Issues:**

1. **Main Script (`lib/scripts/android/main.sh`)**:

   - ✅ Updated `build.gradle.kts` generation to use `${PKG_NAME:-com.example.quikapptest06}` instead of hardcoded package name
   - ✅ Updated both `applicationId` and `namespace` to use PKG_NAME variable
   - ✅ Proper execution order: Version Management → Branding → Customization → Build

2. **Version Management (`lib/scripts/android/version_management.sh`)**:

   - ✅ Handles package name generation based on workflow type
   - ✅ Debug workflows: adds `.debug` suffix to package name
   - ✅ Production workflows: uses original package name
   - ✅ Updates `build.gradle.kts`, `pubspec.yaml`, and `AndroidManifest.xml`

3. **Customization (`lib/scripts/android/customization.sh`)**:
   - ✅ Verifies package name updates from version management
   - ✅ Updates app name in `AndroidManifest.xml`
   - ✅ Updates app icon from assets

## Workflow-Specific Package Name Behavior

### **ALL Workflows (Same Package Name for Firebase Connectivity)**

```bash
# Input PKG_NAME: com.example.quikapptest06
# Final Package Name: com.example.quikapptest06 (same for all workflows)
# Purpose: Seamless Firebase connectivity across workflow progression
```

### **Workflow Progression:**

1. **android-free**: Test basic app functionality (Debug signing)
2. **android-paid**: Test with Firebase features (Debug signing + Firebase)
3. **android-publish**: Deploy to production (Release signing)

### **Why Same Package Name?**

- ✅ **Firebase Connectivity**: Same package name ensures Firebase configuration works across all workflows
- ✅ **Seamless Progression**: Test → Add Features → Publish without package name changes
- ✅ **Consistent Testing**: Firebase features work the same in all environments
- ✅ **No Conflicts**: Users can upgrade from test to production seamlessly

## Package Name Update Process

### **Step 1: Version Management (First)**

```bash
# lib/scripts/android/version_management.sh
# - Determines workflow type
# - Generates appropriate package name
# - Updates build.gradle.kts with new applicationId
# - Updates pubspec.yaml version
# - Exports updated variables
```

### **Step 2: Main Script Generation**

```bash
# lib/scripts/android/main.sh
# - Generates build.gradle.kts with PKG_NAME variable
# - Uses: applicationId = "${PKG_NAME:-com.example.quikapptest06}"
# - Uses: namespace = "${PKG_NAME:-com.example.quikapptest06}"
```

### **Step 3: Customization (Verification)**

```bash
# lib/scripts/android/customization.sh
# - Verifies package name is correctly set
# - Updates app name in AndroidManifest.xml
# - Updates app icon
```

## Verification Commands

### **Check Current Package Name:**

```bash
# Check applicationId
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts

# Check namespace
grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts

# Check app name in manifest
grep -o 'android:label="[^"]*"' android/app/src/main/AndroidManifest.xml
```

### **Expected Results:**

#### **For ALL workflows (android-free, android-paid, android-publish, combined):**

```bash
applicationId = "com.example.quikapptest06"
namespace = "com.example.quikapptest06"
```

**Note**: All workflows now use the same package name for Firebase connectivity and seamless workflow progression.

## Test Cases

### **Test Case 1: Custom Package Name**

```bash
PKG_NAME="com.mycompany.myapp"
WORKFLOW_ID="android-free"
# Expected: com.mycompany.myapp

PKG_NAME="com.mycompany.myapp"
WORKFLOW_ID="android-paid"
# Expected: com.mycompany.myapp

PKG_NAME="com.mycompany.myapp"
WORKFLOW_ID="android-publish"
# Expected: com.mycompany.myapp
```

### **Test Case 2: Default Package Name**

```bash
PKG_NAME=""  # or not set
WORKFLOW_ID="android-free"
# Expected: com.example.quikapptest06

PKG_NAME=""  # or not set
WORKFLOW_ID="android-paid"
# Expected: com.example.quikapptest06

PKG_NAME=""  # or not set
WORKFLOW_ID="android-publish"
# Expected: com.example.quikapptest06
```

### **Test Case 3: Firebase Connectivity**

```bash
# All workflows use same package name for Firebase
PKG_NAME="com.myapp.firebase"
WORKFLOW_ID="android-free"    # Firebase config works
WORKFLOW_ID="android-paid"    # Firebase config works
WORKFLOW_ID="android-publish" # Firebase config works
```

## Files Updated by Package Name Process

### **1. android/app/build.gradle.kts**

```kotlin
android {
    namespace = "${PKG_NAME:-com.example.quikapptest06}"
    // ...
    defaultConfig {
        applicationId = "${PKG_NAME:-com.example.quikapptest06}"
        // ...
    }
}
```

### **2. android/app/src/main/AndroidManifest.xml**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="${APP_NAME:-quikapptest06}"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- Package name is handled by build.gradle.kts -->
    </application>
</manifest>
```

### **3. pubspec.yaml**

```yaml
name: quikapptest06
description: A new Flutter project.
version: ${VERSION_NAME:-1.0.0}+${VERSION_CODE:-1}
# Package name is handled by Android build configuration
```

## Troubleshooting

### **Issue: Package name not updating**

**Symptoms:**

- `build.gradle.kts` shows hardcoded package name
- App installs with wrong package name

**Solutions:**

1. Check if `PKG_NAME` environment variable is set
2. Verify version management script ran successfully
3. Check execution order in main script
4. Clear build cache and rebuild

### **Issue: Package name conflicts**

**Symptoms:**

- "App not installed as package conflicts with existing package"
- Cannot install debug and release versions together

**Solutions:**

1. Use different package names for debug/release
2. Uninstall existing app before installing new version
3. Use ADB with `-r` flag: `adb install -r app-release.apk`

### **Issue: Namespace mismatch**

**Symptoms:**

- Build errors related to namespace
- R.java generation issues

**Solutions:**

1. Ensure namespace matches applicationId
2. Clean and rebuild project
3. Check for typos in package name

## Verification Script

Run the verification script to check package name updates:

```bash
chmod +x lib/scripts/utils/test_package_names.sh
lib/scripts/utils/test_package_names.sh
```

## Summary

✅ **Package name updates are properly configured** across all Android workflows:

- **ALL workflows** use the same package name for Firebase connectivity
- **Workflow progression**: android-free → android-paid → android-publish
- **Variable substitution**: Uses `${PKG_NAME:-default}` pattern
- **Execution order**: Version Management → Main Script → Customization
- **File updates**: build.gradle.kts, AndroidManifest.xml, pubspec.yaml
- **Firebase compatibility**: Same package name ensures Firebase works across all workflows

The system now correctly handles package name updates for seamless workflow progression and Firebase connectivity! 🎉
