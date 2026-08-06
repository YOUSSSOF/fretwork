import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/utils/clock.dart';

/// Tempo bounds the engine will accept, whatever an exercise asks for.
const int kMinBpm = 40;
const int kMaxBpm = 260;

/// Subdivisions the click can actually play.
const List<int> kSubdivisions = [1, 2, 3, 4, 6, 8];

/// Beats per bar the click counts before the downbeat comes round again.
const int kBeatsPerBar = 4;

/// Where a beat sits in the bar. Three kinds, not two: without a distinct
/// downbeat there is no way to hear where the bar restarts, which is most of
/// what a click is for.
enum BeatKind {
  /// Beat one. Highest pitch.
  downbeat,

  /// Beats two, three and four.
  beat,

  /// The notes between the beats. Lower and quieter, so the pulse still reads.
  subdivision,
}

/// Computes when beats happen.
///
/// Every beat time is derived from its absolute index, never by adding an
/// interval to the previous beat. Accumulating intervals is what makes a
/// metronome drift audibly inside a minute: each addition rounds, and the
/// rounding compounds.
@immutable
class BeatClock {
  const BeatClock({required this.bpm, required this.subdivision});

  final int bpm;
  final int subdivision;

  /// Microseconds between consecutive clicks, as an exact rational rather than
  /// a rounded integer.
  double get intervalMicros => 60000000 / (bpm * subdivision);

  /// When beat [index] should sound, measured from the start of the run.
  Duration timeOf(int index) =>
      Duration(microseconds: (index * intervalMicros).round());

  /// The index of the last beat that is due at [elapsed].
  int dueIndex(Duration elapsed) =>
      (elapsed.inMicroseconds / intervalMicros).floor();

  BeatKind kindOf(int index, {required bool accentBeatOne}) {
    if (index % subdivision != 0) return BeatKind.subdivision;
    final isDownbeat = (index ~/ subdivision) % kBeatsPerBar == 0;
    // With the accent turned off every beat sounds the same, which is what
    // that preference is for.
    return isDownbeat && accentBeatOne ? BeatKind.downbeat : BeatKind.beat;
  }

  /// Which beat of the bar this is, 1-based, for the visual indicator.
  int beatInBar(int index) => (index ~/ subdivision) % kBeatsPerBar + 1;
}

/// Plays the clicks. Behind an interface so the audio backend can be swapped —
/// soundpool is the first choice for latency, not a commitment.
abstract interface class MetronomeEngine {
  Future<void> load(MetronomeSound sound);

  Future<void> play(BeatKind kind);

  Future<void> dispose();
}

/// The production engine.
///
/// SoLoud rather than the plan's first choice of soundpool: soundpool is
/// discontinued and its Android side still targets the removed v1 embedding,
/// so it no longer compiles. The plan anticipated this and put the engine
/// behind an interface for exactly this reason — the swap is confined to this
/// class.
class SoLoudMetronome implements MetronomeEngine {
  SoLoudMetronome();

  final Map<BeatKind, AudioSource> _sources = {};
  MetronomeSound? _loaded;

  /// Set when the audio backend cannot be reached at all — no native library
  /// (a unit-test VM, an unsupported desktop target) or a device that refuses
  /// to open an output. The engine then degrades to silence rather than
  /// throwing: the timing grid, the visual pulse and — crucially — the tempo
  /// tracking the analytics depend on all keep working without sound.
  bool _unavailable = false;

  static String _assetFor(MetronomeSound sound, BeatKind kind) {
    final stem = switch (sound) {
      MetronomeSound.click => 'click',
      MetronomeSound.woodblock => 'woodblock',
      MetronomeSound.beep => 'beep',
    };
    final suffix = switch (kind) {
      BeatKind.downbeat => 'down',
      BeatKind.beat => 'beat',
      BeatKind.subdivision => 'sub',
    };
    return 'assets/audio/${stem}_$suffix.wav';
  }

  @override
  Future<void> load(MetronomeSound sound) async {
    if (_unavailable) return;
    if (_loaded == sound && _sources.length == BeatKind.values.length) return;

    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        // A short buffer keeps the gap between "play" and "audible" small; the
        // clicks are tiny, so the memory cost is nothing.
        await soloud.init(bufferSize: 256);
      }

