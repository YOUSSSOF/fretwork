import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_ambient_glow.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_slider.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/onboarding/onboarding_controller.dart';
import 'package:fretwork/features/onboarding/widgets/block_split_preview.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const int _stepCount = 4;

class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final draft = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final pageController = usePageController();
    final pageOffset = useState(0.0);

    useEffect(() {
      void listener() =>
          pageOffset.value = pageController.page ?? draft.step.toDouble();
      pageController.addListener(listener);
      return () => pageController.removeListener(listener);
    }, [pageController]);

    // The draft's step is the single source of truth; the PageView follows it.
    // Driving the controller directly from the button instead would leave the
    // two able to disagree, and anything else that moved the step — a deep
    // link, a restored draft — would not move the page.
    final reduced = context.reduceMotion;
    useEffect(() {
      if (!pageController.hasClients) return null;
      if (pageController.page?.round() == draft.step) return null;
      if (reduced) {
        pageController.jumpToPage(draft.step);
      } else {
        unawaited(
          pageController.animateToPage(
            draft.step,
            duration: Motion.page,
            curve: Motion.emphasize,
          ),
        );
      }
      return null;
    }, [draft.step, reduced]);

    void goTo(int step) => controller.goToStep(step);

    return Scaffold(
      backgroundColor: colors.surface0,
      body: Stack(
        children: [
          // Parallax: the glow travels at 0.4x the page velocity, which reads
          // as depth without anything obviously "moving".
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(-pageOffset.value * 40, 0),
              child: const CoreAmbientGlow(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Progress(step: draft.step),
                Expanded(
                  child: PageView(
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const _WelcomeStep(),
                      _MilestoneStep(onSelected: controller.selectMilestone),
                      const _LengthStep(),
                      const _FirstRoutineStep(),
                    ],
                  ),
                ),
                _Footer(draft: draft, goTo: goTo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
      child: Row(
        children: [
          for (var i = 0; i < _stepCount; i++)
            Expanded(
              child: AnimatedContainer(
                duration: context.motion(Motion.base),
                curve: Motion.standard,
                height: 3,
                margin: EdgeInsetsDirectional.only(
                  end: i == _stepCount - 1 ? 0 : Sp.xs,
                ),
                decoration: BoxDecoration(
                  gradient: i <= step ? colors.accentGradientBright : null,
                  color: i <= step ? null : colors.border,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Sp.lg),
      children: const [
        SizedBox(height: Sp.xxl),
        CoreText.display('Fretwork'),
        SizedBox(height: Sp.lg),
        CoreText.body(
          'A practice companion for a technique course you already own. It '
          'builds a routine every day, runs the session with a timer and a '
          'metronome, and keeps an honest record of what you actually did.',
        ),
        SizedBox(height: Sp.xl),
        CoreCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoreText.title('Keep the book to hand'),
              SizedBox(height: Sp.sm),
              CoreText.bodySm(
                'Fretwork schedules and tracks — it does not reproduce the '
                'music. Each exercise points at a page and a track, and the '
                'book stays open next to the phone. That is the workflow, not '
                'a limitation.',
              ),
            ],
          ),
        ),
        SizedBox(height: Sp.lg),
        CoreCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoreText.title('Nothing leaves the device'),
              SizedBox(height: Sp.sm),
              CoreText.bodySm(
                'No account, no network, no analytics. Everything is stored '
                'locally and exported only when you ask for it.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneStep extends ConsumerWidget {
  const _MilestoneStep({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final courseParts = [
      for (final part in ref.watch(courseProvider))
        if (part.id != 'part_free') part,
    ]..sort((a, b) => a.milestone.compareTo(b.milestone));

    return ListView(
      padding: const EdgeInsets.all(Sp.lg),
      children: [
        const CoreText.h1('How far have you got?'),
        const SizedBox(height: Sp.sm),
        const CoreText.body(
          'Pick the last part you have worked through. Everything up to and '
          'including it unlocks; the rest stays visible but locked.',
        ),
        const SizedBox(height: Sp.xl),
        for (final part in courseParts)
          _MilestoneTile(
            part: part,
            selected: draft.milestone == part.milestone,
            onPressed: () => onSelected(part.milestone),
          ),
        const SizedBox(height: Sp.xl),
      ],
    );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({
    required this.part,
    required this.selected,
    required this.onPressed,
  });

  final CoursePart part;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final categories = ref.watch(categoriesAtMilestoneProvider(part.milestone));

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: CoreCard(
        onPressed: onPressed,
        borderColor: selected ? colors.accentStrong : null,
        padding: const EdgeInsets.all(Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: CoreText.title(part.label)),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colors.accentStrong,
                  ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            CoreText.bodySm(part.blurb),
            // The expansion is the payoff for choosing: it shows what the
            // routine would actually contain.
            _Expandable(
              expanded: selected,
              child: Padding(
                padding: const EdgeInsets.only(top: Sp.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CoreDivider(),
                    const SizedBox(height: Sp.md),
                    const CoreText.caption('UNLOCKS'),
                    const SizedBox(height: Sp.sm),
                    Wrap(
                      spacing: Sp.xs,
                      runSpacing: Sp.xs,
                      children: [
                        for (final category in categories)
                          CoreChip(
                            label: category.label,
                            dotColor: colors.categoryColor(category.index, 11),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Height animation that removes itself entirely under reduced motion.
///
/// [AnimatedSize] with a zero duration re-dirties itself inside its own
/// performLayout, which Flutter asserts on — so "animate over zero" is not a
/// legal way to express "do not animate".
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

class _LengthStep extends ConsumerWidget {
  const _LengthStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final draft = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final milestone = draft.milestone ?? 2;
    final available = ref.watch(categoriesAtMilestoneProvider(milestone));

    final split = allocateMinutes(
      milestone: milestone,
      sessionMinutes: draft.resolvedMinutes,
      available: available,
    );

    return ListView(
      padding: const EdgeInsets.all(Sp.lg),
      children: [
        const CoreText.h1('How long can you practise?'),
        const SizedBox(height: Sp.sm),
        CoreText.body(
          'The course suggests ${draft.suggestedMinutes} minutes at this '
          'stage. Change it to whatever you can actually keep to.',
        ),
        const SizedBox(height: Sp.xl),
        CoreSlider(
          value: draft.resolvedMinutes.toDouble(),
          min: kMinSessionMinutes.toDouble(),
          max: kMaxSessionMinutes.toDouble(),
          divisions: kMaxSessionMinutes - kMinSessionMinutes,
          suggestion: draft.suggestedMinutes.toDouble(),
          label: 'Session length',
          formatValue: (v) => '${v.round()} min',
          onChanged: (value) => controller.setSessionMinutes(value.round()),
        ),
        if (draft.isWellBelowSuggestion) ...[
          const SizedBox(height: Sp.md),
          CoreCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: Sp.sm),
                const Expanded(
                  child: CoreText.bodySm(
                    'That is well under the suggestion — which is fine. '
                    'Consistency beats duration: a short session done daily '
                    'outperforms a long one done three times a week.',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Sp.xl),
        const CoreText.label('YOUR SESSION'),
        const SizedBox(height: Sp.md),
        BlockSplitPreview(split: split),
        const SizedBox(height: Sp.xl),
        const CoreText.label('REST DAYS'),
        const SizedBox(height: Sp.sm),
        const CoreText.bodySm(
          'Rest days do not break a streak and are left out of your adherence.',
        ),
        const SizedBox(height: Sp.md),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [
            for (final weekday in kAllWeekdays)
              CoreChip(
                label: weekdayShortName(weekday),
                selected: draft.restWeekdays.contains(weekday),
                onPressed: () => controller.toggleRestWeekday(weekday),
              ),
          ],
        ),
        const SizedBox(height: Sp.xl),
      ],
    );
  }
}

class _FirstRoutineStep extends ConsumerWidget {
  const _FirstRoutineStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final milestone = draft.milestone ?? 2;
    final parts = [
      for (final part in ref.watch(courseProvider))
        if (part.milestone <= milestone) part,
    ];

    final generated = generateRoutine(
      date: DateTime.now(),
      milestone: milestone,
      sessionMinutes: draft.resolvedMinutes,
      unlockedParts: parts,
      cursors: const {},
      tempos: const {},
      seed: 0,
      restWeekdays: draft.restWeekdays,
    );
    final index = ref.watch(exerciseIndexProvider);

    return ListView(
      padding: const EdgeInsets.all(Sp.lg),
      children: [
        const CoreText.h1('Your first routine'),
        const SizedBox(height: Sp.sm),
        CoreText.body(
          generated.day.isRestDay
              ? 'Today is one of your rest days, so there is nothing to do. '
                    'The routine starts tomorrow.'
              : '${generated.day.plannedMinutes} minutes across '
                    '${generated.day.blocks.length} blocks. It is rebuilt every '
                    'day, and again whenever you advance a part.',
        ),
        const SizedBox(height: Sp.xl),
        for (var i = 0; i < generated.day.blocks.length; i++)
          _StaggeredBlock(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm),
              child: CoreCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CoreText.title(generated.day.blocks[i].label),
                        ),
                        CoreText.mono('${generated.day.blocks[i].minutes} min'),
                      ],
                    ),
                    const SizedBox(height: Sp.sm),
                    for (final item in generated.day.blocks[i].items)
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.xs),
                        child: CoreText.bodySm(
                          _itemLine(
                            index,
                            item.exerciseId,
                            item.variantId,
                            item.minutes,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: Sp.xl),
      ],
    );
  }

  static String _itemLine(
    Map<String, Exercise> index,
    String exerciseId,
    String? variantId,
    int minutes,
  ) {
    final exercise = index[exerciseId];
    final variant = exercise?.variantById(variantId);
    final label = exercise?.label ?? exerciseId;
    final suffix = variant == null ? '' : ' · ${variant.label}';
    return '$label$suffix — $minutes min';
  }
}

/// One of the two entrance animations the plan allows: the first paint of a
/// newly generated routine (§5.3).
class _StaggeredBlock extends StatelessWidget {
  const _StaggeredBlock({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow + Motion.stagger * index,
      curve: Interval(
        (index * 0.08).clamp(0.0, 0.6),
        1,
        curve: Motion.emphasize,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.draft, required this.goTo});

  final OnboardingDraft draft;
  final void Function(int step) goTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLast = draft.step == _stepCount - 1;
    // The milestone step has no default on purpose: guessing how far through
    // the course someone is would misconfigure everything downstream.
    final blocked = draft.step == 1 && !draft.canLeaveMilestoneStep;

    return Padding(
      padding: const EdgeInsets.all(Sp.lg),
      child: Row(
        children: [
          if (draft.step > 0)
            CoreButton.ghost(
              label: 'Back',
              onPressed: () => goTo(draft.step - 1),
            ),
          const Spacer(),
          CoreButton.primary(
            label: isLast ? 'Start practising' : 'Continue',
            size: CoreButtonSize.lg,
            onPressed: blocked
                ? null
                : () async {
                    if (!isLast) {
                      goTo(draft.step + 1);
                      return;
                    }
                    await ref
                        .read(profileProvider.notifier)
                        .completeOnboarding(
                          milestone: draft.milestone ?? 2,
                          sessionMinutes: draft.resolvedMinutes,
                          restWeekdays: draft.restWeekdays,
                        );
                  },
          ),
        ],
      ),
    );
  }
}
