import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';
import 'package:fretwork/features/analytics/export/report_copy.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Everything the report needs, gathered once so the builder itself stays a
/// pure function of its input.
class ReportData {
  const ReportData({
    required this.summary,
    required this.score,
    required this.days,
    required this.exercises,
    required this.startedAt,
    required this.generatedAt,
    required this.milestone,
    required this.parts,
  });

  final AnalyticsSummary summary;
  final DisciplineScore score;
  final List<DayRecord> days;
  final Map<String, Exercise> exercises;
  final DateTime startedAt;
  final DateTime generatedAt;
  final int milestone;
  final List<CoursePart> parts;
}

/// Builds the A4 report.
///
/// Charts are drawn with the pdf package's own primitives rather than by
/// screenshotting widgets, so the output is vector and stays legible at any
/// zoom — and the report can be generated without a rendered UI at all, which
/// is what makes it testable.
Future<pw.Document> buildPracticeReport(ReportData data) async {
  final theme = await _theme();
  final copy = buildReportCopy(
    summary: data.summary,
    score: data.score,
    exerciseLabel: (id) => data.exercises[id]?.label ?? id,
  );

  final document = pw.Document(
    title: 'Fretwork practice report',
    author: 'Fretwork',
    theme: theme,
  );

  document.addPage(_coverPage(data, copy, theme));
  document.addPage(_summaryPage(data, copy, theme));
  document.addPage(_categoryPage(data, theme));
  document.addPage(_tempoPage(data, theme));
  document.addPage(_consistencyPage(data, theme));
  document.addPage(_milestonePage(data, theme));

  return document;
}

/// The embedded face.
///
/// Explicitly bundled rather than relying on the pdf package's built-in
/// Helvetica, which is Latin-1 only: the report already contains an em dash and
/// a middot, and if the UI is ever localised the default would silently drop
/// every non-Latin glyph.
Future<pw.ThemeData> _theme() async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );
  return pw.ThemeData.withFont(base: regular, bold: bold);
}

const PdfColor _ink = PdfColor.fromInt(0xFF16110F);
const PdfColor _muted = PdfColor.fromInt(0xFF6B625F);
const PdfColor _rule = PdfColor.fromInt(0xFFDDD6D3);
const PdfColor _accent = PdfColor.fromInt(0xFF8B1E24);
const PdfColor _accentSoft = PdfColor.fromInt(0xFFE7CFD0);

pw.TextStyle _h1 = const pw.TextStyle(fontSize: 26, color: _ink);
pw.TextStyle _h2 = const pw.TextStyle(fontSize: 15, color: _ink);
pw.TextStyle _body = const pw.TextStyle(fontSize: 10.5, color: _ink);
pw.TextStyle _small = const pw.TextStyle(fontSize: 8.5, color: _muted);

pw.Widget _sectionTitle(String text) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(text, style: _h2.copyWith(fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
    pw.Container(width: 48, height: 2, color: _accent),
    pw.SizedBox(height: 12),
  ],
);

pw.Page _page(pw.ThemeData theme, List<pw.Widget> children) => pw.Page(
  pageFormat: PdfPageFormat.a4,
  theme: theme,
  margin: const pw.EdgeInsets.fromLTRB(42, 48, 42, 48),
  build: (context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: children,
  ),
);

pw.Page _coverPage(ReportData data, ReportCopy copy, pw.ThemeData theme) {
  final window = data.summary.window;
  return _page(theme, [
    pw.Text('Fretwork', style: _h1.copyWith(fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
    pw.Text('Practice report', style: _body.copyWith(color: _muted)),
    pw.SizedBox(height: 32),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _scoreRing(data.score),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                data.score.grade.label,
                style: _h1.copyWith(fontSize: 20),
              ),
              pw.SizedBox(height: 6),
              pw.Text(copy.closingLine, style: _body),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 32),
    pw.Text(copy.headline, style: _body.copyWith(fontSize: 12)),
    pw.SizedBox(height: 24),
    pw.Divider(color: _rule),
    pw.SizedBox(height: 12),
    _keyValue('Practising since', data.startedAt.shortDayLabel),
    _keyValue(
      'Range covered',
      '${window.from.shortDayLabel} — ${window.to.shortDayLabel}',
    ),
    _keyValue('Course milestone', '${data.milestone} of 10'),
    _keyValue('Generated', data.generatedAt.shortDayLabel),
  ]);
}

