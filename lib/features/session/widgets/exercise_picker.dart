import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_book_reference.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_list_tile.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/routine/routine_service.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Every exercise and part available for a block, so the generator's pick can
/// be overruled.
///
/// The routine chooses something sensible; this is for the days you know
/// better. Choosing keeps the block's minutes and swaps only what is played.
Future<RoutineItem?> showExercisePicker({
  required BuildContext context,
  required PracticeCategory category,
  required RoutineItem current,
  required DateTime date,
}) => showCoreSheet<RoutineItem>(
  context: context,
  title: category.label,
  subtitle: 'Choose what to practise in this block',
  builder: (context) =>
      _PickerBody(category: category, current: current, date: date),
);

class _PickerBody extends ConsumerWidget {
  const _PickerBody({
    required this.category,
    required this.current,
    required this.date,
  });

  final PracticeCategory category;
  final RoutineItem current;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tempos = ref.watch(tempoRecordsProvider);
    final exercises = [
      for (final exercise in ref.watch(unlockedExercisesProvider))
        if (exercise.category == category) exercise,
    ]..sort((a, b) => a.id.compareTo(b.id));

    if (exercises.isEmpty) {
      return const CoreText.body('Nothing else is unlocked in this block yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exercise in exercises) ...[
          _ExerciseGroup(
            exercise: exercise,
            current: current,
            onPick: (variantId) => Navigator.of(context).pop(
              _itemFor(
                exercise: exercise,
                variantId: variantId,
                tempos: tempos,
              ),
            ),
          ),
          const CoreDivider(),
        ],
        const SizedBox(height: Sp.lg),
        CoreText.caption(
          'The timer and the click are paused while this is open.',
          color: colors.textTertiary,
        ),
        const SizedBox(height: Sp.sm),
      ],
    );
  }

  RoutineItem _itemFor({
    required Exercise exercise,
    required String? variantId,
    required Map<String, TempoRecord> tempos,
  }) {
    final remembered = tempos[exercise.id]?.lastTempo ?? 0;
    final variant = exercise.variantById(variantId);
    final target =
        variant?.tempo ?? (remembered > 0 ? remembered : exercise.defaultTempo);

    return RoutineItem(
      exerciseId: exercise.id,
      variantId: variantId,
      minutes: exercise.estimatedMinutes,
      targetTempo: exercise.maxTempo == 0
          ? 0
          : target.clamp(exercise.minTempo, exercise.maxTempo),
      procedure: exercise.procedure,
      focusNote: focusNoteFor(
        category: exercise.category,
        procedure: exercise.procedure,
        date: date,
      ),
    );
  }
}

class _ExerciseGroup extends StatelessWidget {
  const _ExerciseGroup({
    required this.exercise,
    required this.current,
    required this.onPick,
  });

  final Exercise exercise;
  final RoutineItem current;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrent = current.exerciseId == exercise.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreListTile(
          title: exercise.label,
          subtitle: exercise.title,
          padding: const EdgeInsets.symmetric(vertical: Sp.sm),
          selected: isCurrent && current.variantId == null,
          onPressed: exercise.variants.isEmpty ? () => onPick(null) : null,
          trailing: exercise.variants.isEmpty && isCurrent
              ? const CoreBadge('Now')
              : null,
        ),
        if (exercise.variants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: Wrap(
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              children: [
                for (final variant in exercise.variants)
                  CoreChip(
                    label: variant.shortLabel ?? variant.label,
                    selected: isCurrent && current.variantId == variant.id,
                    onPressed: () => onPick(variant.id),
                  ),
              ],
            ),
          ),
        if (exercise.summary.isNotEmpty)
          CoreText.caption(
            exercise.summary,
            color: colors.textTertiary,
            maxLines: 2,
          ),
        if (exercise.bookPage > 0) ...[
          const SizedBox(height: Sp.sm),
          CoreBookReference(page: exercise.bookPage, cdTrack: exercise.cdTrack),
        ],
        const SizedBox(height: Sp.sm),
      ],
    );
  }
}
