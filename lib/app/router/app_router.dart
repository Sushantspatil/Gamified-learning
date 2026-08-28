import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/signup_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/chapters/presentation/screens/chapter_list_screen.dart';
import '../../features/chapters/presentation/screens/chapter_summary_screen.dart';
import '../../features/chapters/presentation/screens/topic_learning_screen.dart';
import '../../features/chests/domain/entities/chest_type.dart';
import '../../features/chests/presentation/screens/chest_screen.dart';
import '../../features/cosmetics/presentation/screens/cosmetics_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/learning_paths/presentation/providers/learning_path_providers.dart';
import '../../features/learning_paths/presentation/screens/subject_detail_screen.dart';
import '../../features/onboarding/presentation/screens/learning_path_selection_screen.dart';
import '../../features/practice/presentation/screens/practice_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/questions/domain/entities/question.dart';
import '../../features/quiz/presentation/screens/quiz_screen.dart';
import '../../features/shop/presentation/screens/shop_screen.dart';
import '../../features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import 'authenticated_shell.dart';
import 'go_router_refresh_notifier.dart';
import 'route_guards.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref, [
    authControllerProvider,
    selectedLearningPathControllerProvider,
    splashMinimumDurationProvider,
  ]);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => RouteGuards.redirect(ref, state),
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const LearningPathSelectionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AuthenticatedShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.learningPath,
            builder: (context, state) => const ChapterListScreen(),
          ),
          GoRoute(
            path: RouteNames.practice,
            builder: (context, state) => const PracticeScreen(),
          ),
          GoRoute(
            path: RouteNames.leaderboard,
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.subjectPattern,
        builder: (context, state) =>
            SubjectDetailScreen(subjectId: state.pathParameters['subjectId']!),
      ),
      GoRoute(
        path: RouteNames.chapterPattern,
        builder: (context, state) =>
            ChapterSummaryScreen(chapterId: state.pathParameters['chapterId']!),
      ),
      GoRoute(
        path: RouteNames.topicPattern,
        builder: (context, state) => TopicLearningScreen(
          chapterId: state.pathParameters['chapterId']!,
          topicId: state.pathParameters['topicId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.topicPracticePattern,
        builder: (context, state) => TopicPracticeModeSelectionScreen(
          chapterId: state.pathParameters['chapterId']!,
          topicId: state.pathParameters['topicId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.practiceTypePattern,
        builder: (context, state) =>
            PracticeSubjectSelectionScreen(quizType: _quizTypeFromState(state)),
      ),
      GoRoute(
        path: RouteNames.practiceSubjectPattern,
        builder: (context, state) => PracticeChapterSelectionScreen(
          quizType: _quizTypeFromState(state),
          subjectId: state.pathParameters['subjectId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.practiceChapterPattern,
        builder: (context, state) => PracticeTopicSelectionScreen(
          quizType: _quizTypeFromState(state),
          subjectId: state.pathParameters['subjectId']!,
          chapterId: state.pathParameters['chapterId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.practiceTopicPattern,
        builder: (context, state) => PracticeStartScreen(
          quizType: _quizTypeFromState(state),
          subjectId: state.pathParameters['subjectId']!,
          chapterId: state.pathParameters['chapterId']!,
          topicId: state.pathParameters['topicId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.typedQuizPattern,
        builder: (context, state) => QuizScreen(
          topicId: state.pathParameters['topicId']!,
          quizType: _quizTypeFromState(state),
          subjectId: state.uri.queryParameters['subjectId'],
          chapterId: state.uri.queryParameters['chapterId'],
        ),
      ),
      GoRoute(
        path: RouteNames.quizPattern,
        redirect: (context, state) => RouteNames.quizPath(
          state.pathParameters['topicId']!,
          QuestionType.mcq,
        ),
      ),
      GoRoute(
        path: RouteNames.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RouteNames.shop,
        builder: (context, state) => const ShopScreen(),
      ),
      GoRoute(
        path: RouteNames.chestPattern,
        builder: (context, state) => ChestScreen(
          type: state.pathParameters['type'] == 'daily'
              ? ChestType.daily
              : ChestType.ad,
        ),
      ),
      GoRoute(
        path: RouteNames.spinWheel,
        builder: (context, state) => const SpinWheelScreen(),
      ),
      GoRoute(
        path: RouteNames.cosmetics,
        builder: (context, state) => const CosmeticsScreen(),
      ),
    ],
  );
});

QuestionType _quizTypeFromState(GoRouterState state) {
  return QuestionTypeX.fromRouteValue(state.pathParameters['quizType'] ?? '') ??
      QuestionType.mcq;
}
