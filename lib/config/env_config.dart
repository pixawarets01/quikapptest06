class EnvConfig {
  // App Metadata
  static const String appId =
      String.fromEnvironment('APP_ID', defaultValue: '');
  static const String versionName =
      String.fromEnvironment('VERSION_NAME', defaultValue: '1.0.0');
  static const int versionCode =
      int.fromEnvironment('VERSION_CODE', defaultValue: 1);
  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'QuikApp');
  static const String orgName =
      String.fromEnvironment('ORG_NAME', defaultValue: '');
  static const String webUrl =
      String.fromEnvironment('WEB_URL', defaultValue: '');
  static const String userName =
      String.fromEnvironment('USER_NAME', defaultValue: '');
  static const String emailId =
      String.fromEnvironment('EMAIL_ID', defaultValue: '');
  static const String branch =
      String.fromEnvironment('BRANCH', defaultValue: 'main');
  static const String workflowId =
      String.fromEnvironment('WORKFLOW_ID', defaultValue: '');

  // Package Identifiers
  static const String pkgName =
      String.fromEnvironment('PKG_NAME', defaultValue: '');
  static const String bundleId =
      String.fromEnvironment('BUNDLE_ID', defaultValue: '');

  // Feature Flags
  static const bool pushNotify =
      bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);
  static const bool isChatbot =
      bool.fromEnvironment('IS_CHATBOT', defaultValue: false);
  static const bool isDomainUrl =
      bool.fromEnvironment('IS_DOMAIN_URL', defaultValue: false);
  static const bool isSplash =
      bool.fromEnvironment('IS_SPLASH', defaultValue: true);
  static const bool isPulldown =
      bool.fromEnvironment('IS_PULLDOWN', defaultValue: true);
  static const bool isBottommenu =
      bool.fromEnvironment('IS_BOTTOMMENU', defaultValue: true);
  static const bool isLoadIndicator =
      bool.fromEnvironment('IS_LOAD_IND', defaultValue: true);

  // Permissions
  static const bool isCamera =
      bool.fromEnvironment('IS_CAMERA', defaultValue: false);
  static const bool isLocation =
      bool.fromEnvironment('IS_LOCATION', defaultValue: false);
  static const bool isMic = bool.fromEnvironment('IS_MIC', defaultValue: false);
  static const bool isNotification =
      bool.fromEnvironment('IS_NOTIFICATION', defaultValue: false);
  static const bool isContact =
      bool.fromEnvironment('IS_CONTACT', defaultValue: false);
  static const bool isBiometric =
      bool.fromEnvironment('IS_BIOMETRIC', defaultValue: false);
  static const bool isCalendar =
      bool.fromEnvironment('IS_CALENDAR', defaultValue: false);
  static const bool isStorage =
      bool.fromEnvironment('IS_STORAGE', defaultValue: false);

  // UI/Branding
  static const String logoUrl =
      String.fromEnvironment('LOGO_URL', defaultValue: '');
  static const String splashUrl =
      String.fromEnvironment('SPLASH_URL', defaultValue: '');
  static const String splashBg =
      String.fromEnvironment('SPLASH_BG_URL', defaultValue: '');
  static const String splashBgColor =
      String.fromEnvironment('SPLASH_BG_COLOR', defaultValue: '#FFFFFF');
  static const String splashTagline =
      String.fromEnvironment('SPLASH_TAGLINE', defaultValue: '');
  static const String splashTaglineColor =
      String.fromEnvironment('SPLASH_TAGLINE_COLOR', defaultValue: '#000000');
  static const String splashAnimation =
      String.fromEnvironment('SPLASH_ANIMATION', defaultValue: 'fade');
  static const int splashDuration =
      int.fromEnvironment('SPLASH_DURATION', defaultValue: 3);

  // Bottom Menu Configuration
  static const String bottommenuItems =
      String.fromEnvironment('BOTTOMMENU_ITEMS', defaultValue: '[]');
  static const String bottommenuBgColor =
      String.fromEnvironment('BOTTOMMENU_BG_COLOR', defaultValue: '#FFFFFF');
  static const String bottommenuIconColor =
      String.fromEnvironment('BOTTOMMENU_ICON_COLOR', defaultValue: '#6d6e8c');
  static const String bottommenuTextColor =
      String.fromEnvironment('BOTTOMMENU_TEXT_COLOR', defaultValue: '#6d6e8c');
  static const String bottommenuFont =
      String.fromEnvironment('BOTTOMMENU_FONT', defaultValue: 'DM Sans');
  static  double bottommenuFontSize =
      double.parse(const String.fromEnvironment('BOTTOMMENU_FONT_SIZE', defaultValue: "12.0"));
  static const bool bottommenuFontBold =
      bool.fromEnvironment('BOTTOMMENU_FONT_BOLD', defaultValue: false);
  static const bool bottommenuFontItalic =
      bool.fromEnvironment('BOTTOMMENU_FONT_ITALIC', defaultValue: false);
  static const String bottommenuActiveTabColor = String.fromEnvironment(
      'BOTTOMMENU_ACTIVE_TAB_COLOR',
      defaultValue: '#a30237');
  static  String bottommenuIconPosition =
      const String.fromEnvironment('BOTTOMMENU_ICON_POSITION', defaultValue: 'above');
  static  String bottommenuVisibleOn = const String.fromEnvironment(
      'BOTTOMMENU_VISIBLE_ON',
      defaultValue: 'home,settings,profile');

  // Firebase Configuration
  static  String firebaseConfigAndroid =
      const String.fromEnvironment('FIREBASE_CONFIG_ANDROID', defaultValue: '');
  static String firebaseConfigIos =
      const String.fromEnvironment('FIREBASE_CONFIG_IOS', defaultValue: '');
}
