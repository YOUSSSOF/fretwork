import 'package:flutter/material.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// A live picture of how a session would be split.
///
/// This re-lays out as the length slider moves — it is the moment the app
/// explains itself, so the bars resize with a spring rather than jumping.
class BlockSplitPreview extends StatelessWidget {
  const BlockSplitPreview({
    required this.split,
    this.showLabels = true,
    this.barHeight = 14,
    super.key,
  });

  final Map<PracticeCategory, int> split;
  final bool showLabels;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = split.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border.all(color: colors.border),
        ),
      );
    }

    final entries = split.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < entries.length; i++)
                Expanded(
                  flex: entries[i].value,
                  child: _Segment(
                    color: _colorFor(context, entries[i].key),
                    isFirst: i == 0,
                  ),
                ),
            ],
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: Sp.md),
          for (final entry in entries)
            _Row(
              category: entry.key,
              minutes: entry.value,
              total: total,
              color: _colorFor(context, entry.key),
            ),
        ],
      ],
    );
  }

  static Color _colorFor(BuildContext context, PracticeCategory category) =>
      context.colors.categoryColor(
        category.index,
        PracticeCategory.values.length,
      );
}

class _Segment extends StatelessWidget {
  const _Segment({required this.color, required this.isFirst});

  final Color color;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion(Motion.base),
      curve: context.motionCurve(Motion.gentleCurve),
      margin: EdgeInsetsDirectional.only(start: isFirst ? 0 : 2),
      color: color,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.category,
    required this.minutes,
    required this.total,
    required this.color,
  });

  final PracticeCategory category;
  final int minutes;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: Sp.sm),
          Expanded(child: CoreText.bodySm(category.label)),
          // Animated so a slider drag reads as one continuous change rather
          // than a set of numbers flickering independently.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: minutes.toDouble(), end: minutes.toDouble()),
            duration: context.motion(Motion.base),
            curve: Motion.standard,
            builder: (context, value, _) =>
                CoreText.mono('${value.round()} min'),
          ),
        ],
      ),
    );
  }
}
