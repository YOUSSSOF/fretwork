import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';

@immutable
class CoreSegmentedItem<T> {
  const CoreSegmentedItem({
    required this.value,
    required this.label,
    this.dotColor,
    this.enabled = true,
  });

  final T value;
  final String label;
  final Color? dotColor;
  final bool enabled;
}

/// A wrapping grid of selectable chips.
///
/// Used inside the tab index-jump sheet and anywhere a flat multi-select is
/// wanted (analytics category and tag filters). It is deliberately *not* a
/// substitute for [CoreTabs] — a grid loses the ordering and current-position
/// cues that tabs carry.
class CoreSegmentedGrid<T> extends StatelessWidget {
  const CoreSegmentedGrid({
    required this.items,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
    this.spacing = Sp.sm,
    super.key,
  });

  final List<CoreSegmentedItem<T>> items;
  final Set<T> selected;
  final ValueChanged<T> onChanged;
  final bool multiSelect;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final item in items)
          _Segment<T>(
            item: item,
            selected: selected.contains(item.value),
            onPressed: item.enabled ? () => onChanged(item.value) : null,
          ),
      ],
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final CoreSegmentedItem<T> item;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CorePressable(
      onPressed: onPressed,
      pressedScale: 0.94,
      semanticLabel: item.label,
      child: AnimatedContainer(
        duration: context.motion(Motion.fast),
        curve: Motion.standard,
        constraints: const BoxConstraints(minHeight: Layout.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.selection : colors.surface1,
          border: Border.all(
            color: selected ? colors.accentStrong : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.dotColor,
                ),
              ),
              const SizedBox(width: Sp.sm),
            ],
            CoreText.label(
              item.label,
              color: onPressed == null
                  ? colors.textTertiary
                  : (selected ? colors.textPrimary : colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
