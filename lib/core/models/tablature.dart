import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';

/// Standard tuning, low string first. Index 0 is the 6th string.
const List<String> kStandardTuning = ['E', 'A', 'D', 'G', 'B', 'e'];

const int kStringCount = 6;

/// Articulations a tab can mark between or on notes.
enum TabArticulation {
  none,
  hammerOn,
  pullOff,
  slideUp,
  slideDown,
  bend,
  release,
  vibrato,
  palmMute,
  harmonic,
  tie;

  /// The glyph drawn above the note. Empty where the mark is a line or a
  /// bracket rather than a letter.
  String get glyph => switch (this) {
    TabArticulation.none => '',
    TabArticulation.hammerOn => 'h',
    TabArticulation.pullOff => 'p',
    TabArticulation.slideUp => '/',
    TabArticulation.slideDown => r'\',
    TabArticulation.bend => 'b',
    TabArticulation.release => 'r',
    TabArticulation.vibrato => '~',
    TabArticulation.palmMute => 'PM',
    TabArticulation.harmonic => '◇',
    TabArticulation.tie => '_',
  };

  static TabArticulation fromSymbol(String symbol) => switch (symbol) {
    'h' || 'H' => TabArticulation.hammerOn,
    'p' || 'P' => TabArticulation.pullOff,
    '/' => TabArticulation.slideUp,
    r'\' => TabArticulation.slideDown,
    'b' || 'B' => TabArticulation.bend,
    'r' || 'R' => TabArticulation.release,
    '~' => TabArticulation.vibrato,
    '*' || '◇' => TabArticulation.harmonic,
    _ => TabArticulation.none,
  };
}

/// One fretted note on one string.
@immutable
class TabNote {
  const TabNote({
    required this.string,
    required this.fret,
    this.articulation = TabArticulation.none,
    this.muted = false,
  });

  /// 0 is the low E (6th string), 5 is the high e (1st).
  final int string;

  /// Fret number. 0 is an open string.
  final int fret;

  /// How this note is joined to the one before it on the same string.
  final TabArticulation articulation;

  /// A dead note — 'x' in ASCII tab.
  final bool muted;

  String get label => muted ? 'x' : '$fret';

  Map<String, Object?> toJson() => {
    'string': string,
    'fret': fret,
    if (articulation != TabArticulation.none) 'articulation': articulation.name,
    if (muted) 'muted': true,
  };

