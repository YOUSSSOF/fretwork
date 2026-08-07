import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/routine_day.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_ambient_glow.dart';
import 'package:fretwork/core/widgets/core_book_reference.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_icon_button.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_progress_ring.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';
import 'package:fretwork/features/session/session_controller.dart';
import 'package:fretwork/features/session/widgets/exercise_picker.dart';
import 'package:fretwork/features/session/widgets/metronome_dial.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// How long a second back press has to arrive within to actually leave.
const Duration kDoubleBackWindow = Duration(seconds: 2);

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({this.adHocExerciseId, this.adHocVariantId, super.key});

  /// Lets the exercise detail screen start a one-item session without going
  /// through today's routine.
  final String? adHocExerciseId;
  final String? adHocVariantId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ringTicker;
  double _itemProgress = 0;
  DateTime? _lastBackPress;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The ring runs off its own ticker rather than the controller's 1 Hz state
    // updates, so it stays smooth while the readout ticks once a second.
    _ringTicker = createTicker(_onFrame)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  @override
  void dispose() {
    _ringTicker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Anything other than "in front of the user" stops the clock and the
    // click. Time in another app is not practice time.
    if (state != AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).onBackgrounded();
    }
  }

  void _loadIfNeeded() {
    if (!mounted || ref.read(sessionProvider) != null) return;
    ref.read(sessionProvider.notifier).load(routine: _adHocRoutine());
  }

  /// Builds a one-item plan for "practise now" from the library.
  RoutineDay? _adHocRoutine() {
    final exerciseId = widget.adHocExerciseId;
    if (exerciseId == null) return null;
    final exercise = ref.read(exerciseByIdProvider(exerciseId));
    if (exercise == null) return null;

    final now = ref.read(clockProvider).now();
    return RoutineDay(
      date: now,
      milestone: 0,
      plannedMinutes: exercise.estimatedMinutes,
      generationSeed: 0,
      generatedAt: now,
      blocks: [
        RoutineBlock(
          category: exercise.category,
          label: exercise.category.label,
          minutes: exercise.estimatedMinutes,
          items: [
            RoutineItem(
              exerciseId: exercise.id,
              variantId: widget.adHocVariantId,
              minutes: exercise.estimatedMinutes,
              targetTempo: exercise.defaultTempo,
              procedure: exercise.procedure,
              focusNote: '',
            ),
          ],
        ),
      ],
    );
  }

  void _onFrame(Duration _) {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final duration = session.itemDuration;
    if (duration == Duration.zero) return;
    final elapsed = ref.read(sessionProvider.notifier).itemElapsed;
    final next = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    if ((next - _itemProgress).abs() < 0.0005) return;
    setState(() => _itemProgress = next);
  }

  /// Back leaves the session, but not on the first press.
  Future<void> _handleBack() async {
    final session = ref.read(sessionProvider);
    if (session == null || !session.hasStarted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < kDoubleBackWindow) {
      await ref.read(sessionProvider.notifier).end();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    _lastBackPress = now;
    ref.read(sessionProvider.notifier).pause();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Press back again to end the session'),
          duration: kDoubleBackWindow,
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.colors.surface2,
        ),
      );
  }

  /// Shown when an item's timer runs out, with what is coming next.
  Future<void> _showItemComplete(SessionState session) async {
    if (_promptOpen) return;
    _promptOpen = true;

    final go = await showCoreSheet<bool>(
      context: context,
      title: session.isLastItem ? 'Last item done' : 'Item complete',
      builder: (sheetContext) => _ItemCompleteSheet(session: session),
    );

    _promptOpen = false;
    if (!mounted) return;
    if (go == true) ref.read(sessionProvider.notifier).advance();
  }

  Future<void> _openPicker(SessionState session) async {
    final item = session.item;
    final block = session.block;
    if (item == null || block == null) return;

    final wasRunning = session.isRunning;
    if (wasRunning) ref.read(sessionProvider.notifier).pause();

    final chosen = await showExercisePicker(
      context: context,
      category: block.category,
      current: item,
      date: session.startedAt,
    );

    if (!mounted) return;
    if (chosen != null) {
      await ref.read(sessionProvider.notifier).chooseItem(chosen);
    }
    // Picking should not cost practice time, so the clock picks up where it
    // left off either way.
    if (wasRunning && mounted) ref.read(sessionProvider.notifier).resume();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(sessionProvider);

    ref.listen<SessionPhase?>(sessionProvider.select((s) => s?.phase), (
      _,
      phase,
    ) {
      if (phase != SessionPhase.itemComplete) return;
      final current = ref.read(sessionProvider);
      if (current != null) unawaited(_showItemComplete(current));
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: colors.surface0,
        body: Stack(
          children: [
            const Positioned.fill(child: CoreAmbientGlow(intensity: 1.4)),
            SafeArea(
              child: switch (session) {
                null => _Finished(onClose: () => Navigator.of(context).pop()),
                final s when !s.hasStarted => _ReadyToStart(
                  session: s,
                  onStart: ref.read(sessionProvider.notifier).start,
                  onClose: () => Navigator.of(context).pop(),
                ),
                final s => _RunningSession(
                  session: s,
                  itemProgress: _itemProgress,
                  onBack: _handleBack,
                  onPickExercise: () => _openPicker(s),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The pre-flight screen. Nothing runs until the user says so.
class _ReadyToStart extends ConsumerWidget {
  const _ReadyToStart({
    required this.session,
    required this.onStart,
    required this.onClose,
  });

  final SessionState session;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);
    final first = session.item;
    final exercise = first == null ? null : index[first.exerciseId];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.sm, Sp.sm, 0),
          child: Row(
            children: [
              CoreIconButton(
                icon: Icons.close_rounded,
                semanticLabel: 'Leave',
                onPressed: onClose,
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
            children: [
              const SizedBox(height: Sp.lg),
              CoreText.display('${session.routine.plannedMinutes} min'),
              const SizedBox(height: Sp.xs),
              CoreText.body(
                '${session.totalItems} items across '
                '${session.routine.blocks.length} blocks.',
              ),
              const SizedBox(height: Sp.xl),
              if (exercise != null) ...[
                const CoreText.label('STARTS WITH'),
                const SizedBox(height: Sp.sm),
                CoreCard(
                  glass: true,
                  child: _ItemSummary(
                    exercise: exercise,
                    item: first!,
                    showBook: true,
                  ),
                ),
              ],
              const SizedBox(height: Sp.lg),
              const CoreText.label('THE PLAN'),
              const SizedBox(height: Sp.sm),
              for (final block in session.routine.blocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Row(
                    children: [
                      Expanded(child: CoreText.bodySm(block.label)),
                      CoreText.mono('${block.minutes} min'),
                    ],
                  ),
                ),
              const SizedBox(height: Sp.huge),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Sp.lg),
          child: CoreButton.primary(
            label: 'Start session',
            size: CoreButtonSize.lg,
            fullWidth: true,
            leading: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return CoreEmptyState(
      icon: Icons.check_circle_outline_rounded,
      title: 'Session finished',
      message: 'Everything you practised has been logged.',
      action: CoreButton.primary(label: 'Done', onPressed: onClose),
    );
  }
}

class _ItemCompleteSheet extends ConsumerWidget {
  const _ItemCompleteSheet({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(exerciseIndexProvider);
    final done = session.item;
    final next = session.nextItem;
    final doneExercise = done == null ? null : index[done.exerciseId];
    final nextExercise = next == null ? null : index[next.exerciseId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (doneExercise != null && done != null)
          CoreCard(
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: context.colors.success,
                ),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: CoreText.title(
                    _labelFor(doneExercise, done.variantId),
                  ),
                ),
                CoreText.mono('${done.minutes} min'),
              ],
            ),
          ),
        const SizedBox(height: Sp.lg),
        if (nextExercise != null && next != null) ...[
          const CoreText.label('UP NEXT'),
          const SizedBox(height: Sp.sm),
          CoreCard(
            glass: true,
            child: _ItemSummary(
              exercise: nextExercise,
              item: next,
              showBook: true,
            ),
          ),
          const SizedBox(height: Sp.xl),
          CoreButton.primary(
            label: 'Go to next',
            size: CoreButtonSize.lg,
            fullWidth: true,
            trailing: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Sp.sm),
          CoreButton.ghost(
            label: 'Stay on this one',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ] else ...[
          const CoreText.body(
            'That was the last item. Finishing here saves the session.',
          ),
          const SizedBox(height: Sp.xl),
          CoreButton.primary(
            label: 'Finish session',
            size: CoreButtonSize.lg,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Sp.sm),
          CoreButton.ghost(
            label: 'Stay on this one',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
        const SizedBox(height: Sp.sm),
      ],
    );
  }
}

String _labelFor(Exercise exercise, String? variantId) {
  final variant = exercise.variantById(variantId);
  return variant == null
      ? exercise.label
      : '${exercise.label} · ${variant.label}';
}

class _ItemSummary extends StatelessWidget {
  const _ItemSummary({
    required this.exercise,
    required this.item,
    this.showBook = false,
  });

  final Exercise exercise;
  final RoutineItem item;
  final bool showBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreText.title(_labelFor(exercise, item.variantId)),
        const SizedBox(height: Sp.xs),
        CoreText.bodySm(exercise.title),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.xs,
          runSpacing: Sp.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CoreChip(label: '${item.minutes} min'),
            if (item.targetTempo > 0)
              CoreChip(label: '${item.targetTempo} bpm'),
            CoreChip(label: item.procedure.label),
            if (showBook && exercise.bookPage > 0)
              CoreBookReference(
                page: exercise.bookPage,
                cdTrack: exercise.cdTrack,
              ),
          ],
        ),
      ],
    );
  }
}

class _RunningSession extends ConsumerWidget {
  const _RunningSession({
    required this.session,
    required this.itemProgress,
    required this.onBack,
    required this.onPickExercise,
  });

  final SessionState session;
  final double itemProgress;
  final Future<void> Function() onBack;
  final VoidCallback onPickExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = session.item;
    final exercise = item == null
        ? null
        : ref.watch(exerciseByIdProvider(item.exerciseId));
    final detailed = session.mode == TimerMode.detailed;
    final waiting = session.phase == SessionPhase.itemComplete;

    return Column(
      children: [
        _ProgressRail(session: session),
        _Header(session: session, onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
            child: Column(
              children: [
                const SizedBox(height: Sp.lg),
                _TimerRing(session: session, progress: itemProgress),
                const SizedBox(height: Sp.xl),
                if (exercise != null && item != null)
                  _ExerciseHeadline(
                    exercise: exercise,
                    item: item,
                    detailed: detailed,
                    onPickExercise: onPickExercise,
                  ),
                if (detailed &&
                    item != null &&
                    item.procedure.usesMetronome &&
                    !waiting)
                  const _MetronomePanel(),
                const SizedBox(height: Sp.huge),
              ],
            ),
          ),
        ),
        _ControlBar(session: session),
      ],
    );
  }
}

/// A segmented rail across the very top: one segment per item, filling as the
/// session advances, so the user always knows how much is left.
class _ProgressRail extends StatelessWidget {
  const _ProgressRail({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 3,
      child: Row(
        children: [
          for (var i = 0; i < session.totalItems; i++)
            Expanded(
              child: AnimatedContainer(
                duration: context.motion(Motion.base),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  gradient: i < session.flatIndex
                      ? colors.accentGradientBright
                      : null,
                  color: i == session.flatIndex
                      ? colors.accentStrong.withValues(alpha: 0.5)
                      : (i < session.flatIndex ? null : colors.border),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.onBack});

  final SessionState session;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.sm, Sp.sm, 0),
      child: Row(
        children: [
          CoreIconButton(
            icon: Icons.close_rounded,
            semanticLabel: 'End session',
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                CoreText.label(session.block?.label ?? ''),
                CoreText.caption(
                  'Item ${session.flatIndex + 1} of ${session.totalItems}',
                ),
              ],
            ),
          ),
          const SizedBox(width: Layout.touchTarget),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.session, required this.progress});

  final SessionState session;
  final double progress;

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = switch (session.phase) {
      SessionPhase.paused => 'PAUSED',
      SessionPhase.itemComplete => 'DONE',
      _ => 'REMAINING',
    };
    final dimmed =
        session.isPaused || session.phase == SessionPhase.itemComplete;

    return CoreProgressRing(
      size: 240,
      progress: progress,
      secondaryProgress: session.sessionProgress,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoreText(
            _format(session.itemRemaining),
            style: CoreTextStyle.display,
            tabular: true,
            color: dimmed ? colors.textTertiary : null,
          ),
          CoreText.caption(label),
        ],
      ),
    );
  }
}

