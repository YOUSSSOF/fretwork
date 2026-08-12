import 'package:flutter/material.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/glass.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_slider.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/onboarding/widgets/block_split_preview.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/routine/routine_service.dart';
import 'package:fretwork/features/routine/widgets/routine_block_card.dart';
import 'package:fretwork/features/session/active_session_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:fretwork/router.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  DateTime? _viewing;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(clockProvider).now().dayStart;
    final selected = _viewing ?? today;
    final isToday = selected.isSameDayAs(today);
    final routine = isToday
        ? ref.watch(todayRoutineProvider)
        : ref.watch(routineForDateProvider(selected));
    final completed = isToday
        ? ref.watch(completedTodayProvider)
        : const <String>{};

    return CoreScaffold(
      title: 'Routine',
      subtitle: selected.shortDayLabel,
      glow: true,
      body: Column(
        children: [
          const SizedBox(height: Sp.lg),
          _WeekStrip(
            today: today,
            selected: selected,
            onSelected: (date) => setState(
              () => _viewing = date.isSameDayAs(today) ? null : date,
            ),
          ),
          const SizedBox(height: Sp.md),
          Expanded(
            child: _Body(
              routine: routine,
              selected: selected,
              today: today,
              completed: completed,
            ),
          ),
        ],
      ),
      // The action bar floats over the list rather than sitting in the
      // Scaffold's bottom slot: the shell's own nav bar already owns that
      // space, and two bars stacked there overlapped.
      floating: isToday && routine != null && !routine.isRestDay
          ? _ActionBar(routine: routine)
          : null,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.routine,
    required this.selected,
    required this.today,
    required this.completed,
  });

  final RoutineDay? routine;
  final DateTime selected;
  final DateTime today;
  final Set<String> completed;

  @override
  Widget build(BuildContext context) {
    final day = routine;
    if (day == null) {
      return const CoreEmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No plan for this day',
        message:
            'Days before you started using Fretwork have no recorded routine.',
      );
    }

    if (day.isRestDay) {
      return const _RestDayCard();
    }

    final provisional = isProvisional(selected, today);

    return ListView(
      padding: EdgeInsets.only(
        top: Sp.md,
        bottom: context.shellBottomInset + _ActionBar.height + Sp.xl,
      ),
      children: [
        if (provisional)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: CoreCard(
              padding: const EdgeInsets.all(Sp.md),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: context.colors.textTertiary,
                  ),
                  const SizedBox(width: Sp.sm),
                  const Expanded(
                    child: CoreText.bodySm(
                      'Provisional. This is rebuilt on the day from wherever '
                      'your rotation has reached by then.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(child: CoreText.h2('${day.plannedMinutes} minutes')),
            CoreText.caption('${day.blocks.length} blocks'),
          ],
        ),
        const SizedBox(height: Sp.lg),
        for (var i = 0; i < day.blocks.length; i++)
          RoutineBlockCard(
            key: ValueKey('${day.id}-${day.blocks[i].category.name}'),
            block: day.blocks[i],
            completedKeys: completed,
          ),
      ],
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: CoreCard(
          glass: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 28,
                color: context.colors.accentStrong,
              ),
              const SizedBox(height: Sp.lg),
              const CoreText.h2('Rest day'),
              const SizedBox(height: Sp.sm),
              const CoreText.body(
                'Adaptation happens now, not during the session. This does not '
                'break your streak and is left out of your adherence.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({
    required this.today,
    required this.selected,
    required this.onSelected,
  });

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // Five days back, today, and tomorrow.
    final days = [
      for (var offset = -5; offset <= 1; offset++)
        today.add(Duration(days: offset)),
    ];

    return SizedBox(
      height: 62,
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: CorePressable(
                onPressed: () => onSelected(day),
                pressedScale: 0.9,
                dim: 0,
                semanticLabel: day.shortDayLabel,
                child: AnimatedContainer(
                  duration: context.motion(Motion.fast),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: day.isSameDayAs(selected)
                        ? colors.selection
                        : Colors.transparent,
                    border: Border.all(
                      color: day.isSameDayAs(selected)
                          ? colors.accentStrong
                          : colors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CoreText.caption(day.weekdayLabel),
                      const SizedBox(height: 2),
                      CoreText.label('${day.day}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.routine});

  final RoutineDay routine;

  /// Content height, before the device inset. The list reserves this so items
  /// can always be scrolled clear of the bar.
  static const double height = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final resumable = ref.watch(resumableSessionProvider) != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.shellBottomInset),
        child: GlassSurface(
          enhanced: true,
          bordered: false,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.lg,
              vertical: Sp.md,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CoreButton.primary(
                    label: resumable ? 'Resume session' : 'Start session',
                    size: CoreButtonSize.lg,
                    fullWidth: true,
                    leading: Icons.play_arrow_rounded,
                    onPressed: () => context.go(Routes.session),
                  ),
                ),
                const SizedBox(width: Sp.sm),
                CoreButton.secondary(
                  label: 'Length',
                  size: CoreButtonSize.lg,
                  leading: Icons.tune_rounded,
                  onPressed: () => _adjustLength(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _adjustLength(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider);
  var minutes = profile.sessionMinutes;

  await showCoreSheet<void>(
    context: context,
    title: 'Session length',
    subtitle: 'Applies from today onwards',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final split = allocateMinutes(
          milestone: profile.milestone,
          sessionMinutes: minutes,
          available: ref
              .read(todayRoutineProvider)
              .blocks
              .map((b) => b.category)
              .toSet(),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreSlider(
              value: minutes.toDouble(),
              min: kMinSessionMinutes.toDouble(),
              max: kMaxSessionMinutes.toDouble(),
              divisions: kMaxSessionMinutes - kMinSessionMinutes,
              suggestion: UserProfile.suggestedMinutes(
                profile.milestone,
              ).toDouble(),
              label: 'Minutes',
              formatValue: (v) => '${v.round()} min',
              onChanged: (value) => setState(() => minutes = value.round()),
            ),
            const SizedBox(height: Sp.lg),
            BlockSplitPreview(split: split, showLabels: false),
            const SizedBox(height: Sp.xl),
            CoreButton.primary(
              label: 'Apply and rebuild',
              fullWidth: true,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await ref
                    .read(profileProvider.notifier)
                    .setSessionMinutes(minutes);
                // Always rebuild, even if the number did not move: the plan
                // can be over budget for reasons other than the slider.
                await ref.read(todayRoutineProvider.notifier).regenerate();
              },
            ),
            const SizedBox(height: Sp.sm),
          ],
        );
      },
    ),
  );
}
