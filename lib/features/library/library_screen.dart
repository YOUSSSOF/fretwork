import 'package:flutter/material.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/library/library_controller.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:fretwork/router.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(librarySectionsProvider);
    final filter = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);
    final scheduled = ref.watch(scheduledExercisesProvider);
    final colors = context.colors;

    return CoreScaffold(
      title: 'Library',
      subtitle: '${sections.length} parts',
      body: ListView(
        padding: EdgeInsets.only(
          top: Sp.md,
          bottom: context.shellBottomInset + Sp.xl,
        ),
        children: [
          TextField(
            controller: _search,
            onChanged: notifier.setQuery,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search exercises',
              hintStyle: TextStyle(color: colors.textTertiary),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: colors.textTertiary,
              ),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _search.clear();
                        notifier.setQuery('');
                      },
                    ),
              filled: true,
              fillColor: colors.surface1,
              border: OutlineInputBorder(
                borderRadius: Rd.none,
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: Rd.none,
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: Rd.none,
                borderSide: BorderSide(color: colors.accentStrong),
              ),
            ),
          ),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.xs,
            runSpacing: Sp.xs,
            children: [
              CoreChip(
                label: 'Unlocked only',
                selected: filter.unlockedOnly,
                onPressed: () => notifier.setUnlockedOnly(!filter.unlockedOnly),
              ),
              for (final category in PracticeCategory.values)
                CoreChip(
                  label: category.shortLabel,
                  selected: filter.categories.contains(category),
                  dotColor: colors.categoryColor(
                    category.index,
                    PracticeCategory.values.length,
                  ),
                  onPressed: () => notifier.toggleCategory(category),
                ),
            ],
          ),
          if (filter.isActive) ...[
            const SizedBox(height: Sp.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoreChip(
                label: 'Clear filters',
                icon: Icons.close_rounded,
                onPressed: () {
                  _search.clear();
                  notifier.clear();
                },
              ),
            ),
          ],
          if (sections.isEmpty)
            const SizedBox(
              height: 320,
              child: CoreEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Nothing matches',
                message: 'Try a different search or clear the filters.',
              ),
            )
          else
            for (final section in sections) ...[
              CoreSectionHeader(
                title: section.part.label,
                subtitle: section.lock == PartLock.locked
                    ? 'Locked — reach milestone ${section.part.milestone} to '
                          'open this part'
                    : section.part.blurb,
                trailing: switch (section.lock) {
                  PartLock.unlocked => null,
                  PartLock.next => const CoreBadge('Next'),
                  PartLock.locked => Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: colors.textTertiary,
                  ),
                },
              ),
              for (final exercise in section.exercises)
                _ExerciseCard(
                  exercise: exercise,
                  lock: section.lock,
                  scheduledToday: scheduled.contains(exercise.id),
                ),
            ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.lock,
    required this.scheduledToday,
  });

  final Exercise exercise;
  final PartLock lock;
  final bool scheduledToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = colors.categoryColor(
      exercise.category.index,
      PracticeCategory.values.length,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: CoreCard(
        padding: const EdgeInsets.all(Sp.md),
        onPressed: lock == PartLock.locked
            ? null
            : () => context.go(Routes.exercise(exercise.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, color: dot),
                const SizedBox(width: Sp.sm),
                CoreText.label(exercise.label),
                const SizedBox(width: Sp.sm),
                if (scheduledToday) const CoreBadge('Today'),
                const Spacer(),
                _DifficultyPips(level: exercise.difficulty),
              ],
            ),
            const SizedBox(height: Sp.xs),
            CoreText.title(exercise.title, maxLines: 2),
            const SizedBox(height: Sp.xs),
            CoreText.bodySm(exercise.summary, maxLines: 3),
            const SizedBox(height: Sp.sm),
            Wrap(
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              children: [
                if (exercise.variants.isNotEmpty)
                  CoreChip(label: '${exercise.variants.length} variants'),
                for (final tag in exercise.tags.take(3))
                  CoreChip(label: tag.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyPips extends StatelessWidget {
  const _DifficultyPips({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: 4,
            height: 10,
            margin: const EdgeInsetsDirectional.only(start: 2),
            color: i <= level ? colors.accentStrong : colors.border,
          ),
      ],
    );
  }
}