class _ExerciseHeadline extends StatelessWidget {
  const _ExerciseHeadline({
    required this.exercise,
    required this.item,
    required this.detailed,
    required this.onPickExercise,
  });

  final Exercise exercise;
  final RoutineItem item;
  final bool detailed;
  final VoidCallback onPickExercise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        // The whole title is the control: the generator's pick is a
        // suggestion, and swapping it should not be hidden behind a menu.
        CorePressable(
          onPressed: onPickExercise,
          pressedScale: 0.98,
          semanticLabel: 'Change exercise',
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.md,
              vertical: Sp.sm,
            ),
            decoration: BoxDecoration(border: Border.all(color: colors.border)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: CoreText.h3(
                    _labelFor(exercise, item.variantId),
                    align: TextAlign.center,
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.sm),
        CoreText.body(exercise.title, align: TextAlign.center),
        if (item.focusNote.isNotEmpty) ...[
          const SizedBox(height: Sp.md),
          CoreText.label(item.focusNote, color: colors.accentStrong),
        ],
        if (detailed) ...[
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.xs,
            runSpacing: Sp.xs,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CoreChip(label: exercise.procedure.label),
              if (exercise.bookPage > 0)
                CoreBookReference(
                  page: exercise.bookPage,
                  cdTrack: exercise.cdTrack,
                ),
              CoreChip(
                label: 'Tips',
                icon: Icons.lightbulb_outline_rounded,
                onPressed: () => _showTips(context, exercise),
              ),
            ],
          ),
        ],
        const SizedBox(height: Sp.lg),
      ],
    );
  }
}

