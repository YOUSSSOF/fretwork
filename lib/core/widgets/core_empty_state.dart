import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

class CoreEmptyState extends StatelessWidget {
  const CoreEmptyState({
    required this.title,
    required this.message,
    this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 32, color: colors.textTertiary),
              const SizedBox(height: Sp.lg),
            ],
            CoreText.h3(title, align: TextAlign.center),
            const SizedBox(height: Sp.sm),
            CoreText.body(message, align: TextAlign.center),
            if (action != null) ...[const SizedBox(height: Sp.xl), action!],
          ],
        ),
      ),
    );
  }
}
