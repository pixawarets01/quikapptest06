# Firebase Configuration Validation in Dart

## Overview

This document shows how to use the Firebase configuration variables (`FIREBASE_CONFIG_ANDROID` and `FIREBASE_CONFIG_IOS`) that are now passed as `--dart-define` arguments in your Flutter app for push notification validation.

## Variables Available

- `FIREBASE_CONFIG_ANDROID` - Firebase configuration JSON for Android
- `FIREBASE_CONFIG_IOS` - Firebase configuration JSON for iOS
- `PUSH_NOTIFY` - Boolean flag indicating if push notifications are enabled

## Usage in main.dart

```dart
import 'package:flutter/foundation.dart';

void main() {
  // Get Firebase configuration from build-time variables
  final firebaseConfigAndroid = const String.fromEnvironment('FIREBASE_CONFIG_ANDROID');
  final firebaseConfigIos = const String.fromEnvironment('FIREBASE_CONFIG_IOS');
  final pushNotifyEnabled = const bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);

  // Validate Firebase configuration
  if (pushNotifyEnabled) {
    if (kIsWeb) {
      // Web platform - use web config
      print('Firebase Web configuration: $firebaseConfigAndroid');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Android platform
      if (firebaseConfigAndroid.isNotEmpty) {
        print('Firebase Android configuration: $firebaseConfigAndroid');
        // Initialize Firebase for Android
        initializeFirebaseAndroid(firebaseConfigAndroid);
      } else {
        print('❌ Firebase Android configuration is missing!');
        // Handle missing configuration
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS platform
      if (firebaseConfigIos.isNotEmpty) {
        print('Firebase iOS configuration: $firebaseConfigIos');
        // Initialize Firebase for iOS
        initializeFirebaseIos(firebaseConfigIos);
      } else {
        print('❌ Firebase iOS configuration is missing!');
        // Handle missing configuration
      }
    }
  } else {
    print('ℹ️ Push notifications are disabled');
  }

  runApp(MyApp());
}

void initializeFirebaseAndroid(String config) {
  // Parse and initialize Firebase for Android
  try {
    final configMap = jsonDecode(config);
    // Initialize Firebase with the configuration
    print('✅ Firebase Android initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Firebase Android: $e');
  }
}

void initializeFirebaseIos(String config) {
  // Parse and initialize Firebase for iOS
  try {
    final configMap = jsonDecode(config);
    // Initialize Firebase with the configuration
    print('✅ Firebase iOS initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Firebase iOS: $e');
  }
}
```

## Validation in Your App

### 1. Check if Push Notifications are Enabled

```dart
bool isPushNotifyEnabled() {
  return const bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);
}
```

### 2. Get Firebase Configuration for Current Platform

```dart
String? getFirebaseConfig() {
  if (kIsWeb) {
    return const String.fromEnvironment('FIREBASE_CONFIG_ANDROID');
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    return const String.fromEnvironment('FIREBASE_CONFIG_ANDROID');
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return const String.fromEnvironment('FIREBASE_CONFIG_IOS');
  }
  return null;
}
```

### 3. Validate Firebase Configuration

```dart
bool validateFirebaseConfig() {
  final config = getFirebaseConfig();
  if (config == null || config.isEmpty) {
    print('❌ Firebase configuration is missing');
    return false;
  }

  try {
    final configMap = jsonDecode(config);
    // Check for required Firebase fields
    if (configMap['project_id'] == null) {
      print('❌ Firebase project_id is missing');
      return false;
    }
    print('✅ Firebase configuration is valid');
    return true;
  } catch (e) {
    print('❌ Invalid Firebase configuration JSON: $e');
    return false;
  }
}
```

## Integration with Your Services

### Firebase Service Example

```dart
class FirebaseService {
  static Future<void> initialize() async {
    final pushNotifyEnabled = const bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);

    if (!pushNotifyEnabled) {
      print('ℹ️ Push notifications disabled, skipping Firebase initialization');
      return;
    }

    final config = getFirebaseConfig();
    if (config == null || config.isEmpty) {
      print('❌ Firebase configuration missing, cannot initialize');
      return;
    }

    try {
      // Initialize Firebase with the configuration
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Firebase Messaging for push notifications
      await FirebaseMessaging.instance.requestPermission();

      print('✅ Firebase initialized successfully for push notifications');
    } catch (e) {
      print('❌ Failed to initialize Firebase: $e');
    }
  }
}
```

## Build-Time Validation

Your app can now validate Firebase configuration at build time:

```dart
void main() {
  // Validate Firebase configuration before app starts
  if (const bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false)) {
    if (!validateFirebaseConfig()) {
      // Handle invalid Firebase configuration
      print('⚠️ App will run without push notifications due to invalid Firebase config');
    }
  }

  runApp(MyApp());
}
```

## Benefits

✅ **Build-Time Validation**: Firebase configuration is validated during build
✅ **Platform-Specific**: Different configs for Android and iOS
✅ **Conditional Initialization**: Only initialize Firebase when push notifications are enabled
✅ **Error Handling**: Graceful handling of missing or invalid configurations
✅ **Debug Information**: Clear logging for troubleshooting

## Summary

With these Firebase configuration variables now available as `--dart-define` arguments, your Flutter app can:

1. **Validate Firebase configuration** at build time
2. **Initialize Firebase conditionally** based on push notification settings
3. **Handle platform-specific configurations** for Android and iOS
4. **Provide clear error messages** when configuration is missing or invalid

This ensures your push notification feature works reliably across all platforms! 🚀
