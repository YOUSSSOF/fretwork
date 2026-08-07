import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// How long the whole opening runs, end to end.
const Duration kSplashDuration = Duration(milliseconds: 2100);

/// Plays the opening once, over the app, then gets out of the way.
///
/// This wraps the router rather than being a route of its own: the splash is
/// not a place, it is the moment before the app. Making it a route would put it
/// in the back stack and let the user navigate back into a finished animation.
class SplashGate extends StatefulWidget {
  const SplashGate({required this.child, super.key});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kSplashDuration,
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion means no drawn-on strings and no pluck; the brand mark
    // simply appears and leaves. Skipping the splash entirely would be worse —
    // the app would seem to start mid-thought.
    if (context.reduceMotion && _controller.duration == kSplashDuration) {
      _controller.duration = const Duration(milliseconds: 600);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            // The overlay sits above the Navigator, where there is no Material
            // ancestor and therefore no default text style — text would render
            // in the framework's unstyled debug form. This supplies one.
            child: Material(
              type: MaterialType.transparency,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      _SplashOverlay(progress: _controller.value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The curtain holds opaque until the mark has landed, then lifts.
    final exit = _interval(progress, 0.78, 1);
    final opacity = 1 - Curves.easeInCubic.transform(exit);
    if (opacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.1,
            colors: [
              Color.alphaBlend(colors.glowA, colors.surface0),
              colors.surface0,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 120,
                child: CustomPaint(
                  painter: _StringsPainter(
                    progress: progress,
                    stringColor: colors.textPrimary,
                    accent: colors.accentStrong,
                  ),
                ),
              ),
              const SizedBox(height: Sp.xl),
              _Wordmark(progress: progress),
              const SizedBox(height: Sp.sm),
              Opacity(
                opacity: _interval(progress, 0.55, 0.72),
                child: CoreText.caption(
                  'PRACTICE, ORGANISED',
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const letters = 'FRETWORK';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          _Letter(
            letter: letters[i],
            // Each letter rises a beat after the one before it, so the word
            // reads left to right rather than appearing all at once.
            t: _interval(progress, 0.42 + i * 0.035, 0.62 + i * 0.035),
          ),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.letter, required this.t});

  final String letter;
  final double t;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: CoreText.h1(letter),
        ),
      ),
    );
  }
}

/// Six strings that draw themselves in, then ring.
class _StringsPainter extends CustomPainter {
  const _StringsPainter({
    required this.progress,
    required this.stringColor,
    required this.accent,
  });

  final double progress;
  final Color stringColor;
  final Color accent;

  static const int _strings = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.height / (_strings + 1);

    for (var i = 0; i < _strings; i++) {
      final y = gap * (i + 1);
      // Low strings first, thickest to thinnest, staggered.
      final draw = Curves.easeOutCubic.transform(
        _interval(progress, i * 0.045, 0.30 + i * 0.045),
      );
      if (draw <= 0) continue;

      // Real strings ring hardest just after they are struck and settle to
      // nothing; the amplitude decays on the same clock as the draw finishing.
      final ring = _interval(progress, 0.10 + i * 0.045, 0.62 + i * 0.045);
      final amplitude = (1 - ring) * (1 - ring) * (gap * 0.42) * draw;
      final phase = progress * math.pi * 2 * (9 + i * 1.6);

      final width = size.width * draw;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= width; x += 3) {
        // A plucked string is a standing wave: pinned at both ends, widest in
        // the middle. sin(pi * u) is exactly that envelope.
        final u = x / size.width;
        final envelope = math.sin(math.pi * u.clamp(0.0, 1.0));
        path.lineTo(
          x,
          y + math.sin(phase + u * math.pi * 2) * amplitude * envelope,
        );
      }

      final glow = amplitude / (gap * 0.42);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4 - i * 0.28
          ..color = Color.lerp(
            stringColor,
            accent,
            glow.clamp(0.0, 1.0),
          )!.withValues(alpha: 0.35 + 0.55 * draw),
      );
    }
  }

  @override
  bool shouldRepaint(_StringsPainter old) => old.progress != progress;
}

/// Maps [t] onto 0..1 across the window [start]..[end], clamped outside it.
double _interval(double t, double start, double end) {
  if (end <= start) return t >= end ? 1 : 0;
  return ((t - start) / (end - start)).clamp(0.0, 1.0);
}
