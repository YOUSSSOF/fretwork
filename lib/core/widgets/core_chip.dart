import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';

enum CoreChipStyle { filled, outlined }

/// Technique tags and small filters.
class CoreChip extends StatelessWidget {
  const CoreChip({
    required this.label,
    this.style = CoreChipStyle.outlined,
    this.dotColor,
    this.onPressed,
    this.selected = false,
    this.icon,
    super.key,
  });

  final String label;
  final CoreChipStyle style;
  final Color? dotColor;
  final VoidCallback? onPressed;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = style == CoreChipStyle.filled || selected;

    final body = AnimatedContainer(
      duration: context.motion(Motion.fast),
      curve: Motion.standard,
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
      decoration: BoxDecoration(
        color: filled ? colors.selection : Colors.transparent,
        border: Border.all(
          color: selected ? colors.accentStrong : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: Sp.xs),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.textSecondary),
            const SizedBox(width: Sp.xs),
          ],
          CoreText.caption(
            label,
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
        ],
      ),
    );

    if (onPressed == null) return body;
    return CorePressable(
      onPressed: onPressed,
      pressedScale: 0.94,
      dim: 0,
      semanticLabel: label,
      child: body,
    );
  }
}
