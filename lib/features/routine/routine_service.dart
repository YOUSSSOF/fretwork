import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/models/user_profile.dart';

/// Relative category weights per milestone, before caps. Zero means the
/// category is not unlocked yet.
///
/// The design intent, stated so it survives future edits: **warm-up shrinks as
/// a share of the session as real material unlocks** — it is preparation, not
/// practice. Free play never disappears, because technique that is never used
/// musically stays locked in the practice room.
const Map<int, Map<PracticeCategory, int>> kCategoryWeights = {
  // Only the preface has been read. There is nothing to drill yet, but there
  // is always something to play.
  1: {PracticeCategory.freePlay: 100},
  2: {PracticeCategory.warmupLeft: 70, PracticeCategory.freePlay: 30},
  3: {
    PracticeCategory.warmupLeft: 35,
    PracticeCategory.warmupRight: 35,
    PracticeCategory.freePlay: 30,
  },
  4: {
    PracticeCategory.warmupLeft: 22,
    PracticeCategory.warmupRight: 22,
    PracticeCategory.warmupSync: 21,
    PracticeCategory.freePlay: 35,
  },
  5: {
    PracticeCategory.warmupLeft: 10,
    PracticeCategory.warmupRight: 10,
    PracticeCategory.warmupSync: 10,
    PracticeCategory.timeFeel: 12,
    PracticeCategory.speedAccuracy: 38,
    PracticeCategory.freePlay: 20,
  },
  6: {
    PracticeCategory.warmupLeft: 6,
    PracticeCategory.warmupRight: 6,
    PracticeCategory.warmupSync: 6,
    PracticeCategory.timeFeel: 8,
    PracticeCategory.speedAccuracy: 26,
    PracticeCategory.scalar: 32,
    PracticeCategory.freePlay: 16,
  },
  7: {
    PracticeCategory.warmupLeft: 5,
    PracticeCategory.warmupRight: 5,
    PracticeCategory.warmupSync: 5,
    PracticeCategory.timeFeel: 7,
    PracticeCategory.speedAccuracy: 18,
    PracticeCategory.scalar: 25,
    PracticeCategory.arpeggio: 20,
    PracticeCategory.freePlay: 15,
  },
  8: {
    PracticeCategory.warmupLeft: 4,
    PracticeCategory.warmupRight: 4,
    PracticeCategory.warmupSync: 5,
    PracticeCategory.timeFeel: 6,
    PracticeCategory.speedAccuracy: 14,
    PracticeCategory.scalar: 19,
    PracticeCategory.arpeggio: 16,
    PracticeCategory.legato: 18,
    PracticeCategory.freePlay: 14,
  },
  9: {
    PracticeCategory.warmupLeft: 4,
    PracticeCategory.warmupRight: 4,
    PracticeCategory.warmupSync: 4,
    PracticeCategory.timeFeel: 5,
    PracticeCategory.speedAccuracy: 11,
    PracticeCategory.scalar: 15,
    PracticeCategory.arpeggio: 13,
    PracticeCategory.legato: 15,
    PracticeCategory.sweep: 16,
    PracticeCategory.freePlay: 13,
  },
  10: {
    PracticeCategory.warmupLeft: 3,
    PracticeCategory.warmupRight: 3,
    PracticeCategory.warmupSync: 4,
    PracticeCategory.timeFeel: 5,
    PracticeCategory.speedAccuracy: 9,
    PracticeCategory.scalar: 13,
    PracticeCategory.arpeggio: 11,
    PracticeCategory.legato: 13,
    PracticeCategory.sweep: 14,
    PracticeCategory.chordal: 13,
    PracticeCategory.freePlay: 12,
  },
};

/// Caps applied after the raw weighted split.
abstract final class RoutineCaps {
  /// Warm-up is capped as a *total* across the three warm-up categories, not
  /// per category — twelve minutes of warm-up is twelve minutes whether it is
  /// split two ways or three.
  static const int warmupMin = 6;
  static const int warmupMax = 12;

  static const int freePlayMin = 5;
  static const int freePlayMax = 20;

  static const int timeFeelMin = 3;
  static const int timeFeelMax = 8;

  /// Below this a block is not worth having; the category is dropped for the
  /// day and recorded as owed so it is prioritised tomorrow.
  static const int categoryMin = 4;

  /// Time feel is dropped entirely below this session length — in a short
  /// session the minutes are better spent on material.
  static const int timeFeelSessionFloor = 30;

