import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/reminders/domain/reminder_planner.dart';

// 10:00 UTC on 10 March 2026. Whatever the player's time zone, the UTC day is
// what the streak is counted in.
final _now = DateTime.utc(2026, 3, 10, 10);

List<ReminderPlan> _plan({
  int streak = 5,
  Duration offset = Duration.zero,
  DateTime? now,
}) => planReminders(now: now ?? _now, streak: streak, utcOffset: offset);

void main() {
  test('three reminders: tomorrow, the day after, and four days out', () {
    final plans = _plan();
    expect(plans.map((p) => p.id), [1, 2, 3]);
    final days = plans.map((p) => p.at.toUtc().day).toList();
    expect(days, [11, 12, 14]);
  });

  test('India (UTC+5:30): 19:00 local is 13:30 UTC', () {
    final plans = _plan(offset: const Duration(hours: 5, minutes: 30));
    expect(plans[0].at, DateTime.utc(2026, 3, 11, 13, 30));
    expect(plans[1].at, DateTime.utc(2026, 3, 12, 13, 30));
    expect(plans[2].at, DateTime.utc(2026, 3, 14, 13, 30));
  });

  test('UTC itself: 19:00 UTC', () {
    expect(_plan().first.at, DateTime.utc(2026, 3, 11, 19));
  });

  test('a time zone west of UTC still lands inside the UTC day', () {
    // 19:00 in UTC-8 is 03:00 UTC the next day, so the reminder for UTC day
    // 11 March is the one that reads 19:00 on the player's clock the evening
    // before: 03:00 UTC on the 11th.
    final plans = _plan(offset: const Duration(hours: -8));
    expect(plans.first.at, DateTime.utc(2026, 3, 11, 3));
  });

  test('every reminder falls on its own UTC day at 19:00 on the player\'s '
      'clock, in every time zone', () {
    for (var minutes = -12 * 60; minutes <= 14 * 60; minutes += 15) {
      final offset = Duration(minutes: minutes);
      final plans = _plan(offset: offset);
      for (final (i, daysAhead) in [1, 2, 4].indexed) {
        final at = plans[i].at;
        expect(
          DateTime.utc(at.year, at.month, at.day),
          DateTime.utc(2026, 3, 10 + daysAhead),
          reason: 'offset $offset: reminder ${i + 1} is on the wrong UTC day',
        );
        final local = at.add(offset);
        expect(
          (local.hour, local.minute),
          (19, 0),
          reason: 'offset $offset: reminder ${i + 1} is not at 19:00 local',
        );
        expect(at.isUtc, isTrue);
      }
    }
  });

  test('all reminders are in the future, even late in the UTC day', () {
    final lateNow = DateTime.utc(2026, 3, 10, 23, 59);
    for (final offset in [
      Duration.zero,
      const Duration(hours: 5, minutes: 30),
      const Duration(hours: -8),
    ]) {
      for (final plan in _plan(now: lateNow, offset: offset)) {
        expect(plan.at.isAfter(lateNow), isTrue, reason: '$offset ${plan.id}');
      }
    }
  });

  test('crosses a month and a year end', () {
    final plans = _plan(
      now: DateTime.utc(2026, 12, 30, 8),
      offset: const Duration(hours: 5, minutes: 30),
    );
    expect(plans[0].at, DateTime.utc(2026, 12, 31, 13, 30));
    expect(plans[1].at, DateTime.utc(2027, 1, 1, 13, 30));
    expect(plans[2].at, DateTime.utc(2027, 1, 3, 13, 30));
  });

  test('the first reminder names the streak when there is one', () {
    final p = _plan(streak: 7).first;
    expect(p.title, 'Keep your 7-day streak alive');
    expect(p.body, contains('Open SkillVerse'));
  });

  test('no streak yet: the first reminder invites the player to start', () {
    for (final streak in [0, 1]) {
      final p = _plan(streak: streak).first;
      expect(p.title, 'Ready for today\'s goals?', reason: 'streak $streak');
      expect(p.title, isNot(contains('0-day')));
    }
  });

  test('later reminders do not repeat the streak count', () {
    final plans = _plan(streak: 9);
    expect(plans[1].title, isNot(contains('9')));
    expect(plans[2].title, isNot(contains('9')));
    expect(plans.map((p) => p.title).toSet().length, 3);
  });
}
