import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/features/history/history_service.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';

/// Runs the day rollover.
///
/// Called on launch and on resume. Idempotent — running it twice in a day does
/// nothing the second time, which matters because "resume" fires far more
/// often than the user thinks.
class HistoryRollover {
  const HistoryRollover(this._ref);

  final Ref _ref;

  Future<void> run() async {
    final profile = _ref.read(profileProvider);
    if (!profile.onboardingComplete) return;

    final today = _ref.read(clockProvider).now().dayStart;
    final lastOpened = profile.lastOpenedOn?.dayStart ?? today;
    final days = _ref.read(dayRecordsProvider.notifier);

    final result = backfillDays(
      lastOpenedOn: lastOpened,
      today: today,
      existing: _ref.read(dayRecordsProvider),
      profile: profile,
      plannedMinutesFor: (date) => _plannedMinutesFor(date, profile),
    );

    if (result.clockAnomaly) {
      // Recorded rather than acted on: better a flag an engineer can see than
      // a year of fabricated missed days.
      await _ref.read(storeProvider).putMeta(MetaKeys.clockAnomaly, true);
    } else if (result.records.isNotEmpty) {
      await days.putAll(result.records);
    }

    final todayRecord = ensureTodayRecord(
      today: today,
      existing: _ref.read(dayRecordsProvider),
      profile: profile,
      plannedMinutes: _ref.read(todayRoutineProvider).plannedMinutes,
    );
    if (todayRecord != null) await days.put(todayRecord);

    await _ref.read(profileProvider.notifier).markOpenedOn(today);
  }

  /// What the user was supposed to do on a day they never opened the app.
  ///
  /// The stored routine if one was generated, otherwise the ideal for the
  /// milestone they were at — which is the fairest denominator available.
  int _plannedMinutesFor(DateTime date, UserProfile profile) {
    final stored = _ref
        .read(storeProvider)
        .read(BoxNames.routines, date.dayKey);
    if (stored != null) return RoutineDay.fromJson(stored).plannedMinutes;
    return profile.sessionMinutes;
  }
}

final historyRolloverProvider = Provider<HistoryRollover>(HistoryRollover.new);

/// Day records sorted oldest first, with today included.
final historyProvider = Provider<List<DayRecord>>((ref) {
  final records = ref.watch(dayRecordsProvider).values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return records;
});

/// Everything logged for one day: the plan, the sessions, the outcome.
@immutable
class DayDetail {
  const DayDetail({
    required this.date,
    required this.record,
    required this.routine,
    required this.sessions,
  });

  final DateTime date;
  final DayRecord? record;
  final RoutineDay? routine;
  final List<SessionRecord> sessions;

  bool get hasAnything => record != null || routine != null;

  int get completedMinutes =>
      sessions.fold<int>(0, (sum, s) => sum + s.actualMinutes);
}

final dayDetailProvider = Provider.family<DayDetail, DateTime>((ref, date) {
  final stored = ref.watch(storeProvider).read(BoxNames.routines, date.dayKey);
  return DayDetail(
    date: date,
    record: ref.watch(dayRecordsProvider)[date.dayKey],
    routine: stored == null ? null : RoutineDay.fromJson(stored),
    sessions: [
      for (final session in ref.watch(sessionRecordsProvider))
        if (session.startedAt.isSameDayAs(date)) session,
    ],
  );
});