  static const int itemMinMinutes = 3;
  static const int minutesPerItem = 6;
  static const int maxItemsPerBlock = 5;

  /// Exercises with at least this many variants get several scheduled in one
  /// visit, so Example 11's eighteen fragments cycle in under a week instead of
  /// taking eighteen days.
  static const int multiVariantThreshold = 10;
  static const int variantsPerVisit = 3;

  /// While the user is new to a category, order candidates by difficulty
  /// rather than by rotation.
  static const int newToCategorySessions = 5;
}

/// The outcome of a generation: the plan, plus the advanced cursors.
///
/// Cursors are returned rather than mutated so the whole service stays pure and
/// a preview can be generated without disturbing the rotation.
@immutable
class RoutineGeneration {
  const RoutineGeneration({required this.day, required this.cursors});

  final RoutineDay day;
  final Map<PracticeCategory, RotationCursor> cursors;
}

/// Splits a session into per-category minutes.
///
/// Pure and cheap, so the onboarding slider can call it on every drag frame to
/// preview the block split live.
Map<PracticeCategory, int> allocateMinutes({
  required int milestone,
  required int sessionMinutes,
  required Set<PracticeCategory> available,
}) {
  final table = kCategoryWeights[milestone.clamp(1, kMaxMilestone)];
  if (table == null || sessionMinutes <= 0) return const {};

  var weights = <PracticeCategory, int>{
    for (final entry in table.entries)
      if (entry.value > 0 && available.contains(entry.key))
        entry.key: entry.value,
  };
  if (sessionMinutes < RoutineCaps.timeFeelSessionFloor) {
    weights.remove(PracticeCategory.timeFeel);
  }
  if (weights.isEmpty) return const {};

  // Drop categories whose share is too small to be worth a block, then
  // re-split across the survivors. Iterating matters: dropping one category
  // lifts everyone else, which can rescue a second category that was only just
  // below the floor.
  Map<PracticeCategory, double> raw(Map<PracticeCategory, int> w) {
    final total = w.values.fold<int>(0, (a, b) => a + b);
    return {
      for (final entry in w.entries)
        entry.key: sessionMinutes * entry.value / total,
    };
  }

  var shares = raw(weights);
  for (var pass = 0; pass < weights.length; pass++) {
    final doomed = [
      for (final entry in shares.entries)
        if (_hasOwnFloor(entry.key))
          if (entry.value < RoutineCaps.categoryMin) entry.key,
    ];
    if (doomed.isEmpty) break;
    // Never drop everything: if only floored categories remain, keep the
    // largest rather than returning an empty plan.
    if (doomed.length == weights.length) {
      final keep = shares.entries
          .sorted((a, b) => b.value.compareTo(a.value))
          .first
          .key;
      doomed.remove(keep);
      if (doomed.isEmpty) break;
    }
    weights = {
      for (final entry in weights.entries)
        if (!doomed.contains(entry.key)) entry.key: entry.value,
    };
    shares = raw(weights);
  }

  final fixed = <PracticeCategory, double>{};
  final flexible = <PracticeCategory, double>{};

  // Warm-up: cap the total, then split it back across whichever warm-up
  // categories are present, in proportion to their weights.
  final warmups = shares.keys.where((c) => c.isWarmup).toList();
  if (warmups.isNotEmpty) {
    final rawTotal = warmups.fold<double>(0, (sum, c) => sum + shares[c]!);
    final cappedTotal = rawTotal.clamp(
      RoutineCaps.warmupMin.toDouble(),
      RoutineCaps.warmupMax.toDouble(),
    );
    final weightTotal = warmups.fold<int>(0, (sum, c) => sum + weights[c]!);
    for (final category in warmups) {
      fixed[category] = cappedTotal * weights[category]! / weightTotal;
    }
  }

  if (shares.containsKey(PracticeCategory.freePlay)) {
    fixed[PracticeCategory.freePlay] = shares[PracticeCategory.freePlay]!.clamp(
      RoutineCaps.freePlayMin.toDouble(),
      RoutineCaps.freePlayMax.toDouble(),
    );
  }

  if (shares.containsKey(PracticeCategory.timeFeel)) {
    fixed[PracticeCategory.timeFeel] = shares[PracticeCategory.timeFeel]!.clamp(
      RoutineCaps.timeFeelMin.toDouble(),
      RoutineCaps.timeFeelMax.toDouble(),
    );
  }

  for (final entry in shares.entries) {
    if (!fixed.containsKey(entry.key)) flexible[entry.key] = entry.value;
  }

  // Redistribute whatever the caps freed up (or claimed) across the
  // uncapped categories, in proportion to their existing share.
  final allocatedFixed = fixed.values.fold<double>(0, (a, b) => a + b);
  final flexTotal = flexible.values.fold<double>(0, (a, b) => a + b);
  final delta = sessionMinutes - allocatedFixed - flexTotal;

  final result = <PracticeCategory, double>{...fixed};
  if (flexTotal > 0) {
    for (final entry in flexible.entries) {
      result[entry.key] = entry.value + delta * (entry.value / flexTotal);
    }
  } else if (delta > 0) {
    // Nothing uncapped to absorb it — push into free play, then warm-up, up to
    // their ceilings. Any residue is simply not scheduled, and plannedMinutes
    // reflects that rather than pretending.
    var spare = delta;
    spare = _topUp(
      result,
      PracticeCategory.freePlay,
      RoutineCaps.freePlayMax.toDouble(),
      spare,
    );
    for (final category in warmups) {
      if (spare <= 0) break;
      spare = _topUp(
        result,
        category,
        RoutineCaps.warmupMax.toDouble() / warmups.length,
        spare,
      );
    }
  }

  return _roundToWholeMinutes(result, sessionMinutes);
}

