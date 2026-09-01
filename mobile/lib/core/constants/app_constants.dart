class AppConstants {
  static const String appName = 'CSE JnU EduPortal';
  static const String appVersion = '1.0.0';
  static const String departmentName = 'Department of Computer Science & Engineering';
  static const String universityName = 'Jagannath University';

  // Secure Storage Keys
  static const String keyAccessToken = 'eduportal_access_token';
  static const String keyRefreshToken = 'eduportal_refresh_token';
  static const String keyUserId = 'eduportal_user_id';
  static const String keyUserRole = 'eduportal_user_role';
  static const String keyUserData = 'eduportal_user_data';

  // Shared Preferences Keys
  static const String keyThemeMode = 'eduportal_theme_mode';
  static const String keyActiveSemester = 'eduportal_active_semester';
  static const String keyCachedRoutine = 'eduportal_cached_routine';

  // Animation & Transition Constants
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
}
