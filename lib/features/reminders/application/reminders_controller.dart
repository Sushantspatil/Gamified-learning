import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../../streaks/presentation/providers/streak_providers.dart';
import '../data/reminder_scheduler.dart';
import '../domain/reminder_planner.dart';

const String _enabledKey = 'settings_reminders_enabled';
const String _promptedKey = 'settings_reminders_prompted';

/// The player's reminder choices.
class ReminderSettings extends Equatable {
  /// Reminders are on (and the phone allowed notifications).
  final bool enabled;

  /// The player was already asked, so the app does not ask again.
  final bool prompted;

  const ReminderSettings({this.enabled = false, this.prompted = false});

  @override
  List<Object?> get props => [enabled, prompted];
}

/// The scheduler for this device. Tests replace it.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => createReminderScheduler(),
);

/// The clock reminders are planned from. Tests replace it.
final reminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class ReminderSettingsController extends Notifier<ReminderSettings> {
  LocalStorageService? _storage;

  @override
  ReminderSettings build() {
    try {
      _storage = ref.watch(localStorageServiceProvider);
    } catch (_) {
      _storage =
          null; // some tests have no storage: settings just do not persist
    }
    return ReminderSettings(
      enabled: _storage?.getBool(_enabledKey) ?? false,
      prompted: _storage?.getBool(_promptedKey) ?? false,
    );
  }

  void _save(ReminderSettings next) {
    state = next;
    unawaited(_storage?.setBool(_enabledKey, next.enabled));
    unawaited(_storage?.setBool(_promptedKey, next.prompted));
  }

  /// Turns reminders on, asking the phone for permission. False if the player
  /// (or the phone) said no, in which case reminders stay off.
  Future<bool> enable() async {
    final granted = await ref
        .read(reminderSchedulerProvider)
        .requestPermission();
    _save(ReminderSettings(enabled: granted, prompted: true));
    return granted;
  }

  Future<void> disable() async {
    _save(ReminderSettings(enabled: false, prompted: state.prompted));
    await ref.read(reminderSchedulerProvider).cancelAll();
  }

  /// "Not now": remember the question was asked.
  void declinePrompt() =>
      _save(ReminderSettings(enabled: state.enabled, prompted: true));
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsController, ReminderSettings>(
      ReminderSettingsController.new,
    );

/// Keeps the phone's scheduled reminders in step with the player: planned from
/// the current streak while someone is signed in with reminders on, cleared
/// otherwise (including at sign-out, so a signed-out phone stays quiet).
/// Watch it from a screen that is on while the app is open.
final reminderSyncProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);
  if (!scheduler.isSupported) return;

  final user = ref.watch(authControllerProvider).valueOrNull;
  final settings = ref.watch(reminderSettingsProvider);
  if (user == null || !settings.enabled) {
    unawaited(scheduler.cancelAll());
    return;
  }

  final streak = ref.watch(streakControllerProvider).valueOrNull;
  if (streak == null) return; // wait until the streak is known
  final plans = planReminders(
    now: ref.read(reminderClockProvider)(),
    streak: streak.currentStreak,
  );
  unawaited(scheduler.replaceAll(plans));
});
