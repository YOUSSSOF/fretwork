import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_colors.dart';

/// A translucent blurred surface.
///
/// [BackdropFilter] is expensive: each one forces a save-layer and re-reads the
/// backdrop. The budget is ~6 mounted glass surfaces per screen, reserved for
/// the app bar, sheets and the session HUD. Inside scrolling lists use
/// [GlassSurface.flat] instead, which paints the same colour with no blur.
///
/// When `Preferences.reduceBlur` is on, every instance silently degrades to the
/// flat variant, so a slow device gets a solid surface rather than dropped
/// frames.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.enhanced = false,
    this.bordered = true,
    this.padding = EdgeInsets.zero,
    this.blurred = true,
    super.key,
  });

  /// A flat surface with the same colour and border but no blur. Cheap enough
  /// to use inside a list of any length.
  const GlassSurface.flat({
    required Widget child,
    bool enhanced = false,
    bool bordered = true,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Key? key,
  }) : this(
         child: child,
         enhanced: enhanced,
         bordered: bordered,
         padding: padding,
         blurred: false,
         key: key,
       );

  final Widget child;
  final bool enhanced;
  final bool bordered;
  final bool blurred;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final useBlur = blurred && !context.reduceBlur;
    final sigma = enhanced ? 20.0 : 14.0;

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        // With no blur behind it the surface has to carry its own weight,
        // so the flat variant sits on an opaque tone instead of a wash.
        color: useBlur
            ? Colors.black.withValues(alpha: enhanced ? 0.30 : 0.20)
            : (enhanced ? colors.surface2 : colors.surface1),
        border: bordered ? Border.all(color: colors.border) : null,
        boxShadow: enhanced
            ? const [
                BoxShadow(
                  blurRadius: 32,
                  offset: Offset(0, 8),
                  color: Color(0x5E000000),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (!useBlur) return decorated;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: decorated,
      ),
    );
  }
}
