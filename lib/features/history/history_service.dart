import 'package:flutter/foundation.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/utils/date_x.dart';

/// A gap larger than this is not a gap, it is a clock that has been changed —
/// a timezone jump, a manual date edit, a device that booted with a bad RTC.
/// Backfilling a year of missed days on the strength of that would be worse
/// than doing nothing.
const int kMaxBackfillDays = 365;

@immutable
class BackfillResult {
  const BackfillResult({required this.records, this.clockAnomaly = false});

  final List<DayRecord> records;

  /// Set when the computed gap was negative or absurd. The caller records it
  /// and leaves history alone.
  final bool clockAnomaly;

  static const BackfillResult none = BackfillResult(records: []);
  static const BackfillResult anomalous = BackfillResult(
    records: [],
    clockAnomaly: true,
  );
}

/// Writes a record for every day between the last launch and today.
///
/// This is the requirement that empty days are counted: a missed day is a data
/// point, not the absence of one. Without this the heat map would be blank
/// wherever the user did nothing, and adherence would silently only ever
/// divide by the days they happened to open the app.
///
/// Pure, so every branch — DST, a backwards clock, a year away — is reachable
/// from a test.
BackfillResult backfillDays({
  required DateTime lastOpenedOn,
  required DateTime today,
  required Map<String, DayRecord> existing,
  required UserProfile profile,
  required int Function(DateTime date) plannedMinutesFor,
}) {
  final gap = lastOpenedOn.daysUntil(today);
  if (gap < 0 || gap > kMaxBackfillDays) return BackfillResult.anomalous;
  if (gap == 0) return BackfillResult.none;

  final records = <DayRecord>[];
  // Yesterday is the last day that can be judged: today is still in progress.
  for (final date in daysBetween(lastOpenedOn, today.previousDay)) {
    if (existing.containsKey(date.dayKey)) continue;

    final isRest = profile.isRestWeekday(date);
    records.add(
      DayRecord(
        date: date,
        plannedMinutes: isRest ? 0 : plannedMinutesFor(date),
        completedMinutes: 0,
        status: isRest ? DayStatus.rest : DayStatus.missed,
        milestoneAtTime: profile.milestone,
      ),
    );
  }

  return BackfillResult(records: records);
}

/// Ensures today itself has a record, so the calendar has something to render
/// for the day in progress rather than a hole.
DayRecord? ensureTodayRecord({
  required DateTime today,
  required Map<String, DayRecord> existing,
  required UserProfile profile,
  required int plannedMinutes,
}) {
  if (existing.containsKey(today.dayKey)) return null;
  final isRest = profile.isRestWeekday(today);
  return DayRecord(
    date: today,
    plannedMinutes: isRest ? 0 : plannedMinutes,
    completedMinutes: 0,
    status: isRest ? DayStatus.rest : DayStatus.upcoming,
    milestoneAtTime: profile.milestone,
  );
}
