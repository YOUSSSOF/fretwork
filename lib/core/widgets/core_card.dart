import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/glass.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';

/// A surface panel.
///
/// Set [glass] only where the blur budget allows it (§4.3) — inside scrolling
/// lists leave it false and the card paints a flat `surface1`, which is visually
/// near-identical over the app's dark ground and costs nothing.
///
/// When [onPressed] is set the card grows gradient corner accents on press,
/// mirroring the hover treatment in the source design system.
class CoreCard extends StatefulWidget {
  const CoreCard({
    required this.child,
    this.onPressed,
    this.glass = false,
    this.enhanced = false,
    this.padding,
    this.margin = EdgeInsets.zero,
    this.cornerAccents = true,
    this.borderColor,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool glass;
  final bool enhanced;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final bool cornerAccents;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  State<CoreCard> createState() => _CoreCardState();
}

class _CoreCardState extends State<CoreCard>
    with SingleTickerProviderStateMixin {
  // Created in initState, not as a `late final` field initializer: a widget
  // disposed before it ever builds would otherwise *construct* the controller
  // inside dispose(), which looks up an ancestor on a deactivated element and
  // throws.
  late final AnimationController _accent;

  @override
  void initState() {
    super.initState();
    _accent = AnimationController(vsync: this, duration: Motion.base);
  }

  @override
  void dispose() {
    _accent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = widget.padding ?? const EdgeInsets.all(Sp.lg);

    Widget body = widget.glass
        ? GlassSurface(
            enhanced: widget.enhanced,
            padding: padding,
            child: widget.child,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: widget.enhanced ? colors.surface2 : colors.surface1,
              border: Border.all(color: widget.borderColor ?? colors.border),
            ),
            child: Padding(padding: padding, child: widget.child),
          );

    if (widget.onPressed != null && widget.cornerAccents) {
      body = Stack(
        children: [
          body,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _accent,
                builder: (context, _) => CustomPaint(
                  painter: _CornerAccentPainter(
                    progress: context.reduceMotion ? 0 : _accent.value,
                    gradient: colors.accentGradientBright,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final card = Padding(padding: widget.margin, child: body);

    if (widget.onPressed == null) return card;

    return Listener(
      onPointerDown: (_) => _accent.forward(),
      onPointerUp: (_) => _accent.reverse(),
      onPointerCancel: (_) => _accent.reverse(),
      child: CorePressable(
        onPressed: widget.onPressed,
        semanticLabel: widget.semanticLabel,
        child: card,
      ),
    );
  }
}

/// Draws short gradient rules into the top-right and bottom-left corners,
/// extending as [progress] rises.
class _CornerAccentPainter extends CustomPainter {
  const _CornerAccentPainter({required this.progress, required this.gradient});

  final double progress;
  final Gradient gradient;

  static const double _maxLength = 28;
  static const double _thickness = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;
    final length = _maxLength * progress;
    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..strokeWidth = _thickness
      ..strokeCap = StrokeCap.square;

    // Top-right: rightwards rule plus a downward tick.
    canvas.drawLine(
      Offset(size.width - length, 0),
      Offset(size.width, 0),
      paint,
    );
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    // Bottom-left mirror.
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(
      Offset(0, size.height - length),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerAccentPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.gradient != gradient;
}
