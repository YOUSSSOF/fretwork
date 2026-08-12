import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/session_snapshot.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/session/active_session_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// How often the running session is stamped, so a crash loses seconds rather
/// than a session.
const Duration kSessionAutosave = Duration(seconds: 15);

enum SessionPhase {
  /// Loaded but not started. The user presses Start.
  ready,

  running,
  paused,

  /// The item's timer ran out. Nothing advances until the user says so.
  itemComplete,

  /// Every item is done.
  complete,
}

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
    this.phase = SessionPhase.ready,
    this.results = const {},
  });

  final String id;
  final RoutineDay routine;
  final DateTime startedAt;
  final TimerMode mode;

  final int blockIndex;
  final int itemIndex;
  final Duration itemElapsed;
  final Duration totalElapsed;
  final SessionPhase phase;
  final Map<String, ItemResult> results;

  int get totalItems => routine.allItems.length;

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

  /// The item after this one, for the "up next" preview.
  RoutineItem? get nextItem {
    var block = blockIndex;
    var index = itemIndex + 1;
    while (block < routine.blocks.length) {
      if (index < routine.blocks[block].items.length) {
        return routine.blocks[block].items[index];
      }
      block++;
      index = 0;
    }
    return null;
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
  bool get isPaused => phase == SessionPhase.paused;
  bool get hasStarted => phase != SessionPhase.ready;
  bool get isLastItem => nextItem == null;

  SessionState copyWith({
    int? blockIndex,
    int? itemIndex,
    Duration? itemElapsed,
    Duration? totalElapsed,
    SessionPhase? phase,
    Map<String, ItemResult>? results,
    TimerMode? mode,
    RoutineDay? routine,
  }) => SessionState(
    id: id,
    routine: routine ?? this.routine,
    startedAt: startedAt,
    mode: mode ?? this.mode,
    blockIndex: blockIndex ?? this.blockIndex,
    itemIndex: itemIndex ?? this.itemIndex,
    itemElapsed: itemElapsed ?? this.itemElapsed,
    totalElapsed: totalElapsed ?? this.totalElapsed,
    phase: phase ?? this.phase,
    results: results ?? this.results,
  );
}

/// Runs a session.
///
/// Elapsed time is read from a [Stopwatch] rather than accumulated by counting
/// ticks, so a delayed or dropped callback costs nothing. The stopwatch stops
/// whenever the session is not actively running — paused, waiting on a
/// completion prompt, or backgrounded — which is what makes leaving the app and
/// coming back behave.
class SessionNotifier extends Notifier<SessionState?> {
  final Stopwatch _itemWatch = Stopwatch();
  final Stopwatch _sessionWatch = Stopwatch();
  Timer? _ticker;
  Timer? _autosave;

  /// Whether the click was running when something interrupted, so resuming
  /// puts it back the way the user left it.
  bool _metronomeWasRunning = false;

