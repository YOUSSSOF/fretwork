import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// Title plus a short gradient underline, offset below the baseline. The rule
/// is the design system's section marker and is the same width regardless of
/// title length — it is a mark, not an underline.
class CoreSectionHeader extends StatelessWidget {
  const CoreSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(top: Sp.xl, bottom: Sp.lg),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreText.h2(title),
                const SizedBox(height: Sp.sm),
                Container(
                  width: Layout.sectionUnderlineWidth,
                  height: Layout.sectionUnderlineHeight,
                  decoration: BoxDecoration(
                    gradient: colors.accentGradientBright,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Sp.md),
                  CoreText.bodySm(subtitle!),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