/// Categories subject to the generic four-minute floor. Warm-up, free play and
/// time feel have their own explicit caps instead.
bool _hasOwnFloor(PracticeCategory category) =>
    !category.isWarmup &&
    category != PracticeCategory.freePlay &&
    category != PracticeCategory.timeFeel;

double _topUp(
  Map<PracticeCategory, double> into,
  PracticeCategory category,
  double ceiling,
  double available,
) {
  final current = into[category];
  if (current == null || available <= 0) return available;
  final room = (ceiling - current).clamp(0.0, available);
  into[category] = current + room;
  return available - room;
}

/// Rounds to whole minutes and puts the rounding remainder on the largest
/// block, so the blocks always add up to what the plan claims.
Map<PracticeCategory, int> _roundToWholeMinutes(
  Map<PracticeCategory, double> shares,
  int target,
) {
  final rounded = <PracticeCategory, int>{
    for (final entry in shares.entries) entry.key: entry.value.round(),
  };
  rounded.removeWhere((_, minutes) => minutes <= 0);
  if (rounded.isEmpty) return const {};

  final planned = shares.values.fold<double>(0, (a, b) => a + b).round();
  final ceiling = planned < target ? planned : target;
  var drift = ceiling - rounded.values.fold<int>(0, (a, b) => a + b);
  if (drift != 0) {
    final biggest = rounded.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .first
        .key;
    rounded[biggest] = (rounded[biggest]! + drift).clamp(1, target);
    drift = 0;
  }

  // Order the map the way the blocks are rendered: warm-ups, time feel, the
  // technical categories in unlock order, free play last.
  return {
    for (final category in PracticeCategory.values)
      if (rounded.containsKey(category)) category: rounded[category]!,
  };
}

