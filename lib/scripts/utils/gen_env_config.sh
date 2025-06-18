#!/bin/bash
set -euo pipefail

# Helper to safely echo Dart bool
dart_bool() {
  if [ "$1" = "true" ]; then echo true; else echo false; fi
}

cat > lib/config/env_config.dart <<EOF
class EnvConfig {
  static const String appName = '${APP_NAME:-''}';
  static const String orgName = '${ORG_NAME:-''}';
  static const String webUrl = '${WEB_URL:-''}';
  static const String pkgName = '${PKG_NAME:-''}';
  static const String bundleId = '${BUNDLE_ID:-''}';
  static const String emailId = '${EMAIL_ID:-''}';
  static const bool isChatbot = $(dart_bool "${IS_CHATBOT:-false}");
  static const bool isDomainUrl = $(dart_bool "${IS_DOMAIN_URL:-false}");
  static const bool isSplash = $(dart_bool "${IS_SPLASH:-false}");
  static const bool isPulldown = $(dart_bool "${IS_PULLDOWN:-false}");
  static const bool isBottommenu = $(dart_bool "${IS_BOTTOMMENU:-false}");
  static const bool isLoadIndicator = $(dart_bool "${IS_LOAD_IND:-false}");
  static const bool isCamera = $(dart_bool "${IS_CAMERA:-false}");
  static const bool isLocation = $(dart_bool "${IS_LOCATION:-false}");
  static const bool isMic = $(dart_bool "${IS_MIC:-false}");
  static const bool isNotification = $(dart_bool "${IS_NOTIFICATION:-false}");
  static const bool isContact = $(dart_bool "${IS_CONTACT:-false}");
  static const bool isBiometric = $(dart_bool "${IS_BIOMETRIC:-false}");
  static const bool isCalendar = $(dart_bool "${IS_CALENDAR:-false}");
  static const bool isStorage = $(dart_bool "${IS_STORAGE:-false}");
  static const String logoUrl = '${LOGO_URL:-''}';
  static const String splashUrl = '${SPLASH_URL:-''}';
  static const String splashBg = '${SPLASH_BG_URL:-''}';
  static const String splashBgColor = '${SPLASH_BG_COLOR:-''}';
  static const String splashTagline = '${SPLASH_TAGLINE:-''}';
  static const String splashTaglineColor = '${SPLASH_TAGLINE_COLOR:-''}';
  static const String splashAnimation = '${SPLASH_ANIMATION:-''}';
  static const int splashDuration = ${SPLASH_DURATION:-0};
  static const String bottommenuItems = r'''${BOTTOMMENU_ITEMS:-[]}''';
  static const String bottommenuBgColor = '${BOTTOMMENU_BG_COLOR:-''}';
  static const String bottommenuIconColor = '${BOTTOMMENU_ICON_COLOR:-''}';
  static const String bottommenuTextColor = '${BOTTOMMENU_TEXT_COLOR:-''}';
  static const String bottommenuFont = '${BOTTOMMENU_FONT:-''}';
  static const double bottommenuFontSize = ${BOTTOMMENU_FONT_SIZE:-0};
  static const bool bottommenuFontBold = $(dart_bool "${BOTTOMMENU_FONT_BOLD:-false}");
  static const bool bottommenuFontItalic = $(dart_bool "${BOTTOMMENU_FONT_ITALIC:-false}");
  static const String bottommenuActiveTabColor = '${BOTTOMMENU_ACTIVE_TAB_COLOR:-''}';
  static const String bottommenuIconPosition = '${BOTTOMMENU_ICON_POSITION:-''}';
  static const String bottommenuVisibleOn = '${BOTTOMMENU_VISIBLE_ON:-''}';
  static const bool pushNotify = $(dart_bool "${PUSH_NOTIFY:-false}");
  static const String firebaseConfigAndroid = '${FIREBASE_CONFIG_ANDROID:-''}';
  static const String firebaseConfigIos = '${FIREBASE_CONFIG_IOS:-''}';
}
EOF 