import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/features/history/history_service.dart';

UserProfile _profile({Set<int> restWeekdays = const {}}) => UserProfile(
  milestone: 6,
  sessionMinutes: 60,
  restWeekdays: restWeekdays,
  startedAt: DateTime(2026, 1, 1),
  onboardingComplete: true,
);

BackfillResult _backfill({
  required DateTime lastOpened,
  required DateTime today,
  Map<String, DayRecord> existing = const {},
  Set<int> restWeekdays = const {},
  int planned = 60,
}) => backfillDays(
  lastOpenedOn: lastOpened,
  today: today,
  existing: existing,
  profile: _profile(restWeekdays: restWeekdays),
  plannedMinutesFor: (_) => planned,
);

void main() {
  group('backfillDays', () {
    test('records every skipped day as missed, not as nothing', () {
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 10),
        today: DateTime(2026, 3, 14),
      );

      // 10th through 13th: today is still in progress and is not judged.
      expect(result.records.map((r) => r.id), [
        '2026-03-10',
        '2026-03-11',
        '2026-03-12',
        '2026-03-13',
      ]);
      for (final record in result.records) {
        expect(record.status, DayStatus.missed);
        expect(record.completedMinutes, 0);
        expect(
          record.plannedMinutes,
          60,
          reason: 'a missed day still has a denominator',
        );
      }
    });

    test('rest weekdays backfill as rest, with nothing planned', () {
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 8),
        today: DateTime(2026, 3, 14),
        restWeekdays: {DateTime.sunday},
      );

      final sunday = result.records.firstWhere((r) => r.id == '2026-03-08');
      expect(sunday.status, DayStatus.rest);
      expect(sunday.plannedMinutes, 0);

      final monday = result.records.firstWhere((r) => r.id == '2026-03-09');
      expect(monday.status, DayStatus.missed);
    });

    test('never overwrites a day that already has a record', () {
      final existing = {
        '2026-03-11': DayRecord(
          date: DateTime(2026, 3, 11),
          plannedMinutes: 60,
          completedMinutes: 55,
          status: DayStatus.completed,
          milestoneAtTime: 6,
        ),
      };
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 10),
        today: DateTime(2026, 3, 14),
        existing: existing,
      );

      expect(result.records.map((r) => r.id), isNot(contains('2026-03-11')));
      expect(result.records, hasLength(3));
    });

    test('does nothing when the app was already opened today', () {
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 14, 8),
        today: DateTime(2026, 3, 14, 20),
      );
      expect(result.records, isEmpty);
      expect(result.clockAnomaly, isFalse);
    });

    test('flags a backwards clock instead of backfilling', () {
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 20),
        today: DateTime(2026, 3, 14),
      );
      expect(result.clockAnomaly, isTrue);
      expect(result.records, isEmpty);
    });

    test('flags an absurd gap instead of inventing a year of misses', () {
      final result = _backfill(
        lastOpened: DateTime(2020, 1, 1),
        today: DateTime(2026, 3, 14),
      );
      expect(result.clockAnomaly, isTrue);
      expect(result.records, isEmpty);
    });

    test('accepts a gap right at the limit', () {
      final today = DateTime(2026, 3, 14);
      final result = _backfill(
        lastOpened: today.subtract(const Duration(days: kMaxBackfillDays)),
        today: today,
      );
      expect(result.clockAnomaly, isFalse);
      expect(result.records, hasLength(kMaxBackfillDays));
    });

    test('counts whole days across a spring-forward boundary', () {
      // 29 March 2026 is a 23-hour day in most European zones. A naive
      // difference().inDays would lose a day here.
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 27),
        today: DateTime(2026, 3, 31),
      );
      expect(result.records.map((r) => r.id), [
        '2026-03-27',
        '2026-03-28',
        '2026-03-29',
        '2026-03-30',
      ]);
    });

    test('counts whole days across an autumn fall-back boundary', () {
      final result = _backfill(
        lastOpened: DateTime(2026, 10, 24),
        today: DateTime(2026, 10, 27),
      );
      expect(result.records, hasLength(3));
      expect(result.records.last.id, '2026-10-26');
    });

    test('a single missed day is recorded', () {
      final result = _backfill(
        lastOpened: DateTime(2026, 3, 13),
        today: DateTime(2026, 3, 14),
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.id, '2026-03-13');
    });
  });

  group('ensureTodayRecord', () {
    test('creates an upcoming record for a fresh day', () {
      final record = ensureTodayRecord(
        today: DateTime(2026, 3, 14),
        existing: const {},
        profile: _profile(),
        plannedMinutes: 60,
      );
      expect(record, isNotNull);
      expect(record!.status, DayStatus.upcoming);
      expect(record.plannedMinutes, 60);
    });

    test('creates a rest record when today is a rest weekday', () {
      // 15 March 2026 is a Sunday.
      final record = ensureTodayRecord(
        today: DateTime(2026, 3, 15),
        existing: const {},
        profile: _profile(restWeekdays: {DateTime.sunday}),
        plannedMinutes: 60,
      );
      expect(record!.status, DayStatus.rest);
      expect(record.plannedMinutes, 0);
    });

    test('leaves an existing record alone', () {
      final today = DateTime(2026, 3, 14);
      final record = ensureTodayRecord(
        today: today,
        existing: {
          today.dayKey: DayRecord(
            date: today,
            plannedMinutes: 60,
            completedMinutes: 30,
            status: DayStatus.partial,
            milestoneAtTime: 6,
          ),
        },
        profile: _profile(),
        plannedMinutes: 60,
      );
      expect(record, isNull);
    });
  });
}