      await _release();
      // All three are preloaded: loading on the first beat would make the
      // first click of every session late, which is the one that matters most.
      for (final kind in BeatKind.values) {
        _sources[kind] = await soloud.loadAsset(_assetFor(sound, kind));
      }
      _loaded = sound;
    } on Object catch (error) {
      // Deliberately broad: the failure modes here span an FFI ArgumentError
      // for a missing native library, plugin exceptions, and SoLoud's own
      // errors, and none of them should be able to stop a practice session.
      _unavailable = true;
      debugPrint('Metronome audio unavailable, continuing silently: $error');
    }
  }

  @override
  Future<void> play(BeatKind kind) async {
    if (_unavailable) return;
    final source = _sources[kind];
    if (source == null) return;
    try {
      // `play` returns a handle synchronously rather than a Future — the sound
      // is already scheduled by the time it returns.
      SoLoud.instance.play(source);
    } on Object catch (error) {
      _unavailable = true;
      debugPrint('Metronome playback failed, continuing silently: $error');
    }
  }

  Future<void> _release() async {
    final soloud = SoLoud.instance;
    for (final source in _sources.values) {
      await soloud.disposeSource(source);
    }
    _sources.clear();
    _loaded = null;
  }

  @override
  Future<void> dispose() async {
    if (_unavailable) return;
    try {
      await _release();
    } on Object catch (error) {
      debugPrint('Metronome teardown failed: $error');
    }
  }
}

/// Makes no sound. Used when the metronome is muted or disabled, and in tests —
/// the visual pulse and the beat timing still run, which is exactly what
/// late-night practice wants.
class SilentMetronome implements MetronomeEngine {
  const SilentMetronome();

  @override
  Future<void> load(MetronomeSound sound) async {}

  @override
  Future<void> play(BeatKind kind) async {}

  @override
  Future<void> dispose() async {}
}

/// Drives the click.
///
/// Each beat schedules the next from its own absolute time, so a late timer
/// callback does not push everything after it late too — the following beat
/// simply gets a shorter delay.
class MetronomeRunner {
  MetronomeRunner({
    required MetronomeEngine engine,
    required this.onBeat,
    Clock clock = const SystemClock(),
  }) : _engine = engine,
       _clock = clock;

  final MetronomeEngine _engine;

  /// Elapsed time is measured against an injectable clock rather than a
  /// [Stopwatch], because a Stopwatch reads the real hardware clock and cannot
  /// be advanced by a test — the scheduling logic would be untestable.
  final Clock _clock;

  DateTime? _startedAt;

  /// Fired from the same callback that triggers the sound, so the visual pulse
  /// cannot drift away from what is audible.
  final void Function(int index, BeatKind kind) onBeat;

  BeatClock _beatClock = const BeatClock(bpm: 100, subdivision: 4);
  Timer? _timer;
  int _nextIndex = 0;
  bool _accentBeatOne = true;

  /// Silences the audio while leaving the grid and the visual pulse running —
  /// muting is for practising late, not for turning the metronome off.
  bool muted = false;

  bool get isRunning => _startedAt != null;

  Duration get elapsed {
    final start = _startedAt;
    return start == null ? Duration.zero : _clock.now().difference(start);
  }

  BeatClock get clock => _beatClock;

  void configure({
    required int bpm,
    required int subdivision,
    required bool accentBeatOne,
    bool muted = false,
  }) {
    this.muted = muted;
    final wasRunning = isRunning;
    _beatClock = BeatClock(
      bpm: bpm.clamp(kMinBpm, kMaxBpm),
      subdivision: kSubdivisions.contains(subdivision) ? subdivision : 4,
    );
    _accentBeatOne = accentBeatOne;
    if (wasRunning) {
      // Restart the grid so a tempo change lands on a beat rather than
      // half-way through one.
      stop();
      start();
    }
  }

  void start() {
    if (isRunning) return;
    _startedAt = _clock.now();
    _nextIndex = 0;
    _scheduleNext();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _nextIndex = 0;
  }

  void dispose() {
    stop();
    unawaited(_engine.dispose());
  }

  void _scheduleNext() {
    if (!isRunning) return;
    final target = _beatClock.timeOf(_nextIndex);
    final delay = target - elapsed;
    _timer = Timer(delay.isNegative ? Duration.zero : delay, _fire);
  }

  void _fire() {
    if (!isRunning) return;
    final index = _nextIndex;
    final kind = _beatClock.kindOf(index, accentBeatOne: _accentBeatOne);
    if (!muted) unawaited(_engine.play(kind));
    onBeat(index, kind);
    _nextIndex++;
    _scheduleNext();
  }
}
