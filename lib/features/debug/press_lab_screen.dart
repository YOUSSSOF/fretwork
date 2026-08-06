import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';

/// Phase 1 deliverable: a themed screen whose only job is to let the press
/// physics be judged on a real device before anything else is built on top of
/// them. Kept in the repo because it stays useful for feel regressions.
class PressLabScreen extends ConsumerWidget {
  const PressLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final prefs = ref.watch(preferencesProvider);

    return CoreScaffold(
      title: 'Press lab',
      subtitle: 'Phase 1 — foundation',
      glow: true,
      body: ListView(
        padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.huge),
        children: [
          const CoreText.h1('Everything inherits this.'),
          const SizedBox(height: Sp.sm),
          const CoreText.body(
            'Press and hold, then drag your finger off the target. It should '
            'settle back with a spring, not snap.',
          ),
          const SizedBox(height: Sp.xl),
          Wrap(
            spacing: Sp.md,
            runSpacing: Sp.md,
            children: [
              CoreButton.primary(label: 'Primary', onPressed: () {}),
              CoreButton.secondary(label: 'Secondary', onPressed: () {}),
              CoreButton.ghost(label: 'Ghost', onPressed: () {}),
              CoreButton.destructive(label: 'Destructive', onPressed: () {}),
              const CoreButton.primary(label: 'Disabled'),
              const CoreButton.primary(label: 'Loading', loading: true),
            ],
          ),
          const SizedBox(height: Sp.xl),
          CoreCard(
            glass: true,
            onPressed: () {},
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreText.title('Glass card'),
                SizedBox(height: Sp.xs),
                CoreText.bodySm(
                  'Corner accents grow on press. Blur is real here — this is '
                  'one of the six per screen the budget allows.',
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.md),
          CoreCard(
            onPressed: () {},
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreText.title('Flat card'),
                SizedBox(height: Sp.xs),
                CoreText.bodySm(
                  'The variant used inside scrolling lists — same colour, no '
                  'backdrop filter.',
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.xl),
          const CoreText.label('ACCENT'),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              for (final palette in accentPalettes)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Sp.sm),
                  child: CoreButton(
                    label: palette.label,
                    size: CoreButtonSize.sm,
                    variant: prefs.accentPaletteId == palette.id
                        ? CoreButtonVariant.primary
                        : CoreButtonVariant.secondary,
                    onPressed: () => ref
                        .read(preferencesProvider.notifier)
                        .update((p) => p.copyWith(accentPaletteId: palette.id)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          const CoreText.label('TYPE SCALE'),
          const SizedBox(height: Sp.sm),
          for (final style in CoreTextStyleSamples.all)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.xs),
              child: CoreText(style.$2, style: style.$1),
            ),
          const SizedBox(height: Sp.xl),
          Container(height: 1, color: colors.border),
          const SizedBox(height: Sp.md),
          CoreButton.secondary(
            label: prefs.reduceMotion == ReduceMotionSetting.on
                ? 'Reduced motion: on'
                : 'Reduced motion: off',
            onPressed: () => ref
                .read(preferencesProvider.notifier)
                .update(
                  (p) => p.copyWith(
                    reduceMotion: p.reduceMotion == ReduceMotionSetting.on
                        ? ReduceMotionSetting.off
                        : ReduceMotionSetting.on,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

abstract final class CoreTextStyleSamples {
  static const List<(CoreTextStyle, String)> all = [
    (CoreTextStyle.display, 'Display 40'),
    (CoreTextStyle.h1, 'Heading one 30'),
    (CoreTextStyle.h2, 'Heading two 24'),
    (CoreTextStyle.h3, 'Heading three 20'),
    (CoreTextStyle.title, 'Title 17'),
    (CoreTextStyle.body, 'Body 15 — the default reading size'),
    (CoreTextStyle.bodySm, 'Body small 13'),
    (CoreTextStyle.label, 'LABEL 13'),
    (CoreTextStyle.caption, 'Caption 11'),
    (CoreTextStyle.mono, 'Mono 120 bpm · 04:30'),
  ];
}
