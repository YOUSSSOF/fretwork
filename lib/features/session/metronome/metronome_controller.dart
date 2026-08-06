import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';

/// How long after the last tempo change the new tempo is written to the
/// exercise's record. Long enough that dragging a dial does not produce fifty
/// writes, short enough that leaving the screen keeps the value.
const Duration kTempoPersistDebounce = Duration(milliseconds: 800);

/// The +8 bpm ladder step (§12).
const int kLadderStep = 8;

@immutable
class MetronomeState {
  const MetronomeState({
    this.bpm = 100,
    this.subdivision = 4,
    this.minBpm = kMinBpm,
    this.maxBpm = kMaxBpm,
    this.running = false,
    this.muted = false,
    this.beatIndex = -1,
    this.beatInBar = 0,
    this.accent = false,
    this.exerciseId,
  });

  final int bpm;
  final int subdivision;
  final int minBpm;
  final int maxBpm;
  final bool running;
  final bool muted;

  /// -1 before the first beat, so the visual indicator does not flash on open.
  final int beatIndex;
  final int beatInBar;
  final bool accent;

  final String? exerciseId;

  bool get canGoFaster => bpm < maxBpm;
  bool get canGoSlower => bpm > minBpm;

  MetronomeState copyWith({
    int? bpm,
    int? subdivision,
    int? minBpm,
    int? maxBpm,
    bool? running,
    bool? muted,
    int? beatIndex,
    int? beatInBar,
    bool? accent,
    String? exerciseId,
  }) => MetronomeState(
    bpm: bpm ?? this.bpm,
    subdivision: subdivision ?? this.subdivision,
    minBpm: minBpm ?? this.minBpm,
    maxBpm: maxBpm ?? this.maxBpm,
    running: running ?? this.running,
    muted: muted ?? this.muted,
    beatIndex: beatIndex ?? this.beatIndex,
    beatInBar: beatInBar ?? this.beatInBar,
    accent: accent ?? this.accent,
    exerciseId: exerciseId ?? this.exerciseId,
  );
}

/// Overridden in tests with [SilentMetronome].
final metronomeEngineProvider = Provider<MetronomeEngine>((ref) {
  final engine = SoLoudMetronome();
  ref.onDispose(engine.dispose);
  return engine;
});

class MetronomeNotifier extends Notifier<MetronomeState> {
  MetronomeRunner? _runner;
  Timer? _persistDebounce;

  @override
  MetronomeState build() {
    final prefs = ref.watch(preferencesProvider);
    final engine = ref.watch(metronomeEngineProvider);

    final runner = MetronomeRunner(
      engine: engine,
      onBeat: _handleBeat,
      clock: ref.watch(clockProvider),
    );
    _runner = runner;

    ref.onDispose(() {
      _persistDebounce?.cancel();
      runner.dispose();
    });

    unawaited(engine.load(prefs.metronomeSound));
    return const MetronomeState();
  }

  void _handleBeat(int index, BeatKind kind) {
    state = state.copyWith(
      beatIndex: index,
      beatInBar: _runner?.clock.beatInBar(index) ?? 0,
      accent: kind == BeatKind.downbeat,
    );
    if (ref.read(preferencesProvider).hapticOnBeat) {
      unawaited(
        kind == BeatKind.downbeat
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick(),
      );
    }
  }

  /// Points the metronome at an exercise: its tempo range, its subdivision,
  /// and the tempo it was last left at.
  void prepare({
    required String exerciseId,
    required int tempo,
    required int subdivision,
    required int minTempo,
    required int maxTempo,
  }) {
    final lower = minTempo <= 0 ? kMinBpm : minTempo.clamp(kMinBpm, kMaxBpm);
    final upper = maxTempo <= 0 ? kMaxBpm : maxTempo.clamp(kMinBpm, kMaxBpm);
    final resolved = tempo <= 0 ? lower : tempo.clamp(lower, upper);

    state = state.copyWith(
      exerciseId: exerciseId,
      bpm: resolved,
      subdivision: subdivision,
      minBpm: lower,
      maxBpm: upper > lower ? upper : lower,
      beatIndex: -1,
      beatInBar: 0,
    );
    _applyConfiguration();
  }

  void start() {
    if (state.running) return;
    _applyConfiguration();
    _runner?.start();
    state = state.copyWith(running: true, beatIndex: -1);
  }

  void stop() {
    _runner?.stop();
    state = state.copyWith(running: false, beatIndex: -1, beatInBar: 0);
  }

  void toggle() => state.running ? stop() : start();

  void setMuted(bool muted) {
    // The visual pulse keeps running: muting is for late-night practice, not
    // for turning the metronome off.
    state = state.copyWith(muted: muted);
    _applyConfiguration();
  }

  void setTempo(int bpm) {
    final next = bpm.clamp(state.minBpm, state.maxBpm);
    if (next == state.bpm) return;
    state = state.copyWith(bpm: next);
    _applyConfiguration();
    _schedulePersist();
  }

  void nudge(int delta) => setTempo(state.bpm + delta);

  /// The ladder step. Distinct from [nudge] so the haptic can differ — this is
  /// the gesture the whole ladder procedure is built around.
  void stepLadder() {
    if (!state.canGoFaster) return;
    unawaited(HapticFeedback.lightImpact());
    setTempo(state.bpm + kLadderStep);
  }

  void setSubdivision(int subdivision) {
    if (!kSubdivisions.contains(subdivision)) return;
    state = state.copyWith(subdivision: subdivision, beatIndex: -1);
    _applyConfiguration();
  }

  /// Records that the current tempo was played flawlessly. This one flag is
  /// what the whole tempo-progression chart is built from, so it is written
  /// immediately rather than debounced.
  Future<void> markClean() async {
    final exerciseId = state.exerciseId;
    if (exerciseId == null) return;
    unawaited(HapticFeedback.mediumImpact());
    await ref
        .read(tempoRecordsProvider.notifier)
        .append(
          exerciseId,
          TempoPoint(
            date: ref.read(clockProvider).now(),
            bpm: state.bpm,
            clean: true,
          ),
        );
  }

  void _applyConfiguration() {
    final prefs = ref.read(preferencesProvider);
    _runner?.configure(
      bpm: state.bpm,
      subdivision: state.subdivision,
      accentBeatOne: prefs.accentBeatOne,
      muted: state.muted || !prefs.metronomeEnabled,
    );
  }

  /// Remembers where the exercise was left, so it opens there next time.
  void _schedulePersist() {
    _persistDebounce?.cancel();
    final exerciseId = state.exerciseId;
    if (exerciseId == null) return;
    final bpm = state.bpm;
    _persistDebounce = Timer(kTempoPersistDebounce, () {
      unawaited(
        ref
            .read(tempoRecordsProvider.notifier)
            .append(
              exerciseId,
              TempoPoint(date: ref.read(clockProvider).now(), bpm: bpm),
            ),
      );
    });
  }
}

final metronomeProvider = NotifierProvider<MetronomeNotifier, MetronomeState>(
  MetronomeNotifier.new,
);
