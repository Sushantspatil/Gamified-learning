/// Formats a DateTime as a plain 'yyyy-MM-dd' calendar-day key, used by the
/// streaks/daily-rewards/daily-missions mock datasources to compare "is this
/// the same day" without pulling in intl for a single format.
String dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
