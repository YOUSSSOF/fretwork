import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_service.dart';
import 'package:fretwork/features/session/records_controller.dart';

/// Where each category's rotation has reached.
class CursorsNotifier extends Notifier<Map<PracticeCategory, RotationCursor>> {
  @override
  Map<PracticeCategory, RotationCursor> build() {
    final store = ref.watch(storeProvider);
    final result = <PracticeCategory, RotationCursor>{};
    for (final entry in store.readAll(BoxNames.rotation).entries) {
      final category = PracticeCategory.values
          .where((c) => c.name == entry.key)
          .firstOrNull;
      if (category == null) continue;
      result[category] = RotationCursor.fromJson(entry.value);
    }
    return result;
  }

  Future<void> replace(Map<PracticeCategory, RotationCursor> cursors) async {
    state = cursors;
    final store = ref.read(storeProvider);
    for (final entry in cursors.entries) {
      await store.write(
        BoxNames.rotation,
        entry.key.name,
        entry.value.toJson(),
      );
    }
  }
}

final rotationCursorsProvider =
    NotifierProvider<CursorsNotifier, Map<PracticeCategory, RotationCursor>>(
      CursorsNotifier.new,
    );

/// Today's plan.
///
/// Regenerates when the date rolls over, the milestone changes, the session
/// length changes, the rest weekdays change, or the user reshuffles (§10.5).
/// The first four fall out of watching the profile and the clock; reshuffle is
/// explicit.
///
/// Generation is pure and synchronous, so the plan is available on the first
/// frame with no loading state. Persisting it and advancing the rotation
/// cursors are side effects, and are deferred out of `build` — a provider may
/// not write to another provider while building.
class RoutineNotifier extends Notifier<RoutineDay> {
  int _seedOffset = 0;

  /// Guards the deferred write. A rebuild or a container disposal can happen
  /// between scheduling the microtask and running it, and writing to a
  /// disposed provider throws.
  bool _stale = false;

  @override
  RoutineDay build() {
    _stale = false;
    ref.onDispose(() => _stale = true);

    final clock = ref.watch(clockProvider);
    final profile = ref.watch(profileProvider);
    final parts = ref.watch(unlockedPartsProvider);
    final store = ref.watch(storeProvider);
    final today = clock.now().dayStart;

    // Cursors and tempos are inputs to a generation, not reasons to
    // regenerate: watching them would loop, because generating advances them.
    final cursors = ref.read(rotationCursorsProvider);
    final tempos = ref.read(tempoRecordsProvider);
    final completed = ref.read(completedTodayProvider);

    final stored = store.read(BoxNames.routines, today.dayKey);
    if (stored != null) {
      final existing = RoutineDay.fromJson(stored);
      if (_isStillValid(existing, profile, today)) return existing;

      // A day that has been partially practised keeps what was done and
      // recalculates only the rest.
      if (completed.isNotEmpty) {
        final regenerated = _generate(
          date: today,
          profile: profile,
          parts: parts,
          cursors: cursors,
          tempos: tempos,
          seed: existing.generationSeed,
        );
        final merged = mergePreservingCompleted(
          previous: existing,
          replacement: regenerated.day,
          completedKeys: completed,
        );
        _persist(merged, regenerated.cursors);
        return merged;
      }
    }

    final generated = _generate(
      date: today,
      profile: profile,
      parts: parts,
      cursors: cursors,
      tempos: tempos,
      seed: today.day + _seedOffset,
    );
    _persist(generated.day, generated.cursors);
    return generated.day;
  }

  bool _isStillValid(RoutineDay day, UserProfile profile, DateTime today) =>
      day.date.isSameDayAs(today) &&
      day.milestone == profile.milestone &&
      (day.isRestDay
          ? profile.isRestWeekday(today)
          : !profile.isRestWeekday(today)) &&
      (day.isRestDay || day.plannedMinutes <= profile.sessionMinutes);

  RoutineGeneration _generate({
    required DateTime date,
    required UserProfile profile,
    required List<CoursePart> parts,
    required Map<PracticeCategory, RotationCursor> cursors,
    required Map<String, TempoRecord> tempos,
    required int seed,
  }) => generateRoutine(
    date: date,
    milestone: profile.milestone,
    sessionMinutes: profile.sessionMinutes,
    unlockedParts: parts,
    cursors: cursors,
    tempos: tempos,
    seed: seed,
    restWeekdays: profile.restWeekdays,
    generatedAt: ref.read(clockProvider).now(),
  );

