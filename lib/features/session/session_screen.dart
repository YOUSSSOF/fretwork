import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fretwork/core/data/course_providers.dart';
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
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_icon_button.dart';
import 'package:fretwork/core/widgets/core_progress_ring.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';
import 'package:fretwork/features/session/session_controller.dart';
import 'package:fretwork/features/session/widgets/metronome_dial.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The ring runs off its own ticker rather than the controller's 1 Hz state
    // updates, so it stays smooth while the numeric readout ticks once a
    // second (§5.2).
    _ringTicker = createTicker(_onFrame)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  @override
  void dispose() {
    _ringTicker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(sessionProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.onBackgrounded();
      return;
    }
    if (state == AppLifecycleState.resumed && notifier.onResumed()) {
      _showBackgroundPrompt();
    }
  }

  void _startIfNeeded() {
    if (!mounted) return;
    if (ref.read(sessionProvider) != null) return;

    final adHoc = _adHocRoutine();
    ref.read(sessionProvider.notifier).start(routine: adHoc);
  }

  /// Builds a one-item plan for "practise now" from the library.
  RoutineDay? _adHocRoutine() {
    final exerciseId = widget.adHocExerciseId;
    if (exerciseId == null) return null;
    final exercise = ref.read(exerciseByIdProvider(exerciseId));
    if (exercise == null) return null;

    final now = DateTime.now();
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

  Future<void> _showBackgroundPrompt() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CoreDialog(
        title: 'Paused while you were away',
        message:
            'The app was in the background for more than ten minutes, so the '
            'session was paused rather than counting that time as practice.',
        actions: [
          CoreButton.primary(
            label: 'Got it',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final session = ref.read(sessionProvider);
    if (session == null) return true;

    final choice = await showCoreSheet<String>(
      context: context,
      title: 'End the session?',
      subtitle: 'What you have done so far is kept either way',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoreButton.secondary(
            label: 'Keep practising',
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop('stay'),
          ),
          const SizedBox(height: Sp.sm),
          CoreButton.destructive(
            label: 'End and save',
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop('end'),
          ),
          const SizedBox(height: Sp.sm),
        ],
      ),
    );

    if (choice != 'end') return false;
    await ref.read(sessionProvider.notifier).end();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(sessionProvider);

    return PopScope(
      canPop: session == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (!leave || !mounted) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        backgroundColor: colors.surface0,
        body: Stack(
          children: [
            const Positioned.fill(child: CoreAmbientGlow(intensity: 1.4)),
            SafeArea(
              child: session == null
                  ? _EmptySession(onClose: () => Navigator.of(context).pop())
                  : _RunningSession(
                      session: session,
                      itemProgress: _itemProgress,
                      onExit: () async {
                        final leave = await _confirmExit();
                        if (!leave || !mounted) return;
                        Navigator.of(this.context).pop();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySession extends StatelessWidget {
  const _EmptySession({required this.onClose});

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

class _RunningSession extends ConsumerWidget {
  const _RunningSession({
    required this.session,
    required this.itemProgress,
    required this.onExit,
  });

  final SessionState session;
  final double itemProgress;
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = session.item;
    final exercise = item == null
        ? null
        : ref.watch(exerciseByIdProvider(item.exerciseId));
    final variant = exercise?.variantById(item?.variantId);
    final detailed = session.mode == TimerMode.detailed;

    return Column(
      children: [
        _ProgressRail(session: session),
        _Header(session: session, onExit: onExit),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
            child: Column(
              children: [
                const SizedBox(height: Sp.lg),
                _TimerRing(session: session, progress: itemProgress),
                const SizedBox(height: Sp.xl),
                if (exercise != null)
                  _ExerciseHeadline(
                    exercise: exercise,
                    variant: variant,
                    focusNote: item?.focusNote ?? '',
                    detailed: detailed,
                  ),
                if (detailed && item != null && item.procedure.usesMetronome)
                  const _MetronomePanel(),
                const SizedBox(height: Sp.huge),
              ],
            ),
          ),
        ),
        _ControlBar(session: session, onExit: onExit),
      ],
    );
  }
}

/// A segmented rail across the very top: one segment per item, filling as the
/// session advances, so the user always knows how much is left without doing
/// arithmetic.
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
  const _Header({required this.session, required this.onExit});

  final SessionState session;
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.sm, Sp.sm, 0),
      child: Row(
        children: [
          CoreIconButton(
            icon: Icons.close_rounded,
            semanticLabel: 'End session',
            onPressed: onExit,
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

class _TimerRing extends ConsumerWidget {
  const _TimerRing({required this.session, required this.progress});

  final SessionState session;
  final double progress;

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = session.phase == SessionPhase.paused;
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
            color: paused ? context.colors.textTertiary : null,
          ),
          CoreText.caption(paused ? 'PAUSED' : 'REMAINING'),
        ],
      ),
    );
  }
}

class _ExerciseHeadline extends StatelessWidget {
  const _ExerciseHeadline({
    required this.exercise,
    required this.variant,
    required this.focusNote,
    required this.detailed,
  });

  final Exercise exercise;
  final ExerciseVariant? variant;
  final String focusNote;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        CoreText.h2(
          variant == null
              ? exercise.label
              : '${exercise.label} · ${variant!.label}',
          align: TextAlign.center,
        ),
        const SizedBox(height: Sp.xs),
        CoreText.body(exercise.title, align: TextAlign.center),
        if (focusNote.isNotEmpty) ...[
          const SizedBox(height: Sp.md),
          CoreText.label(focusNote, color: colors.accentStrong),
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

/// Tips are behind a button, never pinned to the screen (§18.5): a wall of
/// instruction during a timed item is something to read instead of playing.
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CoreIconButton(
              icon: metronome.running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              semanticLabel: metronome.running
                  ? 'Stop the click'
                  : 'Start the click',
              bordered: true,
              onPressed: notifier.toggle,
            ),
            const SizedBox(width: Sp.sm),
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
                label: switch (subdivision) {
                  1 => '1/4',
                  2 => '1/8',
                  3 => 'trip',
                  4 => '1/16',
                  6 => 'sext',
                  _ => '1/32',
                },
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

class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.session, required this.onExit});

  final SessionState session;
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sessionProvider.notifier);
    final paused = session.phase == SessionPhase.paused;

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
            onPressed: notifier.next,
          ),
        ],
      ),
    );
  }
}
