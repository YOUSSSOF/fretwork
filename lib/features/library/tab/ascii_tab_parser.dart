import 'package:flutter/foundation.dart';
import 'package:fretwork/core/models/tablature.dart';

/// Parses ASCII tablature into a [Tablature].
///
/// ASCII tab is the format every guitarist can already type, and the one every
/// source they legitimately have will be in, so it is the input rather than a
/// bespoke syntax nobody knows:
///
/// ```
/// e|-----------------|
/// B|-----------------|
/// G|-----------------|
/// D|-------5-7-------|
/// A|---5-7-----------|
/// E|-8---------------|
/// ```
///
/// Handled: two-digit frets, dead notes (`x`), chords (notes in the same
/// column), bar lines, and the usual articulation marks between notes
/// (`h p / \ b r ~`). Rhythm is not encoded in ASCII tab at all, so columns
/// are laid out evenly — which is exactly how ASCII tab reads on paper.
@immutable
class TabParseResult {
  const TabParseResult.success(this.tablature)
    : errors = const [],
      warnings = const [];

  const TabParseResult.failure(this.errors)
    : tablature = null,
      warnings = const [];

  const TabParseResult.partial(this.tablature, this.warnings)
    : errors = const [];

  final Tablature? tablature;
  final List<String> errors;
  final List<String> warnings;

  bool get isSuccess => tablature != null;
}

/// Whether a line looks like one string of a stave.
///
/// Counting dashes rather than matching a shape: tab in the wild starts with
/// a note as often as a dash, uses `|`, `:` or nothing before the first
/// column, and labels strings with anything from `e` to `D#`. Three or more
/// dashes is the one thing every stave line has and no sentence does.
bool _looksLikeStringLine(String line) {
  var dashes = 0;
  for (final unit in line.codeUnits) {
    if (unit == 0x2D || unit == 0x2013 || unit == 0x2014) dashes++;
    if (dashes >= 3) return true;
  }
  return false;
}

TabParseResult parseAsciiTab(String input, {required String key}) {
  final rawLines = input
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList();

  if (rawLines.isEmpty) {
    return const TabParseResult.failure(['There is nothing to parse.']);
  }

  final staveLines = [
    for (final line in rawLines)
      if (_looksLikeStringLine(line)) line,
  ];

  if (staveLines.length < kStringCount) {
    return TabParseResult.failure([
      'Expected six string lines but found ${staveLines.length}. Each line '
          'should start with the string name and contain dashes, like '
          '"E|-8---5---".',
    ]);
  }
  if (staveLines.length % kStringCount != 0) {
    return TabParseResult.failure([
      '${staveLines.length} string lines is not a whole number of six-string '
          'staves. Check for a missing or duplicated line.',
    ]);
  }

  final warnings = <String>[];
  final measures = <TabMeasure>[];
  List<String>? tuning;

  // Each block of six lines is one system, read left to right.
  for (var block = 0; block < staveLines.length ~/ kStringCount; block++) {
    final lines = staveLines.sublist(
      block * kStringCount,
      (block + 1) * kStringCount,
    );

    final labels = <String>[];
    final bodies = <String>[];
    for (final line in lines) {
      final split = _splitLabel(line);
      labels.add(split.$1);
      bodies.add(split.$2);
    }

    // ASCII tab is written high string first; the model stores low string
    // first, so the rows are flipped once here rather than everywhere else.
    final flippedLabels = labels.reversed.toList();
    final flippedBodies = bodies.reversed.toList();
    tuning ??= _resolveTuning(flippedLabels);

    final width = flippedBodies
        .map((b) => b.length)
        .reduce((a, b) => a > b ? a : b);
    final padded = [
      for (final body in flippedBodies) body.padRight(width, '-'),
    ];

    measures.addAll(_parseSystem(padded, width, warnings));
  }

  if (measures.every((m) => m.columns.isEmpty)) {
    return const TabParseResult.failure([
      'No notes found. Fret numbers go on the dashes, like "E|-8---5---".',
    ]);
  }

  final tablature = Tablature(
    key: key,
    measures: measures,
    tuning: tuning ?? kStandardTuning,
  );
  return warnings.isEmpty
      ? TabParseResult.success(tablature)
      : TabParseResult.partial(tablature, warnings);
}

