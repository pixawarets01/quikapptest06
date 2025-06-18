import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../config/env_config.dart';
import '../module/myapp.dart';
import '../services/notification_service.dart';
import '../utils/menu_parser.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("🔔 Handling a background message: ${message.messageId}");
    print("📝 Message data: ${message.data}");
    print("📌 Notification: ${message.notification?.title}");
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to portrait only
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Initialize local notifications first
    await initLocalNotifications();

    if (EnvConfig.pushNotify) {
      try {
        // Use the Firebase service that handles remote config files
        final options = await loadFirebaseOptionsFromJson();
        await Firebase.initializeApp(options: options);
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
        await initializeFirebaseMessaging();
        debugPrint("✅ Firebase initialized successfully");
      } catch (e) {
        debugPrint("❌ Firebase initialization error: $e");
        // Continue without Firebase instead of blocking the app
      }
    } else {
      debugPrint(
          "🚫 Firebase not initialized (pushNotify: ${EnvConfig.pushNotify}, isWeb: $kIsWeb)");
    }

    if (EnvConfig.webUrl.isEmpty) {
      debugPrint("❗ Missing WEB_URL environment variable.");
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(child: Text("WEB_URL not configured.")),
        ),
      ));
      return;
    }

    debugPrint("""
      🛠 Runtime Config:
      - pushNotify: ${EnvConfig.pushNotify}
      - webUrl: ${EnvConfig.webUrl}
      - isSplash: ${EnvConfig.isSplash},
      - splashLogo: ${EnvConfig.splashUrl},
      - splashBg: ${EnvConfig.splashBg},
      - splashDuration: ${EnvConfig.splashDuration},
      - splashAnimation: ${EnvConfig.splashAnimation},
      - taglineColor: ${EnvConfig.splashTaglineColor},
      - spbgColor: ${EnvConfig.splashBgColor},
      - isBottomMenu: ${EnvConfig.isBottommenu},
      - bottomMenuItems: ${parseBottomMenuItems(EnvConfig.bottommenuItems)},
      - isDomainUrl: ${EnvConfig.isDomainUrl},
      - backgroundColor: ${EnvConfig.bottommenuBgColor},
      - activeTabColor: ${EnvConfig.bottommenuActiveTabColor},
      - textColor: ${EnvConfig.bottommenuTextColor},
      - iconColor: ${EnvConfig.bottommenuIconColor},
      - iconPosition: ${EnvConfig.bottommenuIconPosition},
      - Permissions:
        - Camera: ${EnvConfig.isCamera}
        - Location: ${EnvConfig.isLocation}
        - Mic: ${EnvConfig.isMic}
        - Notification: ${EnvConfig.isNotification}
        - Contact: ${EnvConfig.isContact}
      """);

    runApp(const MyApp(
      webUrl: EnvConfig.webUrl,
      isSplash: EnvConfig.isSplash,
      splashLogo: EnvConfig.splashUrl,
      splashBg: EnvConfig.splashBg,
      splashDuration: EnvConfig.splashDuration,
      splashAnimation: EnvConfig.splashAnimation,
      taglineColor: EnvConfig.splashTaglineColor,
      spbgColor: EnvConfig.splashBgColor,
      isBottomMenu: EnvConfig.isBottommenu,
      bottomMenuItems: EnvConfig.bottommenuItems,
      isDomainUrl: EnvConfig.isDomainUrl,
      backgroundColor: EnvConfig.bottommenuBgColor,
      activeTabColor: EnvConfig.bottommenuActiveTabColor,
      textColor: EnvConfig.bottommenuTextColor,
      iconColor: EnvConfig.bottommenuIconColor,
      iconPosition: EnvConfig.bottommenuIconPosition,
      isLoadIndicator: EnvConfig.isLoadIndicator,
      splashTagline: EnvConfig.splashTagline,
    ));
  } catch (e, stackTrace) {
    debugPrint("❌ Fatal error during initialization: $e");
    debugPrint("Stack trace: $stackTrace");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Error: $e")),
      ),
    ));
  }
}
