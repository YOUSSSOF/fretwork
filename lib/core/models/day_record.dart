import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/utils/date_x.dart';

enum DayStatus {
  completed,
  partial,
  missed,
  rest,
  upcoming;

  String get label => switch (this) {
    DayStatus.completed => 'Completed',
    DayStatus.partial => 'Partial',
    DayStatus.missed => 'Missed',
    DayStatus.rest => 'Rest',
    DayStatus.upcoming => 'Upcoming',
  };

  /// Rest days neither break a streak nor extend it, and are excluded from
  /// adherence denominators.
  bool get countsTowardAdherence =>
      this != DayStatus.rest && this != DayStatus.upcoming;
}

/// Fraction of planned minutes that counts as "showing up" for streak purposes.
const double kStreakThreshold = 0.60;

/// One record per calendar day, including days with zero practice.
///
/// A missed day is a data point, not the absence of one — the history heat map
/// renders it, and analytics count it.
@immutable
class DayRecord {
  const DayRecord({
    required this.date,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.status,
    required this.milestoneAtTime,
    this.sessionIds = const [],
  });

  final DateTime date;
  final int plannedMinutes;
  final int completedMinutes;
  final DayStatus status;
  final List<String> sessionIds;
  final int milestoneAtTime;

  String get id => date.dayKey;

  double get completionRatio =>
      plannedMinutes <= 0 ? 0 : (completedMinutes / plannedMinutes).clamp(0, 1);

  bool get countsForStreak =>
      status == DayStatus.rest ||
      (plannedMinutes > 0 && completionRatio >= kStreakThreshold);

  /// Derives the status from the minutes actually completed. Kept here so the
  /// session runner and the backfill agree on what "partial" means.
  static DayStatus statusFor({
    required int plannedMinutes,
    required int completedMinutes,
    required bool isRestDay,
  }) {
    if (isRestDay) return DayStatus.rest;
    if (completedMinutes <= 0) return DayStatus.missed;
    if (plannedMinutes <= 0) return DayStatus.completed;
    return completedMinutes / plannedMinutes >= kStreakThreshold
        ? DayStatus.completed
        : DayStatus.partial;
  }

  DayRecord copyWith({
    int? plannedMinutes,
    int? completedMinutes,
    DayStatus? status,
    List<String>? sessionIds,
    int? milestoneAtTime,
  }) => DayRecord(
    date: date,
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    completedMinutes: completedMinutes ?? this.completedMinutes,
    status: status ?? this.status,
    sessionIds: sessionIds ?? this.sessionIds,
    milestoneAtTime: milestoneAtTime ?? this.milestoneAtTime,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'date': dateToJson(date),
    'plannedMinutes': plannedMinutes,
    'completedMinutes': completedMinutes,
    'status': status.name,
    'sessionIds': sessionIds,
    'milestoneAtTime': milestoneAtTime,
  };

  factory DayRecord.fromJson(Map<String, Object?> json) => DayRecord(
    date: dateFromJson(json['date']),
    plannedMinutes: intFromJson(json['plannedMinutes'], 0),
    completedMinutes: intFromJson(json['completedMinutes'], 0),
    status: enumFromName(DayStatus.values, json['status'], DayStatus.missed),
    sessionIds: stringListFromJson(json['sessionIds']),
    milestoneAtTime: intFromJson(json['milestoneAtTime'], 0),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayRecord &&
          other.id == id &&
          other.plannedMinutes == plannedMinutes &&
          other.completedMinutes == completedMinutes &&
          other.status == status &&
          listEquals(other.sessionIds, sessionIds) &&
          other.milestoneAtTime == milestoneAtTime;

  @override
  int get hashCode => Object.hash(
    id,
    plannedMinutes,
    completedMinutes,
    status,
    Object.hashAll(sessionIds),
    milestoneAtTime,
  );
}

@immutable
class ItemResult {
  const ItemResult({
    required this.exerciseId,
    required this.category,
    required this.seconds,
    required this.startTempo,
    required this.endTempo,
    this.variantId,
    this.clean = false,
    this.skipped = false,
  });

  final String exerciseId;
  final String? variantId;
  final PracticeCategory category;
  final int seconds;
  final int startTempo;
  final int endTempo;

