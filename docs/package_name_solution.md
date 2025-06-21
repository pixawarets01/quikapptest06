# Package Name Solution - Generic Guide

## 🚨 Issue Summary

You're getting this error when uploading AAB to Google Play Console:

```
Your APK or Android App Bundle needs to have the package name [YOUR_PACKAGE_NAME].
```

## 🔍 Root Cause

The `PKG_NAME` and `BUNDLE_ID` environment variables are not set in Codemagic.

## ✅ Solution

### Step 1: Set Environment Variables in Codemagic

Go to your Codemagic project settings → Environment Variables and add:

| Variable    | Value                         | Description                |
| ----------- | ----------------------------- | -------------------------- |
| `PKG_NAME`  | `[YOUR_ANDROID_PACKAGE_NAME]` | Your Android package name  |
| `BUNDLE_ID` | `[YOUR_IOS_BUNDLE_ID]`        | Your iOS bundle identifier |

**Examples:**

- `PKG_NAME = com.mycompany.myapp`
- `BUNDLE_ID = com.mycompany.myapp`
- `PKG_NAME = com.example.testapp`
- `BUNDLE_ID = com.example.testapp`

### Step 2: Verify Configuration

The `codemagic.yaml` is already correctly configured:

```yaml
# Android workflows
PKG_NAME: $PKG_NAME

# iOS workflows
BUNDLE_ID: $BUNDLE_ID

# Combined workflow
PKG_NAME: $PKG_NAME
BUNDLE_ID: $BUNDLE_ID
```

### Step 3: Build Process

When you run a build with the correct environment variables:

1. **Android builds** will use `$PKG_NAME` for:

   - `applicationId` in `build.gradle.kts`
   - `namespace` in `build.gradle.kts`

2. **iOS builds** will use `$BUNDLE_ID` for:
   - `CFBundleIdentifier` in `Info.plist`

## 🧪 Testing

### Before Fix

```bash
# Current package name
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts
# Output: applicationId = "com.example.quikapptest06"
```

### After Fix

```bash
# Expected package name
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts
# Output: applicationId = "[YOUR_PACKAGE_NAME]"
```

## 📊 Workflow Impact

All workflows will use the same package name for Firebase connectivity:

| Workflow            | Package Name          | Status                 |
| ------------------- | --------------------- | ---------------------- |
| **android-free**    | `[YOUR_PACKAGE_NAME]` | ✅ Will work after fix |
| **android-paid**    | `[YOUR_PACKAGE_NAME]` | ✅ Will work after fix |
| **android-publish** | `[YOUR_PACKAGE_NAME]` | ✅ Will work after fix |
| **ios-appstore**    | `[YOUR_BUNDLE_ID]`    | ✅ Will work after fix |
| **ios-adhoc**       | `[YOUR_BUNDLE_ID]`    | ✅ Will work after fix |
| **combined**        | `[YOUR_PACKAGE_NAME]` | ✅ Will work after fix |

## 🚀 Quick Fix Checklist

- [ ] **Set `PKG_NAME = [YOUR_PACKAGE_NAME]`** in Codemagic environment variables
- [ ] **Set `BUNDLE_ID = [YOUR_BUNDLE_ID]`** in Codemagic environment variables
- [ ] **Run a test build** to verify package name updates
- [ ] **Check generated AAB** has correct package name
- [ ] **Upload AAB** to Google Play Console

## 🔧 Verification Commands

Run these commands to verify the fix:

```bash
# Test package name configuration
lib/scripts/utils/test_package_name.sh

# Full verification (generates report)
lib/scripts/utils/verify_package_names.sh
```

## 📝 Summary

**The Issue**: Environment variables `PKG_NAME` and `BUNDLE_ID` are not set in Codemagic.

**The Solution**: Set both variables to your desired package names in Codemagic environment variables.

**The Result**: All workflows will generate apps with the correct package name, and AAB upload will succeed.

---

**Next Steps**:

1. Set the environment variables in Codemagic to your desired package names
2. Run a test build
3. Verify the package name is correct
4. Upload AAB to Google Play Console

The build system is already configured correctly - it just needs the environment variables to be set! 🎯