  factory TabNote.fromJson(Map<String, Object?> json) => TabNote(
    string: intFromJson(json['string'], 0).clamp(0, kStringCount - 1),
    fret: intFromJson(json['fret'], 0).clamp(0, 30),
    articulation: enumFromName(
      TabArticulation.values,
      json['articulation'],
      TabArticulation.none,
    ),
    muted: boolFromJson(json['muted'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabNote &&
          other.string == string &&
          other.fret == fret &&
          other.articulation == articulation &&
          other.muted == muted;

  @override
  int get hashCode => Object.hash(string, fret, articulation, muted);
}

/// How long a column lasts.
///
/// ASCII tab cannot express this at all, which is the single biggest reason it
/// reads worse than engraved tab: without stems and beams you cannot tell a
/// run of sixteenths from a run of quarters.
enum TabDuration {
  whole(4, 0),
  half(2, 0),
  quarter(1, 0),
  eighth(0.5, 1),
  sixteenth(0.25, 2),
  thirtySecond(0.125, 3);

  const TabDuration(this.beats, this.flags);

  /// Length in quarter-note beats.
  final double beats;

  /// Number of beams or flags drawn on the stem.
  final int flags;

  String get label => switch (this) {
    TabDuration.whole => 'whole',
    TabDuration.half => 'half',
    TabDuration.quarter => '1/4',
    TabDuration.eighth => '1/8',
    TabDuration.sixteenth => '1/16',
    TabDuration.thirtySecond => '1/32',
  };

  /// Stems are only drawn from a half note down; a whole note has none.
  bool get hasStem => this != TabDuration.whole;
}

/// Everything sounding at one point in time — one note, or a chord.
@immutable
class TabColumn {
  const TabColumn({
    this.notes = const [],
    this.palmMuted = false,
    this.duration = TabDuration.eighth,
    this.dotted = false,
    this.triplet = false,
  });

  final List<TabNote> notes;
  final bool palmMuted;
  final TabDuration duration;

  /// Adds half again to the length.
  final bool dotted;

  /// Part of a triplet grouping — three in the space of two.
  final bool triplet;

  bool get isEmpty => notes.isEmpty;

  double get beats {
    var value = duration.beats;
    if (dotted) value *= 1.5;
    if (triplet) value *= 2 / 3;
    return value;
  }

  TabColumn copyWith({
    List<TabNote>? notes,
    bool? palmMuted,
    TabDuration? duration,
    bool? dotted,
    bool? triplet,
  }) => TabColumn(
    notes: notes ?? this.notes,
    palmMuted: palmMuted ?? this.palmMuted,
    duration: duration ?? this.duration,
    dotted: dotted ?? this.dotted,
    triplet: triplet ?? this.triplet,
  );

  Map<String, Object?> toJson() => {
    'notes': [for (final note in notes) note.toJson()],
    if (palmMuted) 'palmMuted': true,
    'duration': duration.name,
    if (dotted) 'dotted': true,
    if (triplet) 'triplet': true,
  };

  factory TabColumn.fromJson(Map<String, Object?> json) => TabColumn(
    notes: listFromJson(json['notes'], TabNote.fromJson),
    palmMuted: boolFromJson(json['palmMuted'], false),
    duration: enumFromName(
      TabDuration.values,
      json['duration'],
      TabDuration.eighth,
    ),
    dotted: boolFromJson(json['dotted'], false),
    triplet: boolFromJson(json['triplet'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabColumn &&
          listEquals(other.notes, notes) &&
          other.palmMuted == palmMuted &&
          other.duration == duration &&
          other.dotted == dotted &&
          other.triplet == triplet;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(notes), palmMuted, duration, dotted, triplet);
}

@immutable
class TabMeasure {
  const TabMeasure({this.columns = const [], this.repeat = false});

  final List<TabColumn> columns;
  final bool repeat;

  Map<String, Object?> toJson() => {
    'columns': [for (final column in columns) column.toJson()],
    if (repeat) 'repeat': true,
  };

  factory TabMeasure.fromJson(Map<String, Object?> json) => TabMeasure(
    columns: listFromJson(json['columns'], TabColumn.fromJson),
    repeat: boolFromJson(json['repeat'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabMeasure &&
          listEquals(other.columns, columns) &&
          other.repeat == repeat;

  @override
  int get hashCode => Object.hash(Object.hashAll(columns), repeat);
}

/// A transcription the user has entered for one exercise or variant.
///
/// **User content only.** Nothing ships with the app: the curriculum seed
/// carries page pointers, not notation (§0). This is where someone stores
/// their own transcription of material they own.
@immutable
class Tablature {
  const Tablature({
    required this.key,
    required this.measures,
    this.tuning = kStandardTuning,
    this.title = '',
    this.updatedAt,
  });

  /// `exerciseId` or `exerciseId:variantId`, matching `RoutineItem.key`.
  final String key;

  final List<TabMeasure> measures;
  final List<String> tuning;
  final String title;
  final DateTime? updatedAt;

  bool get isEmpty => measures.every((m) => m.columns.isEmpty);

  int get columnCount =>
      measures.fold<int>(0, (sum, m) => sum + m.columns.length);

  int get noteCount => measures.fold<int>(
    0,
    (sum, m) => sum + m.columns.fold<int>(0, (s, c) => s + c.notes.length),
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'title': title,
    'tuning': tuning,
    'measures': [for (final measure in measures) measure.toJson()],
    if (updatedAt != null) 'updatedAt': dateToJson(updatedAt!),
  };

  factory Tablature.fromJson(Map<String, Object?> json) {
    final tuning = stringListFromJson(json['tuning']);
    return Tablature(
      key: stringFromJson(json['key'], ''),
      title: stringFromJson(json['title'], ''),
      tuning: tuning.length == kStringCount ? tuning : kStandardTuning,
      measures: listFromJson(json['measures'], TabMeasure.fromJson),
      updatedAt: dateFromJsonOrNull(json['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tablature &&
          other.key == key &&
          other.title == title &&
          listEquals(other.tuning, tuning) &&
          listEquals(other.measures, measures);

  @override
  int get hashCode =>
      Object.hash(key, title, Object.hashAll(tuning), Object.hashAll(measures));
}
