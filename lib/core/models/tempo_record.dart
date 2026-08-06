import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';

@immutable
class TempoPoint {
  const TempoPoint({required this.date, required this.bpm, this.clean = false});

  final DateTime date;
  final int bpm;

  /// The user marked this tempo flawless. Only clean points drive the
  /// progression chart and the discipline score's tempo term — an unclean
  /// point records that a tempo was attempted, not that it was reached.
  final bool clean;

  Map<String, Object?> toJson() => {
    'date': dateToJson(date),
    'bpm': bpm,
    'clean': clean,
  };

  factory TempoPoint.fromJson(Map<String, Object?> json) => TempoPoint(
    date: dateFromJson(json['date']),
    bpm: intFromJson(json['bpm'], 0),
    clean: boolFromJson(json['clean'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TempoPoint &&
          other.date == date &&
          other.bpm == bpm &&
          other.clean == clean;

  @override
  int get hashCode => Object.hash(date, bpm, clean);
}

/// Append-only tempo history for one exercise.
@immutable
class TempoRecord {
  const TempoRecord({required this.exerciseId, this.points = const []});

  final String exerciseId;
  final List<TempoPoint> points;

  List<TempoPoint> get cleanPoints => [
    for (final point in points)
      if (point.clean) point,
  ];

  int get bestCleanTempo {
    var best = 0;
    for (final point in points) {
      if (point.clean && point.bpm > best) best = point.bpm;
    }
    return best;
  }

  /// The tempo the exercise should open at next time. Uses the most recent
  /// point of any kind, so a tempo the user backed off to is respected.
  int get lastTempo => points.isEmpty ? 0 : points.last.bpm;

  TempoRecord append(TempoPoint point) =>
      TempoRecord(exerciseId: exerciseId, points: [...points, point]);

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'points': [for (final point in points) point.toJson()],
  };

  factory TempoRecord.fromJson(Map<String, Object?> json) => TempoRecord(
    exerciseId: stringFromJson(json['exerciseId'], ''),
    points: listFromJson(json['points'], TempoPoint.fromJson),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TempoRecord &&
          other.exerciseId == exerciseId &&
          listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(exerciseId, Object.hashAll(points));
}
