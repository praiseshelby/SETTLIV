class AppConfig {
  static const String appVersion = '0.2';
  static const int buildNumber = 1;
  static const String versionString = 'Version 0.2 (build 1)';
  
  /// Feedback email recipient. If non-empty, shows the 'Send by email' button.
  static const String kFeedbackEmail = 'feedback@settliv.app';

  /// WebAuthn screen lock is disabled in the web prototype so unsupported
  /// environments show the designed FeatureComingSheet instead.
  static const bool kScreenLockEnabled = false;
}
