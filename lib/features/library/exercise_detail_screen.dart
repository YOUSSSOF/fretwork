import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_book_reference.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_tabs.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/library/library_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:fretwork/router.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  String? _selectedVariantId;
  late final PageController _panels = PageController();

  @override
  void dispose() {
    _panels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = ref.watch(exerciseByIdProvider(widget.exerciseId));
    if (exercise == null) {
      return const CoreScaffold(
        title: 'Exercise',
        showBack: true,
        body: CoreEmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Not found',
          message:
              'This exercise is no longer part of the course — it may have '
              'been removed by an update.',
        ),
      );
    }

    final scheduled = ref.watch(scheduledVariantsProvider);
    final selected =
        _selectedVariantId ??
        (exercise.variants.isEmpty ? null : exercise.variants.first.id);
    final index = exercise.variants.indexWhere((v) => v.id == selected);

    return CoreScaffold(
      title: exercise.label,
      subtitle: exercise.title,
      showBack: true,
      onBack: () => context.go(Routes.library),
      body: ListView(
        padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.huge),
        children: [
          _Header(exercise: exercise),
          if (exercise.variants.isNotEmpty) ...[
            const CoreSectionHeader(title: 'Variants'),
            CoreTabs(
              items: [
                for (final variant in exercise.variants)
                  CoreTabItem(
                    id: variant.id,
                    label: variant.label,
                    shortLabel: variant.shortLabel,
                    marked: scheduled.contains(variant.id),
                  ),
              ],
              selectedId: selected ?? '',
              density: ref.watch(preferencesProvider).tabDensity,
              onSelected: (id) {
                setState(() => _selectedVariantId = id);
                final next = exercise.variants.indexWhere((v) => v.id == id);
                if (next < 0 || !_panels.hasClients) return;
                if (context.reduceMotion) {
                  _panels.jumpToPage(next);
                } else {
                  _panels.animateToPage(
                    next,
                    duration: Motion.base,
                    curve: Motion.emphasize,
                  );
                }
              },
            ),
            SizedBox(
              height: 132,
              child: PageView.builder(
                controller: _panels,
                itemCount: exercise.variants.length,
                // Swiping the panel moves the selection, so the tabs and the
                // content can never disagree about where the user is.
                onPageChanged: (page) => setState(
                  () => _selectedVariantId = exercise.variants[page].id,
                ),
                itemBuilder: (context, page) => _VariantPanel(
                  exercise: exercise,
                  variant: exercise.variants[page],
                  scheduledToday: scheduled.contains(
                    exercise.variants[page].id,
                  ),
                ),
              ),
            ),
          ],
          const CoreSectionHeader(title: 'Practice'),
          _PracticePanel(
            exercise: exercise,
            variantId: index >= 0 ? selected : null,
          ),
          const CoreSectionHeader(title: 'Tempo history'),
          _TempoHistory(exerciseId: exercise.id),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CoreCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                color: colors.categoryColor(
                  exercise.category.index,
                  PracticeCategory.values.length,
                ),
              ),
              const SizedBox(width: Sp.sm),
              CoreText.label(exercise.category.label),
            ],
          ),
          const SizedBox(height: Sp.md),
          CoreText.h2(exercise.title),
          const SizedBox(height: Sp.sm),
          CoreText.body(exercise.summary),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.xs,
            runSpacing: Sp.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in exercise.tags) CoreChip(label: tag.label),
              if (exercise.keyCenter != null)
                CoreChip(label: exercise.keyCenter!),
              if (exercise.position != null)
                CoreChip(label: exercise.position!),
              if (exercise.bookPage > 0)
                CoreBookReference(
                  page: exercise.bookPage,
                  cdTrack: exercise.cdTrack,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariantPanel extends StatelessWidget {
  const _VariantPanel({
    required this.exercise,
    required this.variant,
    required this.scheduledToday,
  });

  final Exercise exercise;
  final ExerciseVariant variant;
  final bool scheduledToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Sp.md),
      child: CoreCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The full label lives here, so nothing is lost when the tab
                // row shortens to "Frag 7".
                Expanded(child: CoreText.title(variant.label)),
                if (scheduledToday) const CoreBadge('Today'),
              ],
            ),
            const SizedBox(height: Sp.xs),
            CoreText.caption(variant.kind.label.toUpperCase()),
            if (variant.note != null) ...[
              const SizedBox(height: Sp.sm),
              CoreText.bodySm(variant.note!),
            ],
            const Spacer(),
            Wrap(
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (variant.tempo != null)
                  CoreChip(label: '${variant.tempo} bpm'),
                if (variant.bookPage != null)
                  CoreBookReference(
                    page: variant.bookPage!,
                    cdTrack: exercise.cdTrack,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticePanel extends ConsumerWidget {
  const _PracticePanel({required this.exercise, required this.variantId});

  final Exercise exercise;
  final String? variantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remembered = ref.watch(tempoRecordsProvider)[exercise.id]?.lastTempo;
    final tempo = (remembered ?? 0) > 0 ? remembered! : exercise.defaultTempo;

    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Fact(
                  label: 'Target',
                  value: tempo == 0 ? 'Free time' : '$tempo bpm',
                ),
              ),
              Expanded(
                child: _Fact(
                  label: 'Subdivision',
                  value: '${exercise.subdivision}/beat',
                ),
              ),
              Expanded(
                child: _Fact(
                  label: 'Minutes',
                  value: '${exercise.estimatedMinutes}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          const CoreDivider(),
          const SizedBox(height: Sp.md),
          CoreText.label(exercise.procedure.label.toUpperCase()),
          const SizedBox(height: Sp.xs),
          CoreText.bodySm(exercise.procedure.hint),
          const SizedBox(height: Sp.lg),
          Row(
            children: [
              Expanded(
                child: CoreButton.primary(
                  label: 'Practise now',
                  leading: Icons.play_arrow_rounded,
                  fullWidth: true,
                  onPressed: () => context.go(
                    '${Routes.session}?exercise=${exercise.id}'
                    '${variantId == null ? '' : '&variant=$variantId'}',
                  ),
                ),
              ),
              if (exercise.tips.isNotEmpty) ...[
                const SizedBox(width: Sp.sm),
                CoreButton.secondary(
                  label: 'Tips',
                  onPressed: () => _showTips(context, exercise),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Tips open in a sheet, never pinned to the screen (§18.5).
Future<void> _showTips(BuildContext context, Exercise exercise) =>
    showCoreSheet<void>(
      context: context,
      title: 'Tips',
      subtitle: exercise.label,
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in exercise.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: CoreText.body('· $tip'),
            ),
          if (exercise.bookPage > 0) ...[
            const SizedBox(height: Sp.sm),
            CoreBookReference(
              page: exercise.bookPage,
              cdTrack: exercise.cdTrack,
            ),
          ],
          const SizedBox(height: Sp.lg),
        ],
      ),
    );

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreText.caption(label.toUpperCase()),
        const SizedBox(height: Sp.xs),
        CoreText.title(value, tabular: true),
      ],
    );
  }
}

class _TempoHistory extends ConsumerWidget {
  const _TempoHistory({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final record = ref.watch(tempoRecordsProvider)[exerciseId];
    final points = record?.cleanPoints ?? const [];

    if (points.isEmpty) {
      return CoreText.bodySm(
        'Mark a tempo clean during a session and it starts building a curve '
        'here.',
        color: colors.textTertiary,
      );
    }

    final best = record!.bestCleanTempo;
    final min = points.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);

    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: CoreText.label('BEST CLEAN TEMPO')),
              CoreBadge('$best bpm'),
            ],
          ),
          const SizedBox(height: Sp.lg),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: FractionallySizedBox(
                        heightFactor: best == min
                            ? 1
                            : ((point.bpm - min) / (best - min)).clamp(
                                0.12,
                                1.0,
                              ),
                        alignment: Alignment.bottomCenter,
                        child: ColoredBox(
                          color: point.bpm == best
                              ? colors.accentStrong
                              : colors.accentStrong.withValues(alpha: 0.4),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sp.sm),
          CoreText.caption(
            '${points.length} clean ${points.length == 1 ? 'point' : 'points'}'
            ' · from $min to $best bpm',
          ),
        ],
      ),
    );
  }
}
