import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'route_names.dart';

final splashMinimumDurationProvider = FutureProvider<void>((ref) {
  return Future<void>.delayed(const Duration(seconds: 5));
});

class RouteGuards {
  RouteGuards._();

  /// Evaluates auth/onboarding state on every navigation/refresh. Returns the
  /// location to redirect to, or null to allow the requested navigation
  /// through.
  static String? redirect(Ref ref, GoRouterState state) {
    final authState = ref.read(authControllerProvider);
    final location = state.matchedLocation;
    final isAuthRoute =
        location == RouteNames.login || location == RouteNames.signup;
    final isSplash = location == RouteNames.splash;
    final isOnboarding = location == RouteNames.onboarding;
    final splashMinimumDurationState = ref.read(splashMinimumDurationProvider);

    if (splashMinimumDurationState.isLoading &&
        !splashMinimumDurationState.hasValue) {
      return isSplash ? null : RouteNames.splash;
    }

    // Only force the splash screen while auth has genuinely never resolved
    // (no previous value at all). Controllers that mutate already-resolved
    // state (e.g. updateDisplayName) use copyWithPrevious, so isLoading can
    // be true here with hasValue also true — that must NOT be treated as
    // "still resolving", or it would yank the user off whatever screen
    // they're on mid-mutation.
    if (authState.isLoading && !authState.hasValue) {
      return isSplash ? null : RouteNames.splash;
    }

    final isLoggedIn = authState.valueOrNull != null;

    if (!isLoggedIn) {
      return isAuthRoute ? null : RouteNames.login;
    }

    final selectedPathState = ref.read(selectedLearningPathControllerProvider);
    if (selectedPathState.isLoading && !selectedPathState.hasValue) {
      return isSplash ? null : RouteNames.splash;
    }

    final hasSelectedPath = selectedPathState.valueOrNull != null;

    if (!hasSelectedPath) {
      return isOnboarding ? null : RouteNames.onboarding;
    }

    if (isAuthRoute || isSplash || isOnboarding) {
      return RouteNames.dashboard;
    }

    return null;
  }
}
