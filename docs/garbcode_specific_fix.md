# GarbCode App - Package Name Fix

## 🚨 Current Issue

You're building an app for **garbcode.com** and getting this error when uploading AAB to Google Play Console:

```
Your APK or Android App Bundle needs to have the package name com.garbcode.garbcodeapp.
```

## 🔍 Root Cause

The `PKG_NAME` environment variable in Codemagic is not set to `com.garbcode.garbcodeapp`.

## ✅ Solution

### Step 1: Set Environment Variables in Codemagic

Go to your Codemagic project settings → Environment Variables and add:

| Variable    | Value                      | Description                    |
| ----------- | -------------------------- | ------------------------------ |
| `PKG_NAME`  | `com.garbcode.garbcodeapp` | GarbCode Android package name  |
| `BUNDLE_ID` | `com.garbcode.garbcodeapp` | GarbCode iOS bundle identifier |

### Step 2: Verify Current Configuration

Run this command to see current package name:

```bash
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts
```

**Expected Output:**

```bash
applicationId = "com.garbcode.garbcodeapp"
```

**Current Output (Problem):**

```bash
applicationId = "com.example.quikapptest06"
```

### Step 3: Test the Fix

After setting the environment variables in Codemagic:

1. **Run a test build** in Codemagic
2. **Check the generated AAB** has the correct package name
3. **Upload to Google Play Console**

## 🧪 Verification Commands

### Check Environment Variables

```bash
echo "PKG_NAME: ${PKG_NAME:-NOT_SET}"
echo "BUNDLE_ID: ${BUNDLE_ID:-NOT_SET}"
```

### Check Android Configuration

```bash
# Check applicationId
grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts

# Check namespace
grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts
```

### Check iOS Configuration

```bash
# Check CFBundleIdentifier
grep -A1 -B1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string
```

## 📊 Expected Results

### Android (build.gradle.kts)

```kotlin
android {
    namespace = "com.garbcode.garbcodeapp"
    defaultConfig {
        applicationId = "com.garbcode.garbcodeapp"
    }
}
```

### iOS (Info.plist)

```xml
<key>CFBundleIdentifier</key>
<string>com.garbcode.garbcodeapp</string>
```

## 🚀 Quick Fix Checklist

- [ ] **Set `PKG_NAME = com.garbcode.garbcodeapp`** in Codemagic environment variables
- [ ] **Set `BUNDLE_ID = com.garbcode.garbcodeapp`** in Codemagic environment variables
- [ ] **Run a test build** to verify package name updates
- [ ] **Check generated AAB** has correct package name
- [ ] **Upload AAB** to Google Play Console

## 🔧 Verification Scripts

Run these commands to verify the fix:

```bash
# Test package name configuration
lib/scripts/utils/test_package_name.sh

# Full verification (generates report)
lib/scripts/utils/verify_package_names.sh
```

## 📝 Summary

**The Issue**: Environment variables `PKG_NAME` and `BUNDLE_ID` are not set to `com.garbcode.garbcodeapp` in Codemagic.

**The Solution**: Set both variables to `com.garbcode.garbcodeapp` in Codemagic environment variables.

**The Result**: All workflows will generate apps with the correct package name, and AAB upload will succeed.

---

**Next Steps**:

1. Set the environment variables in Codemagic to `com.garbcode.garbcodeapp`
2. Run a test build
3. Verify the package name is correct
4. Upload AAB to Google Play Console

The build system is already configured correctly - it just needs the environment variables to be set! 🎯
