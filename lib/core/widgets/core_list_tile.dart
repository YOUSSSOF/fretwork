import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';

class CoreListTile extends StatelessWidget {
  const CoreListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onPressed,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Sp.lg,
      vertical: Sp.md,
    ),
    this.dense = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final body = Container(
      constraints: const BoxConstraints(minHeight: Layout.touchTarget),
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? colors.selection : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: selected ? colors.accentStrong : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Sp.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoreText(
                  title,
                  style: dense ? CoreTextStyle.label : CoreTextStyle.title,
                  maxLines: 2,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  CoreText.bodySm(subtitle!, maxLines: 2),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Sp.md), trailing!],
        ],
      ),
    );

    if (onPressed == null) return body;
    return CorePressable(
      onPressed: onPressed,
      pressedScale: 0.985,
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      child: body,
    );
  }
}
