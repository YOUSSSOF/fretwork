import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/utils/date_x.dart';

/// Round-trips through a real `jsonEncode`/`jsonDecode` rather than just
/// `fromJson(toJson())`, because that is what Hive actually stores — a map that
/// survives in memory but not through JSON would pass the weaker check.
T _roundTrip<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?>) fromJson,
) => fromJson(Map<String, Object?>.from(jsonDecode(jsonEncode(json)) as Map));

void main() {
  final date = DateTime(2026, 3, 14, 9, 30);

  group('UserProfile', () {
    test('round-trips', () {
      final profile = UserProfile(
        milestone: 6,
        sessionMinutes: 75,
        restWeekdays: const {DateTime.sunday, DateTime.wednesday},
        startedAt: date,
        lastOpenedOn: date.add(const Duration(days: 3)),
        onboardingComplete: true,
      );
      expect(_roundTrip(profile.toJson(), UserProfile.fromJson), profile);
    });

    test('clamps a stored session length that is out of policy', () {
      final json = UserProfile(startedAt: date).toJson()
        ..['sessionMinutes'] = 900;
      expect(UserProfile.fromJson(json).sessionMinutes, kMaxSessionMinutes);
    });

    test('drops nonsense weekday values', () {
      final json = UserProfile(startedAt: date).toJson()
        ..['restWeekdays'] = [0, 3, 99];
      expect(UserProfile.fromJson(json).restWeekdays, {DateTime.wednesday});
    });

    test('suggested minutes follow the milestone table', () {
      expect(UserProfile.suggestedMinutes(2), 30);
      expect(UserProfile.suggestedMinutes(4), 30);
      expect(UserProfile.suggestedMinutes(5), 45);
      expect(UserProfile.suggestedMinutes(6), 60);
      expect(UserProfile.suggestedMinutes(7), 75);
      expect(UserProfile.suggestedMinutes(8), 75);
      expect(UserProfile.suggestedMinutes(9), 90);
      expect(UserProfile.suggestedMinutes(10), 90);
    });
  });

  group('RoutineDay', () {
    final routine = RoutineDay(
      date: date,
      milestone: 6,
      plannedMinutes: 60,
      generationSeed: 42,
      generatedAt: date,
      blocks: const [
        RoutineBlock(
          category: PracticeCategory.warmupLeft,
          label: 'Left-hand warm-up',
          minutes: 8,
          items: [
            RoutineItem(
              exerciseId: 'ex_1',
              variantId: 'ex_1_part_a',
              minutes: 4,
              targetTempo: 72,
              procedure: ProcedureType.ladder,
              focusNote: 'Flawless before +8 bpm',
            ),
            RoutineItem(
              exerciseId: 'ex_3',
              minutes: 4,
              targetTempo: 66,
              procedure: ProcedureType.ladder,
              focusNote: '',
            ),
          ],
        ),
      ],
    );

    test('round-trips', () {
      expect(_roundTrip(routine.toJson(), RoutineDay.fromJson), routine);
    });

    test('id is the local day key', () {
      expect(routine.id, '2026-03-14');
    });

    test('item keys distinguish variants of the same exercise', () {
      expect(routine.blocks.first.items.first.key, 'ex_1:ex_1_part_a');
      expect(routine.blocks.first.items.last.key, 'ex_3');
    });
  });

  group('DayRecord', () {
    test('round-trips', () {
      final record = DayRecord(
        date: date,
        plannedMinutes: 60,
        completedMinutes: 45,
        status: DayStatus.completed,
        sessionIds: const ['s1', 's2'],
        milestoneAtTime: 6,
      );
      expect(_roundTrip(record.toJson(), DayRecord.fromJson), record);
    });

    test('status derivation matches the streak threshold', () {
      DayStatus statusFor(int completed) => DayRecord.statusFor(
        plannedMinutes: 60,
        completedMinutes: completed,
        isRestDay: false,
      );

      expect(statusFor(0), DayStatus.missed);
      expect(statusFor(20), DayStatus.partial);
      expect(statusFor(36), DayStatus.completed);
      expect(statusFor(60), DayStatus.completed);
      expect(
        DayRecord.statusFor(
          plannedMinutes: 0,
          completedMinutes: 0,
          isRestDay: true,
        ),
        DayStatus.rest,
      );
    });

    test('a rest day counts for the streak without any minutes', () {
      final rest = DayRecord(
        date: date,
        plannedMinutes: 0,
        completedMinutes: 0,
        status: DayStatus.rest,
        milestoneAtTime: 6,
      );
      expect(rest.countsForStreak, isTrue);
    });

    test('a day with no plan cannot divide by zero', () {
      final empty = DayRecord(
        date: date,
        plannedMinutes: 0,
        completedMinutes: 0,
        status: DayStatus.missed,
        milestoneAtTime: 2,
      );
      expect(empty.completionRatio, 0);
      expect(empty.countsForStreak, isFalse);
    });
  });

  group('SessionRecord', () {
    test('round-trips and totals by category, ignoring skips', () {
      final session = SessionRecord(
        id: 'session-1',
        startedAt: date,
        endedAt: date.add(const Duration(minutes: 42)),
        plannedMinutes: 60,
        actualMinutes: 42,
        abandoned: true,
        items: const [
          ItemResult(
            exerciseId: 'ex_1',
            category: PracticeCategory.warmupLeft,
            seconds: 240,
            startTempo: 60,
            endTempo: 68,
            clean: true,
          ),
          ItemResult(
            exerciseId: 'ex_3',
            category: PracticeCategory.warmupLeft,
            seconds: 120,
            startTempo: 66,
            endTempo: 66,
          ),
          ItemResult(
            exerciseId: 'ex_11',
            variantId: 'ex_11_frag_07',
            category: PracticeCategory.scalar,
            seconds: 300,
            startTempo: 88,
            endTempo: 88,
            skipped: true,
          ),
        ],
      );

      expect(_roundTrip(session.toJson(), SessionRecord.fromJson), session);
      expect(session.secondsByCategory[PracticeCategory.warmupLeft], 360);
      expect(
        session.secondsByCategory.containsKey(PracticeCategory.scalar),
        isFalse,
        reason: 'a skipped item is not practice time',
      );
      expect(session.dayKey, '2026-03-14');
    });
  });

  group('TempoRecord', () {
    test('round-trips and reports best clean and last tempo', () {
      var record = const TempoRecord(exerciseId: 'ex_8');
      record = record.append(TempoPoint(date: date, bpm: 80, clean: true));
      record = record.append(TempoPoint(date: date, bpm: 96, clean: true));
      // Backed off after a bad day, and not marked clean.
      record = record.append(TempoPoint(date: date, bpm: 88));

      expect(_roundTrip(record.toJson(), TempoRecord.fromJson), record);
      expect(record.bestCleanTempo, 96);
      expect(record.lastTempo, 88);
      expect(record.cleanPoints, hasLength(2));
    });

    test('an empty record reports zeroes rather than throwing', () {
      const record = TempoRecord(exerciseId: 'ex_8');
      expect(record.bestCleanTempo, 0);
      expect(record.lastTempo, 0);
    });
  });

  group('RotationCursor', () {
    test('round-trips including per-exercise variant positions', () {
      const cursor = RotationCursor(
        exerciseIndex: 3,
        variantIndices: {'ex_11': 7, 'ex_9': 2},
        owedMinutes: 5,
        sessionsSeen: 12,
      );
      expect(_roundTrip(cursor.toJson(), RotationCursor.fromJson), cursor);
    });
  });

  group('DateX', () {
    test('daysUntil counts whole days across a DST boundary', () {
      // Northern-hemisphere spring forward: this day is 23 hours long in many
      // zones, which naive difference().inDays truncates to 0.
      final before = DateTime(2026, 3, 28, 12);
      final after = DateTime(2026, 3, 29, 12);
      expect(before.daysUntil(after), 1);

      final autumnBefore = DateTime(2026, 10, 24, 12);
      final autumnAfter = DateTime(2026, 10, 25, 12);
      expect(autumnBefore.daysUntil(autumnAfter), 1);
    });

    test('daysUntil is negative going backwards and zero within a day', () {
      expect(DateTime(2026, 3, 14, 23).daysUntil(DateTime(2026, 3, 14, 1)), 0);
      expect(DateTime(2026, 3, 14).daysUntil(DateTime(2026, 3, 11)), -3);
    });

    test('dayKey and dayKeyToDate are inverses', () {
      final key = date.dayKey;
      expect(key, '2026-03-14');
      expect(dayKeyToDate(key), DateTime(2026, 3, 14));
      expect(dayKeyToDate('not-a-date'), isNull);
    });

    test('daysBetween is inclusive at both ends', () {
      final days = daysBetween(
        DateTime(2026, 3, 14),
        DateTime(2026, 3, 17),
      ).toList();
      expect(days, hasLength(4));
      expect(days.first, DateTime(2026, 3, 14));
      expect(days.last, DateTime(2026, 3, 17));
    });
  });
}
