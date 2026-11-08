import 'package:equatable/equatable.dart';

/// One reminder to show at [at] (an exact moment, in UTC).
class ReminderPlan extends Equatable {
  final int id;
  final DateTime at;
  final String title;
  final String body;

  const ReminderPlan({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  @override
  List<Object?> get props => [id, at, title, body];
}

/// The hour of the day, on the player's clock, reminders aim for.
const int reminderLocalHour = 19;

/// The reminders to schedule after the player has opened the app at [now].
///
/// The backend counts a streak day as a UTC day: opening the app once on each
/// UTC day keeps the streak. So every reminder is placed inside the UTC day it
/// is meant to save, at [reminderLocalHour] on the player's own clock (whatever
/// their time zone), and the first one is for tomorrow: the player has already
/// opened the app today.
///
/// Three reminders at most, then silence until the player comes back:
/// tomorrow, the day after, and four days out. Opening the app replans all
/// three from that moment.
///
/// [utcOffset] is the player's offset from UTC (for example +5:30 in India);
/// it defaults to the offset of [now].
List<ReminderPlan> planReminders({
  required DateTime now,
  required int streak,
  Duration? utcOffset,
}) {
  final utcNow = now.toUtc();
  final today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
  final offset = utcOffset ?? now.timeZoneOffset;

  DateTime inUtcDay(int daysAhead) {
    final day = today.add(Duration(days: daysAhead));
    // The one moment inside that UTC day when the player's clock reads 19:00.
    var intoDay =
        Duration(hours: reminderLocalHour) -
        offset; // may be negative or over 24h
    const dayLength = Duration(hours: 24);
    intoDay = Duration(
      minutes: intoDay.inMinutes % dayLength.inMinutes,
    ); // Dart's % is never negative
    return day.add(intoDay);
  }

  final tomorrow = streak >= 2
      ? ReminderPlan(
          id: 1,
          at: inUtcDay(1),
          title: 'Keep your $streak-day streak alive',
          body: 'Open SkillVerse today and play a quick game.',
        )
      : ReminderPlan(
          id: 1,
          at: inUtcDay(1),
          title: 'Ready for today\'s goals?',
          body: 'A quick game earns coins and starts your streak.',
        );

  return [
    tomorrow,
    ReminderPlan(
      id: 2,
      at: inUtcDay(2),
      title: 'Your streak misses you',
      body: 'Come back today and start a new one. Your goals are waiting.',
    ),
    ReminderPlan(
      id: 3,
      at: inUtcDay(4),
      title: 'Daily goals are waiting',
      body: 'Even one quick game counts. Pick up where you left off.',
    ),
  ];
}
