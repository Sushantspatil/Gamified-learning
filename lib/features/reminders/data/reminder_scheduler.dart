import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_planner.dart';

/// Shows reminders on the phone. Everything here is best effort: a phone that
/// blocks notifications must never break the app, so failures are swallowed.
abstract class ReminderScheduler {
  /// Whether this device can show scheduled reminders at all (phones only).
  bool get isSupported;

  /// Asks the player for permission to show notifications. True if granted.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [plans].
  Future<void> replaceAll(List<ReminderPlan> plans);

  /// Removes every scheduled reminder.
  Future<void> cancelAll();
}

/// For the web, desktop and tests: does nothing.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  bool get isSupported => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceAll(List<ReminderPlan> plans) async {}
  @override
  Future<void> cancelAll() async {}
}

/// The scheduler to use on this device.
ReminderScheduler createReminderScheduler() {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return const NoopReminderScheduler();
  }
  return LocalNotificationsScheduler();
}

/// Reminders through the phone's own notification system, scheduled for exact
/// moments in advance (so they show even when the app is closed). Android
/// shows them within a few minutes of the moment ("inexact"), which needs no
/// special alarm permission.
class LocalNotificationsScheduler implements ReminderScheduler {
  static const _channelId = 'streak_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  @override
  bool get isSupported => true;

  Future<bool> _init() {
    return _ready ??= () async {
      try {
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            // The permission is asked for by the app at a moment it chooses,
            // not at start-up.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
        return true;
      } catch (e) {
        debugPrint('Reminders unavailable: $e');
        return false;
      }
    }();
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (e) {
      debugPrint('Reminder permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<ReminderPlan> plans) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
      for (final plan in plans) {
        // An exact moment, written in UTC, so no time zone database is needed.
        await _plugin.zonedSchedule(
          id: plan.id,
          title: plan.title,
          body: plan.body,
          scheduledDate: tz.TZDateTime.from(plan.at, tz.UTC),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Streak reminders',
              channelDescription: 'A nudge to keep your learning streak going',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }
}
