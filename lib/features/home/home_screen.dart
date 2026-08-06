import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_progress_ring.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:fretwork/router.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The reorderable card stack.
///
/// Cards the user has hidden are simply not built — a hidden card should cost
/// nothing, not render invisibly.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final today = ref.watch(clockProvider).now();

    return CoreScaffold(
      title: 'Today',
      subtitle: today.shortDayLabel,
      glow: true,
      actions: [
        CoreButton.ghost(
          label: 'Progress',
          size: CoreButtonSize.sm,
          onPressed: () => context.go(Routes.progress),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.huge),
        children: [
          for (final card in prefs.visibleCards)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: _cardFor(card),
            ),
        ],
      ),
    );
  }

  Widget _cardFor(HomeCardId id) => switch (id) {
    HomeCardId.todayRoutine => const TodayCard(),
    HomeCardId.streak => const _StreakCard(),
    HomeCardId.score => const _ScoreCard(),
    HomeCardId.nextMilestone => const _NextMilestoneCard(),
    HomeCardId.quickTimer => const _QuickTimerCard(),
    HomeCardId.recentSessions => const _RecentSessionsCard(),
  };
}

/// The first thing on the screen: today's plan and one tap to start it.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final routine = ref.watch(todayRoutineProvider);
    final completedMinutes = ref
        .watch(sessionRecordsProvider.notifier)
        .completedMinutesOn(ref.watch(clockProvider).now());
    final progress = routine.plannedMinutes == 0
        ? 0.0
        : (completedMinutes / routine.plannedMinutes).clamp(0.0, 1.0);

    if (routine.isRestDay) {
      return CoreCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.nightlight_round,
                  size: 18,
                  color: colors.accentStrong,
                ),
                const SizedBox(width: Sp.sm),
                const CoreText.title('Rest day'),
              ],
            ),
            const SizedBox(height: Sp.sm),
            const CoreText.bodySm(
              'Adaptation happens now. Your streak is safe.',
            ),
          ],
        ),
      );
    }

    return CoreCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CoreText.caption("TODAY'S ROUTINE"),
                    const SizedBox(height: Sp.xs),
                    CoreText.h1('${routine.plannedMinutes} min'),
                    const SizedBox(height: Sp.sm),
                    Wrap(
                      spacing: Sp.xs,
                      runSpacing: Sp.xs,
                      children: [
                        for (final block in routine.blocks)
                          CoreBadge(block.category.shortLabel, muted: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (progress > 0)
                CoreProgressRing(
                  size: 64,
                  strokeWidth: 6,
                  progress: progress,
                  center: CoreText.caption('${(progress * 100).round()}%'),
                ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Row(
            children: [
              Expanded(
                child: CoreButton.primary(
                  label: progress > 0 ? 'Continue session' : 'Start session',
                  size: CoreButtonSize.lg,
                  fullWidth: true,
                  leading: Icons.play_arrow_rounded,
                  onPressed: () => context.go(Routes.session),
                ),
              ),
              const SizedBox(width: Sp.sm),
              CoreButton.secondary(
                label: 'View',
                size: CoreButtonSize.lg,
                onPressed: () => context.go(Routes.routine),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(dayRecordsProvider.notifier).sorted;
    final today = ref.watch(clockProvider).now();
    var streak = 0;
    for (var cursor = today.dayStart; ; cursor = cursor.previousDay) {
      final record = days.where((d) => d.date.isSameDayAs(cursor)).firstOrNull;
      if (record == null) break;
      if (!record.countsForStreak) break;
      streak++;
    }

    return CoreCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CoreText.caption('CURRENT STREAK'),
                const SizedBox(height: Sp.xs),
                CoreText.h2(streak == 1 ? '1 day' : '$streak days'),
              ],
            ),
          ),
          Row(
            children: [
              for (var offset = 6; offset >= 0; offset--)
                _DayDot(
                  date: today.subtract(Duration(days: offset)),
                  practised: days
                      .where(
                        (d) => d.date.isSameDayAs(
                          today.subtract(Duration(days: offset)),
                        ),
                      )
                      .any((d) => d.countsForStreak),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.date, required this.practised});

  final DateTime date;
  final bool practised;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsetsDirectional.only(start: Sp.xs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: practised ? colors.accentStrong : Colors.transparent,
        border: Border.all(
          color: practised ? colors.accentStrong : colors.border,
        ),
      ),
    );
  }
}

class _ScoreCard extends ConsumerWidget {
  const _ScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filled in by the analytics phase; until then the card explains itself
    // rather than showing a fabricated number.
    final sessions = ref.watch(sessionRecordsProvider);
    return CoreCard(
      onPressed: () => context.go(Routes.analytics),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CoreText.caption('DISCIPLINE SCORE'),
          const SizedBox(height: Sp.xs),
          CoreText.bodySm(
            sessions.isEmpty
                ? 'Your score appears once you have logged a session.'
                : 'Open Analytics for the full breakdown.',
          ),
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends ConsumerWidget {
  const _NextMilestoneCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextPartProvider);
    if (next == null) {
      return const CoreCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreText.caption('COURSE'),
            SizedBox(height: Sp.xs),
            CoreText.title('Every part unlocked'),
          ],
        ),
      );
    }

    return CoreCard(
      onPressed: () => context.go(Routes.progress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CoreText.caption('NEXT UP'),
          const SizedBox(height: Sp.xs),
          CoreText.title(next.label),
          const SizedBox(height: Sp.xs),
          CoreText.bodySm(next.blurb, maxLines: 2),
          const SizedBox(height: Sp.md),
          CoreButton.secondary(
            label: 'Mark as watched',
            size: CoreButtonSize.sm,
            onPressed: () => context.go(Routes.progress),
          ),
        ],
      ),
    );
  }
}

class _QuickTimerCard extends StatelessWidget {
  const _QuickTimerCard();

  @override
  Widget build(BuildContext context) {
    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CoreText.caption('QUICK TIMER'),
          const SizedBox(height: Sp.xs),
          const CoreText.bodySm(
            'A free-standing timer for ad-hoc work, outside the routine.',
          ),
          const SizedBox(height: Sp.md),
          CoreButton.secondary(
            label: 'Start',
            size: CoreButtonSize.sm,
            onPressed: () => context.go('${Routes.session}?quick=1'),
          ),
        ],
      ),
    );
  }
}

class _RecentSessionsCard extends ConsumerWidget {
  const _RecentSessionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref
        .watch(sessionRecordsProvider)
        .reversed
        .take(3)
        .toList();
    return CoreCard(
      onPressed: () => context.go(Routes.history),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CoreText.caption('RECENT SESSIONS'),
          const SizedBox(height: Sp.sm),
          if (sessions.isEmpty)
            const CoreText.bodySm('Nothing logged yet.')
          else
            for (final session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: CoreText.bodySm(session.startedAt.shortDayLabel),
                    ),
                    CoreText.mono('${session.actualMinutes} min'),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
