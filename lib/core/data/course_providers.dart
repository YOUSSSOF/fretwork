import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_seed.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/features/progress/progress_controller.dart';

/// The curriculum. Static and const — overridable in tests with a smaller
/// course so routine-generator tests do not depend on the real seed.
final courseProvider = Provider<List<CoursePart>>((ref) => kCourseSeed);

/// Parts the user has reached. Everything the routine generator and the
/// library's unlocked section read goes through here.
final unlockedPartsProvider = Provider<List<CoursePart>>((ref) {
  final milestone = ref.watch(profileProvider.select((p) => p.milestone));
  return [
    for (final part in ref.watch(courseProvider))
      if (part.milestone <= milestone) part,
  ];
});

/// The part the user would unlock next, or null once the course is finished.
final nextPartProvider = Provider<CoursePart?>((ref) {
  final milestone = ref.watch(profileProvider.select((p) => p.milestone));
  final upcoming = [
    for (final part in ref.watch(courseProvider))
      if (part.milestone == milestone + 1) part,
  ];
  return upcoming.isEmpty ? null : upcoming.first;
});

final exerciseIndexProvider = Provider<Map<String, Exercise>>(
  (ref) => buildExerciseIndex(ref.watch(courseProvider)),
);

final exerciseByIdProvider = Provider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseIndexProvider)[id],
);

/// Exercises available to the routine generator right now.
final unlockedExercisesProvider = Provider<List<Exercise>>((ref) {
  return [
    for (final part in ref.watch(unlockedPartsProvider)) ...part.exercises,
  ];
});
