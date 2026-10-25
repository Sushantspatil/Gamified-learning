import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:skillverse_app/features/leaderboard/data/models/leaderboard_response_model.dart';

void main() {
  group('LeaderboardEntryModel', () {
    test('parses a valid JSON entry with integer score and server rank', () {
      final json = {
        'rank': 1,
        'user_id': 'user-123',
        'display_name': 'Champion Alex',
        'avatar_id': 'robot',
        'avatar_url': null,
        'score': 1500,
        'is_current_user': true,
      };

      final model = LeaderboardEntryModel.fromJson(json);

      expect(model.rank, 1);
      expect(model.userId, 'user-123');
      expect(model.displayName, 'Champion Alex');
      expect(model.avatarId, 'robot');
      expect(model.avatarUrl, isNull);
      expect(model.score, 1500);
      expect(model.xp, 1500);
      expect(model.isCurrentUser, isTrue);
    });

    test('parses numeric (floating-point) and string scores safely', () {
      final floatEntry = LeaderboardEntryModel.fromJson({
        'rank': 2,
        'user_id': 'user-456',
        'display_name': 'Player Two',
        'avatar_id': 'owl',
        'avatar_url': 'https://example.com/avatar.png',
        'score': 1250.75,
        'is_current_user': false,
      });

      expect(floatEntry.score, 1250);
      expect(floatEntry.avatarUrl, 'https://example.com/avatar.png');
      expect(floatEntry.isCurrentUser, isFalse);

      final stringEntry = LeaderboardEntryModel.fromJson({
        'rank': '3',
        'user_id': 'user-789',
        'display_name': 'Player Three',
        'avatar_id': 'ninja',
        'score': '990',
        'is_current_user': false,
      });

      expect(stringEntry.rank, 3);
      expect(stringEntry.score, 990);
    });

    test('parses zero-score users correctly without omitting them', () {
      final zeroEntry = LeaderboardEntryModel.fromJson({
        'rank': 42,
        'user_id': 'user-000',
        'display_name': 'Newbie',
        'avatar_id': 'user',
        'avatar_url': null,
        'score': 0,
        'is_current_user': false,
      });

      expect(zeroEntry.rank, 42);
      expect(zeroEntry.score, 0);
      expect(zeroEntry.displayName, 'Newbie');
    });

    test('serializes to JSON correctly', () {
      const model = LeaderboardEntryModel(
        rank: 5,
        userId: 'u-5',
        displayName: 'Sam',
        avatarId: 'fox',
        avatarUrl: 'https://cdn.example.com/fox.png',
        score: 750,
        isCurrentUser: true,
      );

      final json = model.toJson();

      expect(json['rank'], 5);
      expect(json['user_id'], 'u-5');
      expect(json['display_name'], 'Sam');
      expect(json['avatar_id'], 'fox');
      expect(json['avatar_url'], 'https://cdn.example.com/fox.png');
      expect(json['score'], 750);
      expect(json['is_current_user'], isTrue);
    });
  });

  group('LeaderboardResponseModel', () {
    test('parses a full paginated server response', () {
      final json = {
        'items': [
          {
            'rank': 1,
            'user_id': 'u-1',
            'display_name': 'Top Player',
            'avatar_id': 'wizard',
            'avatar_url': null,
            'score': 2000,
            'is_current_user': false,
          },
          {
            'rank': 2,
            'user_id': 'u-2',
            'display_name': 'Second Player',
            'avatar_id': 'robot',
            'avatar_url': null,
            'score': 1800,
            'is_current_user': true,
          },
        ],
        'page': 1,
        'page_size': 50,
        'total_count': 120,
        'has_more': true,
        'current_user_rank': 2,
      };

      final response = LeaderboardResponseModel.fromJson(json);

      expect(response.items.length, 2);
      expect(response.page, 1);
      expect(response.pageSize, 50);
      expect(response.totalCount, 120);
      expect(response.hasMore, isTrue);
      expect(response.currentUserRank, 2);
      expect(response.items[0].rank, 1);
      expect(response.items[0].score, 2000);
      expect(response.items[1].isCurrentUser, isTrue);
    });

    test('parses empty items array and nullable current_user_rank', () {
      final json = {
        'items': [],
        'page': 1,
        'page_size': 50,
        'total_count': 0,
        'has_more': false,
        'current_user_rank': null,
      };

      final response = LeaderboardResponseModel.fromJson(json);

      expect(response.items, isEmpty);
      expect(response.page, 1);
      expect(response.pageSize, 50);
      expect(response.totalCount, 0);
      expect(response.hasMore, isFalse);
      expect(response.currentUserRank, isNull);
    });

    test('serializes response to JSON', () {
      const response = LeaderboardResponseModel(
        items: [
          LeaderboardEntryModel(
            rank: 1,
            userId: 'u-1',
            displayName: 'Winner',
            avatarId: 'star',
            score: 500,
            isCurrentUser: false,
          ),
        ],
        page: 1,
        pageSize: 20,
        totalCount: 1,
        hasMore: false,
        currentUserRank: 1,
      );

      final json = response.toJson();

      expect(json['page'], 1);
      expect(json['page_size'], 20);
      expect(json['total_count'], 1);
      expect(json['has_more'], isFalse);
      expect(json['current_user_rank'], 1);
      expect((json['items'] as List).length, 1);
    });
  });
}
