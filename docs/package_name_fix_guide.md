# Package Name Fix Guide for AAB Upload

## Issue Description

You're getting this error when uploading AAB to Google Play Console:

```
Your APK or Android App Bundle needs to have the package name [YOUR_PACKAGE_NAME].
```

This means the `PKG_NAME` environment variable is not being set correctly in Codemagic.

## Root Cause

The `PKG_NAME` environment variable in Codemagic is not set to your desired package name.

## Solution Steps

### 1. **Set PKG_NAME in Codemagic Environment Variables**

Go to your Codemagic project settings and add these environment variables:

#### **For Android Workflows:**

```
PKG_NAME = [YOUR_ANDROID_PACKAGE_NAME]
```

#### **For iOS Workflows:**

```
BUNDLE_ID = [YOUR_IOS_BUNDLE_ID]
```

#### **For Combined Workflow:**

```
PKG_NAME = [YOUR_ANDROID_PACKAGE_NAME]
BUNDLE_ID = [YOUR_IOS_BUNDLE_ID]
```

**Examples:**

- `PKG_NAME = com.mycompany.myapp`
- `BUNDLE_ID = com.mycompany.myapp`
- `PKG_NAME = com.example.testapp`
- `BUNDLE_ID = com.example.testapp`

### 2. **Verify Environment Variables in codemagic.yaml**

The codemagic.yaml is already correctly configured:

```yaml
# Android workflows
PKG_NAME: $PKG_NAME

# iOS workflows
BUNDLE_ID: $BUNDLE_ID

# Combined workflow
PKG_NAME: $PKG_NAME
BUNDLE_ID: $BUNDLE_ID
```

### 3. **Check Current Package Name Configuration**

Run this command to see current package name:

```bash
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts
```

**Expected Output:**

```bash
applicationId = "[YOUR_PACKAGE_NAME]"
```

**Current Output (Problem):**

```bash
applicationId = "com.example.quikapptest06"
```

### 4. **How the Package Name Update Works**

The build process updates the package name in this order:

1. **Version Management** (`lib/scripts/android/version_management.sh`):

   - Uses `$PKG_NAME` environment variable
   - Updates `build.gradle.kts` with correct package name

2. **Main Script** (`lib/scripts/android/main.sh`):

   - Generates `build.gradle.kts` with `${PKG_NAME:-default}` pattern
   - Ensures package name is set correctly

3. **Customization** (`lib/scripts/android/customization.sh`):
   - Verifies package name updates
   - Updates app name and icon

### 5. **Verification Commands**

#### **Check Environment Variables:**

```bash
echo "PKG_NAME: ${PKG_NAME:-NOT_SET}"
echo "BUNDLE_ID: ${BUNDLE_ID:-NOT_SET}"
```

#### **Check Android Configuration:**

```bash
# Check applicationId
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts

# Check namespace
grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts
```

#### **Check iOS Configuration:**

```bash
# Check CFBundleIdentifier
grep -A1 -B1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string
```

### 6. **Expected Results After Fix**

#### **Android (build.gradle.kts):**

```kotlin
android {
    namespace = "[YOUR_PACKAGE_NAME]"
    defaultConfig {
        applicationId = "[YOUR_PACKAGE_NAME]"
    }
}
```

#### **iOS (Info.plist):**

```xml
<key>CFBundleIdentifier</key>
<string>[YOUR_BUNDLE_ID]</string>
```

### 7. **Workflow-Specific Package Names**

All workflows should use the same package name for Firebase connectivity:

| Workflow            | Package Name          | Purpose          |
| ------------------- | --------------------- | ---------------- |
| **android-free**    | `[YOUR_PACKAGE_NAME]` | Basic testing    |
| **android-paid**    | `[YOUR_PACKAGE_NAME]` | Firebase testing |
| **android-publish** | `[YOUR_PACKAGE_NAME]` | Production       |
| **ios-appstore**    | `[YOUR_BUNDLE_ID]`    | App Store        |
| **ios-adhoc**       | `[YOUR_BUNDLE_ID]`    | Ad Hoc testing   |
| **combined**        | `[YOUR_PACKAGE_NAME]` | Both platforms   |

### 8. **Troubleshooting**

#### **Issue: PKG_NAME still not updating**

**Solution:**

1. Check if `PKG_NAME` is set in Codemagic environment variables
2. Ensure the variable name is exactly `PKG_NAME` (case sensitive)
3. Rebuild the project after setting the variable

#### **Issue: Build still uses old package name**

**Solution:**

1. Clear build cache: `flutter clean`
2. Delete build artifacts: `rm -rf build/`
3. Rebuild with correct environment variables

#### **Issue: AAB upload still fails**

**Solution:**

1. Verify the AAB was built with correct package name
2. Check Google Play Console app configuration
3. Ensure package name matches exactly

### 9. **Verification Script**

Run the verification script to check package names:

```bash
chmod +x lib/scripts/utils/verify_package_names.sh
lib/scripts/utils/verify_package_names.sh
```

This will generate a detailed report in `package_name_report.txt`.

### 10. **Complete Fix Checklist**

- [ ] Set `PKG_NAME = [YOUR_PACKAGE_NAME]` in Codemagic environment variables
- [ ] Set `BUNDLE_ID = [YOUR_BUNDLE_ID]` in Codemagic environment variables
- [ ] Verify variables are set correctly
- [ ] Run a test build to confirm package name updates
- [ ] Check generated AAB has correct package name
- [ ] Upload AAB to Google Play Console

## Summary

The issue is that the `PKG_NAME` environment variable is not set to your desired package name in your Codemagic project. Once you set this variable correctly, all workflows will use the correct package name and your AAB upload will succeed.

**Key Points:**

- ✅ codemagic.yaml is correctly configured
- ✅ Build scripts are correctly implemented
- ❌ Environment variable `PKG_NAME` needs to be set in Codemagic
- ❌ Current package name is `com.example.quikapptest06` instead of your desired package name

Set the environment variable to your desired package name and rebuild! 🚀
