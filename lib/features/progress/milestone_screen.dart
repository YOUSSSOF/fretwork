import 'package:flutter/material.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/onboarding/onboarding_controller.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _PartState { unlocked, next, locked }

/// The course as a vertical timeline, and the place where advancing happens.
class MilestoneScreen extends ConsumerWidget {
  const MilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final parts = [
      for (final part in ref.watch(courseProvider))
        if (part.id != 'part_free') part,
    ]..sort((a, b) => a.milestone.compareTo(b.milestone));

    return CoreScaffold(
      title: 'Progress',
      subtitle: 'Milestone ${profile.milestone} of $kMaxMilestone',
      showBack: true,
      glow: true,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Sp.lg),
        children: [
          const CoreText.body(
            'Mark a part as watched once you have actually worked through it. '
            'Advancing unlocks its exercises and rebalances every routine from '
            'today onwards.',
          ),
          const SizedBox(height: Sp.xl),
          for (final part in parts)
            _TimelineRow(
              part: part,
              state: _stateFor(part.milestone, profile.milestone),
              isLast: part == parts.last,
            ),
          const SizedBox(height: Sp.xl),
          if (profile.milestone > 0) const _DowngradeRow(),
        ],
      ),
    );
  }

  static _PartState _stateFor(int partMilestone, int current) {
    if (partMilestone <= current) return _PartState.unlocked;
    if (partMilestone == current + 1) return _PartState.next;
    return _PartState.locked;
  }
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({
    required this.part,
    required this.state,
    required this.isLast,
  });

  final CoursePart part;
  final _PartState state;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unlocked = state == _PartState.unlocked;
    final isNext = state == _PartState.next;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(unlocked: unlocked, isNext: isNext, isLast: isLast),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.lg),
              child: CoreCard(
                padding: const EdgeInsets.all(Sp.md),
                borderColor: isNext ? colors.accentStrong : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CoreText.title(
                            part.label,
                            color: state == _PartState.locked
                                ? colors.textTertiary
                                : null,
                          ),
                        ),
                        if (unlocked)
                          const CoreBadge('Unlocked')
                        else if (isNext)
                          const CoreBadge('Next')
                        else
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                      ],
                    ),
                    // A locked part shows its label only — the road ahead is
                    // visible but not browsable.
                    if (state != _PartState.locked) ...[
                      const SizedBox(height: Sp.xs),
                      CoreText.bodySm(part.blurb),
                      const SizedBox(height: Sp.sm),
                      _Contribution(part: part),
                    ],
                    if (isNext) ...[
                      const SizedBox(height: Sp.md),
                      CoreButton.secondary(
                        label:
                            "I've finished ${part.label.split('—').first.trim()}",
                        size: CoreButtonSize.sm,
                        onPressed: () => _confirmAdvance(context, ref, part),
                      ),
                    ],
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

class _Rail extends StatelessWidget {
  const _Rail({
    required this.unlocked,
    required this.isNext,
    required this.isLast,
  });

  final bool unlocked;
  final bool isNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 16,
      child: Column(
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: Sp.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? colors.accentStrong : Colors.transparent,
              border: Border.all(
                color: unlocked || isNext ? colors.accentStrong : colors.border,
                width: 2,
              ),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: Sp.xs),
                color: unlocked ? colors.accentStrong : colors.border,
              ),
            ),
        ],
      ),
    );
  }
}

class _Contribution extends StatelessWidget {
  const _Contribution({required this.part});

  final CoursePart part;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = part.categories;
    if (categories.isEmpty) {
      return const CoreText.caption('No drills — reading only');
    }
    return Wrap(
      spacing: Sp.xs,
      runSpacing: Sp.xs,
      children: [
        for (final category in categories)
          CoreChip(
            label: category.label,
            dotColor: colors.categoryColor(
              category.index,
              PracticeCategory.values.length,
            ),
          ),
        CoreChip(label: '${part.exercises.length} exercises'),
      ],
    );
  }
}

/// Advancing is deliberate and confirmed: the sheet says what changes before
/// anything does.
Future<void> _confirmAdvance(
  BuildContext context,
  WidgetRef ref,
  CoursePart part,
) async {
  final profile = ref.read(profileProvider);
  final before = ref.read(categoriesAtMilestoneProvider(profile.milestone));
  final after = ref.read(categoriesAtMilestoneProvider(part.milestone));
  final gained = after.difference(before);
  final suggested = UserProfile.suggestedMinutes(part.milestone);

  final confirmed = await showCoreSheet<bool>(
    context: context,
    title: 'Advance to ${part.label}?',
    subtitle: 'This changes your routine from today onwards',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gained.isNotEmpty) ...[
          const CoreText.label('NEW IN YOUR ROUTINE'),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: Sp.xs,
            runSpacing: Sp.xs,
            children: [
              for (final category in gained) CoreChip(label: category.label),
            ],
          ),
          const SizedBox(height: Sp.lg),
        ],
        const CoreText.label('WHAT CHANGES'),
        const SizedBox(height: Sp.sm),
        CoreText.bodySm(
          'Warm-up shrinks as a share of the session to make room. '
          '${part.exercises.length} exercises become available. '
          '${suggested == profile.sessionMinutes ? 'Your session length still suits this stage.' : 'The course suggests $suggested minutes at this stage — yours is ${profile.sessionMinutes}. You can change it in Settings.'}',
        ),
        const SizedBox(height: Sp.xl),
        Row(
          children: [
            Expanded(
              child: CoreButton.ghost(
                label: 'Cancel',
                fullWidth: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: CoreButton.primary(
                label: 'Advance',
                fullWidth: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.sm),
      ],
    ),
  );

  if (confirmed != true) return;
  await ref.read(profileProvider.notifier).setMilestone(part.milestone);
}

class _DowngradeRow extends ConsumerWidget {
  const _DowngradeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Padding(
      padding: const EdgeInsets.only(top: Sp.lg),
      child: CoreButton.ghost(
        label: 'Step back a part',
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => CoreDialog(
              title: 'Step back to milestone ${profile.milestone - 1}?',
              message:
                  'Content above that level is hidden again and your routine '
                  'rebalances. Nothing you have already logged is deleted — '
                  'your history and tempo records are kept.',
              actions: [
                CoreButton.ghost(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                CoreButton.destructive(
                  label: 'Step back',
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await ref
              .read(profileProvider.notifier)
              .setMilestone(profile.milestone - 1);
        },
      ),
    );
  }
}

/// Staggered entrance for newly unlocked cards (§5.3). Used by the summary that
/// follows an advance.
class UnlockStagger extends StatelessWidget {
  const UnlockStagger({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Motion.stagger * index,
      curve: Motion.bouncyCurve,
      builder: (context, t, child) => Transform.scale(
        scale: 0.9 + 0.1 * t,
        child: Opacity(opacity: t, child: child),
      ),
      child: child,
    );
  }
}
