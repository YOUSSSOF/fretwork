import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/utils/date_x.dart';

@immutable
class RoutineItem {
  const RoutineItem({
    required this.exerciseId,
    required this.minutes,
    required this.targetTempo,
    required this.procedure,
    required this.focusNote,
    this.variantId,
  });

  final String exerciseId;

  /// Today's fragment / development, when the exercise has variants.
  final String? variantId;

  final int minutes;
  final int targetTempo;
  final ProcedureType procedure;

  /// One short line of intent for today, e.g. 'Start on an up-stroke'.
  final String focusNote;

  /// Stable identity within a day, since one exercise can appear under two
  /// different variants.
  String get key => variantId == null ? exerciseId : '$exerciseId:$variantId';

  RoutineItem copyWith({int? minutes, int? targetTempo}) => RoutineItem(
    exerciseId: exerciseId,
    variantId: variantId,
    minutes: minutes ?? this.minutes,
    targetTempo: targetTempo ?? this.targetTempo,
    procedure: procedure,
    focusNote: focusNote,
  );

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    if (variantId != null) 'variantId': variantId,
    'minutes': minutes,
    'targetTempo': targetTempo,
    'procedure': procedure.name,
    'focusNote': focusNote,
  };

  factory RoutineItem.fromJson(Map<String, Object?> json) => RoutineItem(
    exerciseId: stringFromJson(json['exerciseId'], ''),
    variantId: stringFromJsonOrNull(json['variantId']),
    minutes: intFromJson(json['minutes'], 0),
    targetTempo: intFromJson(json['targetTempo'], 0),
    procedure: enumFromName(
      ProcedureType.values,
      json['procedure'],
      ProcedureType.fixedTempo,
    ),
    focusNote: stringFromJson(json['focusNote'], ''),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineItem &&
          other.exerciseId == exerciseId &&
          other.variantId == variantId &&
          other.minutes == minutes &&
          other.targetTempo == targetTempo &&
          other.procedure == procedure &&
          other.focusNote == focusNote;

  @override
  int get hashCode => Object.hash(
    exerciseId,
    variantId,
    minutes,
    targetTempo,
    procedure,
    focusNote,
  );
}

@immutable
class RoutineBlock {
  const RoutineBlock({
    required this.category,
    required this.label,
    required this.minutes,
    required this.items,
  });

  final PracticeCategory category;
  final String label;
  final int minutes;
  final List<RoutineItem> items;

  RoutineBlock copyWith({int? minutes, List<RoutineItem>? items}) =>
      RoutineBlock(
        category: category,
        label: label,
        minutes: minutes ?? this.minutes,
        items: items ?? this.items,
      );

  Map<String, Object?> toJson() => {
    'category': category.name,
    'label': label,
    'minutes': minutes,
    'items': [for (final item in items) item.toJson()],
  };

  factory RoutineBlock.fromJson(Map<String, Object?> json) => RoutineBlock(
    category: enumFromName(
      PracticeCategory.values,
      json['category'],
      PracticeCategory.freePlay,
    ),
    label: stringFromJson(json['label'], ''),
    minutes: intFromJson(json['minutes'], 0),
    items: listFromJson(json['items'], RoutineItem.fromJson),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineBlock &&
          other.category == category &&
          other.label == label &&
          other.minutes == minutes &&
          listEquals(other.items, items);

  @override
  int get hashCode =>
      Object.hash(category, label, minutes, Object.hashAll(items));
}

@immutable
class RoutineDay {
  const RoutineDay({
    required this.date,
    required this.milestone,
    required this.plannedMinutes,
    required this.blocks,
    required this.generationSeed,
    required this.generatedAt,
    this.isRestDay = false,
  });

  final DateTime date;
  final int milestone;
  final int plannedMinutes;
  final List<RoutineBlock> blocks;

  /// Makes a day's plan reproducible: the same seed and cursors always yield
  /// the same plan, which is what lets Reshuffle re-roll without corrupting
  /// the rotation.
  final int generationSeed;

  final DateTime generatedAt;
  final bool isRestDay;

  String get id => date.dayKey;

