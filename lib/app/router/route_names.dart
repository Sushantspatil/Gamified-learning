class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String learningPath = '/learning-path';
  static const String chapter = '/chapter';
  static const String chapterPattern = '/chapter/:chapterId';
  static String chapterPath(String chapterId) => '/chapter/$chapterId';
  static const String quiz = '/quiz';
  static const String quizPattern = '/quiz/:topicId';
  static String quizPath(String topicId) => '/quiz/$topicId';
  static const String dailyMissions = '/daily-missions';
  static const String dailyRewards = '/daily-rewards';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String cosmetics = '/cosmetics';
  static const String wallet = '/wallet';
  static const String shop = '/shop';
  static const String chest = '/chest';
  static const String chestPattern = '/chest/:type';
  static String chestPath(String type) => '/chest/$type';
  static const String spinWheel = '/spin-wheel';
  static const String settings = '/settings';
}