  @override
  SessionState? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _autosave?.cancel();
    });
    return null;
  }

  /// Offset applied by "+30 s". The item's length is fixed by the plan, so the
  /// way to add time is to give elapsed time back.
  Duration _itemOffset = Duration.zero;

  /// Time already banked by a session that was resumed from disk. The
  /// stopwatches always start from zero; what was practised before the app was
  /// closed is added back through these offsets.
  Duration _sessionOffset = Duration.zero;

  Duration get itemElapsed {
    final raw = _itemWatch.elapsed + _itemOffset;
    return raw.isNegative ? Duration.zero : raw;
  }

  Duration get totalElapsed => _sessionWatch.elapsed + _sessionOffset;

  /// Loads a plan without starting the clock. The user presses Start.
  void load({RoutineDay? routine, TimerMode? mode}) {
    if (state != null) return;
    final RoutineDay plan = routine ?? ref.read(todayRoutineProvider);
    if (plan.allItems.isEmpty) return;

    final prefs = ref.read(preferencesProvider);
    final now = ref.read(clockProvider).now();

    state = SessionState(
      id: 'session-${now.microsecondsSinceEpoch}',
      routine: plan,
      startedAt: now,
      mode: mode ?? prefs.timerMode,
    );
    _prepareMetronomeForCurrentItem();
  }

  /// Picks a session back up exactly where it was left.
  ///
  /// It comes back paused, never running: the app may have been closed hours
  /// ago, and a click starting under a guitar that is still in its case is the
  /// one thing worse than an extra tap.
  bool restore(SessionSnapshot snapshot) {
    if (state != null) return false;
    if (snapshot.routine.allItems.isEmpty) return false;

    _itemOffset = snapshot.itemElapsed;
    _sessionOffset = snapshot.totalElapsed;
    _itemWatch.reset();
    _sessionWatch.reset();
    _metronomeWasRunning = false;

    state = SessionState(
      id: snapshot.id,
      routine: snapshot.routine,
      startedAt: snapshot.startedAt,
      mode: snapshot.mode,
      blockIndex: snapshot.blockIndex.clamp(
        0,
        snapshot.routine.blocks.length - 1,
      ),
      itemIndex: snapshot.itemIndex,
      itemElapsed: snapshot.itemElapsed,
      totalElapsed: snapshot.totalElapsed,
      phase: SessionPhase.paused,
      results: {for (final result in snapshot.results) result.key: result},
    );
    _prepareMetronomeForCurrentItem();
    _startAutosave();
    return true;
  }

  void start() {
    final current = state;
    if (current == null || current.phase != SessionPhase.ready) return;

    _itemOffset = Duration.zero;
    _sessionOffset = Duration.zero;
    _itemWatch
      ..reset()
      ..start();
    _sessionWatch
      ..reset()
      ..start();
    _startTicker();
    _startAutosave();
    state = current.copyWith(phase: SessionPhase.running);
    unawaited(WakelockGuard.enable());
    unawaited(_saveSnapshot());
  }

  void pause({bool remember = true}) {
    final current = state;
    if (current == null || !current.isRunning) return;

    _itemWatch.stop();
    _sessionWatch.stop();
    _ticker?.cancel();
    _ticker = null;

    // The click stops with the clock. A metronome ticking against a stopped
    // timer is the most confusing state this screen can be in.
    if (remember) _metronomeWasRunning = ref.read(metronomeProvider).running;
    ref.read(metronomeProvider.notifier).stop();

    state = current.copyWith(
      itemElapsed: itemElapsed,
      totalElapsed: totalElapsed,
      phase: SessionPhase.paused,
    );

    // Stopping is the moment most likely to be followed by the app going away
    // for good, so both the resume point and the credit earned so far are
    // written now rather than on the next autosave tick.
    unawaited(_saveSnapshot());
    unawaited(_checkpoint());
  }

  void resume() {
    final current = state;
    if (current == null || !current.isPaused) return;

    _itemWatch.start();
    _sessionWatch.start();
    _startTicker();
    _startAutosave();
    state = current.copyWith(phase: SessionPhase.running);
    unawaited(WakelockGuard.enable());

    if (_metronomeWasRunning) {
      ref.read(metronomeProvider.notifier).start();
      _metronomeWasRunning = false;
    }
  }

  void togglePause() {
    final current = state;
    if (current == null) return;
    if (current.isPaused) {
      resume();
    } else if (current.isRunning) {
      pause();
    }
  }

  void extend(Duration by) {
    final current = state;
    if (current == null) return;
    _itemOffset -= by;

    // Adding time to a finished item puts it back on the clock.
    final phase = current.phase == SessionPhase.itemComplete
        ? SessionPhase.running
        : current.phase;
    if (phase == SessionPhase.running && !_itemWatch.isRunning) {
      _itemWatch.start();
      if (!_sessionWatch.isRunning) _sessionWatch.start();
      _startTicker();
    }
    state = current.copyWith(itemElapsed: itemElapsed, phase: phase);
  }

  void skip() => _finishItem(skipped: true, thenAdvance: true);

  /// Ends the current item and waits. The screen shows what was done and what
  /// is next; nothing moves until the user chooses.
  void completeItem() => _finishItem(skipped: false, thenAdvance: false);

  /// Moves to the next item, or finishes the session on the last one.
  void advance() {
    final current = state;
    if (current == null) return;

    final next = _nextPosition(current);
    if (next == null) {
      state = current.copyWith(phase: SessionPhase.complete);
      unawaited(end(abandoned: false));
      return;
    }

    _itemOffset = Duration.zero;
    _itemWatch
      ..reset()
      ..start();
    if (!_sessionWatch.isRunning) _sessionWatch.start();
    _startTicker();

    state = next.copyWith(
      itemElapsed: Duration.zero,
      totalElapsed: totalElapsed,
      phase: SessionPhase.running,
    );
    _prepareMetronomeForCurrentItem();
    unawaited(_saveSnapshot());
  }

  /// Swaps the current item for another exercise, keeping the minutes.
  ///
  /// The clock is paused while the picker is open and restarted after, so
  /// choosing does not cost practice time.
  Future<void> chooseItem(RoutineItem replacement) async {
    final current = state;
    final existing = current?.item;
    if (current == null || existing == null) return;

    final blocks = [
      for (final block in current.routine.blocks)
        block.copyWith(
          items: [
            for (final item in block.items)
              if (item.key == existing.key)
                replacement.copyWith(minutes: item.minutes)
              else
                item,
          ],
        ),
    ];

    state = current.copyWith(routine: current.routine.copyWith(blocks: blocks));
    _prepareMetronomeForCurrentItem();
    unawaited(_saveSnapshot());

    // Keep the stored plan in step so the change survives leaving the screen.
    await ref
        .read(todayRoutineProvider.notifier)
        .replaceItem(itemKey: existing.key, replacement: replacement);
  }

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

  /// Ends the session, keeping whatever was done.
  Future<void> end({bool abandoned = true}) async {
    final current = state;
    if (current == null) return;

    _teardown();
    await _persist(current, abandoned: abandoned);
    await ref.read(activeSessionProvider.notifier).clear();

    state = null;
    _sessionWatch.reset();
    _itemWatch.reset();
    _itemOffset = Duration.zero;
    _sessionOffset = Duration.zero;
  }

  /// Writes what has been practised so far, without ending anything.
  ///
  /// Progress is logged exercise by exercise rather than only when a routine
  /// runs to the end: half a session is half a session's worth of practice,
  /// and analytics that only count finished routines quietly punish the days
  /// where something came up.
  Future<void> _checkpoint() async {
    final current = state;
    if (current == null || !current.hasStarted) return;
    await _persist(current, abandoned: true);
  }

  /// Upserts the session record and re-derives the day from it.
  ///
  /// Called repeatedly for the same session id, so both writes have to be
  /// idempotent — the record replaces its earlier self, and the day's minutes
  /// are recomputed from the day's sessions rather than added to.
  Future<void> _persist(SessionState session, {required bool abandoned}) async {
    final results = _resultsIncludingCurrent(session);
    if (results.isEmpty) return;

    final now = ref.read(clockProvider).now();
    final record = SessionRecord(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: now,
      plannedMinutes: session.routine.plannedMinutes,
      actualMinutes: (totalElapsed.inSeconds / 60).round(),
      items: results.values.toList(),
      abandoned: abandoned && results.length < session.totalItems,
    );

    await ref.read(sessionRecordsProvider.notifier).save(record);
    await _writeDayRecord(record);
  }

  /// The finished items plus whatever time the item in flight has already
  /// earned, so leaving mid-exercise still banks the minutes played.
  Map<String, ItemResult> _resultsIncludingCurrent(SessionState session) {
    final results = {...session.results};
    final item = session.item;
    if (item == null) return results;

    final seconds = itemElapsed.inSeconds;
    if (seconds <= 0) return results;

    final existing = results[item.key];
    // A finished item keeps its recorded time; only an item still running has
    // its partial time folded in.
    if (existing != null) return results;

    return {...results, item.key: _resultFor(item, seconds: seconds)};
  }

  Future<void> _writeDayRecord(SessionRecord record) async {
    final days = ref.read(dayRecordsProvider.notifier);
    final profile = ref.read(profileProvider);
    final date = record.startedAt;
    final existing = days.forDate(date);

    final completed = ref
        .read(sessionRecordsProvider.notifier)
        .completedMinutesOn(date);
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
        sessionIds: {...?existing?.sessionIds, record.id}.toList(),
        milestoneAtTime: profile.milestone,
      ),
    );
  }

  Future<void> _saveSnapshot() async {
    final current = state;
    if (current == null || !current.hasStarted) return;

    await ref
        .read(activeSessionProvider.notifier)
        .save(
          SessionSnapshot(
            id: current.id,
            routine: current.routine,
            startedAt: current.startedAt,
            savedAt: ref.read(clockProvider).now(),
            mode: current.mode,
            blockIndex: current.blockIndex,
            itemIndex: current.itemIndex,
            itemElapsed: itemElapsed,
            totalElapsed: totalElapsed,
            results: current.results.values.toList(),
          ),
        );
  }

  void _startTicker() {
    _ticker?.cancel();
    // 1 Hz drives the numeric readout. The ring interpolates from
    // [itemElapsed] on its own ticker, so it stays smooth without the whole
    // state object rebuilding sixty times a second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _startAutosave() {
    _autosave?.cancel();
    // Stamps the resume point on a timer, so a crash or a swipe-away costs
    // seconds rather than the session.
    _autosave = Timer.periodic(kSessionAutosave, (_) {
      if (state == null) return;
      unawaited(_saveSnapshot());
    });
  }

  void _onTick() {
    final current = state;
    if (current == null || !current.isRunning) return;

    final elapsed = itemElapsed;
    if (current.itemDuration > Duration.zero &&
        elapsed >= current.itemDuration) {
      completeItem();
      return;
    }

    state = current.copyWith(itemElapsed: elapsed, totalElapsed: totalElapsed);
  }

  ItemResult _resultFor(RoutineItem item, {required int seconds}) {
    final exercise = ref.read(exerciseByIdProvider(item.exerciseId));
    final metronome = ref.read(metronomeProvider);
    return ItemResult(
      exerciseId: item.exerciseId,
      variantId: item.variantId,
      category: exercise?.category ?? item.procedure.fallbackCategory,
      seconds: seconds,
      startTempo: item.targetTempo,
      endTempo: metronome.exerciseId == item.exerciseId
          ? metronome.bpm
          : item.targetTempo,
    );
  }

  void _finishItem({required bool skipped, required bool thenAdvance}) {
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

    if (thenAdvance) {
      state = current.copyWith(results: results);
      // Banked before moving on: what is done is done, whether or not the rest
      // of the routine ever happens.
      unawaited(_checkpoint());
      advance();
      return;
    }

    // Hold here. The clock and the click both stop until the user decides.
    _itemWatch.stop();
    _ticker?.cancel();
    _ticker = null;
    ref.read(metronomeProvider.notifier).stop();
    _metronomeWasRunning = false;

    state = current.copyWith(
      results: results,
      itemElapsed: current.itemDuration,
      totalElapsed: totalElapsed,
      phase: SessionPhase.itemComplete,
    );
    unawaited(_checkpoint());
    unawaited(_saveSnapshot());
  }

  SessionState? _nextPosition(SessionState current) {
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

  void _prepareMetronomeForCurrentItem() {
    final item = state?.item;
    if (item == null) return;
    final exercise = ref.read(exerciseByIdProvider(item.exerciseId));
    final metronome = ref.read(metronomeProvider.notifier);
    if (exercise == null || !item.procedure.usesMetronome) {
      metronome.stop();
      return;
    }
    metronome.prepare(
      exerciseId: exercise.id,
      tempo: item.targetTempo,
      subdivision: exercise.subdivision,
      minTempo: exercise.minTempo,
      maxTempo: exercise.maxTempo,
    );
  }

  /// The app went to the background. Everything stops until it comes back —
  /// time spent in another app is not practice.
  void onBackgrounded() {
    if (state?.isRunning ?? false) pause();
  }

  /// True when the app came back to a session that is sitting paused.
  ///
  /// It is left paused deliberately: the user was not holding the guitar, and
  /// restarting a click they cannot hear coming is worse than a tap on Resume.
  bool onResumed() => state?.isPaused ?? false;

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

/// Keeps the screen awake while a session runs, and always releases it again.
///
/// Failures are logged and swallowed: a platform that will not hold the screen
/// awake is a nuisance, not a reason to refuse to start practising.
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
