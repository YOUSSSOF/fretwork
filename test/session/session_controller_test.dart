import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/utils/clock.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/session/session_controller.dart';

import '../support/store.dart';

RoutineDay _plan() => RoutineDay(
  date: DateTime(2026, 3, 14),
  milestone: 6,
  plannedMinutes: 12,
  generationSeed: 1,
  generatedAt: DateTime(2026, 3, 14),
  blocks: const [
    RoutineBlock(
      category: PracticeCategory.warmupLeft,
      label: 'Left-hand warm-up',
      minutes: 6,
      items: [
        RoutineItem(
          exerciseId: 'ex_1',
          variantId: 'ex_1_part_a',
          minutes: 3,
          targetTempo: 60,
          procedure: ProcedureType.ladder,
          focusNote: 'Flawless before +8 bpm',
        ),
        RoutineItem(
          exerciseId: 'ex_3',
          minutes: 3,
          targetTempo: 66,
          procedure: ProcedureType.ladder,
          focusNote: '',
        ),
      ],
    ),
    RoutineBlock(
      category: PracticeCategory.scalar,
      label: 'Scale fragments',
      minutes: 6,
      items: [
        RoutineItem(
          exerciseId: 'ex_12',
          minutes: 6,
          targetTempo: 80,
          procedure: ProcedureType.ladder,
          focusNote: '',
        ),
      ],
    ),
  ],
);

Future<ProviderContainer> _ready(FixedClock clock) async {
  final container = testContainer(
    overrides: [
      clockProviderOverride(clock),
      metronomeEngineProvider.overrideWithValue(const SilentMetronome()),
    ],
  );
  await container
      .read(profileProvider.notifier)
      .completeOnboarding(
        milestone: 6,
        sessionMinutes: 60,
        restWeekdays: const {},
      );
  return container;
}

