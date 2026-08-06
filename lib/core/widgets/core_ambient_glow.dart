import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';

/// Slow-drifting blurred circles behind the content on Home and Analytics.
///
/// Uses [ImageFiltered] (blurs its own children) rather than [BackdropFilter]
/// (re-reads everything painted beneath it), so it does not eat into the glass
/// budget. The float loop stops entirely under reduced motion.
class CoreAmbientGlow extends StatefulWidget {
  const CoreAmbientGlow({this.blobs = 3, this.intensity = 1, super.key});

  final int blobs;
  final double intensity;

  @override
  State<CoreAmbientGlow> createState() => _CoreAmbientGlowState();
}

class _CoreAmbientGlowState extends State<CoreAmbientGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: Motion.ambientFloat,
  );

  @override
  void initState() {
    super.initState();
    _float.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _float.stop();
      _float.value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
          child: AnimatedBuilder(
            animation: _float,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    for (var i = 0; i < widget.blobs; i++)
                      _blob(i, w, h, colors),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(int index, double w, double h, AppColors colors) {
    // Deterministic per-index placement and phase — no randomness, so the
    // composition is the same every launch.
    final phase = _float.value * 2 * math.pi + index * 2.1;
    final radius = (index.isEven ? 0.42 : 0.34) * w * widget.intensity;
    final baseX = (index * 0.37 + 0.12) % 1.0;
    final baseY = (index * 0.53 + 0.08) % 1.0;
    final dx = math.sin(phase) * w * 0.06;
    final dy = math.cos(phase * 0.8) * h * 0.05;

    return Positioned(
      left: baseX * w - radius / 2 + dx,
      top: baseY * h - radius / 2 + dy,
      width: radius,
      height: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              (index.isEven
                      ? colors.glowA
                      : colors.palette.a.withValues(alpha: 0.08))
                  .withValues(alpha: 0.10 * widget.intensity),
        ),
      ),
    );
  }
}
