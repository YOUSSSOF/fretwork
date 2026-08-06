import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Drag to reorder the Home cards, tap the eye to hide one.
class HomeLayoutEditor extends ConsumerWidget {
  const HomeLayoutEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final order = prefs.resolvedOrder;

    return CoreCard(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: order.length,
        proxyDecorator: (child, index, animation) =>
            _LiftedCard(animation: animation, child: child),
        onReorder: (from, to) {
          HapticFeedback.selectionClick();
          final next = [...order];
          final moved = next.removeAt(from);
          next.insert(to > from ? to - 1 : to, moved);
          notifier.update((p) => p.copyWith(homeCardOrder: next));
        },
        itemBuilder: (context, index) {
          final card = order[index];
          final hidden = prefs.hiddenHomeCards.contains(card);
          return _CardRow(
            key: ValueKey(card),
            index: index,
            card: card,
            hidden: hidden,
            onToggle: () {
              final next = {...prefs.hiddenHomeCards};
              next.contains(card) ? next.remove(card) : next.add(card);
              notifier.update((p) => p.copyWith(hiddenHomeCards: next));
            },
          );
        },
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.index,
    required this.card,
    required this.hidden,
    required this.onToggle,
    super.key,
  });

  final int index;
  final HomeCardId card;
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 2),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.md),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: CoreText.body(
              card.label,
              color: hidden ? colors.textTertiary : colors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onToggle,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: hidden ? colors.textTertiary : colors.textSecondary,
            ),
            tooltip: hidden ? 'Show on Home' : 'Hide from Home',
          ),
        ],
      ),
    );
  }
}

/// The lifted card while dragging: scale up, shadow ramps in (§5.2).
class _LiftedCard extends StatelessWidget {
  const _LiftedCard({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (context.reduceMotion) {
      return Material(color: colors.surface2, child: child);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Motion.standard.transform(animation.value.clamp(0, 1));
        return Transform.scale(
          scale: 1 + 0.03 * t,
          child: Material(
            color: colors.surface2,
            elevation: 8 * t,
            shadowColor: Colors.black,
            child: child,
          ),
        );
      },
    );
  }
}
