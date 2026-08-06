import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/course_seed.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';

void main() {
  final allExercises = [for (final part in kCourseSeed) ...part.exercises];

  group('seed integrity', () {
    test('every exercise id is unique', () {
      final ids = allExercises.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every variant id is unique across the whole seed', () {
      final ids = [
        for (final exercise in allExercises)
          for (final variant in exercise.variants) variant.id,
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('every part id is unique', () {
      final ids = kCourseSeed.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every exercise partId resolves to its containing part', () {
      for (final part in kCourseSeed) {
        for (final exercise in part.exercises) {
          expect(
            exercise.partId,
            part.id,
            reason: '${exercise.id} claims part ${exercise.partId}',
          );
        }
      }
    });

    test('course milestones are unique and contiguous from 1', () {
      final milestones = kCourseParts.map((p) => p.milestone).toList()..sort();
      expect(milestones.toSet().length, milestones.length);
      expect(milestones.first, 1);
      for (var i = 0; i < milestones.length; i++) {
        expect(milestones[i], i + 1);
      }
    });

    test('parts are ordered by milestone', () {
      final ordered = [...kCourseParts]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i].milestone, greaterThan(ordered[i - 1].milestone));
      }
    });

    test('defaultTempo sits inside [minTempo, maxTempo]', () {
      for (final exercise in allExercises) {
        expect(
          exercise.minTempo,
          lessThanOrEqualTo(exercise.maxTempo),
          reason: '${exercise.id} has an inverted tempo range',
        );
        expect(
          exercise.defaultTempo,
          inInclusiveRange(exercise.minTempo, exercise.maxTempo),
          reason: '${exercise.id} opens outside its own range',
        );
      }
    });

    test('free-time exercises carry no tempo and use no metronome', () {
      for (final exercise in allExercises) {
        if (exercise.procedure != ProcedureType.freeTime) continue;
        expect(exercise.defaultTempo, 0, reason: exercise.id);
        expect(exercise.procedure.usesMetronome, isFalse);
      }
    });

    test('metronome exercises have a real tempo', () {
      for (final exercise in allExercises) {
        if (!exercise.procedure.usesMetronome) continue;
        expect(
          exercise.defaultTempo,
          greaterThan(0),
          reason: '${exercise.id} needs a click but has no tempo',
        );
      }
    });

    test('subdivision is one the metronome can actually play', () {
      const supported = {1, 2, 3, 4, 6, 8};
      for (final exercise in allExercises) {
        expect(supported, contains(exercise.subdivision), reason: exercise.id);
      }
    });

    test('difficulty is 1..5 and every exercise has a summary', () {
      for (final exercise in allExercises) {
        expect(
          exercise.difficulty,
          inInclusiveRange(1, 5),
          reason: exercise.id,
        );
        expect(exercise.summary, isNotEmpty, reason: exercise.id);
        expect(exercise.title, isNotEmpty, reason: exercise.id);
        expect(exercise.tags, isNotEmpty, reason: exercise.id);
      }
    });

    test('every category the weight table can select has an exercise', () {
      final covered = allExercises.map((e) => e.category).toSet();
      expect(covered, containsAll(PracticeCategory.values));
    });

    test('free play is available from the first practising milestone', () {
      expect(kFreePlayPart.milestone, 2);
      expect(kFreePlayPart.exercises, isNotEmpty);
    });

    test('the preface unlocks first and schedules nothing', () {
      final preface = kCourseParts.firstWhere((p) => p.milestone == 1);
      expect(preface.exercises, isEmpty);
    });

    test('variants with a stated tempo stay inside the exercise range', () {
      for (final exercise in allExercises) {
        for (final variant in exercise.variants) {
          final tempo = variant.tempo;
          if (tempo == null) continue;
          expect(
            tempo,
            inInclusiveRange(exercise.minTempo, exercise.maxTempo),
            reason: '${variant.id} states a tempo outside ${exercise.id}',
          );
        }
      }
    });

    test('the counts the plan specifies are present', () {
      Exercise byId(String id) => allExercises.firstWhere((e) => e.id == id);

      expect(byId('ex_1').variants, hasLength(4));
      expect(byId('ex_2').variants, hasLength(2));
      expect(byId('ex_4').variants, hasLength(4));
      expect(byId('ex_5').variants, hasLength(2));
      expect(byId('ex_6').variants, hasLength(2));
      expect(byId('ex_8').variants, hasLength(6));
      expect(byId('ex_9').variants, hasLength(7));
      expect(byId('ex_19').variants, hasLength(6));
      expect(byId('ex_28').variants, hasLength(4));

      final ex11 = byId('ex_11');
      expect(
        ex11.variants.where((v) => v.kind == VariantKind.fragment),
        hasLength(18),
      );
      expect(
        ex11.variants.where((v) => v.kind == VariantKind.development),
        hasLength(4),
      );
    });

    test('long variant sets supply short labels for scrollable tabs', () {
      for (final exercise in allExercises) {
        if (exercise.variants.length <= 10) continue;
        for (final variant in exercise.variants) {
          expect(
            variant.shortLabel,
            isNotNull,
            reason:
                '${variant.id} would render its full label in a crowded row',
          );
        }
      }
    });
  });

  group('seed serialisation', () {
    test('every part round-trips through JSON', () {
      for (final part in kCourseSeed) {
        expect(CoursePart.fromJson(part.toJson()).toJson(), part.toJson());
      }
    });
  });

  group('buildExerciseIndex', () {
    test('indexes every exercise exactly once', () {
      final index = buildExerciseIndex();
      expect(index.length, allExercises.length);
      expect(index['ex_11']?.title, 'Scale fragments in G major');
    });
  });
}
