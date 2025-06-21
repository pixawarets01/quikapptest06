# Dynamic Package Name Update System

## Overview

The QuikApp platform now includes an automated package name update system that dynamically replaces any old package names with the user's specified `PKG_NAME` environment variable. This ensures that apps built through the platform always use the correct package name regardless of the template's original package name.

## Features

### 🔄 Dynamic Package Name Detection

- Automatically scans for common default package names
- Only updates files that actually contain old package names
- Preserves existing correct package names

### 📦 Comprehensive File Updates

- **AndroidManifest.xml** files (main, debug, profile)
- **build.gradle.kts** applicationId and namespace
- **Java/Kotlin** package declarations and directory structure
- **iOS files** (for combined workflows)

### 🛡️ Safe Operation

- Creates backups before major changes
- Only processes files that exist
- Cleans up empty directories after package moves
- Cross-platform compatible (macOS and Linux)

## Integration Points

### Android Workflows

The package name update runs automatically in all Android workflows:

- `android-free`
- `android-paid`
- `android-publish`

### Combined Workflow

Also runs for the combined workflow and updates both:

- Android package name (`PKG_NAME`)
- iOS bundle identifier (`BUNDLE_ID`)

## Script Location

```bash
lib/scripts/android/update_package_name.sh
```

## Environment Variables

### Required

- `PKG_NAME`: Target Android package name (e.g., `com.garbcode.garbcodeapp`)

### Optional

- `BUNDLE_ID`: Target iOS bundle identifier (for combined workflows)
- `WORKFLOW_ID`: Set to "combined" for combined workflows

## Execution Flow

### 1. Detection Phase

```bash
[PKG_UPDATE] 🔄 Starting dynamic package name update for QuikApp platform
[PKG_UPDATE] 📦 Target package name: com.garbcode.garbcodeapp
[PKG_UPDATE] 🔍 Scanning for old package names to replace...
```

### 2. Update Phase

For each old package name found:

```bash
[PKG_UPDATE] 📦 Found com.example.quikapptest06 - updating to com.garbcode.garbcodeapp
[PKG_UPDATE] 🔧 Updating main AndroidManifest.xml: android/app/src/main/AndroidManifest.xml
[PKG_UPDATE]    ✅ Updated com.example.quikapptest06 → com.garbcode.garbcodeapp
[PKG_UPDATE] 🔧 Updating build.gradle.kts applicationId: android/app/build.gradle.kts
[PKG_UPDATE]    ✅ Updated com.example.quikapptest06 → com.garbcode.garbcodeapp
```

### 3. Directory Restructure

```bash
[PKG_UPDATE] 🔧 Updating Java package directory: android/app/src/main/java/com/example/quikapptest06 → android/app/src/main/java/com/garbcode/garbcodeapp
[PKG_UPDATE] 🧹 Removing empty directory: android/app/src/main/java/com/example/quikapptest06
```

### 4. Cleanup Phase

```bash
[PKG_UPDATE] 🧹 Cleaning up build artifacts after package name changes...
[PKG_UPDATE] ✅ Package name update completed successfully
[PKG_UPDATE] 📦 All references updated to: com.garbcode.garbcodeapp
```

## Supported Old Package Names

The script automatically detects and updates these common package names:

- `com.example.quikapptest06` (current template)
- `com.example.myapp`
- `com.myapp.app`
- `com.mynewapp.app`
- `com.example.flutter_app`
- `com.example.app`

## Files Updated

### Android Manifest Files

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/debug/AndroidManifest.xml` (if exists)
- `android/app/src/profile/AndroidManifest.xml` (if exists)

### Build Configuration

- `android/app/build.gradle.kts` (applicationId and namespace)
- `android/app/build.gradle` (applicationId - if exists)

### Java/Kotlin Files

- Package declarations in `.java` and `.kt` files
- Directory structure reorganization
- Automatic cleanup of empty directories

### iOS Files (Combined Workflow Only)

- `ios/Runner.xcodeproj/project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER)
- `ios/Runner/Info.plist` (CFBundleIdentifier)