/// Tips are behind a button, never pinned to the screen: a wall of instruction
/// during a timed item is something to read instead of playing.
Future<void> _showTips(BuildContext context, Exercise exercise) =>
    showCoreSheet<void>(
      context: context,
      title: exercise.label,
      subtitle: exercise.title,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoreText.body(exercise.summary),
          const SizedBox(height: Sp.lg),
          CoreText.label(exercise.procedure.label.toUpperCase()),
          const SizedBox(height: Sp.xs),
          CoreText.bodySm(exercise.procedure.hint),
          if (exercise.tips.isNotEmpty) ...[
            const SizedBox(height: Sp.lg),
            const CoreText.label('NOTES'),
            const SizedBox(height: Sp.xs),
            for (final tip in exercise.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.sm),
                child: CoreText.bodySm('· $tip'),
              ),
          ],
          if (exercise.bookPage > 0) ...[
            const SizedBox(height: Sp.lg),
            CoreBookReference(
              page: exercise.bookPage,
              cdTrack: exercise.cdTrack,
            ),
          ],
          const SizedBox(height: Sp.lg),
        ],
      ),
    );

class _MetronomePanel extends ConsumerWidget {
  const _MetronomePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);

    return Column(
      children: [
        MetronomeDial(state: metronome, onTempoChanged: notifier.setTempo),
        const SizedBox(height: Sp.lg),
        TempoStepRow(state: metronome, notifier: notifier),
        const SizedBox(height: Sp.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CoreButton.secondary(
              label: '+$kLadderStep bpm',
              onPressed: metronome.canGoFaster ? notifier.stepLadder : null,
            ),
            const SizedBox(width: Sp.sm),
            CoreIconButton(
              icon: metronome.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              semanticLabel: metronome.muted ? 'Unmute' : 'Mute',
              bordered: true,
              onPressed: () => notifier.setMuted(!metronome.muted),
            ),
          ],
        ),
        const SizedBox(height: Sp.lg),
        CoreSegmentedGrid<int>(
          items: [
            for (final subdivision in kSubdivisions)
              CoreSegmentedItem(
                value: subdivision,
                label: subdivisionLabel(subdivision),
              ),
          ],
          selected: {metronome.subdivision},
          onChanged: notifier.setSubdivision,
        ),
        const SizedBox(height: Sp.lg),
        CoreButton.secondary(
          label: 'Mark clean at ${metronome.bpm} bpm',
          leading: Icons.check_rounded,
          fullWidth: true,
          onPressed: () => ref.read(sessionProvider.notifier).markClean(),
        ),
      ],
    );
  }
}