void main() {
  // The session controller talks to the wakelock plugin, which needs a
  // binding even though the call is a no-op in tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionState', () {
    test('flatIndex walks blocks and items in order', () {
      final plan = _plan();
      var state = SessionState(
        id: 's',
        routine: plan,
        startedAt: DateTime(2026, 3, 14),
        mode: TimerMode.detailed,
      );
      expect(state.totalItems, 3);
      expect(state.flatIndex, 0);

      state = state.copyWith(itemIndex: 1);
      expect(state.flatIndex, 1);
      expect(state.item?.exerciseId, 'ex_3');

      state = state.copyWith(blockIndex: 1, itemIndex: 0);
      expect(state.flatIndex, 2);
      expect(state.item?.exerciseId, 'ex_12');
      expect(state.isLastItem, isTrue);
    });

    test('remaining never goes negative', () {
      final state = SessionState(
        id: 's',
        routine: _plan(),
        startedAt: DateTime(2026, 3, 14),
        mode: TimerMode.detailed,
        itemElapsed: const Duration(minutes: 9),
      );
      expect(state.itemRemaining, Duration.zero);
      expect(state.itemProgress, 1.0);
    });

    test('progress is zero rather than NaN for a zero-length plan', () {
      final state = SessionState(
        id: 's',
        routine: RoutineDay(
          date: DateTime(2026, 3, 14),
          milestone: 1,
          plannedMinutes: 0,
          blocks: const [],
          generationSeed: 0,
          generatedAt: DateTime(2026, 3, 14),
        ),
        startedAt: DateTime(2026, 3, 14),
        mode: TimerMode.quick,
      );
      expect(state.sessionProgress, 0);
      expect(state.itemProgress, 0);
    });
  });

  group('SessionNotifier', () {
    test('starting sets up the first item', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);

      container.read(sessionProvider.notifier).load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      final state = container.read(sessionProvider);

      expect(state, isNotNull);
      expect(state!.phase, SessionPhase.running);
      expect(state.item?.exerciseId, 'ex_1');
      expect(state.totalItems, 3);
    });

    test('refuses to start an empty plan', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .load(
            routine: RoutineDay(
              date: DateTime(2026, 3, 14),
              milestone: 6,
              plannedMinutes: 0,
              blocks: const [],
              generationSeed: 0,
              generatedAt: DateTime(2026, 3, 14),
            ),
          );
      expect(container.read(sessionProvider), isNull);
    });

    test('next advances through blocks and finishes the session', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      notifier.completeItem();
      notifier.advance();
      expect(container.read(sessionProvider)!.item?.exerciseId, 'ex_3');

      notifier.completeItem();
      notifier.advance();
      expect(container.read(sessionProvider)!.item?.exerciseId, 'ex_12');
      expect(container.read(sessionProvider)!.blockIndex, 1);

      notifier.completeItem();
      notifier.advance();
      // Finishing the last item ends the session.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionProvider), isNull);

      final records = container.read(sessionRecordsProvider);
      expect(records, hasLength(1));
      expect(records.single.items, hasLength(3));
      expect(
        records.single.abandoned,
        isFalse,
        reason: 'completing every item is not abandoning',
      );
    });

    test('skipping records the item as skipped with no time', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      notifier.skip();
      await notifier.end();

      final result = container
          .read(sessionRecordsProvider)
          .single
          .items
          .firstWhere((i) => i.exerciseId == 'ex_1');
      expect(result.skipped, isTrue);
      expect(result.seconds, 0);
    });

    test('ending early saves what was done and marks it abandoned', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      notifier.completeItem();
      notifier.advance();
      await notifier.end();

      final record = container.read(sessionRecordsProvider).single;
      expect(record.abandoned, isTrue);
      expect(record.items, hasLength(1));
      expect(container.read(sessionProvider), isNull);
    });

    test('ending writes a day record with partial credit', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      notifier.completeItem();
      notifier.advance();
      await notifier.end();

      final day = container
          .read(dayRecordsProvider.notifier)
          .forDate(DateTime(2026, 3, 14));
      expect(day, isNotNull);
      expect(day!.plannedMinutes, 12);
      // No wall-clock time passed on the fixed clock, so this is a partial
      // day, not a completed one — which is the honest reading.
      expect(day.status, isNot(DayStatus.completed));
      expect(day.sessionIds, hasLength(1));
    });

    test('pause stops the clock and resume restarts it', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      notifier.pause();
      expect(container.read(sessionProvider)!.phase, SessionPhase.paused);

      notifier.resume();
      expect(container.read(sessionProvider)!.phase, SessionPhase.running);

      notifier.togglePause();
      expect(container.read(sessionProvider)!.phase, SessionPhase.paused);
      await notifier.end();
    });

    test(
      '+30s gives elapsed time back rather than lengthening the item',
      () async {
        final clock = FixedClock(DateTime(2026, 3, 14, 18));
        final container = await _ready(clock);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.load(routine: _plan());
        container.read(sessionProvider.notifier).start();
        final before = container.read(sessionProvider)!.itemDuration;
        notifier.extend(const Duration(seconds: 30));

        expect(
          container.read(sessionProvider)!.itemDuration,
          before,
          reason: "the plan's minutes are not rewritten",
        );
        expect(notifier.itemElapsed, Duration.zero);
        await notifier.end();
      },
    );

    test('backgrounding pauses instead of counting the time', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock);
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      container.read(sessionProvider.notifier).start();
      notifier.onBackgrounded();

      clock.advance(const Duration(minutes: 30));
      expect(container.read(sessionProvider)!.phase, SessionPhase.paused);
      final elapsed = notifier.itemElapsed;
      expect(elapsed, lessThan(const Duration(minutes: 1)));
      await notifier.end();
    });

    test(
      'coming back leaves the session paused for the user to restart',
      () async {
        final clock = FixedClock(DateTime(2026, 3, 14, 18));
        final container = await _ready(clock);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.load(routine: _plan());
        container.read(sessionProvider.notifier).start();
        notifier.onBackgrounded();

        clock.advance(const Duration(minutes: 2));
        expect(notifier.onResumed(), isTrue, reason: 'it is sitting paused');
        expect(container.read(sessionProvider)!.phase, SessionPhase.paused);

        notifier.resume();
        expect(container.read(sessionProvider)!.phase, SessionPhase.running);
        await notifier.end();
      },
    );

    test(
      'marking clean records a clean tempo point for the exercise',
      () async {
        final clock = FixedClock(DateTime(2026, 3, 14, 18));
        final container = await _ready(clock);
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.load(routine: _plan());
        container.read(sessionProvider.notifier).start();
        await notifier.markClean();

        final record = container.read(tempoRecordsProvider)['ex_1'];
        expect(record, isNotNull);
        expect(record!.cleanPoints, hasLength(1));
        expect(record.bestCleanTempo, greaterThan(0));
        await notifier.end();
      },
    );
  });
}
