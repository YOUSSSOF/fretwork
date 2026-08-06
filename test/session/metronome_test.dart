import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/utils/clock.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';

/// Advances the test's fake timers and the runner's clock together, so the
/// scheduler sees the same passage of time the Timers do.
Future<void> _run(WidgetTester tester, FixedClock clock, Duration total) async {
  const step = Duration(milliseconds: 10);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    clock.advance(step);
    await tester.pump(step);
  }
}

void main() {
  group('BeatClock', () {
    test('beat timestamps stay within 5ms of ideal over 120s at 200bpm', () {
      const clock = BeatClock(bpm: 200, subdivision: 4);
      // 200 bpm, sixteenth notes: 800 clicks a minute, 1600 over the run.
      const totalBeats = 1600;
      const idealIntervalMicros = 60000000 / (200 * 4);

      var worst = 0.0;
      for (var index = 0; index <= totalBeats; index++) {
        final ideal = index * idealIntervalMicros;
        final actual = clock.timeOf(index).inMicroseconds.toDouble();
        final error = (actual - ideal).abs();
        if (error > worst) worst = error;
      }

      expect(
        worst,
        lessThan(5000),
        reason: 'worst-case error was ${worst / 1000}ms',
      );
      expect(
        clock.timeOf(totalBeats).inSeconds,
        120,
        reason: 'the run should still be exactly two minutes long',
      );
    });

    test('holds accuracy across every supported tempo and subdivision', () {
      for (var bpm = kMinBpm; bpm <= kMaxBpm; bpm += 10) {
        for (final subdivision in kSubdivisions) {
          final clock = BeatClock(bpm: bpm, subdivision: subdivision);
          final beats = (120 * bpm * subdivision / 60).floor();
          final ideal = beats * clock.intervalMicros;
          final actual = clock.timeOf(beats).inMicroseconds.toDouble();
          expect(
            (actual - ideal).abs(),
            lessThan(5000),
            reason: '$bpm bpm at 1/$subdivision drifted',
          );
        }
      }
    });

    test('never accumulates: every beat is derived from its own index', () {
      // A naive implementation adds a rounded interval each time. At 200 bpm
      // the exact interval is 75000.0 µs, so pick a tempo where it is not a
      // whole number of microseconds and the difference shows.
      const clock = BeatClock(bpm: 97, subdivision: 3);
      expect(clock.intervalMicros, isNot(clock.intervalMicros.roundToDouble()));

      final naiveStep = clock.intervalMicros.round();
      const beats = 5000;
      final naiveTotal = naiveStep * beats;
      final actual = clock.timeOf(beats).inMicroseconds;
      final ideal = (clock.intervalMicros * beats).round();

      expect((actual - ideal).abs(), lessThanOrEqualTo(1));
      expect(
        (naiveTotal - ideal).abs(),
        greaterThan(1000),
        reason:
            'the naive approach should visibly drift, or this test proves '
            'nothing',
      );
    });

    test('dueIndex is the inverse of timeOf', () {
      const clock = BeatClock(bpm: 120, subdivision: 4);
      for (final index in [0, 1, 7, 64, 999]) {
        expect(clock.dueIndex(clock.timeOf(index)), index);
      }
    });

    test('only the downbeat of the bar gets the downbeat tone', () {
      const clock = BeatClock(bpm: 120, subdivision: 4);

      // Sixteenths: index 0 is beat one, 4 is beat two, 16 is the next bar.
      expect(clock.kindOf(0, accentBeatOne: true), BeatKind.downbeat);
      expect(clock.kindOf(4, accentBeatOne: true), BeatKind.beat);
      expect(clock.kindOf(8, accentBeatOne: true), BeatKind.beat);
      expect(clock.kindOf(12, accentBeatOne: true), BeatKind.beat);
      expect(clock.kindOf(16, accentBeatOne: true), BeatKind.downbeat);
    });

    test('the notes between beats get the quieter subdivision tone', () {
      const clock = BeatClock(bpm: 120, subdivision: 4);
      for (final index in [1, 2, 3, 5, 6, 7]) {
        expect(
          clock.kindOf(index, accentBeatOne: true),
          BeatKind.subdivision,
          reason: 'index $index is between beats',
        );
      }
    });

    test('turning the accent off makes every beat sound the same', () {
      const clock = BeatClock(bpm: 120, subdivision: 4);
      expect(clock.kindOf(0, accentBeatOne: false), BeatKind.beat);
      expect(clock.kindOf(16, accentBeatOne: false), BeatKind.beat);
      // Subdivisions are still distinct — that is not what the accent
      // preference controls.
      expect(clock.kindOf(1, accentBeatOne: false), BeatKind.subdivision);
    });

    test('the downbeat comes round once per bar at every subdivision', () {
      for (final subdivision in kSubdivisions) {
        final clock = BeatClock(bpm: 120, subdivision: subdivision);
        final downbeats = [
          for (var i = 0; i < subdivision * kBeatsPerBar * 3; i++)
            if (clock.kindOf(i, accentBeatOne: true) == BeatKind.downbeat) i,
        ];
        expect(
          downbeats,
          hasLength(3),
          reason: 'three bars at 1/$subdivision should give three downbeats',
        );
        expect(downbeats.first, 0);
        expect(downbeats[1], subdivision * kBeatsPerBar);
      }
    });

    test('the bar position cycles 1-2-3-4', () {
      const clock = BeatClock(bpm: 120, subdivision: 2);
      expect(
        [for (var i = 0; i < 10; i += 2) clock.beatInBar(i)],
        [1, 2, 3, 4, 1],
      );
    });
  });

  group('MetronomeRunner', () {
    test('clamps a tempo outside the engine range', () {
      final runner = MetronomeRunner(
        engine: const SilentMetronome(),
        onBeat: (_, _) {},
      );
      addTearDown(runner.dispose);

      runner.configure(bpm: 9999, subdivision: 4, accentBeatOne: true);
      expect(runner.clock.bpm, kMaxBpm);

      runner.configure(bpm: 1, subdivision: 4, accentBeatOne: true);
      expect(runner.clock.bpm, kMinBpm);
    });

    test('falls back to a playable subdivision', () {
      final runner = MetronomeRunner(
        engine: const SilentMetronome(),
        onBeat: (_, _) {},
      );
      addTearDown(runner.dispose);

      runner.configure(bpm: 120, subdivision: 5, accentBeatOne: true);
      expect(runner.clock.subdivision, 4);

      runner.configure(bpm: 120, subdivision: 6, accentBeatOne: true);
      expect(runner.clock.subdivision, 6);
    });

    testWidgets('fires beats on the grid once started', (tester) async {
      final fired = <int>[];
      final clock = FixedClock(DateTime(2026, 3, 14, 9));
      final runner = MetronomeRunner(
        engine: const SilentMetronome(),
        onBeat: (index, _) => fired.add(index),
        clock: clock,
      );
      addTearDown(runner.dispose);

      runner.configure(bpm: 120, subdivision: 1, accentBeatOne: true);
      runner.start();

      // 120 bpm quarter notes: one every 500 ms.
      await _run(tester, clock, const Duration(milliseconds: 2100));
      expect(fired, [0, 1, 2, 3, 4]);

      runner.stop();
      final count = fired.length;
      await _run(tester, clock, const Duration(seconds: 2));
      expect(fired.length, count, reason: 'stopping should stop the clicks');
    });

    testWidgets('muting keeps the grid running', (tester) async {
      final fired = <int>[];
      final clock = FixedClock(DateTime(2026, 3, 14, 9));
      final runner = MetronomeRunner(
        engine: const SilentMetronome(),
        onBeat: (index, _) => fired.add(index),
        clock: clock,
      );
      addTearDown(runner.dispose);

      runner.configure(
        bpm: 120,
        subdivision: 1,
        accentBeatOne: true,
        muted: true,
      );
      runner.start();
      await _run(tester, clock, const Duration(milliseconds: 1100));

      expect(fired, isNotEmpty, reason: 'the visual pulse must survive muting');
      // Stopped inside the test body: the framework checks for pending timers
      // before tearDown callbacks run.
      runner.stop();
    });

    testWidgets('a late callback does not push the following beats late', (
      tester,
    ) async {
      // The whole point of scheduling from an absolute index: if one beat
      // fires late, the next one gets a shorter delay rather than inheriting
      // the lateness.
      final fired = <int, Duration>{};
      final clock = FixedClock(DateTime(2026, 3, 14, 9));
      final start = clock.now();
      final runner = MetronomeRunner(
        engine: const SilentMetronome(),
        onBeat: (index, _) => fired[index] = clock.now().difference(start),
        clock: clock,
      );
      addTearDown(runner.dispose);

      runner.configure(bpm: 120, subdivision: 1, accentBeatOne: true);
      runner.start();

      // Coarse 120 ms steps: every beat lands late by up to a step.
      for (var i = 0; i < 30; i++) {
        clock.advance(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(fired.keys.length, greaterThanOrEqualTo(6));
      for (final entry in fired.entries) {
        final ideal = entry.key * 500;
        expect(
          (entry.value.inMilliseconds - ideal).abs(),
          lessThan(250),
          reason:
              'beat ${entry.key} landed at ${entry.value.inMilliseconds}ms, '
              'ideal ${ideal}ms — lateness is accumulating',
        );
      }
      runner.stop();
    });
  });
}