String subdivisionLabel(int subdivision) => switch (subdivision) {
  1 => '1/4',
  2 => '1/8',
  3 => 'trip',
  4 => '1/16',
  6 => 'sext',
  _ => '1/32',
};

class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sessionProvider.notifier);

    // Once an item is done the transport is meaningless — the only thing left
    // to do is move on.
    if (session.phase == SessionPhase.itemComplete) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
        child: Row(
          children: [
            Expanded(
              child: CoreButton.secondary(
                label: '+30s more',
                size: CoreButtonSize.lg,
                fullWidth: true,
                onPressed: () => notifier.extend(const Duration(seconds: 30)),
              ),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              flex: 2,
              child: CoreButton.primary(
                label: session.isLastItem ? 'Finish' : 'Next exercise',
                size: CoreButtonSize.lg,
                fullWidth: true,
                trailing: Icons.arrow_forward_rounded,
                onPressed: notifier.advance,
              ),
            ),
          ],
        ),
      );
    }

    final paused = session.isPaused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CoreIconButton(
            icon: Icons.skip_next_rounded,
            semanticLabel: 'Skip this item',
            bordered: true,
            onPressed: notifier.skip,
          ),
          CoreButton.primary(
            label: paused ? 'Resume' : 'Pause',
            size: CoreButtonSize.lg,
            leading: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onPressed: notifier.togglePause,
          ),
          CoreButton.secondary(
            label: '+30s',
            onPressed: () => notifier.extend(const Duration(seconds: 30)),
          ),
          CoreIconButton(
            icon: Icons.check_rounded,
            semanticLabel: 'Finish this item',
            bordered: true,
            onPressed: notifier.completeItem,
          ),
        ],
      ),
    );
  }
}

