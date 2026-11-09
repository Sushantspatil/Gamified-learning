import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../data/analytics_service.dart';

/// The app's usage reporter. Tests replace it.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return ApiAnalyticsService(
    apiClient: ref.watch(apiClientProvider),
    isSignedIn: () => ref.read(authControllerProvider).valueOrNull != null,
  );
});
