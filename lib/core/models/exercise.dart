import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';
import 'package:fretwork/core/models/practice_category.dart';

/// One subdivision of an exercise: a part, variation, development or fragment.
///
/// Carries metadata only — a label, an optional one-line original note, and a
/// page pointer. No notation, no tablature (§0).
@immutable
class ExerciseVariant {
  const ExerciseVariant({
    required this.id,
    required this.label,
    required this.kind,
    this.shortLabel,
    this.note,
    this.tempo,
    this.bookPage,
  });

  final String id;
  final String label;
  final String? shortLabel;
  final VariantKind kind;
  final String? note;
  final int? tempo;
  final int? bookPage;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (shortLabel != null) 'shortLabel': shortLabel,
    'kind': kind.name,
    if (note != null) 'note': note,
    if (tempo != null) 'tempo': tempo,
    if (bookPage != null) 'bookPage': bookPage,
  };

  factory ExerciseVariant.fromJson(Map<String, Object?> json) =>
      ExerciseVariant(
        id: stringFromJson(json['id'], ''),
        label: stringFromJson(json['label'], ''),
        shortLabel: stringFromJsonOrNull(json['shortLabel']),
        kind: enumFromName(VariantKind.values, json['kind'], VariantKind.part),
        note: stringFromJsonOrNull(json['note']),
        tempo: json['tempo'] is int ? json['tempo']! as int : null,
        bookPage: json['bookPage'] is int ? json['bookPage']! as int : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseVariant &&
          other.id == id &&
          other.label == label &&
          other.shortLabel == shortLabel &&
          other.kind == kind &&
          other.note == note &&
          other.tempo == tempo &&
          other.bookPage == bookPage;

  @override
  int get hashCode =>
      Object.hash(id, label, shortLabel, kind, note, tempo, bookPage);
}

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.partId,
    required this.label,
    required this.title,
    required this.summary,
    required this.category,
    required this.tags,
    required this.procedure,
    required this.difficulty,
    required this.defaultTempo,
    required this.minTempo,
    required this.maxTempo,
    required this.subdivision,
    required this.estimatedMinutes,
    required this.bookPage,
    this.keyCenter,
    this.position,
    this.cdTrack,
    this.variants = const [],
    this.tips = const [],
  });

  final String id;
  final String partId;

  /// e.g. 'Example 11'.
  final String label;

  /// e.g. 'Scale fragments in G major'.
  final String title;

  /// One or two sentences, written by the app author.
  final String summary;

  final PracticeCategory category;
  final List<TechniqueTag> tags;
  final ProcedureType procedure;

  /// 1..5.
  final int difficulty;

  /// bpm; 0 means free time.
  final int defaultTempo;
  final int minTempo;
  final int maxTempo;

  /// Notes per beat: 1, 2, 3, 4, 6 or 8.
  final int subdivision;

  final String? keyCenter;
  final String? position;

  /// Ideal minutes for one visit.
  final int estimatedMinutes;

  final int bookPage;
  final int? cdTrack;
  final List<ExerciseVariant> variants;

  /// Paraphrased procedure guidance, shown on demand only — never pinned to
  /// the screen (§18.5).
  final List<String> tips;

  bool get hasVariants => variants.isNotEmpty;

  bool get isFreeTime => procedure == ProcedureType.freeTime;

  ExerciseVariant? variantById(String? id) {
    if (id == null) return null;
    for (final variant in variants) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'partId': partId,
    'label': label,
    'title': title,
    'summary': summary,
    'category': category.name,
    'tags': [for (final tag in tags) tag.name],
    'procedure': procedure.name,
    'difficulty': difficulty,
    'defaultTempo': defaultTempo,
    'minTempo': minTempo,
    'maxTempo': maxTempo,
    'subdivision': subdivision,
    if (keyCenter != null) 'keyCenter': keyCenter,
    if (position != null) 'position': position,
    'estimatedMinutes': estimatedMinutes,
    'bookPage': bookPage,
    if (cdTrack != null) 'cdTrack': cdTrack,
    'variants': [for (final variant in variants) variant.toJson()],
    'tips': tips,
  };

  factory Exercise.fromJson(Map<String, Object?> json) => Exercise(
    id: stringFromJson(json['id'], ''),
    partId: stringFromJson(json['partId'], ''),
    label: stringFromJson(json['label'], ''),
    title: stringFromJson(json['title'], ''),
    summary: stringFromJson(json['summary'], ''),
    category: enumFromName(
      PracticeCategory.values,
      json['category'],
      PracticeCategory.freePlay,
    ),
    tags: [
      for (final name in stringListFromJson(json['tags']))
        ?enumFromNameOrNull(TechniqueTag.values, name),
    ],
    procedure: enumFromName(
      ProcedureType.values,
      json['procedure'],
      ProcedureType.fixedTempo,
    ),
    difficulty: intFromJson(json['difficulty'], 1),
    defaultTempo: intFromJson(json['defaultTempo'], 0),
    minTempo: intFromJson(json['minTempo'], 0),
    maxTempo: intFromJson(json['maxTempo'], 0),
    subdivision: intFromJson(json['subdivision'], 1),
    keyCenter: stringFromJsonOrNull(json['keyCenter']),
    position: stringFromJsonOrNull(json['position']),
    estimatedMinutes: intFromJson(json['estimatedMinutes'], 4),
    bookPage: intFromJson(json['bookPage'], 0),
    cdTrack: json['cdTrack'] is int ? json['cdTrack']! as int : null,
    variants: listFromJson(json['variants'], ExerciseVariant.fromJson),
    tips: stringListFromJson(json['tips']),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One part of the course. Unlocks at [milestone].
@immutable
class CoursePart {
  const CoursePart({
    required this.id,
    required this.order,
    required this.label,
    required this.milestone,
    required this.blurb,
    this.exercises = const [],
  });

  final String id;
  final int order;
  final String label;

  /// The progression level at which this part becomes available.
  final int milestone;

  /// One line describing what the part covers, for the onboarding picker and
  /// the milestone timeline. The app author's own words.
  final String blurb;

  final List<Exercise> exercises;

  Set<PracticeCategory> get categories => {
    for (final exercise in exercises) exercise.category,
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'order': order,
    'label': label,
    'milestone': milestone,
    'blurb': blurb,
    'exercises': [for (final exercise in exercises) exercise.toJson()],
  };

  factory CoursePart.fromJson(Map<String, Object?> json) => CoursePart(
    id: stringFromJson(json['id'], ''),
    order: intFromJson(json['order'], 0),
    label: stringFromJson(json['label'], ''),
    milestone: intFromJson(json['milestone'], 0),
    blurb: stringFromJson(json['blurb'], ''),
    exercises: listFromJson(json['exercises'], Exercise.fromJson),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CoursePart && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