## Build Integration

### Android Main Script

```bash
# Update package names dynamically (replaces any old package names with PKG_NAME)
log "📦 Running dynamic package name update..."
if [ -f "lib/scripts/android/update_package_name.sh" ]; then
    chmod +x lib/scripts/android/update_package_name.sh
    if lib/scripts/android/update_package_name.sh; then
        log "✅ Package name update completed"
    else
        log "❌ Package name update failed"
        exit 1
    fi
else
    log "⚠️ Package name update script not found, skipping..."
fi
```

### Combined Main Script

```bash
# Update package names dynamically (replaces any old package names with PKG_NAME/BUNDLE_ID)
log "📦 Running dynamic package name update for combined workflow..."
if [ -f "lib/scripts/android/update_package_name.sh" ]; then
    chmod +x lib/scripts/android/update_package_name.sh
    # Set WORKFLOW_ID for the script to know it's a combined workflow
    export WORKFLOW_ID="combined"
    if lib/scripts/android/update_package_name.sh; then
        log "✅ Package name update completed for both Android and iOS"
    else
        log "❌ Package name update failed"
        exit 1
    fi
else
    log "⚠️ Package name update script not found, skipping..."
fi
```

## Execution Order

The package name update runs early in the build process:

1. **Environment Setup** - Force fix env_config.dart, generate environment
2. **Version Management** - Resolve package conflicts
3. **📦 Package Name Update** - ← **NEW STEP**
4. **Asset Download** - Branding and custom icons
5. **Customization** - App name, icons
6. **Permissions** - Configure platform permissions
7. **Firebase/Keystore** - Platform-specific setup
8. **Build** - Generate APK/AAB/IPA

## Error Handling

### Graceful Fallback

- If no old package names are found, the script completes successfully
- Missing files are skipped without errors
- Directory operations are safe and atomic

### Build Integration

- Script failure stops the build process
- Detailed logging for troubleshooting
- Clean error messages in build logs

## Cross-Platform Compatibility

### macOS (Local Development)

```bash
# macOS requires empty string after -i
sed -i '' "s|${old_pkg}|${new_pkg}|g" "$file_path"
```

### Linux (Codemagic CI/CD)

```bash
# Linux doesn't need empty string
sed -i "s|${old_pkg}|${new_pkg}|g" "$file_path"
```

## Benefits

### 🚀 Automation

- No manual package name updates required
- Works with any user's package name
- Consistent across all workflows

### 🛡️ Safety

- Only updates files that need changes
- Preserves correct existing package names
- Comprehensive backup and cleanup

### 📱 Platform Support

- Android package names
- iOS bundle identifiers (combined workflow)
- Java and Kotlin file support

### 🔧 Maintenance

- Easily extensible for new package name patterns
- Centralized update logic
- Comprehensive logging for debugging

## Usage Examples

### Codemagic Environment Variables

```yaml
environment:
  PKG_NAME: "com.garbcode.garbcodeapp"
  BUNDLE_ID: "com.garbcode.garbcodeapp" # For iOS in combined workflow
```

### Local Testing

```bash
export PKG_NAME="com.test.myapp"
bash lib/scripts/android/update_package_name.sh
```

### Combined Workflow

```bash
export PKG_NAME="com.company.androidapp"
export BUNDLE_ID="com.company.iosapp"
export WORKFLOW_ID="combined"
bash lib/scripts/android/update_package_name.sh
```

## Troubleshooting

### Common Issues

1. **No Changes Made**

   - Check if `PKG_NAME` environment variable is set
   - Verify the current package name isn't already correct

2. **sed Errors**

   - Script automatically handles macOS vs Linux differences
   - Check file permissions

3. **Directory Move Failures**
   - Ensure target directories don't already exist
   - Check file system permissions

### Debug Mode

```bash
bash -x lib/scripts/android/update_package_name.sh
```

This comprehensive system ensures that every QuikApp build uses the correct package name specified by the user, eliminating manual configuration errors and ensuring consistent app identity across all builds.
