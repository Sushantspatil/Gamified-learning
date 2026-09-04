import '../../features/questions/domain/entities/question.dart';

class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String learningPath = '/learning-path';
  static const String practice = '/practice';
  static const String practiceTypePattern = '/practice/:quizType';
  static String practiceTypePath(QuestionType quizType) =>
      '/practice/${quizType.routeValue}';
  static const String practiceSubjectPattern = '/practice/:quizType/:subjectId';
  static String practiceSubjectPath(QuestionType quizType, String subjectId) =>
      '/practice/${quizType.routeValue}/$subjectId';
  static const String practiceChapterPattern =
      '/practice/:quizType/:subjectId/:chapterId';
  static String practiceChapterPath(
    QuestionType quizType,
    String subjectId,
    String chapterId,
  ) => '/practice/${quizType.routeValue}/$subjectId/$chapterId';
  static const String practiceTopicPattern =
      '/practice/:quizType/:subjectId/:chapterId/:topicId';
  static String practiceTopicPath(
    QuestionType quizType,
    String subjectId,
    String chapterId,
    String topicId,
  ) => '/practice/${quizType.routeValue}/$subjectId/$chapterId/$topicId';
  static const String topicPracticePattern =
      '/practice/topic/:chapterId/:topicId';
  static String topicPracticePath(String chapterId, String topicId) =>
      '/practice/topic/$chapterId/$topicId';
  static const String subjectPattern = '/learn/:subjectId';
  static String subjectPath(String subjectId) => '/learn/$subjectId';
  static const String subjectLearnPattern = '/learn/:subjectId/chapters';
  static String subjectLearnPath(String subjectId) =>
      '/learn/$subjectId/chapters';
  static const String subjectPlayPattern = '/learn/:subjectId/play';
  static String subjectPlayPath(String subjectId) => '/learn/$subjectId/play';
  static const String chapter = '/chapter';
  static const String chapterPattern = '/chapter/:chapterId';
  static String chapterPath(String chapterId) => '/chapter/$chapterId';
  static const String topicPattern = '/chapter/:chapterId/topic/:topicId';
  static String topicPath(String chapterId, String topicId) =>
      '/chapter/$chapterId/topic/$topicId';
  static const String quiz = '/quiz';
  static const String quizPattern = '/quiz/:topicId';
  static const String typedQuizPattern = '/quiz/:topicId/:quizType';
  static String quizPath(
    String topicId,
    QuestionType quizType, {
    String? subjectId,
    String? chapterId,
  }) {
    final query = <String, String>{};
    if (subjectId != null) {
      query['subjectId'] = subjectId;
    }
    if (chapterId != null) {
      query['chapterId'] = chapterId;
    }
    final basePath = '/quiz/$topicId/${quizType.routeValue}';
    if (query.isEmpty) return basePath;
    return Uri(path: basePath, queryParameters: query).toString();
  }

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
