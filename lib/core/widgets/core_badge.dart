import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// A small count or date badge on the accent gradient.
class CoreBadge extends StatelessWidget {
  const CoreBadge(this.label, {this.muted = false, super.key});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 2),
      decoration: BoxDecoration(
        gradient: muted ? null : colors.accentGradient,
        color: muted ? colors.surface2 : null,
        border: Border.all(color: colors.border),
      ),
      child: CoreText.caption(
        label,
        color: muted ? colors.textSecondary : colors.textPrimary,
      ),
    );
  }
}
