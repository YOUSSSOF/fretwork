import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';

class CoreIconButton extends StatelessWidget {
  const CoreIconButton({
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = Layout.touchTarget,
    this.iconSize = 20,
    this.color,
    this.bordered = false,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? color;
  final bool bordered;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = color ?? colors.textSecondary;
    return CorePressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? colors.surface1 : Colors.transparent,
          border: bordered ? Border.all(color: colors.border) : null,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: onPressed == null ? ink.withValues(alpha: 0.35) : ink,
        ),
      ),
    );
  }
}
