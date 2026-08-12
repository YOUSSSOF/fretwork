import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/session_snapshot.dart';
import 'package:fretwork/core/utils/clock.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/session/active_session_controller.dart';
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
          focusNote: '',
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

/// A container on [store], onboarded and wired to a silent click.
Future<ProviderContainer> _ready(Clock clock, DocumentStore store) async {
  final container = testContainer(
    store: store,
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

/// The controller banks progress through unawaited futures so the frame is
/// never blocked on a write; the writes themselves land on the microtask
/// queue.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('per-exercise progress', () {
    test('an item is logged as soon as it is done, not at the end', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      notifier.start();
      notifier.completeItem();
      await _settle();

      final record = container.read(sessionRecordsProvider).single;
      expect(record.items, hasLength(1));
      expect(record.items.single.exerciseId, 'ex_1');
      expect(
        container.read(sessionProvider),
        isNotNull,
        reason: 'the session is still running',
      );
    });

    test('half a routine leaves a day record behind', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      notifier.start();
      notifier.completeItem();
      notifier.advance();
      await _settle();

      final day = container
          .read(dayRecordsProvider.notifier)
          .forDate(DateTime(2026, 3, 14));
      expect(day, isNotNull);
      expect(day!.plannedMinutes, 12);
      expect(day.sessionIds, hasLength(1));
    });

    test('repeated checkpoints do not count the day twice', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      notifier.start();
      for (var i = 0; i < 3; i++) {
        notifier.completeItem();
        notifier.advance();
        await _settle();
      }
      await notifier.end();

      final days = container.read(dayRecordsProvider.notifier);
      final day = days.forDate(DateTime(2026, 3, 14))!;
      expect(
        container.read(sessionRecordsProvider),
        hasLength(1),
        reason: 'every checkpoint replaces the same record',
      );
      expect(day.sessionIds, hasLength(1));
      expect(
        day.completedMinutes,
        container
            .read(sessionRecordsProvider.notifier)
            .completedMinutesOn(DateTime(2026, 3, 14)),
      );
    });

    test('pausing banks the time the current item has earned', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      notifier.start();
      notifier.extend(const Duration(seconds: -90)); // 90 s already played
      notifier.pause();
      await _settle();

      final record = container.read(sessionRecordsProvider).single;
      expect(record.items, hasLength(1));
      expect(record.items.single.seconds, greaterThanOrEqualTo(90));
      expect(record.abandoned, isTrue);
    });
  });

  group('resuming a session', () {
    test('a running session is written as a resumable snapshot', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      notifier.start();
      notifier.completeItem();
      notifier.advance();
      await _settle();

      final snapshot = container.read(resumableSessionProvider);
      expect(snapshot, isNotNull);
      expect(snapshot!.itemIndex, 1);
      expect(snapshot.flatIndex, 1);
      expect(snapshot.results, hasLength(1));
    });

    test('a fresh launch picks the session up where it stopped', () async {
      final store = MemoryDocumentStore();
      final clock = FixedClock(DateTime(2026, 3, 14, 18));

      final first = await _ready(clock, store);
      final notifier = first.read(sessionProvider.notifier);
      notifier.load(routine: _plan());
      notifier.start();
      notifier.completeItem();
      notifier.advance();
      notifier.extend(const Duration(seconds: -45));
      notifier.pause();
      await _settle();
      first.dispose();

      // A new container over the same store is what a cold launch looks like.
      final second = await _ready(clock, store);
      addTearDown(second.dispose);

      final snapshot = second.read(resumableSessionProvider);
      expect(snapshot, isNotNull);
      expect(second.read(sessionProvider.notifier).restore(snapshot!), isTrue);

      final state = second.read(sessionProvider)!;
      expect(state.blockIndex, 0);
      expect(state.itemIndex, 1);
      expect(state.item?.exerciseId, 'ex_3');
      expect(state.results, hasLength(1));
      expect(
        state.phase,
        SessionPhase.paused,
        reason: 'the guitar may still be in its case',
      );
      expect(state.itemElapsed.inSeconds, greaterThanOrEqualTo(45));

      second.read(sessionProvider.notifier).resume();
      expect(second.read(sessionProvider)!.phase, SessionPhase.running);
      expect(
        second.read(sessionProvider.notifier).itemElapsed.inSeconds,
        greaterThanOrEqualTo(45),
        reason: 'resuming does not reset the item clock',
      );
    });

    test('a resumed session keeps its id rather than logging twice', () async {
      final store = MemoryDocumentStore();
      final clock = FixedClock(DateTime(2026, 3, 14, 18));

      final first = await _ready(clock, store);
      final notifier = first.read(sessionProvider.notifier);
      notifier.load(routine: _plan());
      notifier.start();
      notifier.completeItem();
      notifier.advance();
      await _settle();
      final id = first.read(sessionProvider)!.id;
      first.dispose();

      final second = await _ready(clock, store);
      addTearDown(second.dispose);
      second
          .read(sessionProvider.notifier)
          .restore(second.read(resumableSessionProvider)!);
      second.read(sessionProvider.notifier).resume();
      second.read(sessionProvider.notifier).completeItem();
      await _settle();
      await second.read(sessionProvider.notifier).end();

      final records = second.read(sessionRecordsProvider);
      expect(records, hasLength(1));
      expect(records.single.id, id);
      expect(records.single.items, hasLength(2));
    });

    test('ending clears the snapshot so it is not offered again', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.load(routine: _plan());
      notifier.start();
      notifier.completeItem();
      await _settle();
      expect(container.read(resumableSessionProvider), isNotNull);

      await notifier.end();
      expect(container.read(resumableSessionProvider), isNull);
      expect(container.read(activeSessionProvider), isNull);
    });

    test('yesterday is not offered for resuming', () async {
      final clock = FixedClock(DateTime(2026, 3, 14, 18));
      final container = await _ready(clock, MemoryDocumentStore());
      addTearDown(container.dispose);

      await container
          .read(activeSessionProvider.notifier)
          .save(
            SessionSnapshot(
              id: 'session-yesterday',
              routine: _plan(),
              startedAt: DateTime(2026, 3, 13, 20),
              savedAt: DateTime(2026, 3, 13, 20, 30),
              mode: TimerMode.detailed,
              blockIndex: 0,
              itemIndex: 1,
              itemElapsed: const Duration(seconds: 30),
              totalElapsed: const Duration(minutes: 4),
              results: const [],
            ),
          );

      expect(container.read(activeSessionProvider), isNotNull);
      expect(
        container.read(resumableSessionProvider),
        isNull,
        reason: 'today has its own plan',
      );
    });

    test('a snapshot survives a round trip through storage', () {
      final snapshot = SessionSnapshot(
        id: 'session-1',
        routine: _plan(),
        startedAt: DateTime(2026, 3, 14, 18),
        savedAt: DateTime(2026, 3, 14, 18, 12),
        mode: TimerMode.quick,
        blockIndex: 1,
        itemIndex: 0,
        itemElapsed: const Duration(seconds: 95),
        totalElapsed: const Duration(minutes: 7, seconds: 5),
        results: const [
          ItemResult(
            exerciseId: 'ex_1',
            variantId: 'ex_1_part_a',
            category: PracticeCategory.warmupLeft,
            seconds: 180,
            startTempo: 60,
            endTempo: 68,
            clean: true,
          ),
        ],
      );

      expect(SessionSnapshot.fromJson(snapshot.toJson()), snapshot);
    });
  });
}
