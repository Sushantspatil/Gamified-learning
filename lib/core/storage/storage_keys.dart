class StorageKeys {
  StorageKeys._();

  static const String currentUserId = 'current_user_id';
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String selectedLearningPathId = 'selected_learning_path_id';
  static const String themePreference = 'theme';
  static const String sfxEnabled = 'settings_sfx_enabled';
  static const String musicEnabled = 'settings_music_enabled';

  static String profileForUser(String userId) => 'profile_$userId';
}
