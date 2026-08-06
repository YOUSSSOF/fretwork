import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// How often the running item log is written, so a crash or force-quit loses
/// seconds rather than a session.
const Duration kSessionAutosave = Duration(seconds: 15);

/// Backgrounded for longer than this and the app offers to pause rather than
/// silently burning through the plan.
const Duration kBackgroundGraceLimit = Duration(minutes: 10);

enum SessionPhase { idle, running, paused, resting, itemDone, complete }

@immutable
class SessionState {
  const SessionState({
    required this.id,
    required this.routine,
    required this.startedAt,
    required this.mode,
    this.blockIndex = 0,
    this.itemIndex = 0,
    this.itemElapsed = Duration.zero,
    this.totalElapsed = Duration.zero,
    this.restRemaining = Duration.zero,
    this.phase = SessionPhase.idle,
    this.results = const {},
    this.currentTempo = 0,
  });

  final String id;
  final RoutineDay routine;
  final DateTime startedAt;
  final TimerMode mode;

  final int blockIndex;
  final int itemIndex;
  final Duration itemElapsed;
  final Duration totalElapsed;
  final Duration restRemaining;
  final SessionPhase phase;
  final Map<String, ItemResult> results;
  final int currentTempo;

  List<RoutineItem> get _flat => routine.allItems;

  int get totalItems => _flat.length;

  /// Position in the flattened item list, which is what the top rail fills.
  int get flatIndex {
    var index = 0;
    for (var b = 0; b < blockIndex && b < routine.blocks.length; b++) {
      index += routine.blocks[b].items.length;
    }
    return index + itemIndex;
  }

  RoutineBlock? get block =>
      blockIndex < routine.blocks.length ? routine.blocks[blockIndex] : null;

  RoutineItem? get item {
    final current = block;
    if (current == null) return null;
    return itemIndex < current.items.length ? current.items[itemIndex] : null;
  }

  Duration get itemDuration => Duration(minutes: item?.minutes ?? 0);

  Duration get itemRemaining {
    final remaining = itemDuration - itemElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get plannedDuration => Duration(minutes: routine.plannedMinutes);

  double get itemProgress => itemDuration.inMicroseconds == 0
      ? 0
      : (itemElapsed.inMicroseconds / itemDuration.inMicroseconds).clamp(0, 1);

  double get sessionProgress => plannedDuration.inMicroseconds == 0
      ? 0
      : (totalElapsed.inMicroseconds / plannedDuration.inMicroseconds).clamp(
          0,
          1,
        );

  bool get isRunning => phase == SessionPhase.running;
  bool get isLastItem => flatIndex >= totalItems - 1;

  int get completedMinutes {
    final seconds = results.values
        .where((r) => !r.skipped)
        .fold<int>(0, (sum, r) => sum + r.seconds);
    return (seconds / 60).round();
  }

  SessionState copyWith({
    int? blockIndex,
    int? itemIndex,
    Duration? itemElapsed,
    Duration? totalElapsed,
    Duration? restRemaining,
    SessionPhase? phase,
    Map<String, ItemResult>? results,
    int? currentTempo,
    TimerMode? mode,
  }) => SessionState(
    id: id,
    routine: routine,
    startedAt: startedAt,
    mode: mode ?? this.mode,
    blockIndex: blockIndex ?? this.blockIndex,
    itemIndex: itemIndex ?? this.itemIndex,
    itemElapsed: itemElapsed ?? this.itemElapsed,
    totalElapsed: totalElapsed ?? this.totalElapsed,
    restRemaining: restRemaining ?? this.restRemaining,
    phase: phase ?? this.phase,
    results: results ?? this.results,
    currentTempo: currentTempo ?? this.currentTempo,
  );
}

/// Runs a session.
///
/// Elapsed time is always read from a [Stopwatch], never accumulated by
/// counting ticks. A dropped or delayed timer callback then costs nothing —
/// the next read still reports the true wall-clock elapsed — and backgrounding
/// the app does not silently stop the clock.
class SessionNotifier extends Notifier<SessionState?> {
  final Stopwatch _itemWatch = Stopwatch();
  final Stopwatch _sessionWatch = Stopwatch();
  Timer? _ticker;
  Timer? _autosave;
  DateTime? _backgroundedAt;

