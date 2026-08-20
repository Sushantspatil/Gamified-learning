import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges a Riverpod provider to GoRouter's Listenable-based refresh so the
/// router re-evaluates `redirect` whenever auth state changes, without
/// rebuilding the GoRouter instance itself (which would drop navigation
/// history).
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref, List<ProviderListenable> triggers) {
    for (final trigger in triggers) {
      ref.listen(trigger, (_, _) => notifyListeners());
    }
  }
}
