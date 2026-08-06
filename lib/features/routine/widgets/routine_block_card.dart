import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_book_reference.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One block of a plan, expandable to show its items.
class RoutineBlockCard extends ConsumerStatefulWidget {
  const RoutineBlockCard({
    required this.block,
    this.initiallyExpanded = false,
    this.completedKeys = const {},
    super.key,
  });

  final RoutineBlock block;
  final bool initiallyExpanded;
  final Set<String> completedKeys;

  @override
  ConsumerState<RoutineBlockCard> createState() => _RoutineBlockCardState();
}

class _RoutineBlockCardState extends ConsumerState<RoutineBlockCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final index = ref.watch(exerciseIndexProvider);
    final dot = colors.categoryColor(
      widget.block.category.index,
      PracticeCategory.values.length,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: CoreCard(
        padding: const EdgeInsets.all(Sp.md),
        onPressed: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, color: dot),
                const SizedBox(width: Sp.sm),
                Expanded(child: CoreText.title(widget.block.label)),
                CoreText.mono('${widget.block.minutes} min'),
                const SizedBox(width: Sp.sm),
                AnimatedRotation(
                  duration: context.motion(Motion.fast),
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            if (!_expanded) ...[
              const SizedBox(height: Sp.sm),
              CoreText.caption(
                widget.block.items
                    .map((i) => index[i.exerciseId]?.label ?? i.exerciseId)
                    .toSet()
                    .join(' · '),
                maxLines: 1,
              ),
            ],
            _Expandable(
              expanded: _expanded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Sp.md),
                  const CoreDivider(),
                  for (final item in widget.block.items)
                    _ItemRow(
                      item: item,
                      done: widget.completedKeys.contains(item.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, required this.done});

  final RoutineItem item;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final exercise = ref.watch(exerciseByIdProvider(item.exerciseId));
    if (exercise == null) return const SizedBox.shrink();
    final variant = exercise.variantById(item.variantId);

    return Padding(
      padding: const EdgeInsets.only(top: Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (done)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Sp.sm),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: colors.success,
                  ),
                ),
              Expanded(
                child: CoreText.label(
                  variant == null
                      ? exercise.label
                      : '${exercise.label} · ${variant.label}',
                  color: done ? colors.textTertiary : null,
                ),
              ),
              CoreText.mono('${item.minutes} min', color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 2),
          CoreText.bodySm(exercise.title, maxLines: 1),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: Sp.xs,
            runSpacing: Sp.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.targetTempo > 0)
                CoreChip(label: '${item.targetTempo} bpm'),
              CoreChip(label: item.procedure.label),
              if (exercise.bookPage > 0)
                CoreBookReference(
                  page: exercise.bookPage,
                  cdTrack: exercise.cdTrack,
                ),
            ],
          ),
          if (item.focusNote.isNotEmpty) ...[
            const SizedBox(height: Sp.sm),
            CoreText.caption(item.focusNote, color: colors.textSecondary),
          ],
        ],
      ),
    );
  }
}

/// Height animation that removes itself under reduced motion — an AnimatedSize
/// with a zero duration re-dirties itself during its own layout.
class _Expandable extends StatelessWidget {
  const _Expandable({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      return expanded ? child : const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.gentleCurve,
      alignment: Alignment.topCenter,
      child: expanded ? child : const SizedBox(width: double.infinity),
    );
  }
}
