import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/leaderboard/data/datasources/remote/leaderboard_remote_datasource.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_filter.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LeaderboardRemoteDatasource', () {
    test('sends expected endpoint and default query parameters', () async {
      final storage = await LocalStorageService.create();
      await storage.setString(StorageKeys.authToken, 'valid-token');

      http.Request? capturedRequest;
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'rank': 1,
                    'user_id': 'u-1',
                    'display_name': 'Player 1',
                    'avatar_id': 'robot',
                    'avatar_url': null,
                    'score': 1000,
                    'is_current_user': true,
                  }
                ],
                'page': 1,
                'page_size': 50,
                'total_count': 1,
                'has_more': false,
                'current_user_rank': 1,
              },
            }),
            200,
          );
        }),
      );

      final datasource = LeaderboardRemoteDatasource(client);
      final result = await datasource.getLeaderboardPage(
        filter: const LeaderboardFilter(),
        page: 1,
        pageSize: 50,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/v1/leaderboard');
      expect(capturedRequest!.url.queryParameters['scope'], 'global');
      expect(capturedRequest!.url.queryParameters['time_range'], 'weekly');
      expect(capturedRequest!.url.queryParameters['page'], '1');
      expect(capturedRequest!.url.queryParameters['page_size'], '50');
      // game_mode and subject_id should be omitted
      expect(capturedRequest!.url.queryParameters.containsKey('game_mode'), isFalse);
      expect(capturedRequest!.url.queryParameters.containsKey('subject_id'), isFalse);

      expect(result.items.length, 1);
      expect(result.items.first.displayName, 'Player 1');
      expect(result.items.first.score, 1000);
      expect(result.items.first.isCurrentUser, isTrue);
    });

    test('sends selected game_mode, subject_id, and time_range when filtered', () async {
      final storage = await LocalStorageService.create();
      http.Request? capturedRequest;

      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [],
                'page': 2,
                'page_size': 25,
                'total_count': 0,
                'has_more': false,
              },
            }),
            200,
          );
        }),
      );

      final datasource = LeaderboardRemoteDatasource(client);
      await datasource.getLeaderboardPage(
        filter: const LeaderboardFilter(
          quizType: QuestionType.matchTheFollowing,
          subjectId: 'accounting',
          timeRange: LeaderboardTimeRange.monthly,
          scope: LeaderboardScope.global,
        ),
        page: 2,
        pageSize: 25,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.queryParameters['scope'], 'global');
      expect(capturedRequest!.url.queryParameters['time_range'], 'monthly');
      expect(capturedRequest!.url.queryParameters['game_mode'], 'match_the_following');
      expect(capturedRequest!.url.queryParameters['subject_id'], 'accounting');
      expect(capturedRequest!.url.queryParameters['page'], '2');
      expect(capturedRequest!.url.queryParameters['page_size'], '25');
    });

    test('maps all QuestionTypes and LeaderboardTimeRanges accurately', () async {
      expect(LeaderboardRemoteDatasource.mapTimeRange(LeaderboardTimeRange.daily), 'daily');
      expect(LeaderboardRemoteDatasource.mapTimeRange(LeaderboardTimeRange.weekly), 'weekly');
      expect(LeaderboardRemoteDatasource.mapTimeRange(LeaderboardTimeRange.monthly), 'monthly');
      expect(LeaderboardRemoteDatasource.mapTimeRange(LeaderboardTimeRange.allTime), 'all_time');

      expect(QuestionType.mcq.backendGameMode, 'mcq');
      expect(QuestionType.suddenDeath.backendGameMode, 'sudden_death');
      expect(QuestionType.sortItRight.backendGameMode, 'sort_it_out');
      expect(QuestionType.matchTheFollowing.backendGameMode, 'match_the_following');
    });

    test('returns empty page without calling backend for unsupported scopes', () async {
      final storage = await LocalStorageService.create();
      var networkCalled = false;

      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          networkCalled = true;
          return http.Response('{}', 200);
        }),
      );

      final datasource = LeaderboardRemoteDatasource(client);

      final friendsResult = await datasource.getLeaderboardPage(
        filter: const LeaderboardFilter(scope: LeaderboardScope.friends),
      );
      expect(friendsResult.items, isEmpty);
      expect(networkCalled, isFalse);

      final schoolResult = await datasource.getLeaderboardPage(
        filter: const LeaderboardFilter(scope: LeaderboardScope.school),
      );
      expect(schoolResult.items, isEmpty);
      expect(networkCalled, isFalse);
    });

    test('propagates 401 AuthException and does not return fallback players', () async {
      final storage = await LocalStorageService.create();
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Missing or invalid authentication token'}),
            401,
          );
        }),
      );

      final datasource = LeaderboardRemoteDatasource(client);

      await expectLater(
        datasource.getLeaderboardPage(filter: const LeaderboardFilter()),
        throwsA(isA<AuthException>()),
      );
    });

    test('propagates 500 ServerException without converting to empty result', () async {
      final storage = await LocalStorageService.create();
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'https://api.example.com/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Internal Server Error'}),
            500,
          );
        }),
      );

      final datasource = LeaderboardRemoteDatasource(client);

      await expectLater(
        datasource.getLeaderboardPage(filter: const LeaderboardFilter()),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