pw.Page _summaryPage(ReportData data, ReportCopy copy, pw.ThemeData theme) {
  final summary = data.summary;
  return _page(theme, [
    _sectionTitle('Summary'),
    pw.Text(copy.durationLine, style: _body),
    if (copy.progressLine != null) ...[
      pw.SizedBox(height: 8),
      pw.Text(copy.progressLine!, style: _body),
    ],
    pw.SizedBox(height: 24),
    pw.Table(
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: _rule),
      ),
      children: [
        _statRow('Total minutes', '${summary.totalMinutes}'),
        _statRow('Planned minutes', '${summary.plannedMinutes}'),
        _statRow(
          'Sessions',
          '${summary.completedSessions} completed, '
              '${summary.abandonedSessions} ended early',
        ),
        _statRow('Practice days', '${summary.practiceDays}'),
        _statRow('Missed days', '${summary.missedDays}'),
        _statRow('Rest days', '${summary.restDays}'),
        _statRow('Current streak', '${summary.currentStreak}'),
        _statRow('Longest streak', '${summary.longestStreak}'),
        _statRow('Adherence', '${(summary.adherence * 100).round()}%'),
        _statRow('Consistency', '${(summary.consistency * 100).round()}%'),
      ],
    ),
  ]);
}

pw.Page _categoryPage(ReportData data, pw.ThemeData theme) {
  final entries =
      data.summary.minutesByCategory.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final max = entries.isEmpty
      ? 1
      : entries.map((e) => e.value).reduce(math.max);

  return _page(theme, [
    _sectionTitle('Where the time went'),
    if (entries.isEmpty)
      pw.Text('Nothing logged in this range.', style: _body)
    else
      for (final entry in entries)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(entry.key.label, style: _body),
              ),
              pw.Expanded(
                // Two flex children rather than a fractional box: the pdf
                // package has no FractionallySizedBox, and flex weights give
                // the same proportional bar without measuring anything.
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: entry.value,
                      child: pw.Container(height: 10, color: _accent),
                    ),
                    pw.Expanded(
                      flex: math.max(1, max - entry.value),
                      child: pw.Container(height: 10, color: _accentSoft),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                width: 54,
                child: pw.Text(
                  '${entry.value} min',
                  style: _small,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
  ]);
}

pw.Page _tempoPage(ReportData data, pw.ThemeData theme) {
  final progress = data.summary.tempoProgress;
  return _page(theme, [
    _sectionTitle('Tempo progress'),
    if (progress.isEmpty)
      pw.Text(
        'No exercise has two or more clean tempo points in this range, so '
        'there is nothing to compare yet.',
        style: _body,
      )
    else
      pw.Table(
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: _rule),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            children: [
              _cell('Exercise', bold: true),
              _cell('Start', bold: true),
              _cell('Best', bold: true),
              _cell('Delta', bold: true),
              _cell('Trend', bold: true),
            ],
          ),
          for (final row in progress)
            pw.TableRow(
              children: [
                _cell(data.exercises[row.exerciseId]?.label ?? row.exerciseId),
                _cell('${row.startBpm}'),
                _cell('${row.bestBpm}'),
                _cell('${row.delta >= 0 ? '+' : ''}${row.delta}'),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: _sparkline(row),
                ),
              ],
            ),
        ],
      ),
  ]);
}