  void _persist(RoutineDay day, Map<PracticeCategory, RotationCursor> cursors) {
    // Resolved now, used later: by the time the microtask runs, reading them
    // back off `ref` may no longer be legal.
    final store = ref.read(storeProvider);
    final cursorsNotifier = ref.read(rotationCursorsProvider.notifier);

    scheduleMicrotask(() async {
      if (_stale) return;
      await store.write(BoxNames.routines, day.id, day.toJson());
      if (_stale) return;
      await cursorsNotifier.replace(cursors);
    });
  }

  /// Re-rolls today without disturbing the rotation, so a reshuffle cannot
  /// quietly skip material the user has not seen yet.
  Future<void> reshuffle() async {
    _seedOffset++;
    final profile = ref.read(profileProvider);
    final today = ref.read(clockProvider).now().dayStart;
    final generated = _generate(
      date: today,
      profile: profile,
      parts: ref.read(unlockedPartsProvider),
      cursors: ref.read(rotationCursorsProvider),
      tempos: ref.read(tempoRecordsProvider),
      seed: today.day + _seedOffset,
    );

    final completed = ref.read(completedTodayProvider);
    final next = completed.isEmpty
        ? generated.day
        : mergePreservingCompleted(
            previous: state,
            replacement: generated.day,
            completedKeys: completed,
          );

    state = next;
    await ref
        .read(storeProvider)
        .write(BoxNames.routines, next.id, next.toJson());
  }
}

final todayRoutineProvider = NotifierProvider<RoutineNotifier, RoutineDay>(
  RoutineNotifier.new,
);

/// A day's plan for the routine screen's week strip.
///
/// Past days come from storage and are read-only. A future day has no stored
/// plan yet, so one is generated provisionally and deliberately *not* saved:
/// it will be rebuilt on the day from whatever the rotation looks like then.
final routineForDateProvider = Provider.family<RoutineDay?, DateTime>((
  ref,
  date,
) {
  final store = ref.watch(storeProvider);
  final stored = store.read(BoxNames.routines, date.dayKey);
  if (stored != null) return RoutineDay.fromJson(stored);

  final today = ref.watch(clockProvider).now().dayStart;
  if (date.dayStart.isBefore(today)) return null;

  final profile = ref.watch(profileProvider);
  return generateRoutine(
    date: date.dayStart,
    milestone: profile.milestone,
    sessionMinutes: profile.sessionMinutes,
    unlockedParts: ref.watch(unlockedPartsProvider),
    cursors: ref.read(rotationCursorsProvider),
    tempos: ref.read(tempoRecordsProvider),
    seed: date.day,
    restWeekdays: profile.restWeekdays,
  ).day;
});

/// Whether a plan shown for [date] is provisional rather than committed.
bool isProvisional(DateTime date, DateTime today) =>
    date.dayStart.isAfter(today.dayStart);

/// Rebuilds a plan while keeping anything already practised today.
///
/// Completed items keep their original minutes and position; everything else
/// is taken from the replacement. A block that ends up with no items at all is
/// dropped rather than rendered empty.
RoutineDay mergePreservingCompleted({
  required RoutineDay previous,
  required RoutineDay replacement,
  required Set<String> completedKeys,
}) {
  if (completedKeys.isEmpty) return replacement;

  final frozen = <PracticeCategory, List<RoutineItem>>{};
  for (final block in previous.blocks) {
    final kept = [
      for (final item in block.items)
        if (completedKeys.contains(item.key)) item,
    ];
    if (kept.isNotEmpty) frozen[block.category] = kept;
  }

  final blocks = <RoutineBlock>[];
  final categories = <PracticeCategory>{
    ...frozen.keys,
    ...replacement.blocks.map((b) => b.category),
  };

  for (final category in PracticeCategory.values) {
    if (!categories.contains(category)) continue;
    final kept = frozen[category] ?? const <RoutineItem>[];
    final fresh = replacement.blocks
        .where((b) => b.category == category)
        .expand((b) => b.items)
        .where((item) => !completedKeys.contains(item.key))
        .toList();

    final items = [...kept, ...fresh];
    if (items.isEmpty) continue;

    blocks.add(
      RoutineBlock(
        category: category,
        label: category.label,
        minutes: items.fold<int>(0, (sum, item) => sum + item.minutes),
        items: items,
      ),
    );
  }

  return replacement.copyWith(
    blocks: blocks,
    plannedMinutes: blocks.fold<int>(0, (sum, block) => sum + block.minutes),
  );
}
