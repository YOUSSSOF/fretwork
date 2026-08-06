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
  static const double _footroom = 20;
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
      for (final column in tablature.measures[m].columns) {
        _paintColumn(canvas, column, x);
        x += columnWidth;
      }
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
