import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_animated_number.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_progress_ring.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/analytics/analytics_controller.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';
import 'package:fretwork/features/analytics/export/pdf_export.dart';
import 'package:fretwork/features/analytics/widgets/analytics_charts.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:fretwork/router.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(analyticsProvider);
    final score = ref.watch(disciplineScoreProvider);
    final filter = ref.watch(analyticsFilterProvider);

    return CoreScaffold(
      title: 'Analytics',
      subtitle: filter.range.label,
      glow: true,
      actions: [
        CoreButton.ghost(
          label: 'History',
          size: CoreButtonSize.sm,
          onPressed: () => context.go(Routes.history),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.only(
          top: Sp.md,
          bottom: context.shellBottomInset + Sp.xl,
        ),
        children: [
          const _FilterBar(),
          const SizedBox(height: Sp.lg),
          if (summary.isEmpty)
            const SizedBox(
              height: 320,
              child: CoreEmptyState(
                icon: Icons.insights_outlined,
                title: 'Nothing to show yet',
                message:
                    'Log a session and this fills up: minutes, adherence, '
                    'streaks, tempo curves and a discipline score.',
              ),
            )
          else ...[
            _ScoreCard(score: score),
            const SizedBox(height: Sp.md),
            _TotalsRow(summary: summary),
            const CoreSectionHeader(title: 'Minutes over time'),
            MinutesOverTimeChart(minutesByDay: summary.minutesByDay),
            const CoreSectionHeader(title: 'Where the time went'),
            CategoryDonut(minutesByCategory: summary.minutesByCategory),
            const CoreSectionHeader(title: 'By weekday'),
            const CoreText.bodySm(
              'Average minutes per weekday. The short bar is the day to fix.',
            ),
            const SizedBox(height: Sp.md),
            WeekdayBars(minutesByWeekday: summary.minutesByWeekday),
            const CoreSectionHeader(title: 'When you practise'),
            TimeOfDayHistogram(sessionsByHour: summary.sessionsByHour),
            const CoreSectionHeader(title: 'Tempo progress'),
            _TempoTable(summary: summary),
            const SizedBox(height: Sp.xl),
            const _ExportRow(),
          ],
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(analyticsFilterProvider);
    final notifier = ref.read(analyticsFilterProvider.notifier);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreSegmentedGrid<AnalyticsRange>(
          items: [
            for (final range in AnalyticsRange.values)
              CoreSegmentedItem(value: range, label: range.label),
          ],
          selected: {filter.range},
          onChanged: notifier.setRange,
        ),
        const SizedBox(height: Sp.md),
        Wrap(
          spacing: Sp.xs,
          runSpacing: Sp.xs,
          children: [
            CoreChip(
              label: 'All categories',
              selected: filter.categories.isEmpty,
              onPressed: notifier.clearCategories,
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
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final DisciplineScore score;

  @override
  Widget build(BuildContext context) {
    return CoreCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoreProgressRing(
                size: 96,
                strokeWidth: 8,
                progress: score.score / 100,
                center: CoreAnimatedNumber(
                  value: '${score.score}',
                  style: CoreTextStyle.h2,
                ),
              ),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CoreText.caption('DISCIPLINE SCORE'),
                    const SizedBox(height: Sp.xs),
                    CoreText.h2(score.grade.label),
                    const SizedBox(height: Sp.xs),
                    CoreText.caption('Rolling $kScoreWindowDays days'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          CoreText.bodySm(score.lever),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              _ScorePart(label: 'Adherence', value: score.adherence),
              _ScorePart(label: 'Consistency', value: score.consistency),
              _ScorePart(label: 'Tempo', value: score.tempoProgress),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePart extends StatelessWidget {
  const _ScorePart({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: Sp.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreText.caption(label.toUpperCase()),
            const SizedBox(height: Sp.xs),
            Container(
              height: 4,
              decoration: BoxDecoration(color: colors.border),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: colors.accentGradientBright,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.xs),
            CoreText.caption('${(value * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final hours = summary.totalMinutes ~/ 60;
    final minutes = summary.totalMinutes % 60;

    return Row(
      children: [
        _Total(
          label: 'Total',
          value: hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
        ),
        _Total(label: 'Sessions', value: '${summary.totalSessions}'),
        _Total(label: 'Streak', value: '${summary.currentStreak}'),
        _Total(label: 'Missed', value: '${summary.missedDays}'),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: Sp.sm),
        child: CoreCard(
          padding: const EdgeInsets.all(Sp.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoreText.caption(label.toUpperCase()),
              const SizedBox(height: Sp.xs),
              CoreText.title(value, tabular: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _TempoTable extends ConsumerWidget {
  const _TempoTable({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);
    if (summary.tempoProgress.isEmpty) {
      return CoreText.bodySm(
        'Mark a tempo clean on two different days and the progression shows '
        'up here.',
        color: context.colors.textTertiary,
      );
    }

    return Column(
      children: [
        for (final progress in summary.tempoProgress) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.sm),
            child: Row(
              children: [
                Expanded(
                  child: CoreText.bodySm(
                    index[progress.exerciseId]?.label ?? progress.exerciseId,
                    maxLines: 1,
                  ),
                ),
                CoreText.mono('${progress.startBpm} → ${progress.bestBpm}'),
                const SizedBox(width: Sp.sm),
                SizedBox(
                  width: 52,
                  child: CoreText.caption(
                    '${progress.delta >= 0 ? '+' : ''}${progress.delta} bpm',
                    align: TextAlign.end,
                    color: progress.delta >= 0
                        ? context.colors.success
                        : context.colors.danger,
                  ),
                ),
              ],
            ),
          ),
          const CoreDivider(),
        ],
      ],
    );
  }
}

class _ExportRow extends ConsumerStatefulWidget {
  const _ExportRow();

  @override
  ConsumerState<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends ConsumerState<_ExportRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return CoreButton.primary(
      label: 'Export PDF report',
      leading: Icons.picture_as_pdf_outlined,
      fullWidth: true,
      size: CoreButtonSize.lg,
      loading: _busy,
      onPressed: () async {
        setState(() => _busy = true);
        try {
          await exportPracticeReport(ref);
        } finally {
          // Restored even if the share sheet throws or the user cancels —
          // a button stuck in its loading state is worse than no feedback.
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}
