import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/data/analytics_service.dart';
import '../../analytics/presentation/analytics_host.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../../streaks/domain/entities/streak.dart';
import '../../streaks/presentation/providers/streak_providers.dart';
import '../application/reminders_controller.dart';

/// Wraps the home screen. While the app is open it:
///  - keeps the phone's scheduled reminders planned from the current streak;
///  - when the app comes back to the front, re-reads the streak. Opening the
///    app is what counts as a day on the streak, and a phone that left the app
///    open overnight has not told the server about the new day yet;
///  - asks, once, whether to turn reminders on: the first time the player is on
///    a streak of two days or more, when a reminder is clearly worth having.
class ReminderHost extends ConsumerStatefulWidget {
  final Widget child;

  const ReminderHost({super.key, required this.child});

  @override
  ConsumerState<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<ReminderHost>
    with WidgetsBindingObserver {
  bool _askedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The streak may already be loaded by the time this screen is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAsk(ref.read(streakControllerProvider).valueOrNull);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authControllerProvider).valueOrNull != null) {
      ref.invalidate(streakControllerProvider);
    }
  }

  Future<void> _maybeAsk(Streak? streak) async {
    if (_askedThisSession || streak == null || streak.currentStreak < 2) return;
    if (ref.read(authControllerProvider).valueOrNull == null) return;
    if (!ref.read(reminderSchedulerProvider).isSupported) return;
    final settings = ref.read(reminderSettingsProvider);
    if (settings.enabled || settings.prompted) return;

    _askedThisSession = true;
    ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvents.reminderPromptShown);
    final turnOn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protect your streak'),
        content: const Text(
          'Want a gentle reminder if you have not played for a day? '
          'You can turn it off anytime in Profile.',
        ),
        actions: [
          TextButton(
            key: const Key('reminder_prompt_not_now'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('reminder_prompt_turn_on'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    final controller = ref.read(reminderSettingsProvider.notifier);
    if (turnOn != true) {
      controller.declinePrompt();
      return;
    }
    final granted = await controller.enable();
    if (!mounted || granted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are blocked. You can allow them in your phone settings.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderSyncProvider);
    ref.listen<AsyncValue<Streak>>(streakControllerProvider, (_, next) {
      _maybeAsk(next.valueOrNull);
    });
    // The same home screen also reports app opens and sends queued usage events
    // when the app goes to the background.
    return AnalyticsHost(child: widget.child);
  }
}
