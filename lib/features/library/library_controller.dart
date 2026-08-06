import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';

/// Named to avoid colliding with Flutter's own LockState.
enum PartLock { unlocked, next, locked }

@immutable
class LibraryFilter {
  const LibraryFilter({
    this.query = '',
    this.categories = const {},
    this.tags = const {},
    this.unlockedOnly = false,
  });

  final String query;
  final Set<PracticeCategory> categories;
  final Set<TechniqueTag> tags;
  final bool unlockedOnly;

  bool get isActive =>
      query.isNotEmpty ||
      categories.isNotEmpty ||
      tags.isNotEmpty ||
      unlockedOnly;

  bool matches(Exercise exercise, PartLock lock) {
    if (unlockedOnly && lock != PartLock.unlocked) return false;
    if (categories.isNotEmpty && !categories.contains(exercise.category)) {
      return false;
    }
    if (tags.isNotEmpty && !exercise.tags.any(tags.contains)) return false;
    if (query.isEmpty) return true;

    final needle = query.toLowerCase();
    return exercise.label.toLowerCase().contains(needle) ||
        exercise.title.toLowerCase().contains(needle) ||
        (exercise.keyCenter?.toLowerCase().contains(needle) ?? false);
  }

  LibraryFilter copyWith({
    String? query,
    Set<PracticeCategory>? categories,
    Set<TechniqueTag>? tags,
    bool? unlockedOnly,
  }) => LibraryFilter(
    query: query ?? this.query,
    categories: categories ?? this.categories,
    tags: tags ?? this.tags,
    unlockedOnly: unlockedOnly ?? this.unlockedOnly,
  );
}

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleCategory(PracticeCategory category) {
    final next = {...state.categories};
    next.contains(category) ? next.remove(category) : next.add(category);
    state = state.copyWith(categories: next);
  }

  void toggleTag(TechniqueTag tag) {
    final next = {...state.tags};
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    state = state.copyWith(tags: next);
  }

  void setUnlockedOnly(bool value) =>
      state = state.copyWith(unlockedOnly: value);

  void clear() => state = const LibraryFilter();
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
      LibraryFilterNotifier.new,
    );

final lockStateProvider = Provider.family<PartLock, int>((ref, milestone) {
  final current = ref.watch(profileProvider.select((p) => p.milestone));
  if (milestone <= current) return PartLock.unlocked;
  if (milestone == current + 1) return PartLock.next;
  return PartLock.locked;
});

@immutable
class LibrarySection {
  const LibrarySection({
    required this.part,
    required this.lock,
    required this.exercises,
  });

  final CoursePart part;
  final PartLock lock;
  final List<Exercise> exercises;
}

/// The library, grouped by part and filtered.
///
/// Locked parts stay in the list with an empty exercise list: the road ahead
/// should be visible without being browsable.
final librarySectionsProvider = Provider<List<LibrarySection>>((ref) {
  final filter = ref.watch(libraryFilterProvider);
  final parts = [...ref.watch(courseProvider)]
    ..sort((a, b) => a.milestone.compareTo(b.milestone));

  final sections = <LibrarySection>[];
  for (final part in parts) {
    final lock = ref.watch(lockStateProvider(part.milestone));
    final visible = lock == PartLock.locked
        ? const <Exercise>[]
        : [
            for (final exercise in part.exercises)
              if (filter.matches(exercise, lock)) exercise,
          ];

    // A part with nothing to show is dropped while filtering, but kept when
    // browsing, so the course structure stays legible.
    if (filter.isActive && visible.isEmpty) continue;
    sections.add(LibrarySection(part: part, lock: lock, exercises: visible));
  }
  return sections;
});

/// Variant ids the routine picked for today, so the detail screen can mark
/// them in the tab row.
final scheduledVariantsProvider = Provider<Set<String>>((ref) {
  return {
    for (final item in ref.watch(todayRoutineProvider).allItems)
      if (item.variantId != null) item.variantId!,
  };
});

final scheduledExercisesProvider = Provider<Set<String>>((ref) {
  return {
    for (final item in ref.watch(todayRoutineProvider).allItems)
      item.exerciseId,
  };
});
