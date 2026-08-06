import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';

/// A painter-based progress ring supporting two concentric arcs.
///
/// In the session runner the outer arc is the whole session and the inner arc
/// is the current block, so the user can read both without doing arithmetic.
/// It is driven by an [Animation] rather than rebuilt from a per-second stream:
/// the ring stays at 60 fps while the numeric readout beside it ticks at 1 Hz.
class CoreProgressRing extends StatelessWidget {
  const CoreProgressRing({
    required this.progress,
    this.secondaryProgress,
    this.size = 220,
    this.strokeWidth = 10,
    this.secondaryStrokeWidth = 4,
    this.center,
    this.trackColor,
    this.color,
    this.secondaryColor,
    super.key,
  });

  /// 0..1. Pass an [Animation]-backed value so the ring interpolates rather
  /// than stepping.
  final double progress;
  final double? secondaryProgress;
  final double size;
  final double strokeWidth;
  final double secondaryStrokeWidth;
  final Widget? center;
  final Color? trackColor;
  final Color? color;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1),
          secondaryProgress: secondaryProgress?.clamp(0, 1),
          strokeWidth: strokeWidth,
          secondaryStrokeWidth: secondaryStrokeWidth,
          track: trackColor ?? colors.border,
          gradient: colors.accentGradientBright,
          solid: color ?? colors.accentStrong,
          secondary: secondaryColor ?? colors.textTertiary,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.secondaryProgress,
    required this.strokeWidth,
    required this.secondaryStrokeWidth,
    required this.track,
    required this.gradient,
    required this.solid,
    required this.secondary,
  });

  final double progress;
  final double? secondaryProgress;
  final double strokeWidth;
  final double secondaryStrokeWidth;
  final Color track;
  final Gradient gradient;
  final Color solid;
  final Color secondary;

  static const double _startAngle = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(outerRect, 0, math.pi * 2, false, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [gradient.colors.first, gradient.colors.last],
          transform: const GradientRotation(_startAngle),
        ).createShader(outerRect);
      canvas.drawArc(
        outerRect,
        _startAngle,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }

    final inner = secondaryProgress;
    if (inner == null) return;

    final gap = strokeWidth + 6;
    final innerRect = Rect.fromLTWH(
      gap + secondaryStrokeWidth / 2,
      gap + secondaryStrokeWidth / 2,
      size.width - 2 * gap - secondaryStrokeWidth,
      size.height - 2 * gap - secondaryStrokeWidth,
    );
    if (innerRect.width <= 0 || innerRect.height <= 0) return;

    canvas.drawArc(
      innerRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = secondaryStrokeWidth
        ..color = track,
    );
    if (inner > 0) {
      canvas.drawArc(
        innerRect,
        _startAngle,
        math.pi * 2 * inner,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = secondaryStrokeWidth
          ..strokeCap = StrokeCap.round
          ..color = secondary,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.secondaryProgress != secondaryProgress ||
      old.solid != solid ||
      old.track != track;
}
