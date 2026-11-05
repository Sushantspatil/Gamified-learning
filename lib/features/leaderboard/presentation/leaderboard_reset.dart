import '../domain/entities/leaderboard_filter.dart';

/// How long until the current board starts again, assuming the usual
/// boundaries (midnight, Monday, the 1st of the month), or null for "All Time",
/// which never resets.
Duration? leaderboardResetIn(LeaderboardTimeRange range, DateTime now) {
  final DateTime next;
  switch (range) {
    case LeaderboardTimeRange.daily:
      next = DateTime(now.year, now.month, now.day + 1);
    case LeaderboardTimeRange.weekly:
      // The next Monday; on a Monday it is a full week away.
      var days = (DateTime.monday - now.weekday + 7) % 7;
      if (days == 0) days = 7;
      next = DateTime(now.year, now.month, now.day + days);
    case LeaderboardTimeRange.monthly:
      next = DateTime(now.year, now.month + 1, 1);
    case LeaderboardTimeRange.allTime:
      return null;
  }
  return next.difference(now);
}

/// "2d 5h", "5h 20m" or "12m".
String leaderboardResetLabel(Duration remaining) {
  final minutes = (remaining.inSeconds + 59) ~/ 60; // round up
  final days = minutes ~/ (24 * 60);
  final hours = (minutes ~/ 60) % 24;
  final mins = minutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${mins}m';
  return '${mins < 1 ? 1 : mins}m';
}

/// 1 becomes "1st", 2 "2nd", 3 "3rd", 11 "11th", 22 "22nd".
String ordinal(int n) {
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}
