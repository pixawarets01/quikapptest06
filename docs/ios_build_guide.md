# iOS Build Guide for QuikApp

## Table of Contents

- [Overview](#overview)
- [Build Types](#build-types)
- [Required Variables](#required-variables)
- [Optional Variables](#optional-variables)
- [Certificate Options](#certificate-options)
- [Build Process](#build-process)
- [OTA Installation](#ota-installation)
- [Troubleshooting](#troubleshooting)

## Overview

This guide explains how to build iOS apps using the QuikApp build system. The system supports both App Store and Ad-Hoc distribution methods, with options for OTA installation and device-specific builds.

## Build Types

### 1. App Store Build

- For submitting to the App Store
- Uses App Store provisioning profile
- Full bitcode and symbol support
- Example configuration:

```yaml
PROFILE_TYPE: "app-store"
```

### 2. Ad-Hoc Build

- For internal distribution
- Supports OTA installation
- Optional device-specific builds
- Example configuration:

```yaml
PROFILE_TYPE: "ad-hoc"
ENABLE_DEVICE_SPECIFIC_BUILDS: "true" # Optional
```

## Required Variables

### Core Variables (Always Required)

| Variable       | Description                  | Example                 |
| -------------- | ---------------------------- | ----------------------- |
| `BUNDLE_ID`    | App's bundle identifier      | "com.company.appname"   |
| `APP_NAME`     | Display name of the app      | "My App"                |
| `VERSION_NAME` | App version string           | "1.0.0"                 |
| `VERSION_CODE` | Build number                 | "1"                     |
| `PROFILE_TYPE` | Type of provisioning profile | "app-store" or "ad-hoc" |

### Signing Variables (Required)

| Variable        | Description                 | Example                                       |
| --------------- | --------------------------- | --------------------------------------------- |
| `APPLE_TEAM_ID` | Apple Developer Team ID     | "ABCD12345E"                                  |
| `CERT_PASSWORD` | Certificate password        | "your_password"                               |
| `PROFILE_URL`   | URL to provisioning profile | "https://example.com/profile.mobileprovision" |

## Optional Variables

### Certificate Variables (One Set Required)

Option 1 (Preferred):
| Variable | Description |
|----------|-------------|
| `CERT_P12_URL` | URL to P12 certificate file |

Option 2:
| Variable | Description |
|----------|-------------|
| `CERT_CER_URL` | URL to certificate file (.cer) |
| `CERT_KEY_URL` | URL to private key file (.key) |

### Ad-Hoc Specific Variables

| Variable                        | Required | Description                           |
| ------------------------------- | -------- | ------------------------------------- |
| `INSTALL_URL`                   | No       | URL where IPA will be hosted          |
| `DISPLAY_IMAGE_URL`             | No       | Icon for OTA installation             |
| `FULL_SIZE_IMAGE_URL`           | No       | Full image for OTA installation       |
| `ENABLE_DEVICE_SPECIFIC_BUILDS` | No       | Enable device-specific builds         |
| `THINNING`                      | No       | App thinning option (default: "none") |

### Firebase Variables

| Variable              | Required | Description                     |
| --------------------- | -------- | ------------------------------- |
| `FIREBASE_CONFIG_IOS` | No       | URL to GoogleService-Info.plist |
| `PUSH_NOTIFY`         | No       | Enable push notifications       |

### Email Notification Variables

| Variable                     | Required   | Description                |
| ---------------------------- | ---------- | -------------------------- |
| `ENABLE_EMAIL_NOTIFICATIONS` | No         | Enable email notifications |
| `EMAIL_SMTP_SERVER`          | If enabled | SMTP server address        |
| `EMAIL_SMTP_PORT`            | If enabled | SMTP server port           |
| `EMAIL_SMTP_USER`            | If enabled | SMTP username              |
| `EMAIL_SMTP_PASS`            | If enabled | SMTP password              |
| `EMAIL_ID`                   | If enabled | Recipient email address    |

## Certificate Options

### Option 1: Using P12 Certificate (Recommended)

1. Export P12 from Keychain Access
2. Host P12 file securely
3. Set variables:

```yaml
CERT_P12_URL: "https://example.com/cert.p12"
CERT_PASSWORD: "your_password"
```

### Option 2: Using Certificate and Key Files

1. Export certificate and key files
2. Host files securely
3. Set variables:

```yaml
CERT_CER_URL: "https://example.com/cert.cer"
CERT_KEY_URL: "https://example.com/key.key"
CERT_PASSWORD: "your_password"
```

## Build Process

1. **Environment Setup**

   - Validates required variables
   - Creates necessary directories
   - Sets up keychain

2. **Certificate Processing**

   - Downloads certificates
   - Processes into P12 format (if needed)
   - Imports into keychain

3. **Provisioning Profile Setup**

   - Downloads provisioning profile
   - Installs profile
   - Configures export options

4. **Flutter Setup**

   - Runs flutter clean
   - Gets dependencies
   - Sets up CocoaPods

5. **Build Process**

   - Archives app
   - Exports IPA
   - Generates manifest (for Ad-Hoc)

6. **Output**
   - IPA file in output/ios/
   - Manifest file (for Ad-Hoc)
   - Build logs

## OTA Installation

For Ad-Hoc builds with OTA installation:

1. **Required Variables**

```yaml
PROFILE_TYPE: "ad-hoc"
INSTALL_URL: "https://example.com/app.ipa"
DISPLAY_IMAGE_URL: "https://example.com/icon.png"
FULL_SIZE_IMAGE_URL: "https://example.com/image.png"
```

2. **Generated Files**

- IPA file
- manifest.plist for installation

3. **Installation Link**
   Format: `itms-services://?action=download-manifest&url=https://example.com/manifest.plist`

## Troubleshooting

### Common Issues

1. **Certificate Import Failed**

   - Check certificate password
   - Verify certificate format
   - Ensure certificate is not expired

2. **Provisioning Profile Issues**

   - Verify profile matches bundle ID
   - Check profile type matches build type
   - Ensure profile is not expired

3. **Build Failed**
   - Check Xcode version compatibility
   - Verify all required variables are set
   - Check Flutter dependencies

### Debug Logs

Build logs are available:

- In Codemagic build output
- In email notifications (if enabled)
- In ios_build_debug.log file

### Support

For additional support:

- Check Codemagic documentation
- Contact QuikApp support
- Review build logs for specific errors
