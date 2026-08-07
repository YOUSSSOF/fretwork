import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/course_seed.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/features/routine/routine_service.dart';

List<CoursePart> _partsFor(int milestone) => [
  for (final part in kCourseSeed)
    if (part.milestone <= milestone) part,
];

Set<PracticeCategory> _categoriesFor(int milestone) => {
  for (final part in _partsFor(milestone))
    for (final exercise in part.exercises) exercise.category,
};

RoutineGeneration _generate({
  int milestone = 6,
  int sessionMinutes = 60,
  int seed = 0,
  DateTime? date,
  Map<PracticeCategory, RotationCursor> cursors = const {},
  Map<String, TempoRecord> tempos = const {},
  Set<int> restWeekdays = const {},
}) => generateRoutine(
  date: date ?? DateTime(2026, 3, 14),
  milestone: milestone,
  sessionMinutes: sessionMinutes,
  unlockedParts: _partsFor(milestone),
  cursors: cursors,
  tempos: tempos,
  seed: seed,
  restWeekdays: restWeekdays,
);

void main() {
  group('the weight table', () {
    test('covers every milestone from 1 to 10', () {
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        expect(kCategoryWeights[milestone], isNotNull, reason: '$milestone');
      }
    });

    test('never gives weight to a category the course has not unlocked', () {
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        final unlocked = _categoriesFor(milestone);
        for (final entry in kCategoryWeights[milestone]!.entries) {
          if (entry.value == 0) continue;
          expect(
            unlocked,
            contains(entry.key),
            reason:
                'milestone $milestone weights ${entry.key.name}, which has no '
                'unlocked exercises',
          );
        }
      }
    });

    test('warm-up shrinks as a share of the session as material unlocks', () {
      double warmupShare(int milestone) {
        final weights = kCategoryWeights[milestone]!;
        final total = weights.values.fold<int>(0, (a, b) => a + b);
        final warmup = weights.entries
            .where((e) => e.key.isWarmup)
            .fold<int>(0, (a, e) => a + e.value);
        return warmup / total;
      }

      for (var milestone = 5; milestone < kMaxMilestone; milestone++) {
        expect(
          warmupShare(milestone + 1),
          lessThan(warmupShare(milestone)),
          reason: 'warm-up grew from $milestone to ${milestone + 1}',
        );
      }
    });

    test('every milestone past the preface schedules something', () {
      for (var milestone = 2; milestone <= kMaxMilestone; milestone++) {
        expect(
          kCategoryWeights[milestone],
          isNotEmpty,
          reason: 'milestone $milestone has nothing to practise',
        );
      }
    });
  });

  group('allocateMinutes', () {
    test('never exceeds the session length, at any milestone or length', () {
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        for (final minutes in [
          kMinSessionMinutes,
          30,
          45,
          60,
          90,
          kMaxSessionMinutes,
        ]) {
          final split = allocateMinutes(
            milestone: milestone,
            sessionMinutes: minutes,
            available: _categoriesFor(milestone),
          );
          final total = split.values.fold<int>(0, (a, b) => a + b);
          expect(
            total,
            lessThanOrEqualTo(minutes),
            reason: 'milestone $milestone at $minutes min allocated $total',
          );
        }
      }
    });

    test('every block it produces is worth having', () {
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        for (final minutes in [20, 35, 60, 90, 150]) {
          final split = allocateMinutes(
            milestone: milestone,
            sessionMinutes: minutes,
            available: _categoriesFor(milestone),
          );
          for (final entry in split.entries) {
            expect(
              entry.value,
              greaterThan(0),
              reason: '${entry.key.name} got a zero-minute block',
            );
          }
        }
      }
    });

    test('respects the warm-up total cap however many warm-ups exist', () {
      for (var milestone = 2; milestone <= kMaxMilestone; milestone++) {
        for (final minutes in [20, 60, 150]) {
          final split = allocateMinutes(
            milestone: milestone,
            sessionMinutes: minutes,
            available: _categoriesFor(milestone),
          );
          final warmup = split.entries
              .where((e) => e.key.isWarmup)
              .fold<int>(0, (a, e) => a + e.value);
          if (warmup == 0) continue;
          expect(
            warmup,
            inInclusiveRange(
              RoutineCaps.warmupMin - 1,
              RoutineCaps.warmupMax + 1,
            ),
            reason: 'milestone $milestone at $minutes min gave $warmup warm-up',
          );
        }
      }
    });

    test('no single block swallows the session', () {
      for (final minutes in [20, 60, 150]) {
        final split = allocateMinutes(
          milestone: 10,
          sessionMinutes: minutes,
          available: _categoriesFor(10),
        );
        for (final entry in split.entries) {
          expect(
            entry.value,
            lessThan(minutes),
            reason: '${entry.key} took the whole $minutes-minute session',
          );
        }
      }
    });

    test('drops time feel entirely below the session floor', () {
      final short = allocateMinutes(
        milestone: 6,
        sessionMinutes: RoutineCaps.timeFeelSessionFloor - 1,
        available: _categoriesFor(6),
      );
      expect(short.containsKey(PracticeCategory.timeFeel), isFalse);

      final long = allocateMinutes(
        milestone: 6,
        sessionMinutes: RoutineCaps.timeFeelSessionFloor,
        available: _categoriesFor(6),
      );
      expect(long.containsKey(PracticeCategory.timeFeel), isTrue);
    });

    test('a 20-minute session at the top milestone still produces a plan', () {
      final split = allocateMinutes(
        milestone: 10,
        sessionMinutes: 20,
        available: _categoriesFor(10),
      );
      expect(split, isNotEmpty);
      // With so little time most categories are priced out, which is correct:
      // four one-minute blocks would be worse than three real ones.
      expect(split.length, lessThan(kCategoryWeights[10]!.length));
    });

    test('blocks come back in rendering order', () {
      final split = allocateMinutes(
        milestone: 10,
        sessionMinutes: 120,
        available: _categoriesFor(10),
      );
      final order = split.keys.map((c) => c.index).toList();
      expect(order, orderedEquals([...order]..sort()));
    });

    test('returns nothing when no category is available', () {
      expect(
        allocateMinutes(milestone: 6, sessionMinutes: 60, available: const {}),
        isEmpty,
      );
    });

    test('returns nothing for a zero-length session', () {
      expect(
        allocateMinutes(
          milestone: 6,
          sessionMinutes: 0,
          available: _categoriesFor(6),
        ),
        isEmpty,
      );
    });
  });

  group('generateRoutine', () {
    test('is deterministic: same inputs, same plan', () {
      final a = _generate(seed: 7);
      final b = _generate(seed: 7);
      expect(a.day, b.day);
    });

    test('a different seed re-rolls the day', () {
      final a = _generate(seed: 1);
      final b = _generate(seed: 2);
      expect(a.day.blocks, isNot(equals(b.day.blocks)));
    });

    test('reshuffling does not advance the rotation', () {
      final first = _generate(seed: 1);
      final reshuffled = _generate(seed: 2);
      // Both started from empty cursors, so both advance by the same amount:
      // the seed changes what is picked, not how far the rotation has moved.
      expect(
        reshuffled.cursors[PracticeCategory.scalar]!.exerciseIndex,
        first.cursors[PracticeCategory.scalar]!.exerciseIndex,
      );
    });

    test('block minutes add up to plannedMinutes', () {
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        for (final minutes in [20, 45, 75, 150]) {
          final result = _generate(
            milestone: milestone,
            sessionMinutes: minutes,
          );
          final sum = result.day.blocks.fold<int>(
            0,
            (a, block) => a + block.minutes,
          );
          expect(result.day.plannedMinutes, sum);
          expect(sum, lessThanOrEqualTo(minutes));
        }
      }
    });

    test('item minutes add up to their block', () {
      final result = _generate(milestone: 10, sessionMinutes: 120);
      for (final block in result.day.blocks) {
        final sum = block.items.fold<int>(0, (a, item) => a + item.minutes);
        expect(
          sum,
          block.minutes,
          reason: '${block.category.name} items do not fill the block',
        );
      }
    });

    test('no item is shorter than its block can afford', () {
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        for (final minutes in [20, 45, 90, 150]) {
          final result = _generate(
            milestone: milestone,
            sessionMinutes: minutes,
          );
          for (final block in result.day.blocks) {
            // Three warm-ups sharing a six-minute cap legitimately give
            // two-minute blocks, and a two-minute block holds one two-minute
            // item. Everywhere else the three-minute floor applies.
            final floor = block.minutes < RoutineCaps.itemMinMinutes
                ? block.minutes
                : RoutineCaps.itemMinMinutes;
            for (final item in block.items) {
              expect(
                item.minutes,
                greaterThanOrEqualTo(floor),
                reason:
                    '${item.exerciseId} got ${item.minutes} min in a '
                    '${block.minutes} min ${block.category.name} block',
              );
              expect(item.minutes, greaterThan(0));
            }
          }
        }
      }
    });

    test('every item resolves to a real, unlocked exercise', () {
      final index = buildExerciseIndex();
      for (var milestone = 1; milestone <= kMaxMilestone; milestone++) {
        final unlocked = {
          for (final part in _partsFor(milestone))
            for (final exercise in part.exercises) exercise.id,
        };
        final result = _generate(milestone: milestone);
        for (final item in result.day.allItems) {
          expect(index.containsKey(item.exerciseId), isTrue);
          expect(unlocked, contains(item.exerciseId));
          if (item.variantId != null) {
            expect(
              index[item.exerciseId]!.variantById(item.variantId),
              isNotNull,
              reason: '${item.variantId} does not belong to ${item.exerciseId}',
            );
          }
        }
      }
    });

    test('a block never holds more than the item ceiling', () {
      final result = _generate(milestone: 10, sessionMinutes: 150);
      for (final block in result.day.blocks) {
        expect(
          block.items.length,
          lessThanOrEqualTo(RoutineCaps.maxItemsPerBlock),
        );
      }
    });

    test('the extremes of the session range both produce valid plans', () {
      for (final minutes in [kMinSessionMinutes, kMaxSessionMinutes]) {
        final result = _generate(milestone: 10, sessionMinutes: minutes);
        expect(result.day.blocks, isNotEmpty);
        expect(result.day.allItems, isNotEmpty);
      }
    });

    test(
      'a rest day produces an empty plan and does not move the rotation',
      () {
        final result = _generate(
          date: DateTime(2026, 3, 15), // a Sunday
          restWeekdays: {DateTime.sunday},
          cursors: const {
            PracticeCategory.scalar: RotationCursor(exerciseIndex: 3),
          },
        );
        expect(result.day.isRestDay, isTrue);
        expect(result.day.blocks, isEmpty);
        expect(result.day.plannedMinutes, 0);
        expect(result.cursors[PracticeCategory.scalar]!.exerciseIndex, 3);
      },
    );

    test('cursors advance and wrap rather than running off the end', () {
      var cursors = <PracticeCategory, RotationCursor>{};
      final seen = <String>{};

      for (var day = 0; day < 30; day++) {
        final result = _generate(
          date: DateTime(2026, 3, 1).add(Duration(days: day)),
          cursors: cursors,
        );
        cursors = result.cursors;
        for (final item in result.day.allItems) {
          seen.add(item.exerciseId);
        }
      }

      for (final cursor in cursors.values) {
        expect(cursor.exerciseIndex, greaterThanOrEqualTo(0));
      }
      // A month of practice should have touched everything unlocked at this
      // milestone, not just the first few in each category.
      final unlocked = {
        for (final part in _partsFor(6))
          for (final exercise in part.exercises) exercise.id,
      };
      expect(seen, unlocked);
    });

    test("Example 11's fragments cycle within a week", () {
      var cursors = <PracticeCategory, RotationCursor>{};
      final fragments = <String>{};

      for (var day = 0; day < 7; day++) {
        final result = _generate(
          date: DateTime(2026, 3, 1).add(Duration(days: day)),
          cursors: cursors,
          sessionMinutes: 90,
        );
        cursors = result.cursors;
        for (final item in result.day.allItems) {
          if (item.exerciseId == 'ex_11' && item.variantId != null) {
            fragments.add(item.variantId!);
          }
        }
      }

      expect(
        fragments.length,
        greaterThanOrEqualTo(12),
        reason: 'only ${fragments.length} of 22 variants surfaced in a week',
      );
    });

    test(
      'the target tempo comes from the remembered tempo when there is one',
      () {
        final result = _generate(
          milestone: 2,
          tempos: {
            'ex_1': TempoRecord(
              exerciseId: 'ex_1',
              points: [TempoPoint(date: DateTime(2026, 3, 1), bpm: 96)],
            ),
          },
        );
        final item = result.day.allItems.firstWhere(
          (i) => i.exerciseId == 'ex_1',
        );
        expect(item.targetTempo, 96);
      },
    );

    test('a remembered tempo is still clamped to the exercise range', () {
      final result = _generate(
        milestone: 2,
        tempos: {
          'ex_1': TempoRecord(
            exerciseId: 'ex_1',
            points: [TempoPoint(date: DateTime(2026, 3, 1), bpm: 9999)],
          ),
        },
      );
      final item = result.day.allItems.firstWhere(
        (i) => i.exerciseId == 'ex_1',
      );
      final exercise = buildExerciseIndex()['ex_1']!;
      expect(item.targetTempo, exercise.maxTempo);
    });

    test('free-time exercises are scheduled without a tempo', () {
      final result = _generate(milestone: 10, sessionMinutes: 120);
      for (final item in result.day.allItems) {
        if (item.procedure != ProcedureType.freeTime) continue;
        expect(item.targetTempo, 0, reason: item.exerciseId);
      }
    });

    test('a milestone-1 user gets an empty plan, because the preface is '
        'reading rather than playing', () {
      final result = _generate(milestone: 1, sessionMinutes: 30);
      expect(result.day.blocks, isEmpty);
    });
  });

  group('focus notes', () {
    test('the right-hand starting stroke alternates by date', () {
      final even = focusNoteFor(
        category: PracticeCategory.warmupRight,
        procedure: ProcedureType.ladder,
        date: DateTime(2026, 3, 14),
      );
      final odd = focusNoteFor(
        category: PracticeCategory.warmupRight,
        procedure: ProcedureType.ladder,
        date: DateTime(2026, 3, 15),
      );
      expect(even, 'Start on a down-stroke');
      expect(odd, 'Start on an up-stroke');
      expect(even, isNot(odd));
    });

    test('procedure drives the note everywhere else', () {
      expect(
        focusNoteFor(
          category: PracticeCategory.scalar,
          procedure: ProcedureType.ladder,
          date: DateTime(2026, 3, 14),
        ),
        'Flawless before +8 bpm',
      );
      expect(
        focusNoteFor(
          category: PracticeCategory.scalar,
          procedure: ProcedureType.hold,
          date: DateTime(2026, 3, 14),
        ),
        'One minute each, no stopping',
      );
    });

    test('every procedure has a note', () {
      for (final procedure in ProcedureType.values) {
        expect(
          focusNoteFor(
            category: PracticeCategory.scalar,
            procedure: procedure,
            date: DateTime(2026, 3, 14),
          ),
          isNotEmpty,
        );
      }
    });
  });
}
