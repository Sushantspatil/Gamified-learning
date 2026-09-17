import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/signup_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/learning_paths/presentation/providers/learning_path_providers.dart';
import '../../features/onboarding/presentation/screens/how_to_play_tutorial_screen.dart';
import '../../features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/questions/domain/entities/question.dart';
import '../../features/quiz/presentation/screens/quiz_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import 'authenticated_shell.dart';
import 'go_router_refresh_notifier.dart';
import 'route_guards.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref, [
    authControllerProvider,
    profileControllerProvider,
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
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: RouteNames.tutorial,
        builder: (context, state) => const HowToPlayTutorialScreen(),
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
            redirect: (context, state) => RouteNames.dashboard,
          ),
          GoRoute(
            path: RouteNames.practice,
            redirect: (context, state) =>
                RouteNames.quizPath('accounting', QuestionType.mcq),
          ),
          GoRoute(
            path: RouteNames.leaderboard,
            redirect: (context, state) => RouteNames.dashboard,
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
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.subjectLearnPattern,
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.subjectPlayPattern,
        redirect: (context, state) =>
            RouteNames.quizPath('accounting', QuestionType.mcq),
      ),
      GoRoute(
        path: RouteNames.chapterPattern,
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.topicPattern,
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.topicPracticePattern,
        redirect: (context, state) =>
            RouteNames.quizPath('accounting', QuestionType.mcq),
      ),
      GoRoute(
        path: RouteNames.practiceTypePattern,
        redirect: (context, state) =>
            RouteNames.quizPath('accounting', QuestionType.mcq),
      ),
      GoRoute(
        path: RouteNames.practiceSubjectPattern,
        redirect: (context, state) =>
            RouteNames.quizPath('accounting', QuestionType.mcq),
      ),
      GoRoute(
        path: RouteNames.practiceChapterPattern,
        redirect: (context, state) =>
            RouteNames.quizPath('accounting', QuestionType.mcq),
      ),
      GoRoute(
        path: RouteNames.practiceTopicPattern,
        redirect: (context, state) =>
            RouteNames.quizPath('accounting', QuestionType.mcq),
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
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.chestPattern,
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.spinWheel,
        redirect: (context, state) => RouteNames.dashboard,
      ),
      GoRoute(
        path: RouteNames.cosmetics,
        redirect: (context, state) => RouteNames.dashboard,
      ),
    ],
  );
});

QuestionType _quizTypeFromState(GoRouterState state) {
  return QuestionTypeX.fromRouteValue(state.pathParameters['quizType'] ?? '') ??
      QuestionType.mcq;
}
