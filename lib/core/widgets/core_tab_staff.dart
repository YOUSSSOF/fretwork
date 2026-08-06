import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fretwork/core/models/tablature.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// Draws tablature.
///
/// Painted rather than laid out as widgets because a stave is one continuous
/// object: the string lines have to run *behind* the fret numbers with a
/// knockout around each digit, articulation slurs have to arc between two
/// specific notes, and bar lines have to span the exact height of the stave.
/// Expressing that as nested boxes fights the layout system the whole way.
class CoreTabStaff extends StatelessWidget {
  const CoreTabStaff({
    required this.tablature,
    this.stringSpacing = 15,
    this.columnWidth = 26,
    this.showTuning = true,
    super.key,
  });

  final Tablature tablature;

  /// Distance between string lines. 15 is about the smallest that keeps
  /// two-digit frets legible at the app's type scale.
  final double stringSpacing;

  final double columnWidth;
  final bool showTuning;

  static const double _headroom = 26;
  static const double _footroom = 42;
  static const double _gutter = 26;
  static const double _measureGap = 12;

  double get staveHeight => stringSpacing * (kStringCount - 1);

  double get height => staveHeight + _headroom + _footroom;

  double get width {
    final columns = tablature.columnCount;
    final gaps = tablature.measures.length * _measureGap;
    return _gutter + columns * columnWidth + gaps + _gutter;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = CoreText.styleOf(context, CoreTextStyle.caption);
    final fretStyle = CoreText.styleOf(
      context,
      CoreTextStyle.label,
      color: colors.textPrimary,
      tabular: true,
    );
    final markStyle = CoreText.styleOf(
      context,
      CoreTextStyle.caption,
      color: colors.accentStrong,
    );

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _TabPainter(
              tablature: tablature,
              stringSpacing: stringSpacing,
              columnWidth: columnWidth,
              showTuning: showTuning,
              line: colors.border,
              strongLine: colors.textTertiary,
              surface: colors.surface1,
              labelStyle: labelStyle,
              fretStyle: fretStyle,
              markStyle: markStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabPainter extends CustomPainter {
  _TabPainter({
    required this.tablature,
    required this.stringSpacing,
    required this.columnWidth,
    required this.showTuning,
    required this.line,
    required this.strongLine,
    required this.surface,
    required this.labelStyle,
    required this.fretStyle,
    required this.markStyle,
  });

  final Tablature tablature;
  final double stringSpacing;
  final double columnWidth;
  final bool showTuning;
  final Color line;
  final Color strongLine;
  final Color surface;
  final TextStyle labelStyle;
  final TextStyle fretStyle;
  final TextStyle markStyle;

  static const double _headroom = CoreTabStaff._headroom;
  static const double _gutter = CoreTabStaff._gutter;
  static const double _measureGap = CoreTabStaff._measureGap;

  /// Strings are drawn high-to-low down the page, so model string 5 (high e)
  /// is the top line — the way every guitarist reads tab.
  double _yFor(int string) =>
      _headroom + (kStringCount - 1 - string) * stringSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final left = showTuning ? _gutter : Sp.sm;
    final right = size.width - Sp.sm;

    _paintStrings(canvas, left, right);
    if (showTuning) _paintTuning(canvas, left);

    var x = left + Sp.sm;
    for (var m = 0; m < tablature.measures.length; m++) {
      _paintBarLine(canvas, x - Sp.sm / 2);
      final columns = tablature.measures[m].columns;
      final origin = x;
      for (final column in columns) {
        _paintColumn(canvas, column, x);
        x += columnWidth;
      }
      // Rhythm is drawn after the notes so beams sit on top of the stems.
      _paintRhythm(canvas, columns, origin);
      x += _measureGap;
    }
    _paintBarLine(canvas, x - _measureGap, heavy: true);
  }

  void _paintStrings(Canvas canvas, double left, double right) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var string = 0; string < kStringCount; string++) {
      final y = _yFor(string);
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  void _paintTuning(Canvas canvas, double left) {
    for (var string = 0; string < kStringCount; string++) {
      final painter = _text(tablature.tuning[string], labelStyle);
      painter.paint(
        canvas,
        Offset(
          left - painter.width - Sp.xs,
          _yFor(string) - painter.height / 2,
        ),
      );
      painter.dispose();
    }
  }

  void _paintBarLine(Canvas canvas, double x, {bool heavy = false}) {
    canvas.drawLine(
      Offset(x, _yFor(kStringCount - 1)),
      Offset(x, _yFor(0)),
      Paint()
        ..color = heavy ? strongLine : line
        ..strokeWidth = heavy ? 2 : 1,
    );
  }

  void _paintColumn(Canvas canvas, TabColumn column, double x) {
    if (column.palmMuted) {
      final painter = _text('PM', markStyle);
      painter.paint(canvas, Offset(x - painter.width / 2, 2));
      painter.dispose();
    }

    for (final note in column.notes) {
      final y = _yFor(note.string);
      final painter = _text(note.label, fretStyle);
      final centre = Offset(x, y);

      // Knock the string line out behind the digit. Without this the line
      // strikes through the number and two-digit frets become unreadable.
      final knockout = Rect.fromCenter(
        center: centre,
        width: painter.width + 5,
        height: painter.height * 0.82,
      );
      canvas.drawRect(knockout, Paint()..color = surface);

      painter.paint(
        canvas,
        Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2),
      );
      painter.dispose();

      _paintArticulation(canvas, note, centre);
    }
  }

  void _paintArticulation(Canvas canvas, TabNote note, Offset centre) {
    if (note.articulation == TabArticulation.none) return;

    switch (note.articulation) {
      case TabArticulation.hammerOn:
      case TabArticulation.pullOff:
        // A slur arcing back to the previous note, with its letter above.
        final path = Path()
          ..moveTo(centre.dx - columnWidth + 4, centre.dy - 9)
          ..quadraticBezierTo(
            centre.dx - columnWidth / 2,
            centre.dy - 17,
            centre.dx - 4,
            centre.dy - 9,
          );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = markStyle.color!,
        );
        final painter = _text(note.articulation.glyph, markStyle);
        painter.paint(
          canvas,
          Offset(
            centre.dx - columnWidth / 2 - painter.width / 2,
            centre.dy - 26,
          ),
        );
        painter.dispose();

      case TabArticulation.slideUp:
      case TabArticulation.slideDown:
        final rising = note.articulation == TabArticulation.slideUp;
        canvas.drawLine(
          Offset(centre.dx - columnWidth + 5, centre.dy + (rising ? 5 : -5)),
          Offset(centre.dx - 7, centre.dy + (rising ? -5 : 5)),
          Paint()
            ..strokeWidth = 1.4
            ..color = markStyle.color!,
        );

      case TabArticulation.bend:
      case TabArticulation.release:
        // An arrow curving up out of the note, which is how bends read.
        final path = Path()
          ..moveTo(centre.dx + 7, centre.dy - 2)
          ..quadraticBezierTo(
            centre.dx + 14,
            centre.dy - 6,
            centre.dx + 14,
            centre.dy - 15,
          );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = markStyle.color!,
        );
        final head = Path()
          ..moveTo(centre.dx + 14, centre.dy - 19)
          ..lineTo(centre.dx + 11, centre.dy - 14)
          ..lineTo(centre.dx + 17, centre.dy - 14)
          ..close();
        canvas.drawPath(head, Paint()..color = markStyle.color!);

      case TabArticulation.vibrato:
        _paintWave(canvas, centre);

      case TabArticulation.harmonic:
        canvas.drawCircle(
          centre,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = markStyle.color!,
        );

      case TabArticulation.palmMute:
      case TabArticulation.tie:
      case TabArticulation.none:
        break;
    }
  }

  void _paintWave(Canvas canvas, Offset centre) {
    final path = Path()..moveTo(centre.dx - 6, centre.dy - 12);
    for (var i = 0; i < 3; i++) {
      final x = centre.dx - 6 + i * 5;
      path
        ..quadraticBezierTo(x + 1.2, centre.dy - 16, x + 2.5, centre.dy - 12)
        ..quadraticBezierTo(x + 3.8, centre.dy - 8, x + 5, centre.dy - 12);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = markStyle.color!,
    );
  }

  /// The rhythm line under the stave: stems, beams, flags, dots and triplet
  /// brackets. This is what makes it readable as music rather than as a grid
  /// of fret numbers.
  void _paintRhythm(Canvas canvas, List<TabColumn> columns, double origin) {
    if (columns.isEmpty) return;

    final top = _yFor(0) + 8;
    final base = top + 18;
    final paint = Paint()
      ..color = strongLine
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      if (column.isEmpty) continue;
      final x = origin + i * columnWidth;

      if (!column.duration.hasStem) continue;
      canvas.drawLine(Offset(x, top), Offset(x, base), paint);

      if (column.dotted) {
        canvas.drawCircle(
          Offset(x + 4, base - 2),
          1.4,
          Paint()..color = strongLine,
        );
      }

      final flags = column.duration.flags;
      if (flags == 0) continue;

      // Beam to the next column when it carries the same number of flags,
      // otherwise draw free flags. Real engraving beams by beat; this beams by
      // run, which reads correctly for the scale and picking figures this app
      // is used for.
      final next = i + 1 < columns.length ? columns[i + 1] : null;
      final beamsRight =
          next != null && !next.isEmpty && next.duration.flags == flags;

      for (var f = 0; f < flags; f++) {
        final y = base - f * 4;
        if (beamsRight) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x + columnWidth, y),
            paint..strokeWidth = 2.4,
          );
        } else {
          final previous = i > 0 ? columns[i - 1] : null;
          final beamedFromLeft =
              previous != null &&
              !previous.isEmpty &&
              previous.duration.flags == flags;
          if (!beamedFromLeft) {
            // A lone flag, hooked forward off the stem.
            final hook = Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(x + 7, y - 1, x + 6, y - 7);
            canvas.drawPath(
              hook,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..color = strongLine,
            );
          }
        }
      }
      paint.strokeWidth = 1.2;
    }

    _paintTripletBrackets(canvas, columns, origin, base);
  }

  void _paintTripletBrackets(
    Canvas canvas,
    List<TabColumn> columns,
    double origin,
    double base,
  ) {
    var start = -1;
    for (var i = 0; i <= columns.length; i++) {
      final isTriplet = i < columns.length && columns[i].triplet;
      if (isTriplet && start < 0) start = i;
      if (!isTriplet && start >= 0) {
        final from = origin + start * columnWidth;
        final to = origin + (i - 1) * columnWidth;
        final y = base + 8;
        canvas.drawLine(
          Offset(from, y),
          Offset(to, y),
          Paint()
            ..color = markStyle.color!
            ..strokeWidth = 1,
        );
        final painter = _text('3', markStyle);
        final mid = (from + to) / 2;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(mid, y),
            width: painter.width + 4,
            height: painter.height,
          ),
          Paint()..color = surface,
        );
        painter.paint(
          canvas,
          Offset(mid - painter.width / 2, y - painter.height / 2),
        );
        painter.dispose();
        start = -1;
      }
    }
  }

  TextPainter _text(String value, TextStyle style) => TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: ui.TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_TabPainter old) =>
      old.tablature != tablature ||
      old.stringSpacing != stringSpacing ||
      old.columnWidth != columnWidth ||
      old.line != line;
}
