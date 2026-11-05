import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/leaderboard/domain/entities/leaderboard_filter.dart';
import 'package:skillverse_app/features/leaderboard/presentation/leaderboard_reset.dart';

void main() {
  group('leaderboardResetIn', () {
    test('daily resets at the next midnight', () {
      final now = DateTime(2026, 11, 4, 18, 30);
      expect(
        leaderboardResetIn(LeaderboardTimeRange.daily, now),
        const Duration(hours: 5, minutes: 30),
      );
    });

    test('weekly resets on the next Monday', () {
      // Wednesday 4 November 2026 at noon: Monday is 4 days 12 hours away.
      final now = DateTime(2026, 11, 4, 12);
      expect(
        leaderboardResetIn(LeaderboardTimeRange.weekly, now),
        const Duration(days: 4, hours: 12),
      );
      // On a Monday the next reset is a full week away.
      final monday = DateTime(2026, 11, 2);
      expect(
        leaderboardResetIn(LeaderboardTimeRange.weekly, monday),
        const Duration(days: 7),
      );
    });

    test('monthly resets on the 1st, and all time never resets', () {
      final now = DateTime(2026, 11, 30, 23);
      expect(
        leaderboardResetIn(LeaderboardTimeRange.monthly, now),
        const Duration(hours: 1),
      );
      expect(leaderboardResetIn(LeaderboardTimeRange.allTime, now), isNull);
    });
  });

  test('the countdown reads as days, hours or minutes', () {
    expect(leaderboardResetLabel(const Duration(days: 2, hours: 5)), '2d 5h');
    expect(
      leaderboardResetLabel(const Duration(hours: 5, minutes: 20)),
      '5h 20m',
    );
    expect(leaderboardResetLabel(const Duration(minutes: 12)), '12m');
    expect(leaderboardResetLabel(const Duration(seconds: 5)), '1m');
  });

  test('ordinals', () {
    const cases = {
      1: '1st',
      2: '2nd',
      3: '3rd',
      4: '4th',
      11: '11th',
      12: '12th',
      13: '13th',
      21: '21st',
      22: '22nd',
      23: '23rd',
      101: '101st',
      111: '111th',
    };
    cases.forEach((n, expected) => expect(ordinal(n), expected));
  });
}