  @override
  SessionState? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _autosave?.cancel();
    });
    return null;
  }

  /// The offset "+30 s" applies. The item's length is fixed by the plan, so
  /// the way to add time is to give elapsed time back.
  Duration _itemOffset = Duration.zero;

  /// True elapsed time for the current item, read straight off the stopwatch so
  /// the ring can be driven at 60 fps without the controller ticking that fast.
  Duration get itemElapsed {
    final raw = _itemWatch.elapsed + _itemOffset;
    return raw.isNegative ? Duration.zero : raw;
  }

  Duration get sessionElapsed => _sessionWatch.elapsed;

  void start({RoutineDay? routine, TimerMode? mode}) {
    final RoutineDay plan = routine ?? ref.read(todayRoutineProvider);
    if (plan.allItems.isEmpty) return;

    final prefs = ref.read(preferencesProvider);
    final now = ref.read(clockProvider).now();

    state = SessionState(
      id: 'session-${now.microsecondsSinceEpoch}',
      routine: plan,
      startedAt: now,
      mode: mode ?? prefs.timerMode,
      phase: SessionPhase.running,
    );

    _itemWatch
      ..reset()
      ..start();
    _sessionWatch
      ..reset()
      ..start();
    _startTicker();
    _startAutosave();
    _prepareMetronomeForCurrentItem();
    unawaited(WakelockGuard.enable());
  }

  void pause() {
    final current = state;
    if (current == null || !current.isRunning) return;
    _itemWatch.stop();
    _sessionWatch.stop();
    _ticker?.cancel();
    ref.read(metronomeProvider.notifier).stop();
    state = current.copyWith(phase: SessionPhase.paused);
  }

  void resume() {
    final current = state;
    if (current == null || current.phase != SessionPhase.paused) return;
    _itemWatch.start();
    _sessionWatch.start();
    _startTicker();
    state = current.copyWith(phase: SessionPhase.running);
  }

  void togglePause() =>
      state?.phase == SessionPhase.paused ? resume() : pause();

  void extend(Duration by) {
    final current = state;
    if (current == null) return;
    _itemOffset -= by;
    state = current.copyWith(itemElapsed: itemElapsed);
  }

  void skip() => _finishItem(skipped: true);

  void next() => _finishItem(skipped: false);

  Future<void> markClean() async {
    await ref.read(metronomeProvider.notifier).markClean();
    final current = state;
    final item = current?.item;
    if (current == null || item == null) return;
    final existing = current.results[item.key];
    final tempo = ref.read(metronomeProvider).bpm;
    state = current.copyWith(
      results: {
        ...current.results,
        item.key: (existing ?? _resultFor(item, seconds: 0)).copyWith(
          clean: true,
          endTempo: tempo,
        ),
      },
    );
  }

  /// Ends the session, keeping whatever was done. Partial credit is real
  /// credit — the analytics treat this as `partial`, never `missed`.
  Future<void> end({bool abandoned = true}) async {
    final current = state;
    if (current == null) return;

    // Bank the item in progress before tearing anything down.
    final item = current.item;
    final results = {...current.results};
    if (item != null && !results.containsKey(item.key)) {
      final seconds = itemElapsed.inSeconds;
      if (seconds > 0) {
        results[item.key] = _resultFor(item, seconds: seconds);
      }
    }

    _teardown();

    final now = ref.read(clockProvider).now();
    final record = SessionRecord(
      id: current.id,
      startedAt: current.startedAt,
      endedAt: now,
      plannedMinutes: current.routine.plannedMinutes,
      actualMinutes: (_sessionWatch.elapsed.inSeconds / 60).round(),
      items: results.values.toList(),
      abandoned: abandoned && !_isComplete(current, results),
    );

    await ref.read(sessionRecordsProvider.notifier).save(record);
    await _writeDayRecord(record);

    state = null;
    _sessionWatch.reset();
  }

  bool _isComplete(SessionState session, Map<String, ItemResult> results) =>
      results.length >= session.totalItems;

  Future<void> _writeDayRecord(SessionRecord record) async {
    final days = ref.read(dayRecordsProvider.notifier);
    final profile = ref.read(profileProvider);
    final date = record.startedAt;
    final existing = days.forDate(date);

    final completed = (existing?.completedMinutes ?? 0) + record.actualMinutes;
    final planned = existing?.plannedMinutes ?? record.plannedMinutes;

    await days.put(
      DayRecord(
        date: date,
        plannedMinutes: planned,
        completedMinutes: completed,
        status: DayRecord.statusFor(
          plannedMinutes: planned,
          completedMinutes: completed,
          isRestDay: false,
        ),
        sessionIds: [...?existing?.sessionIds, record.id],
        milestoneAtTime: profile.milestone,
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    // 1 Hz: this drives the numeric readout only. The ring interpolates from
    // [itemElapsed] on its own ticker, so it stays smooth without the whole
    // state object rebuilding sixty times a second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _startAutosave() {
    _autosave?.cancel();
    _autosave = Timer.periodic(kSessionAutosave, (_) => _autosaveNow());
  }

  void _autosaveNow() {
    final current = state;
    if (current == null) return;
    // Nothing to persist beyond what end() writes yet; the running log lives in
    // memory and is flushed on end. Kept as a hook so a crash-recovery record
    // can be added without restructuring the timer.
    unawaited(ref.read(storeProvider).putMeta('runningSession', current.id));
  }

  void _onTick() {
    final current = state;
    if (current == null || !current.isRunning) return;

    final elapsed = itemElapsed;
    if (elapsed >= current.itemDuration &&
        current.itemDuration > Duration.zero) {
      _finishItem(skipped: false);
      return;
    }

    state = current.copyWith(
      itemElapsed: elapsed,
      totalElapsed: _sessionWatch.elapsed,
    );
  }

  ItemResult _resultFor(RoutineItem item, {required int seconds}) {
    final exercise = ref.read(exerciseByIdProvider(item.exerciseId));
    final metronome = ref.read(metronomeProvider);
    return ItemResult(
      exerciseId: item.exerciseId,
      variantId: item.variantId,
      // Only reachable if a seed edit removed the exercise between generating
      // the plan and running it. Recording the time under free play beats
      // dropping the result.
      category: exercise?.category ?? PracticeCategory.freePlay,
      seconds: seconds,
      startTempo: item.targetTempo,
      endTempo: metronome.exerciseId == item.exerciseId
          ? metronome.bpm
          : item.targetTempo,
    );
  }

  void _finishItem({required bool skipped}) {
    final current = state;
    final item = current?.item;
    if (current == null || item == null) return;

    unawaited(HapticFeedback.mediumImpact());

    final existing = current.results[item.key];
    final seconds = skipped ? 0 : itemElapsed.inSeconds;
    final result = (existing ?? _resultFor(item, seconds: seconds)).copyWith(
      seconds: seconds,
      skipped: skipped,
    );

    final results = {...current.results, item.key: result};
    final advanced = _advance(current);

    if (advanced == null) {
      state = current.copyWith(results: results, phase: SessionPhase.complete);
      unawaited(end(abandoned: false));
      return;
    }

    final prefs = ref.read(preferencesProvider);
    final restSeconds = advanced.blockIndex != current.blockIndex
        ? prefs.restBetweenBlocksSeconds
        : prefs.restBetweenItemsSeconds;

    _restartItemWatch();
    state = advanced.copyWith(
      results: results,
      totalElapsed: _sessionWatch.elapsed,
      restRemaining: Duration(seconds: restSeconds),
      phase: restSeconds > 0 ? SessionPhase.resting : SessionPhase.running,
    );
    _prepareMetronomeForCurrentItem();
  }

  /// The next position, or null when the plan is finished.
  SessionState? _advance(SessionState current) {
    var block = current.blockIndex;
    var item = current.itemIndex + 1;

    while (block < current.routine.blocks.length) {
      if (item < current.routine.blocks[block].items.length) {
        return current.copyWith(blockIndex: block, itemIndex: item);
      }
      block++;
      item = 0;
    }
    return null;
  }

  void _restartItemWatch() {
    _itemOffset = Duration.zero;
    _itemWatch
      ..reset()
      ..start();
  }

  void _prepareMetronomeForCurrentItem() {
    final item = state?.item;
    if (item == null) return;
    final exercise = ref.read(exerciseByIdProvider(item.exerciseId));
    if (exercise == null || !item.procedure.usesMetronome) {
      ref.read(metronomeProvider.notifier).stop();
      return;
    }
    ref
        .read(metronomeProvider.notifier)
        .prepare(
          exerciseId: exercise.id,
          tempo: item.targetTempo,
          subdivision: exercise.subdivision,
          minTempo: exercise.minTempo,
          maxTempo: exercise.maxTempo,
        );
  }

  /// Called when the app goes to the background.
  void onBackgrounded() {
    _backgroundedAt = ref.read(clockProvider).now();
  }

  /// Called on resume. Returns true when the gap was long enough that the app
  /// should ask rather than assume — the wall clock kept running, so a session
  /// left overnight would otherwise be reported as practised.
  bool onResumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || state?.isRunning != true) return false;
    final away = ref.read(clockProvider).now().difference(since);
    if (away < kBackgroundGraceLimit) return false;
    pause();
    return true;
  }

  void _teardown() {
    _ticker?.cancel();
    _autosave?.cancel();
    _ticker = null;
    _autosave = null;
    _itemWatch.stop();
    _sessionWatch.stop();
    ref.read(metronomeProvider.notifier).stop();
    unawaited(WakelockGuard.disable());
  }
}

/// Keeps the screen awake while a session runs, and — importantly — always
/// releases it again. A practice session is the one time the user is looking at
/// the phone from across the room with both hands busy.
///
/// Failures are logged and swallowed: a platform that will not hold the screen
/// awake is a nuisance, but it is not a reason to refuse to start a session.
abstract final class WakelockGuard {
  static Future<void> enable() => _attempt(WakelockPlus.enable);

  static Future<void> disable() => _attempt(WakelockPlus.disable);

  static Future<void> _attempt(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (error) {
      debugPrint('Wakelock unavailable: ${error.message}');
    } on MissingPluginException {
      // No platform side — tests, or a desktop build without the plugin.
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState?>(
  SessionNotifier.new,
);