/// Builds a day's plan.
///
/// Pure: no I/O, no clock, no providers. Everything it needs is a parameter, so
/// every branch is reachable from a unit test.
RoutineGeneration generateRoutine({
  required DateTime date,
  required int milestone,
  required int sessionMinutes,
  required List<CoursePart> unlockedParts,
  required Map<PracticeCategory, RotationCursor> cursors,
  required Map<String, TempoRecord> tempos,
  required int seed,
  required Set<int> restWeekdays,
  DateTime? generatedAt,
}) {
  final stamp = generatedAt ?? date;

  if (restWeekdays.contains(date.weekday)) {
    return RoutineGeneration(
      day: RoutineDay(
        date: date,
        milestone: milestone,
        plannedMinutes: 0,
        blocks: const [],
        generationSeed: seed,
        generatedAt: stamp,
        isRestDay: true,
      ),
      cursors: cursors,
    );
  }

  final byCategory = <PracticeCategory, List<Exercise>>{};
  for (final part in unlockedParts) {
    for (final exercise in part.exercises) {
      byCategory.putIfAbsent(exercise.category, () => []).add(exercise);
    }
  }

  final allocation = allocateMinutes(
    milestone: milestone,
    sessionMinutes: sessionMinutes,
    available: byCategory.keys.toSet(),
  );

  final nextCursors = <PracticeCategory, RotationCursor>{...cursors};
  final blocks = <RoutineBlock>[];

  for (final entry in allocation.entries) {
    final category = entry.key;
    final minutes = entry.value;
    final candidates = byCategory[category];
    if (candidates == null || candidates.isEmpty) continue;

    final cursor = nextCursors[category] ?? const RotationCursor();
    final picked = _selectItems(
      category: category,
      candidates: candidates,
      blockMinutes: minutes,
      cursor: cursor,
      tempos: tempos,
      date: date,
      seed: seed,
    );

    nextCursors[category] = picked.cursor;
    if (picked.items.isEmpty) continue;
    blocks.add(
      RoutineBlock(
        category: category,
        label: category.label,
        minutes: minutes,
        items: picked.items,
      ),
    );
  }

  // Categories the weights wanted but the caps priced out are recorded as owed,
  // so tomorrow's generation prioritises them.
  final wanted =
      kCategoryWeights[milestone.clamp(1, kMaxMilestone)] ?? const {};
  for (final category in wanted.keys) {
    if (allocation.containsKey(category)) continue;
    if (!byCategory.containsKey(category)) continue;
    final cursor = nextCursors[category] ?? const RotationCursor();
    nextCursors[category] = cursor.copyWith(
      owedMinutes: cursor.owedMinutes + RoutineCaps.categoryMin,
    );
  }

  final planned = blocks.fold<int>(0, (sum, block) => sum + block.minutes);

  return RoutineGeneration(
    day: RoutineDay(
      date: date,
      milestone: milestone,
      plannedMinutes: planned,
      blocks: blocks,
      generationSeed: seed,
      generatedAt: stamp,
    ),
    cursors: nextCursors,
  );
}

@immutable
class _Selection {
  const _Selection({required this.items, required this.cursor});

  final List<RoutineItem> items;
  final RotationCursor cursor;
}

_Selection _selectItems({
  required PracticeCategory category,
  required List<Exercise> candidates,
  required int blockMinutes,
  required RotationCursor cursor,
  required Map<String, TempoRecord> tempos,
  required DateTime date,
  required int seed,
}) {
  final affordable = blockMinutes ~/ RoutineCaps.itemMinMinutes;
  final slots = (blockMinutes ~/ RoutineCaps.minutesPerItem).clamp(
    1,
    affordable < 1 ? 1 : affordable.clamp(1, RoutineCaps.maxItemsPerBlock),
  );

  // Stable base order. While the user is new to a category, easiest first —
  // being handed a grade-5 sweep on day one of Part VIII teaches nothing.
  final ordered = [...candidates];
  if (cursor.sessionsSeen < RoutineCaps.newToCategorySessions) {
    ordered.sort((a, b) {
      final byDifficulty = a.difficulty.compareTo(b.difficulty);
      return byDifficulty != 0 ? byDifficulty : a.id.compareTo(b.id);
    });
  } else {
    ordered.sort((a, b) => a.id.compareTo(b.id));
  }

  // The seed rotates the starting point, so Reshuffle re-rolls the day without
  // touching the rotation cursor and corrupting the long-run coverage.
  final start = ordered.isEmpty
      ? 0
      : (cursor.exerciseIndex + seed) % ordered.length;

  final chosen = <(Exercise, ExerciseVariant?)>[];
  final variantIndices = <String, int>{...cursor.variantIndices};
  var consumed = 0;

  while (chosen.length < slots && consumed < ordered.length) {
    final exercise = ordered[(start + consumed) % ordered.length];
    consumed++;

    if (exercise.variants.isEmpty) {
      chosen.add((exercise, null));
      continue;
    }

    // A long variant set gets several slots in one visit; otherwise eighteen
    // fragments would take eighteen days to come round.
    final take = exercise.variants.length >= RoutineCaps.multiVariantThreshold
        ? RoutineCaps.variantsPerVisit
        : 1;
    var index = variantIndices[exercise.id] ?? 0;
    for (var i = 0; i < take && chosen.length < slots; i++) {
      final variant =
          exercise.variants[(index + seed) % exercise.variants.length];
      chosen.add((exercise, variant));
      index++;
    }
    variantIndices[exercise.id] = index % exercise.variants.length;
  }

  final items = _distributeMinutes(
    chosen: chosen,
    blockMinutes: blockMinutes,
    tempos: tempos,
    category: category,
    date: date,
  );

  return _Selection(
    items: items,
    cursor: cursor.copyWith(
      exerciseIndex: ordered.isEmpty
          ? 0
          : (cursor.exerciseIndex + consumed) % ordered.length,
      variantIndices: variantIndices,
      sessionsSeen: cursor.sessionsSeen + 1,
      owedMinutes: 0,
    ),
  );
}

