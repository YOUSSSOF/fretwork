import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/utils/clock.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';

import '../support/store.dart';

Future<ProviderContainer> _ready({DateTime? now}) async {
  final container = testContainer(now: now);
  await container
      .read(profileProvider.notifier)
      .completeOnboarding(
        milestone: 6,
        sessionMinutes: 60,
        restWeekdays: const {},
      );
  return container;
}

/// The routine notifier defers its writes to a microtask so it does not mutate
/// another provider during build.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('todayRoutineProvider', () {
    test('generates and persists a plan on first read', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      final routine = container.read(todayRoutineProvider);
      expect(routine.blocks, isNotEmpty);
      await _settle();

      final stored = container
          .read(storeProvider)
          .read(BoxNames.routines, routine.id);
      expect(stored, isNotNull);
      expect(RoutineDay.fromJson(stored!), routine);
    });

    test('advances the rotation cursors once generated', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      container.read(todayRoutineProvider);
      await _settle();

      final cursors = container.read(rotationCursorsProvider);
      expect(cursors, isNotEmpty);
      expect(cursors[PracticeCategory.scalar]?.sessionsSeen, greaterThan(0));
    });

    test('a second read within the day returns the stored plan', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      final first = container.read(todayRoutineProvider);
      await _settle();
      container.invalidate(todayRoutineProvider);
      final second = container.read(todayRoutineProvider);

      expect(second, first);
    });

    test('changing the milestone regenerates the plan', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      final before = container.read(todayRoutineProvider);
      await _settle();
      expect(
        before.blocks.map((b) => b.category),
        isNot(contains(PracticeCategory.legato)),
      );

      await container.read(profileProvider.notifier).setMilestone(8);
      final after = container.read(todayRoutineProvider);

      expect(after.milestone, 8);
      expect(
        after.blocks.map((b) => b.category),
        contains(PracticeCategory.legato),
      );
    });

    test('changing the session length regenerates the plan', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      final before = container.read(todayRoutineProvider);
      await _settle();

      await container.read(profileProvider.notifier).setSessionMinutes(30);
      final after = container.read(todayRoutineProvider);

      expect(after.plannedMinutes, lessThan(before.plannedMinutes));
      expect(after.plannedMinutes, lessThanOrEqualTo(30));
    });

    test('marking today a rest day empties the plan', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      container.read(todayRoutineProvider);
      await _settle();

      final today = container.read(clockProvider).now();
      await container.read(profileProvider.notifier).setRestWeekdays({
        today.weekday,
      });

      final after = container.read(todayRoutineProvider);
      expect(after.isRestDay, isTrue);
      expect(after.blocks, isEmpty);
    });

    test('the date rolling over produces a new plan', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 9));
      final container = testContainer(
        overrides: [clockProvider.overrideWithValue(clock)],
      );
      addTearDown(container.dispose);
      await container
          .read(profileProvider.notifier)
          .completeOnboarding(
            milestone: 6,
            sessionMinutes: 60,
            restWeekdays: const {},
          );

      final first = container.read(todayRoutineProvider);
      await _settle();
      expect(first.id, '2026-03-14');

      clock.set(DateTime(2026, 3, 15, 9));
      container.invalidate(todayRoutineProvider);
      final second = container.read(todayRoutineProvider);

      expect(second.id, '2026-03-15');
      expect(second, isNot(first));
    });

    test('regenerate rebuilds the same day rather than a new one', () async {
      final container = await _ready();
      addTearDown(container.dispose);

      final before = container.read(todayRoutineProvider);
      await _settle();

      await container.read(todayRoutineProvider.notifier).regenerate();
      final after = container.read(todayRoutineProvider);

      expect(after.id, before.id);
      expect(after.date, before.date);
    });

    test('regenerate fits the plan back inside the session budget', () async {
      final container = await _ready();
      addTearDown(container.dispose);
      await _settle();

      await container.read(profileProvider.notifier).setSessionMinutes(30);
      await container.read(todayRoutineProvider.notifier).regenerate();

      final after = container.read(todayRoutineProvider);
      final minutes = after.allItems.fold<int>(0, (sum, i) => sum + i.minutes);
      expect(minutes, lessThanOrEqualTo(30));
    });
  });

  group('fitToBudget', () {
    RoutineDay dayWith(List<RoutineBlock> blocks) => RoutineDay(
      date: DateTime(2026, 3, 14),
      milestone: 6,
      plannedMinutes: blocks.fold(0, (a, b) => a + b.minutes),
      blocks: blocks,
      generationSeed: 1,
      generatedAt: DateTime(2026, 3, 14),
    );

    RoutineItem item(String id, {int minutes = 5}) => RoutineItem(
      exerciseId: id,
      minutes: minutes,
      targetTempo: 80,
      procedure: ProcedureType.ladder,
      focusNote: '',
    );

    RoutineBlock block(PracticeCategory category, List<RoutineItem> items) =>
        RoutineBlock(
          category: category,
          label: category.label,
          minutes: items.fold(0, (a, b) => a + b.minutes),
          items: items,
        );

    test('leaves a plan that already fits alone', () {
      final day = dayWith([
        block(PracticeCategory.warmupLeft, [item('ex_1')]),
      ]);
      expect(fitToBudget(day, 60), day);
    });

    test('trims an over-long plan down to the budget', () {
      final day = dayWith([
        block(PracticeCategory.warmupLeft, [item('ex_1'), item('ex_2')]),
        block(PracticeCategory.scalar, [item('ex_12'), item('ex_13')]),
        block(PracticeCategory.chordal, [item('ex_25'), item('ex_26')]),
      ]);
      expect(day.plannedMinutes, 30);

      final fitted = fitToBudget(day, 15);

      expect(fitted.plannedMinutes, lessThanOrEqualTo(15));
      expect(
        fitted.blocks.first.category,
        PracticeCategory.warmupLeft,
        reason: 'the warm-up survives; time comes off the tail',
      );
      expect(fitted.allItems, isNotEmpty);
    });

    test('the stated minutes match what the items actually add up to', () {
      final day = dayWith([
        block(PracticeCategory.scalar, [item('ex_12'), item('ex_13')]),
        block(PracticeCategory.chordal, [item('ex_25')]),
      ]);

      final fitted = fitToBudget(day, 9);

      for (final b in fitted.blocks) {
        expect(b.minutes, b.items.fold<int>(0, (sum, i) => sum + i.minutes));
      }
      expect(
        fitted.plannedMinutes,
        fitted.allItems.fold<int>(0, (sum, i) => sum + i.minutes),
      );
    });

    test('a rest day is never trimmed, because there is nothing to trim', () {
      final rest = RoutineDay(
        date: DateTime(2026, 3, 15),
        milestone: 6,
        plannedMinutes: 0,
        blocks: const [],
        generationSeed: 1,
        generatedAt: DateTime(2026, 3, 15),
        isRestDay: true,
      );
      expect(fitToBudget(rest, 5), rest);
    });
  });

  group('mergePreservingCompleted', () {
    RoutineDay dayWith(List<RoutineBlock> blocks) => RoutineDay(
      date: DateTime(2026, 3, 14),
      milestone: 6,
      plannedMinutes: blocks.fold(0, (a, b) => a + b.minutes),
      blocks: blocks,
      generationSeed: 1,
      generatedAt: DateTime(2026, 3, 14),
    );

    RoutineItem item(String id, {String? variant, int minutes = 5}) =>
        RoutineItem(
          exerciseId: id,
          variantId: variant,
          minutes: minutes,
          targetTempo: 80,
          procedure: ProcedureType.ladder,
          focusNote: '',
        );

    test('returns the replacement untouched when nothing is done', () {
      final replacement = dayWith([
        RoutineBlock(
          category: PracticeCategory.scalar,
          label: 'Scale fragments',
          minutes: 10,
          items: [item('ex_12'), item('ex_13')],
        ),
      ]);
      expect(
        mergePreservingCompleted(
          previous: dayWith(const []),
          replacement: replacement,
          completedKeys: const {},
        ),
        replacement,
      );
    });

    test('keeps completed items and takes the rest from the replacement', () {
      final previous = dayWith([
        RoutineBlock(
          category: PracticeCategory.scalar,
          label: 'Scale fragments',
          minutes: 12,
          items: [
            item('ex_11', variant: 'ex_11_frag_01'),
            item('ex_12'),
          ],
        ),
      ]);
      final replacement = dayWith([
        RoutineBlock(
          category: PracticeCategory.scalar,
          label: 'Scale fragments',
          minutes: 12,
          items: [item('ex_15'), item('ex_16')],
        ),
      ]);

      final merged = mergePreservingCompleted(
        previous: previous,
        replacement: replacement,
        completedKeys: {'ex_11:ex_11_frag_01'},
      );

      final keys = merged.blocks.single.items.map((i) => i.key).toList();
      expect(keys.first, 'ex_11:ex_11_frag_01');
      expect(keys, containsAll(['ex_15', 'ex_16']));
      expect(
        keys,
        isNot(contains('ex_12')),
        reason: 'an unstarted item is replaced, not preserved',
      );
    });

    test('keeps a completed block whose category the replacement dropped', () {
      final previous = dayWith([
        RoutineBlock(
          category: PracticeCategory.warmupLeft,
          label: 'Left-hand warm-up',
          minutes: 6,
          items: [item('ex_1', minutes: 6)],
        ),
      ]);
      final replacement = dayWith([
        RoutineBlock(
          category: PracticeCategory.scalar,
          label: 'Scale fragments',
          minutes: 10,
          items: [item('ex_12', minutes: 10)],
        ),
      ]);

      final merged = mergePreservingCompleted(
        previous: previous,
        replacement: replacement,
        completedKeys: {'ex_1'},
      );

      expect(merged.blocks.map((b) => b.category), [
        PracticeCategory.warmupLeft,
        PracticeCategory.scalar,
      ]);
      expect(merged.plannedMinutes, 16);
    });

    test('drops a block that ends up empty rather than rendering it', () {
      final replacement = dayWith([
        RoutineBlock(
          category: PracticeCategory.scalar,
          label: 'Scale fragments',
          minutes: 5,
          items: [item('ex_12')],
        ),
      ]);

      final merged = mergePreservingCompleted(
        previous: dayWith(const []),
        replacement: replacement,
        completedKeys: {'ex_12'},
      );
      expect(merged.blocks, isEmpty);
      expect(merged.plannedMinutes, 0);
    });
  });

  group('completedTodayProvider', () {
    test('ignores skipped items and other days', () async {
      final container = await _ready(now: DateTime(2026, 3, 14, 20));
      addTearDown(container.dispose);

      await container
          .read(sessionRecordsProvider.notifier)
          .save(
            SessionRecord(
              id: 's1',
              startedAt: DateTime(2026, 3, 14, 18),
              endedAt: DateTime(2026, 3, 14, 18, 30),
              plannedMinutes: 60,
              actualMinutes: 30,
              items: const [
                ItemResult(
                  exerciseId: 'ex_1',
                  category: PracticeCategory.warmupLeft,
                  seconds: 300,
                  startTempo: 60,
                  endTempo: 60,
                ),
                ItemResult(
                  exerciseId: 'ex_3',
                  category: PracticeCategory.warmupLeft,
                  seconds: 0,
                  startTempo: 60,
                  endTempo: 60,
                  skipped: true,
                ),
              ],
            ),
          );

      await container
          .read(sessionRecordsProvider.notifier)
          .save(
            SessionRecord(
              id: 's0',
              startedAt: DateTime(2026, 3, 13, 18),
              endedAt: DateTime(2026, 3, 13, 19),
              plannedMinutes: 60,
              actualMinutes: 60,
              items: const [
                ItemResult(
                  exerciseId: 'ex_12',
                  category: PracticeCategory.scalar,
                  seconds: 600,
                  startTempo: 80,
                  endTempo: 80,
                ),
              ],
            ),
          );

      expect(container.read(completedTodayProvider), {'ex_1'});
    });
  });

  group('routineForDateProvider', () {
    test('returns null for a past day with no stored plan', () async {
      final container = await _ready(now: DateTime(2026, 3, 14, 9));
      addTearDown(container.dispose);

      expect(
        container.read(routineForDateProvider(DateTime(2026, 3, 10))),
        isNull,
      );
    });

    test(
      'generates a provisional plan for tomorrow without storing it',
      () async {
        final container = await _ready(now: DateTime(2026, 3, 14, 9));
        addTearDown(container.dispose);

        final tomorrow = DateTime(2026, 3, 15);
        final plan = container.read(routineForDateProvider(tomorrow));
        expect(plan, isNotNull);
        expect(plan!.blocks, isNotEmpty);

        expect(
          container
              .read(storeProvider)
              .read(BoxNames.routines, tomorrow.dayKey),
          isNull,
          reason: 'a provisional plan must not be committed',
        );
      },
    );

    test('isProvisional is true only for days after today', () {
      final today = DateTime(2026, 3, 14, 15);
      expect(isProvisional(DateTime(2026, 3, 15), today), isTrue);
      expect(isProvisional(DateTime(2026, 3, 14, 1), today), isFalse);
      expect(isProvisional(DateTime(2026, 3, 13), today), isFalse);
    });
  });
}
