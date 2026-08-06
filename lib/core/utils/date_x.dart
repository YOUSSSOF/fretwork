import 'package:intl/intl.dart';

final DateFormat _dayKeyFormat = DateFormat('yyyy-MM-dd');
final DateFormat _shortDayFormat = DateFormat('EEE d MMM');
final DateFormat _monthFormat = DateFormat('MMMM yyyy');
final DateFormat _weekdayFormat = DateFormat('EEE');

extension DateX on DateTime {
  /// The key every day-scoped document is stored under.
  ///
  /// Deliberately local-time and date-only: a practice day is the user's day,
  /// not a UTC window, so a session at 00:30 belongs to the day the user
  /// thinks it does.
  String get dayKey => _dayKeyFormat.format(this);

  DateTime get dayStart => DateTime(year, month, day);

  DateTime get nextDay => DateTime(year, month, day + 1);

  DateTime get previousDay => DateTime(year, month, day - 1);

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Whole days between two dates, ignoring time of day and DST.
  ///
  /// Subtracting `DateTime`s directly is wrong across a DST boundary: one day
  /// can be 23 or 25 hours, so the difference truncates to 0 or rounds to 2.
  int daysUntil(DateTime other) {
    final from = dayStart;
    final to = other.dayStart;
    return (to.difference(from).inHours / 24).round();
  }

  String get shortDayLabel => _shortDayFormat.format(this);

  String get monthLabel => _monthFormat.format(this);

  String get weekdayLabel => _weekdayFormat.format(this);
}

DateTime? dayKeyToDate(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Every date from [from] up to and including [to], ascending.
Iterable<DateTime> daysBetween(DateTime from, DateTime to) sync* {
  var cursor = from.dayStart;
  final end = to.dayStart;
  while (!cursor.isAfter(end)) {
    yield cursor;
    cursor = cursor.nextDay;
  }
}

const List<int> kAllWeekdays = [
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

String weekdayName(int weekday) => switch (weekday) {
  DateTime.monday => 'Monday',
  DateTime.tuesday => 'Tuesday',
  DateTime.wednesday => 'Wednesday',
  DateTime.thursday => 'Thursday',
  DateTime.friday => 'Friday',
  DateTime.saturday => 'Saturday',
  DateTime.sunday => 'Sunday',
  _ => '',
};

String weekdayShortName(int weekday) => weekdayName(weekday).substring(0, 3);