  List<RoutineItem> get allItems => [
    for (final block in blocks) ...block.items,
  ];

  int get itemCount => allItems.length;

  RoutineDay copyWith({
    int? plannedMinutes,
    List<RoutineBlock>? blocks,
    int? generationSeed,
    DateTime? generatedAt,
  }) => RoutineDay(
    date: date,
    milestone: milestone,
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    blocks: blocks ?? this.blocks,
    generationSeed: generationSeed ?? this.generationSeed,
    generatedAt: generatedAt ?? this.generatedAt,
    isRestDay: isRestDay,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'date': dateToJson(date),
    'milestone': milestone,
    'plannedMinutes': plannedMinutes,
    'blocks': [for (final block in blocks) block.toJson()],
    'generationSeed': generationSeed,
    'generatedAt': dateToJson(generatedAt),
    'isRestDay': isRestDay,
  };

  factory RoutineDay.fromJson(Map<String, Object?> json) => RoutineDay(
    date: dateFromJson(json['date']),
    milestone: intFromJson(json['milestone'], 0),
    plannedMinutes: intFromJson(json['plannedMinutes'], 0),
    blocks: listFromJson(json['blocks'], RoutineBlock.fromJson),
    generationSeed: intFromJson(json['generationSeed'], 0),
    generatedAt: dateFromJson(json['generatedAt']),
    isRestDay: boolFromJson(json['isRestDay'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineDay &&
          other.id == id &&
          other.milestone == milestone &&
          other.plannedMinutes == plannedMinutes &&
          listEquals(other.blocks, blocks) &&
          other.generationSeed == generationSeed &&
          other.isRestDay == isRestDay;

  @override
  int get hashCode => Object.hash(
    id,
    milestone,
    plannedMinutes,
    Object.hashAll(blocks),
    generationSeed,
    isRestDay,
  );
}

/// Where a category's round-robin has got to.
@immutable
class RotationCursor {
  const RotationCursor({
    this.exerciseIndex = 0,
    this.variantIndices = const {},
    this.owedMinutes = 0,
    this.sessionsSeen = 0,
  });

  final int exerciseIndex;

  /// Per-exercise variant position, so Example 11's eighteen fragments cycle
  /// rather than restarting every day.
  final Map<String, int> variantIndices;

  /// Minutes a dropped block is owed, prioritised tomorrow.
  final int owedMinutes;

  /// How many sessions have included this category — used to order by
  /// difficulty while the user is new to it.
  final int sessionsSeen;

  RotationCursor copyWith({
    int? exerciseIndex,
    Map<String, int>? variantIndices,
    int? owedMinutes,
    int? sessionsSeen,
  }) => RotationCursor(
    exerciseIndex: exerciseIndex ?? this.exerciseIndex,
    variantIndices: variantIndices ?? this.variantIndices,
    owedMinutes: owedMinutes ?? this.owedMinutes,
    sessionsSeen: sessionsSeen ?? this.sessionsSeen,
  );

  Map<String, Object?> toJson() => {
    'exerciseIndex': exerciseIndex,
    'variantIndices': variantIndices,
    'owedMinutes': owedMinutes,
    'sessionsSeen': sessionsSeen,
  };

  factory RotationCursor.fromJson(Map<String, Object?> json) => RotationCursor(
    exerciseIndex: intFromJson(json['exerciseIndex'], 0),
    variantIndices: {
      for (final entry in asMap(json['variantIndices']).entries)
        entry.key: intFromJson(entry.value, 0),
    },
    owedMinutes: intFromJson(json['owedMinutes'], 0),
    sessionsSeen: intFromJson(json['sessionsSeen'], 0),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationCursor &&
          other.exerciseIndex == exerciseIndex &&
          mapEquals(other.variantIndices, variantIndices) &&
          other.owedMinutes == owedMinutes &&
          other.sessionsSeen == sessionsSeen;

  @override
  int get hashCode => Object.hash(
    exerciseIndex,
    Object.hashAllUnordered(variantIndices.entries.map((e) => e.key)),
    owedMinutes,
    sessionsSeen,
  );
}
