import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_animated_number.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';

/// A rotary tempo control.
///
/// Rotary rather than a slider because the range is 220 bpm wide and a slider
/// that fits a phone would give roughly two bpm per pixel. Dragging round the
/// dial gives as much travel as the user wants.
///
/// Past either limit the dial goes rubber-band: further drag still moves the
/// needle, at a fifth of the rate, and it snaps back on release. A control that
/// simply stops dead feels broken; one that resists feels bounded.
class MetronomeDial extends StatefulWidget {
  const MetronomeDial({
    required this.state,
    required this.onTempoChanged,
    this.size = 200,
    super.key,
  });

  final MetronomeState state;
  final ValueChanged<int> onTempoChanged;
  final double size;

  /// Degrees of rotation per bpm.
  static const double degreesPerBpm = 2.4;

  /// How much of a drag past the limit actually counts.
  static const double rubberBandFactor = 0.2;

  @override
  State<MetronomeDial> createState() => _MetronomeDialState();
}

class _MetronomeDialState extends State<MetronomeDial> {
  double _accumulated = 0;
  double _overshoot = 0;
  int _lastAnnounced = 0;

  void _onPanStart(Offset _) {
    _accumulated = widget.state.bpm.toDouble();
    _overshoot = 0;
    _lastAnnounced = widget.state.bpm;
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final position = details.localPosition - centre;
    final previous = position - details.delta;
    if (position.distance < 24 || previous.distance < 24) return;

    // Signed angular travel, in degrees.
    var sweep =
        (math.atan2(position.dy, position.dx) -
            math.atan2(previous.dy, previous.dx)) *
        180 /
        math.pi;
    // Normalise the wrap at ±180°.
    if (sweep > 180) sweep -= 360;
    if (sweep < -180) sweep += 360;

    final delta = sweep / MetronomeDial.degreesPerBpm;
    final proposed = _accumulated + delta;
    final min = widget.state.minBpm.toDouble();
    final max = widget.state.maxBpm.toDouble();

    if (proposed > max) {
      _overshoot = (proposed - max) * MetronomeDial.rubberBandFactor;
      _accumulated = max;
    } else if (proposed < min) {
      _overshoot = (proposed - min) * MetronomeDial.rubberBandFactor;
      _accumulated = min;
    } else {
      _overshoot = 0;
      _accumulated = proposed;
    }

    final rounded = _accumulated.round();
    if (rounded != _lastAnnounced) {
      _lastAnnounced = rounded;
      // A tick per bpm, a firmer one at each rung of the +8 ladder.
      unawaited(
        rounded % kLadderStep == 0
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick(),
      );
      widget.onTempoChanged(rounded);
    }
    setState(() {});
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _overshoot = 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = Size(widget.size, widget.size);

    return GestureDetector(
      onPanStart: (details) => _onPanStart(details.localPosition),
      onPanUpdate: (details) => _onPanUpdate(details, size),
      onPanEnd: _onPanEnd,
      child: Semantics(
        slider: true,
        value: '${widget.state.bpm} beats per minute',
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _DialPainter(
              bpm: widget.state.bpm.toDouble() + _overshoot,
              min: widget.state.minBpm.toDouble(),
              max: widget.state.maxBpm.toDouble(),
              beatInBar: widget.state.beatIndex < 0
                  ? 0
                  : widget.state.beatInBar,
              accent: widget.state.accent,
              running: widget.state.running,
              track: colors.border,
              accentColor: colors.accentStrong,
              gradient: colors.accentGradientBright,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoreAnimatedNumber(
                    value: '${widget.state.bpm}',
                    style: CoreTextStyle.display,
                  ),
                  CoreText.caption('BPM'),
                  const SizedBox(height: 4),
                  _BeatPips(
                    active: widget.state.running ? widget.state.beatInBar : 0,
                    accent: widget.state.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeatPips extends StatelessWidget {
  const _BeatPips({required this.active, required this.accent});

  final int active;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var beat = 1; beat <= 4; beat++)
          AnimatedContainer(
            duration: context.motion(Motion.instant),
            width: beat == active ? 8 : 6,
            height: beat == active ? 8 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: beat == active
                  ? (accent ? colors.accentStrong : colors.textPrimary)
                  : colors.border,
            ),
          ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.bpm,
    required this.min,
    required this.max,
    required this.beatInBar,
    required this.accent,
    required this.running,
    required this.track,
    required this.accentColor,
    required this.gradient,
  });

  final double bpm;
  final double min;
  final double max;
  final int beatInBar;
  final bool accent;
  final bool running;
  final Color track;
  final Color accentColor;
  final Gradient gradient;

  static const double _sweep = math.pi * 1.5;
  static const double _start = math.pi * 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    final fraction = max <= min
        ? 0.0
        : ((bpm - min) / (max - min)).clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      _start,
      _sweep * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect),
    );

    // Needle.
    final angle = _start + _sweep * fraction;
    final centre = Offset(size.width / 2, size.height / 2);
    final outer =
        centre +
        Offset(math.cos(angle), math.sin(angle)) *
            (size.width / 2 - stroke / 2);
    final inner =
        centre +
        Offset(math.cos(angle), math.sin(angle)) *
            (size.width / 2 - stroke * 2.2);
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = accentColor,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.bpm != bpm ||
      old.beatInBar != beatInBar ||
      old.accent != accent ||
      old.running != running ||
      old.min != min ||
      old.max != max;
}
