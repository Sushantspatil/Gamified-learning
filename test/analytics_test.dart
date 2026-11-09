import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/analytics/data/analytics_service.dart';
import 'package:skillverse_app/features/analytics/presentation/analytics_providers.dart';
import 'package:skillverse_app/shared/widgets/quit_game_dialog.dart';

/// What the backend accepts for a string value (Go: analyticsValuePattern).
final _backendValue = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

/// Records every request the service sends.
class _Backend {
  final requests = <List<Map<String, dynamic>>>[];
  http.Response Function() respond = () =>
      http.Response('{"success":true}', 202);
  Object? failWith;

  MockClient get client => MockClient((request) async {
    expect(request.url.path, endsWith('/analytics/events'));
    expect(request.method, 'POST');
    final failure = failWith;
    if (failure != null) throw failure;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    requests.add(List<Map<String, dynamic>>.from(body['events'] as List));
    return respond();
  });
}

Future<(ApiAnalyticsService, _Backend, void Function())> _service({
  bool signedIn = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  final backend = _Backend();
  var signed = signedIn;
  final service = ApiAnalyticsService(
    apiClient: ApiClient(
      config: ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
      storage: storage,
      httpClient: backend.client,
    ),
    isSignedIn: () => signed,
    now: () => DateTime.utc(2026, 3, 10, 12),
  );
  return (service, backend, () => signed = false);
}

void main() {
  group('ApiAnalyticsService', () {
    test(
      'nothing is queued or sent for someone who is not signed in',
      () async {
        final (service, backend, _) = await _service(signedIn: false);
        for (var i = 0; i < 10; i++) {
          service.track(AnalyticsEvents.appOpen);
        }
        await service.flush();
        expect(service.queued, 0);
        expect(backend.requests, isEmpty);
      },
    );

    test('events wait until five are queued, then go out together', () async {
      final (service, backend, _) = await _service();
      for (var i = 0; i < 4; i++) {
        service.track(AnalyticsEvents.appOpen);
      }
      await Future<void>.delayed(Duration.zero);
      expect(backend.requests, isEmpty, reason: 'four is not enough to send');
      expect(service.queued, 4);

      service.track(AnalyticsEvents.appOpen);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(backend.requests.length, 1);
      expect(backend.requests.single.length, 5);
      expect(service.queued, 0);
    });

    test('flush sends what is waiting, with name, props and time', () async {
      final (service, backend, _) = await _service();
      service.track(AnalyticsEvents.gameQuit, {'mode': 'mcq-quiz', 'n': 3});
      service.track(AnalyticsEvents.reminderEnabled);
      await service.flush();

      final events = backend.requests.single;
      expect(events[0]['name'], 'game_quit');
      expect(events[0]['props'], {'mode': 'mcq-quiz', 'n': 3});
      expect(events[0]['at'], '2026-03-10T12:00:00.000Z');
      expect(events[1]['name'], 'reminder_enabled');
      expect(events[1].containsKey('props'), isFalse, reason: 'no empty props');
      expect(service.queued, 0);
    });

    test('flush with nothing waiting sends nothing', () async {
      final (service, backend, _) = await _service();
      await service.flush();
      expect(backend.requests, isEmpty);
    });

    test('no network: events are kept and sent on the next flush', () async {
      final (service, backend, _) = await _service();
      backend.failWith = const SocketException('offline');
      service.track(AnalyticsEvents.appOpen);
      service.track(AnalyticsEvents.reminderDeclined);
      await service.flush();
      expect(service.queued, 2);

      backend.failWith = null;
      await service.flush();
      expect(service.queued, 0);
      expect(backend.requests.single.map((e) => e['name']), [
        'app_open',
        'reminder_declined',
      ]);
    });

    test('a server error keeps the events too', () async {
      final (service, backend, _) = await _service();
      backend.respond = () => http.Response('{"message":"boom"}', 500);
      service.track(AnalyticsEvents.appOpen);
      await service.flush();
      expect(service.queued, 1);
    });

    test('a refused batch (400/429) is dropped, not retried forever', () async {
      final (service, backend, _) = await _service();
      backend.respond = () => http.Response('{"message":"slow down"}', 429);
      service.track(AnalyticsEvents.appOpen);
      await service.flush();
      expect(service.queued, 0);
    });

    test('keeps at most 50 events, dropping the oldest', () async {
      final (service, backend, _) = await _service();
      backend.failWith = const SocketException('offline');
      for (var i = 0; i < 80; i++) {
        service.track(AnalyticsEvents.gameQuit, {'n': i});
      }
      // Let the sends that tracking started finish (and fail) first.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.queued, ApiAnalyticsService.maxQueued);

      backend.failWith = null;
      await service.flush();
      // 50 events go out in two requests of at most 25, newest ones kept.
      expect(backend.requests.map((r) => r.length), [25, 25]);
      expect(backend.requests.first.first['props'], {'n': 30});
      expect(backend.requests.last.last['props'], {'n': 79});
    });

    test('two flushes at once do not send the same events twice', () async {
      final (service, backend, _) = await _service();
      service.track(AnalyticsEvents.appOpen);
      service.track(AnalyticsEvents.appOpen);
      await Future.wait([service.flush(), service.flush()]);
      expect(backend.requests.expand((r) => r).length, 2);
    });

    test('signing out stops sending and nothing throws', () async {
      final (service, backend, signOut) = await _service();
      service.track(AnalyticsEvents.appOpen);
      signOut();
      await service.flush();
      expect(backend.requests, isEmpty);
    });
  });

  group('game mode ids', () {
    test('become short identifiers the backend accepts', () {
      const modes = {
        'MCQ Quiz': 'mcq-quiz',
        'Match It': 'match-it',
        'Sort It Out': 'sort-it-out',
        'Sudden Death': 'sudden-death',
      };
      modes.forEach((mode, id) {
        expect(gameModeId(mode), id);
        expect(_backendValue.hasMatch(gameModeId(mode)), isTrue, reason: mode);
      });
    });

    test('odd text is cleaned up', () {
      expect(gameModeId('  Hello,  World!! '), 'hello-world');
    });
  });

  group('quitting a game', () {
    late _RecordingAnalytics recorder;

    Future<void> openDialog(WidgetTester tester) async {
      recorder = _RecordingAnalytics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyticsServiceProvider.overrideWithValue(recorder)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const Key('ask'),
                  onPressed: () => confirmQuitGame(context, mode: 'MCQ Quiz'),
                  child: const Text('ask'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('ask')));
      await tester.pumpAndSettle();
    }

    testWidgets('leaving is reported with the mode', (tester) async {
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('quit_game_leave')));
      await tester.pumpAndSettle();
      expect(recorder.events.length, 1);
      expect(recorder.events.single.$1, AnalyticsEvents.gameQuit);
      expect(recorder.events.single.$2, {'mode': 'mcq-quiz'});
    });

    testWidgets('keep playing reports nothing', (tester) async {
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('quit_game_keep')));
      await tester.pumpAndSettle();
      expect(recorder.events, isEmpty);
    });

    testWidgets('a screen without any provider scope still works', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('ask'),
                onPressed: () => confirmQuitGame(context, mode: 'Match It'),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('ask')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quit_game_leave')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

class _RecordingAnalytics implements AnalyticsService {
  final events = <(String, Map<String, Object>?)>[];

  @override
  void track(String name, [Map<String, Object>? props]) =>
      events.add((name, props));

  @override
  Future<void> flush() async {}
}