List<RoutineItem> _distributeMinutes({
  required List<(Exercise, ExerciseVariant?)> chosen,
  required int blockMinutes,
  required Map<String, TempoRecord> tempos,
  required PracticeCategory category,
  required DateTime date,
}) {
  if (chosen.isEmpty || blockMinutes <= 0) return const [];

  // Three warm-up categories sharing a six-minute cap give two-minute blocks,
  // which is a perfectly good warm-up and a block shorter than the normal item
  // floor. In that case the floor becomes the block itself.
  final floor = RoutineCaps.itemMinMinutes <= blockMinutes
      ? RoutineCaps.itemMinMinutes
      : blockMinutes;

  final weights = [
    for (final (exercise, _) in chosen) exercise.estimatedMinutes,
  ];
  final weightTotal = weights.fold<int>(0, (a, b) => a + b);
  final minutes = <int>[];

  for (var i = 0; i < chosen.length; i++) {
    final share = weightTotal == 0
        ? blockMinutes / chosen.length
        : blockMinutes * weights[i] / weightTotal;
    minutes.add(share.round().clamp(floor, blockMinutes));
  }

  // The floor can push the total past the block; trim from the largest until
  // it fits, dropping trailing items rather than scheduling one-minute stubs.
  var total = minutes.fold<int>(0, (a, b) => a + b);
  while (total > blockMinutes && minutes.length > 1) {
    final largest = minutes.indexOf(minutes.reduce((a, b) => a > b ? a : b));
    if (minutes[largest] > floor) {
      minutes[largest]--;
    } else {
      minutes.removeLast();
      chosen.removeLast();
    }
    total = minutes.fold<int>(0, (a, b) => a + b);
  }
  if (minutes.length == 1) minutes[0] = blockMinutes;

  // Any remainder goes to the first item, which is the one the user is
  // freshest for.
  final remainder = blockMinutes - minutes.fold<int>(0, (a, b) => a + b);
  if (remainder > 0) minutes[0] += remainder;

  return [
    for (var i = 0; i < chosen.length; i++)
      _buildItem(
        exercise: chosen[i].$1,
        variant: chosen[i].$2,
        minutes: minutes[i],
        tempos: tempos,
        category: category,
        date: date,
      ),
  ];
}

RoutineItem _buildItem({
  required Exercise exercise,
  required ExerciseVariant? variant,
  required int minutes,
  required Map<String, TempoRecord> tempos,
  required PracticeCategory category,
  required DateTime date,
}) {
  final remembered = tempos[exercise.id]?.lastTempo ?? 0;
  final target =
      variant?.tempo ?? (remembered > 0 ? remembered : exercise.defaultTempo);

  return RoutineItem(
    exerciseId: exercise.id,
    variantId: variant?.id,
    minutes: minutes,
    targetTempo: exercise.maxTempo == 0
        ? 0
        : target.clamp(exercise.minTempo, exercise.maxTempo),
    procedure: exercise.procedure,
    focusNote: focusNoteFor(
      category: category,
      procedure: exercise.procedure,
      date: date,
    ),
  );
}

/// One line of intent for today.
///
/// The right-hand alternation is mandatory rather than cosmetic: a player who
/// only ever starts on a down-stroke builds a hand that can only start on a
/// down-stroke.
@visibleForTesting
String focusNoteFor({
  required PracticeCategory category,
  required ProcedureType procedure,
  required DateTime date,
}) {
  if (category == PracticeCategory.warmupRight) {
    return date.day.isEven ? 'Start on a down-stroke' : 'Start on an up-stroke';
  }
  return switch (procedure) {
    ProcedureType.ladder => 'Flawless before +8 bpm',
    ProcedureType.hold => 'One minute each, no stopping',
    ProcedureType.burst => 'Short flurries, keep the time',
    ProcedureType.accelDecel => 'Up and back down, no breaks',
    ProcedureType.freeTime => 'No click — make it musical',
    ProcedureType.fixedTempo => 'Hold the tempo, chase accuracy',
  };
}
