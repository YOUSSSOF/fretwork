import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/utils/date_x.dart';

/// A session frozen mid-flight, so closing the app is not the same as ending
/// the session.
///
/// It carries the whole plan rather than a reference to today's routine: the
/// user may have swapped an exercise while practising, and coming back to a
/// different plan than the one being worked through would be worse than not
/// resuming at all.
@immutable
class SessionSnapshot {
  const SessionSnapshot({
    required this.id,
    required this.routine,
    required this.startedAt,
    required this.savedAt,
    required this.mode,
    required this.blockIndex,
    required this.itemIndex,
    required this.itemElapsed,
    required this.totalElapsed,
    required this.results,
  });

  /// The only key this document is ever stored under — one session at a time.
  static const String storageKey = 'current';

  final String id;
  final RoutineDay routine;
  final DateTime startedAt;

  /// When the snapshot was last stamped, which is what the resume banner
  /// reports rather than the start of the session.
  final DateTime savedAt;

  final TimerMode mode;
  final int blockIndex;
  final int itemIndex;
  final Duration itemElapsed;
  final Duration totalElapsed;
  final List<ItemResult> results;

  /// A session is only worth resuming on the day it was started. Tomorrow has
  /// its own plan, and half of yesterday's routine is not part of it.
  bool isResumableOn(DateTime now) =>
      startedAt.isSameDayAs(now) && routine.allItems.isNotEmpty;

  /// How far through the plan the user got, for the resume prompt.
  int get flatIndex {
    var index = 0;
    for (var b = 0; b < blockIndex && b < routine.blocks.length; b++) {
      index += routine.blocks[b].items.length;
    }
    return index + itemIndex;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'routine': routine.toJson(),
    'startedAt': dateToJson(startedAt),
    'savedAt': dateToJson(savedAt),
    'mode': mode.name,
    'blockIndex': blockIndex,
    'itemIndex': itemIndex,
    'itemElapsedSeconds': itemElapsed.inSeconds,
    'totalElapsedSeconds': totalElapsed.inSeconds,
    'results': [for (final result in results) result.toJson()],
  };

  factory SessionSnapshot.fromJson(Map<String, Object?> json) =>
      SessionSnapshot(
        id: stringFromJson(json['id'], ''),
        routine: RoutineDay.fromJson(asMap(json['routine'])),
        startedAt: dateFromJson(json['startedAt']),
        savedAt: dateFromJson(json['savedAt']),
        mode: enumFromName(TimerMode.values, json['mode'], TimerMode.detailed),
        blockIndex: intFromJson(json['blockIndex'], 0),
        itemIndex: intFromJson(json['itemIndex'], 0),
        itemElapsed: Duration(
          seconds: intFromJson(json['itemElapsedSeconds'], 0),
        ),
        totalElapsed: Duration(
          seconds: intFromJson(json['totalElapsedSeconds'], 0),
        ),
        results: listFromJson(json['results'], ItemResult.fromJson),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSnapshot &&
          other.id == id &&
          other.routine == routine &&
          other.startedAt == startedAt &&
          other.savedAt == savedAt &&
          other.mode == mode &&
          other.blockIndex == blockIndex &&
          other.itemIndex == itemIndex &&
          other.itemElapsed == itemElapsed &&
          other.totalElapsed == totalElapsed &&
          listEquals(other.results, results);

  @override
  int get hashCode => Object.hash(
    id,
    routine,
    startedAt,
    savedAt,
    mode,
    blockIndex,
    itemIndex,
    itemElapsed,
    totalElapsed,
    Object.hashAll(results),
  );
}
