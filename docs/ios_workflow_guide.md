# iOS Workflow Guide - App Store vs Ad Hoc Distribution

## Overview

This guide explains the iOS workflow structure in Codemagic, which has been split into two distinct workflows following Apple's official documentation for App Store and Ad Hoc distribution.

## 🍎 iOS Workflow Types

### 1. **iOS App Store Build** (`ios-appstore`)

- **Purpose**: Builds IPA files for App Store distribution
- **Profile Type**: `app-store`
- **Use Case**: Production releases to the App Store
- **Requirements**: App Store provisioning profile, distribution certificate

### 2. **iOS Ad Hoc Build** (`ios-adhoc`)

- **Purpose**: Builds IPA files for Ad Hoc distribution
- **Profile Type**: `ad-hoc`
- **Use Case**: Testing on specific devices, beta distribution
- **Requirements**: Ad Hoc provisioning profile, distribution certificate

## 🔄 Combined Workflow Types

### 3. **Combined Android & iOS Build** (`combined`)

- **Purpose**: Builds both Android (APK+AAB) and iOS (Ad Hoc IPA)
- **iOS Profile Type**: `ad-hoc`
- **Use Case**: Cross-platform testing and beta distribution

### 4. **Combined Android & iOS App Store Build** (`combined-appstore`)

- **Purpose**: Builds both Android (APK+AAB) and iOS (App Store IPA)
- **iOS Profile Type**: `app-store`
- **Use Case**: Cross-platform production releases

## 📋 Apple Documentation Compliance

### App Store Distribution Requirements

According to [Apple's App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/):

- ✅ **Provisioning Profile**: Must be "App Store" type
- ✅ **Code Signing**: Distribution certificate required
- ✅ **Bundle ID**: Must match App Store Connect
- ✅ **Version Management**: Proper version and build numbers
- ✅ **Metadata**: App name, description, screenshots
- ✅ **Privacy**: Privacy policy and data usage disclosure

### Ad Hoc Distribution Requirements

According to [Apple's Ad Hoc Distribution Guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases):

- ✅ **Provisioning Profile**: Must be "Ad Hoc" type
- ✅ **Device Registration**: Up to 100 devices per year
- ✅ **Code Signing**: Distribution certificate required
- ✅ **Bundle ID**: Must match provisioning profile
- ✅ **Installation**: Via TestFlight or direct installation

## 🛠️ Workflow Configuration

### Environment Variables

All iOS workflows support the following key variables:

```yaml
# Required for all iOS builds
APPLE_TEAM_ID: $APPLE_TEAM_ID
CERT_PASSWORD: $CERT_PASSWORD
PROFILE_URL: $PROFILE_URL
BUNDLE_ID: $BUNDLE_ID

# Certificate options (one of these combinations)
CERT_P12_URL: $CERT_P12_URL # Option 1: Pre-made P12
CERT_CER_URL: $CERT_CER_URL # Option 2: Certificate + Key
CERT_KEY_URL: $CERT_KEY_URL # Option 2: Certificate + Key

# App Store specific
APP_STORE_CONNECT_KEY_IDENTIFIER: $APP_STORE_CONNECT_KEY_IDENTIFIER

# Push notifications (if enabled)
PUSH_NOTIFY: $PUSH_NOTIFY
FIREBASE_CONFIG_IOS: $FIREBASE_CONFIG_IOS
APNS_KEY_ID: $APNS_KEY_ID
APNS_AUTH_KEY_URL: $APNS_AUTH_KEY_URL
```

### Profile Type Configuration

| Workflow            | Profile Type | Use Case                      |
| ------------------- | ------------ | ----------------------------- |
| `ios-appstore`      | `app-store`  | App Store distribution        |
| `ios-adhoc`         | `ad-hoc`     | Beta testing, device-specific |
| `combined`          | `ad-hoc`     | Cross-platform beta           |
| `combined-appstore` | `app-store`  | Cross-platform production     |

## 🚀 Usage Examples

### App Store Release

```bash
# Trigger App Store build
codemagic build --workflow ios-appstore

# Or combined App Store build
codemagic build --workflow combined-appstore
```

### Beta Testing

```bash
# Trigger Ad Hoc build for testing
codemagic build --workflow ios-adhoc

# Or combined Ad Hoc build
codemagic build --workflow combined
```

## 📱 Build Outputs

### iOS App Store Build

- **Artifacts**: `output/ios/Runner.ipa`
- **Profile Type**: `app-store`
- **Distribution**: App Store Connect
- **Installation**: App Store download

### iOS Ad Hoc Build

- **Artifacts**: `output/ios/Runner.ipa`
- **Profile Type**: `ad-hoc`
- **Distribution**: TestFlight or direct installation
- **Installation**: Device-specific installation

## 🔐 Security Considerations

### Certificate Management

- ✅ **P12 Files**: Encrypted with password protection
- ✅ **Certificate + Key**: Separate files for enhanced security
- ✅ **URL-based**: Secure download from trusted sources
- ✅ **Environment Variables**: Encrypted in Codemagic

### Provisioning Profile Security

- ✅ **Team ID Validation**: Ensures correct Apple Developer account
- ✅ **Bundle ID Matching**: Validates app identifier
- ✅ **Device Registration**: Ad Hoc profiles include specific devices
- ✅ **Expiration Handling**: Automatic renewal notifications

## 📊 Workflow Comparison

| Feature            | App Store   | Ad Hoc            |
| ------------------ | ----------- | ----------------- |
| **Distribution**   | App Store   | TestFlight/Direct |
| **Device Limit**   | Unlimited   | 100 devices/year  |
| **Review Process** | Required    | None              |
| **Installation**   | App Store   | Manual/TestFlight |
| **Use Case**       | Production  | Beta Testing      |
| **Profile Type**   | `app-store` | `ad-hoc`          |

## 🎯 Best Practices

### For App Store Builds

1. ✅ Use `ios-appstore` or `combined-appstore` workflows
2. ✅ Ensure App Store Connect setup is complete
3. ✅ Validate bundle ID matches App Store Connect
4. ✅ Test with TestFlight before App Store submission
5. ✅ Follow App Store Review Guidelines

### For Ad Hoc Builds

1. ✅ Use `ios-adhoc` or `combined` workflows
2. ✅ Register test devices in Apple Developer portal
3. ✅ Use TestFlight for easier distribution
4. ✅ Monitor device registration limits
5. ✅ Keep provisioning profiles updated

## 🔧 Troubleshooting

### Common Issues

1. **Profile Type Mismatch**

   - **Error**: "Provisioning profile doesn't match bundle identifier"
   - **Solution**: Ensure `PROFILE_TYPE` matches workflow type

2. **Certificate Issues**

   - **Error**: "Code signing is required for product type"
   - **Solution**: Verify certificate files and password

3. **Device Registration**

   - **Error**: "Device not registered in provisioning profile"
   - **Solution**: Add device UDID to Ad Hoc profile

4. **Bundle ID Mismatch**
   - **Error**: "Bundle identifier doesn't match provisioning profile"
   - **Solution**: Ensure `BUNDLE_ID` matches profile

## 📞 Support

For issues with iOS builds:

1. Check Codemagic build logs for specific errors
2. Verify Apple Developer account settings
3. Ensure all required variables are set
4. Contact support with build ID and error details

---

_This guide follows Apple's official documentation for iOS app distribution and is regularly updated to maintain compliance._