pw.Page _consistencyPage(ReportData data, pw.ThemeData theme) {
  final window = data.summary.window;
  final byKey = {for (final day in data.days) day.date.dayKey: day};
  final months = <DateTime>{
    for (final date in daysBetween(window.from, window.to))
      DateTime(date.year, date.month),
  }.toList()..sort();

  return _page(theme, [
    _sectionTitle('Consistency'),
    pw.Text(
      'Filled squares are days you practised, outlined squares are days you '
      'did not, and grey squares are rest days. Missed days are shown rather '
      'than left blank — they are part of the record.',
      style: _small,
    ),
    pw.SizedBox(height: 16),
    for (final month in months.take(4)) ...[
      pw.Text(month.monthLabel, style: _body.copyWith(color: _muted)),
      pw.SizedBox(height: 6),
      _monthGrid(month, byKey, window),
      pw.SizedBox(height: 16),
    ],
  ]);
}

pw.Page _milestonePage(ReportData data, pw.ThemeData theme) => _page(theme, [
  _sectionTitle('Course progress'),
  pw.Text(
    'Milestone ${data.milestone} of 10. Parts at or below your milestone are '
    'in the routine; the rest unlock as you work through them.',
    style: _body,
  ),
  pw.SizedBox(height: 16),
  for (final part in data.parts)
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8,
            height: 8,
            color: part.milestone <= data.milestone ? _accent : _rule,
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(part.label, style: _body)),
          pw.Text(
            part.milestone <= data.milestone ? 'unlocked' : 'locked',
            style: _small,
          ),
        ],
      ),
    ),
]);

pw.Widget _scoreRing(DisciplineScore score) => pw.Container(
  width: 96,
  height: 96,
  child: pw.Stack(
    alignment: pw.Alignment.center,
    children: [
      pw.CircularProgressIndicator(
        value: score.score / 100,
        color: _accent,
        backgroundColor: _accentSoft,
        strokeWidth: 8,
        // Drawn as vector, so it stays crisp however far the reader zooms.
      ),
      pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            '${score.score}',
            style: _h1.copyWith(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('/ 100', style: _small),
        ],
      ),
    ],
  ),
);

pw.Widget _sparkline(TempoProgress row) {
  final rise = row.delta <= 0 ? 0.0 : 1.0;
  return pw.SizedBox(
    height: 14,
    child: pw.CustomPaint(
      painter: (canvas, size) {
        canvas
          ..setStrokeColor(_accent)
          ..setLineWidth(1.2)
          ..moveTo(0, 2)
          ..lineTo(size.x, 2 + (size.y - 4) * rise)
          ..strokePath();
      },
    ),
  );
}

pw.Widget _monthGrid(
  DateTime month,
  Map<String, DayRecord> byKey,
  DateWindow window,
) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  return pw.Wrap(
    spacing: 3,
    runSpacing: 3,
    children: [
      for (var day = 1; day <= daysInMonth; day++)
        _daySquare(DateTime(month.year, month.month, day), byKey, window),
    ],
  );
}

pw.Widget _daySquare(
  DateTime date,
  Map<String, DayRecord> byKey,
  DateWindow window,
) {
  if (!window.contains(date)) {
    return pw.SizedBox(width: 12, height: 12);
  }
  final record = byKey[date.dayKey];
  final (PdfColor fill, PdfColor border) = switch (record?.status) {
    DayStatus.completed => (_accent, _accent),
    DayStatus.partial => (_accentSoft, _accent),
    DayStatus.rest => (_rule, _rule),
    _ => (PdfColors.white, _accent),
  };
  return pw.Container(
    width: 12,
    height: 12,
    decoration: pw.BoxDecoration(
      color: fill,
      border: pw.Border.all(color: border, width: 0.6),
    ),
  );
}

pw.Widget _keyValue(String key, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Row(
    children: [
      pw.SizedBox(width: 140, child: pw.Text(key, style: _small)),
      pw.Text(value, style: _body),
    ],
  ),
);

pw.TableRow _statRow(String label, String value) =>
    pw.TableRow(children: [_cell(label), _cell(value)]);

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  child: pw.Text(
    text,
    style: bold ? _body.copyWith(fontWeight: pw.FontWeight.bold) : _body,
  ),
);