/// Explicit tempo steps in both directions. The dial is faster for a big move,
/// but a poor way to take exactly one bpm off.
class TempoStepRow extends StatelessWidget {
  const TempoStepRow({required this.state, required this.notifier, super.key});

  final MetronomeState state;
  final MetronomeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TempoStep(
          label: '-5',
          enabled: state.canGoSlower,
          onPressed: () => notifier.nudge(-5),
        ),
        const SizedBox(width: Sp.sm),
        _TempoStep(
          label: '-1',
          enabled: state.canGoSlower,
          onPressed: () => notifier.nudge(-1),
        ),
        const SizedBox(width: Sp.md),
        CoreIconButton(
          icon: state.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          semanticLabel: state.running ? 'Stop the click' : 'Start the click',
          bordered: true,
          onPressed: notifier.toggle,
        ),
        const SizedBox(width: Sp.md),
        _TempoStep(
          label: '+1',
          enabled: state.canGoFaster,
          onPressed: () => notifier.nudge(1),
        ),
        const SizedBox(width: Sp.sm),
        _TempoStep(
          label: '+5',
          enabled: state.canGoFaster,
          onPressed: () => notifier.nudge(5),
        ),
      ],
    );
  }
}

class _TempoStep extends StatefulWidget {
  const _TempoStep({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_TempoStep> createState() => _TempoStepState();
}

class _TempoStepState extends State<_TempoStep> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    widget.onPressed();
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => widget.enabled ? widget.onPressed() : _stop(),
    );
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Listener(
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: CorePressable(
        onPressed: widget.enabled ? widget.onPressed : null,
        onLongPress: widget.enabled ? _start : null,
        semanticLabel: '${widget.label} beats per minute',
        child: Container(
          width: Layout.touchTarget,
          height: Layout.touchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface1,
            border: Border.all(color: colors.border),
          ),
          child: CoreText.label(
            widget.label,
            color: widget.enabled ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
