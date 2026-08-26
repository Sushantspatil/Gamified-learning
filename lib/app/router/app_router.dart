import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/signup_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/chapters/presentation/screens/chapter_list_screen.dart';
import '../../features/chapters/presentation/screens/chapter_summary_screen.dart';
import '../../features/chests/domain/entities/chest_type.dart';
import '../../features/chests/presentation/screens/chest_screen.dart';
import '../../features/cosmetics/presentation/screens/cosmetics_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/learning_paths/presentation/providers/learning_path_providers.dart';
import '../../features/onboarding/presentation/screens/learning_path_selection_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/quiz/presentation/screens/quiz_screen.dart';
import '../../features/shop/presentation/screens/shop_screen.dart';
import '../../features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import 'go_router_refresh_notifier.dart';
import 'route_guards.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(
    ref,
    [
      authControllerProvider,
      selectedLearningPathControllerProvider,
      splashMinimumDurationProvider,
    ],
  );
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
      GoRoute(
        path: RouteNames.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.learningPath,
        builder: (context, state) => const ChapterListScreen(),
      ),
      GoRoute(
        path: RouteNames.chapterPattern,
        builder: (context, state) => ChapterSummaryScreen(
          chapterId: state.pathParameters['chapterId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.quizPattern,
        builder: (context, state) => QuizScreen(
          topicId: state.pathParameters['topicId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
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
          type: state.pathParameters['type'] == 'daily' ? ChestType.daily : ChestType.ad,
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