/// Splits `E|---5---` into its label and its body.
(String, String) _splitLabel(String line) {
  final bar = line.indexOf(RegExp(r'[|:]'));
  final dash = line.indexOf(RegExp('[-–—]'));
  final cut = bar >= 0 && (dash < 0 || bar < dash) ? bar + 1 : dash;
  if (cut <= 0) return ('', line);
  return (
    line.substring(0, cut).replaceAll(RegExp(r'[|:\s]'), ''),
    line.substring(cut),
  );
}

List<String> _resolveTuning(List<String> labels) {
  final cleaned = [
    for (final label in labels)
      if (label.isEmpty) '' else label,
  ];
  if (cleaned.any((l) => l.isEmpty)) return kStandardTuning;
  return cleaned;
}

List<TabMeasure> _parseSystem(
  List<String> rows,
  int width,
  List<String> warnings,
) {
  final measures = <TabMeasure>[];
  var columns = <TabColumn>[];
  var palmMuted = false;

  var x = 0;
  while (x < width) {
    // A bar line in any row ends the measure.
    if (rows.any((row) => row[x] == '|')) {
      if (columns.isNotEmpty) {
        measures.add(TabMeasure(columns: columns));
        columns = <TabColumn>[];
      }
      x++;
      continue;
    }

    final notes = <TabNote>[];
    var consumed = 1;

    for (var string = 0; string < kStringCount; string++) {
      final row = rows[string];
      final char = row[x];

      if (char == 'x' || char == 'X') {
        notes.add(TabNote(string: string, fret: 0, muted: true));
        continue;
      }
      if (!_isDigit(char)) continue;

      // Two-digit frets: look ahead one character.
      var text = char;
      if (x + 1 < width && _isDigit(row[x + 1])) {
        text += row[x + 1];
        consumed = 2;
      }
      final fret = int.tryParse(text);
      if (fret == null || fret > 30) {
        warnings.add('Ignored an unreadable fret number "$text".');
        continue;
      }

      notes.add(
        TabNote(
          string: string,
          fret: fret,
          articulation: _articulationBefore(row, x),
        ),
      );
    }

    if (rows.any((row) => row[x] == 'P')) palmMuted = true;
    if (notes.isNotEmpty) {
      columns.add(TabColumn(notes: notes, palmMuted: palmMuted));
    }
    x += consumed;
  }

  if (columns.isNotEmpty) measures.add(TabMeasure(columns: columns));
  return measures;
}

/// The mark immediately to the left of a note, which is where ASCII tab puts
/// the articulation joining it to the previous note.
TabArticulation _articulationBefore(String row, int x) {
  if (x == 0) return TabArticulation.none;
  return TabArticulation.fromSymbol(row[x - 1]);
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

/// Renders a [Tablature] back to ASCII, for editing what was already parsed.
String toAsciiTab(Tablature tablature) {
  final rows = List.generate(kStringCount, (_) => StringBuffer());

  for (var m = 0; m < tablature.measures.length; m++) {
    for (final row in rows) {
      row.write('|-');
    }
    for (final column in tablature.measures[m].columns) {
      final labels = List.filled(kStringCount, '-');
      for (final note in column.notes) {
        labels[note.string] = note.label;
      }
      final width = labels.map((l) => l.length).reduce((a, b) => a > b ? a : b);
      for (var s = 0; s < kStringCount; s++) {
        rows[s].write(labels[s].padRight(width, '-'));
        rows[s].write('-');
      }
    }
  }
  for (final row in rows) {
    row.write('|');
  }

  // Back to high-string-first for display.
  return [
    for (var s = kStringCount - 1; s >= 0; s--)
      '${tablature.tuning[s].padRight(2)}${rows[s]}',
  ].join('\n');
}