  /// The user marked this flawless at [endTempo]. This single flag is what
  /// powers the tempo-progression chart.
  final bool clean;

  final bool skipped;

  String get key => variantId == null ? exerciseId : '$exerciseId:$variantId';

  int get minutes => (seconds / 60).round();

  ItemResult copyWith({
    int? seconds,
    int? endTempo,
    bool? clean,
    bool? skipped,
  }) => ItemResult(
    exerciseId: exerciseId,
    variantId: variantId,
    category: category,
    seconds: seconds ?? this.seconds,
    startTempo: startTempo,
    endTempo: endTempo ?? this.endTempo,
    clean: clean ?? this.clean,
    skipped: skipped ?? this.skipped,
  );

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    if (variantId != null) 'variantId': variantId,
    'category': category.name,
    'seconds': seconds,
    'startTempo': startTempo,
    'endTempo': endTempo,
    'clean': clean,
    'skipped': skipped,
  };

  factory ItemResult.fromJson(Map<String, Object?> json) => ItemResult(
    exerciseId: stringFromJson(json['exerciseId'], ''),
    variantId: stringFromJsonOrNull(json['variantId']),
    category: enumFromName(
      PracticeCategory.values,
      json['category'],
      PracticeCategory.freePlay,
    ),
    seconds: intFromJson(json['seconds'], 0),
    startTempo: intFromJson(json['startTempo'], 0),
    endTempo: intFromJson(json['endTempo'], 0),
    clean: boolFromJson(json['clean'], false),
    skipped: boolFromJson(json['skipped'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemResult &&
          other.exerciseId == exerciseId &&
          other.variantId == variantId &&
          other.category == category &&
          other.seconds == seconds &&
          other.startTempo == startTempo &&
          other.endTempo == endTempo &&
          other.clean == clean &&
          other.skipped == skipped;

  @override
  int get hashCode => Object.hash(
    exerciseId,
    variantId,
    category,
    seconds,
    startTempo,
    endTempo,
    clean,
    skipped,
  );
}

@immutable
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedMinutes,
    required this.actualMinutes,
    required this.items,
    this.abandoned = false,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedMinutes;
  final int actualMinutes;
  final List<ItemResult> items;

  /// Ended early. Partial credit is real credit — analytics treat these as
  /// `partial`, never `missed`.
  final bool abandoned;

  String get dayKey => startedAt.dayKey;

  Map<PracticeCategory, int> get secondsByCategory {
    final totals = <PracticeCategory, int>{};
    for (final item in items) {
      if (item.skipped) continue;
      totals[item.category] = (totals[item.category] ?? 0) + item.seconds;
    }
    return totals;
  }

  SessionRecord copyWith({
    DateTime? endedAt,
    int? actualMinutes,
    List<ItemResult>? items,
    bool? abandoned,
  }) => SessionRecord(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    plannedMinutes: plannedMinutes,
    actualMinutes: actualMinutes ?? this.actualMinutes,
    items: items ?? this.items,
    abandoned: abandoned ?? this.abandoned,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': dateToJson(startedAt),
    'endedAt': dateToJson(endedAt),
    'plannedMinutes': plannedMinutes,
    'actualMinutes': actualMinutes,
    'items': [for (final item in items) item.toJson()],
    'abandoned': abandoned,
  };

  factory SessionRecord.fromJson(Map<String, Object?> json) => SessionRecord(
    id: stringFromJson(json['id'], ''),
    startedAt: dateFromJson(json['startedAt']),
    endedAt: dateFromJson(json['endedAt']),
    plannedMinutes: intFromJson(json['plannedMinutes'], 0),
    actualMinutes: intFromJson(json['actualMinutes'], 0),
    items: listFromJson(json['items'], ItemResult.fromJson),
    abandoned: boolFromJson(json['abandoned'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecord &&
          other.id == id &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.plannedMinutes == plannedMinutes &&
          other.actualMinutes == actualMinutes &&
          listEquals(other.items, items) &&
          other.abandoned == abandoned;

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    plannedMinutes,
    actualMinutes,
    Object.hashAll(items),
    abandoned,
  );
}
