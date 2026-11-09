import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// The usage events the app reports. The backend only accepts these names
/// (`AnalyticsEventNames` in the Go backend); anything else is dropped there.
class AnalyticsEvents {
  AnalyticsEvents._();

  static const String appOpen = 'app_open';
  static const String reminderPromptShown = 'reminder_prompt_shown';
  static const String reminderEnabled = 'reminder_enabled';
  static const String reminderDeclined = 'reminder_declined';
  static const String reminderBlocked = 'reminder_blocked';
  static const String gameQuit = 'game_quit';
}

/// Reports what players do so the app can be improved. Strictly best effort: it
/// never throws, never waits for the network, and never shows anything to the
/// player.
abstract class AnalyticsService {
  /// Notes that something happened. Details must be numbers, booleans or short
  /// lowercase identifiers (no names, no free text): the backend rejects the rest.
  void track(String name, [Map<String, Object>? props]);

  /// Sends what is waiting. Called when the app goes to the background.
  Future<void> flush();
}

/// Does nothing: the web, tests, and anyone not signed in.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  void track(String name, [Map<String, Object>? props]) {}
  @override
  Future<void> flush() async {}
}

/// Collects events in memory and sends them in small batches to the backend.
///
/// There is no timer: events are sent when five are waiting and whenever the app
/// goes to the background, which keeps it quiet and easy to test. Events that
/// cannot be sent (no network) stay queued for the next try, up to [maxQueued];
/// beyond that the oldest are dropped.
class ApiAnalyticsService implements AnalyticsService {
  static const int sendWhenQueued = 5;
  static const int maxQueued = 50;
  static const int maxPerRequest = 25; // the backend's limit per request

  final ApiClient _apiClient;
  final bool Function() _isSignedIn;
  final DateTime Function() _now;
  final List<Map<String, Object>> _queue = [];
  bool _sending = false;

  ApiAnalyticsService({
    required ApiClient apiClient,
    required bool Function() isSignedIn,
    DateTime Function() now = DateTime.now,
  }) : _apiClient = apiClient,
       _isSignedIn = isSignedIn,
       _now = now;

  /// How many events are waiting (for tests).
  int get queued => _queue.length;

  @override
  void track(String name, [Map<String, Object>? props]) {
    // The endpoint is for signed-in players; asking it anything else would only
    // produce errors.
    if (!_isSignedIn()) return;
    _queue.add({
      'name': name,
      if (props != null && props.isNotEmpty) 'props': props,
      'at': _now().toUtc().toIso8601String(),
    });
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    if (_queue.length >= sendWhenQueued) unawaited(flush());
  }

  @override
  Future<void> flush() async {
    if (_sending || _queue.isEmpty || !_isSignedIn()) return;
    _sending = true;
    try {
      while (_queue.isNotEmpty && _isSignedIn()) {
        final count = _queue.length < maxPerRequest
            ? _queue.length
            : maxPerRequest;
        final batch = List<Map<String, Object>>.of(_queue.take(count));
        try {
          await _apiClient.post(
            ApiEndpoints.analyticsEvents,
            body: {'events': batch},
          );
        } on ValidationException {
          // The server refused this batch (too many, too fast): sending it
          // again would be refused again, so let it go.
        } on AppException {
          return; // no network or a server problem: keep the events for later
        }
        _queue.removeRange(0, count);
      }
    } catch (_) {
      // Analytics never gets in the way of the app.
    } finally {
      _sending = false;
    }
  }
}
