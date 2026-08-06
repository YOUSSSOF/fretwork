import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_animated_number.dart';
import 'package:fretwork/core/widgets/core_badge.dart';
import 'package:fretwork/core/widgets/core_book_reference.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_divider.dart';
import 'package:fretwork/core/widgets/core_empty_state.dart';
import 'package:fretwork/core/widgets/core_icon_button.dart';
import 'package:fretwork/core/widgets/core_list_tile.dart';
import 'package:fretwork/core/widgets/core_progress_ring.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_slider.dart';
import 'package:fretwork/core/widgets/core_stepper_field.dart';
import 'package:fretwork/core/widgets/core_tabs.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Every `core_*` widget in every state, on one route.
///
/// This is the Phase 2 deliverable and stays in the build behind `/debug/
/// gallery`: it is where a widget's states get checked after a change, and it
/// is far cheaper than navigating the real app to find each one.
class GalleryScreen extends HookConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final prefs = ref.watch(preferencesProvider);

    final tabCount = useState(5);
    final selectedTab = useState('tab_1');
    final tempo = useState(120);
    final minutes = useState(45.0);
    final chips = useState(<String>{'stretch'});
    final loading = useState(false);

    final tabs = [
      for (var i = 1; i <= tabCount.value; i++)
        CoreTabItem(
          id: 'tab_$i',
          label: 'Fragment $i',
          shortLabel: 'Frag $i',
          marked: i == 3,
        ),
    ];

    return CoreScaffold(
      title: 'Gallery',
      subtitle: 'Phase 2 — core widget library',
      glow: true,
      actions: [
        CoreIconButton(
          icon: Icons.palette_outlined,
          semanticLabel: 'Cycle accent theme',
          onPressed: () {
            final index = accentPalettes.indexWhere(
              (p) => p.id == prefs.accentPaletteId,
            );
            final next = accentPalettes[(index + 1) % accentPalettes.length];
            ref
                .read(preferencesProvider.notifier)
                .update((p) => p.copyWith(accentPaletteId: next.id));
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: Sp.huge),
        children: [
          const CoreSectionHeader(
            title: 'Tabs',
            subtitle:
                'Change the count to watch the layout mode flip. Nothing wraps, '
                'nothing compresses, nothing ellipsizes.',
          ),
          CoreSegmentedGrid<int>(
            items: const [
              CoreSegmentedItem(value: 2, label: '2'),
              CoreSegmentedItem(value: 5, label: '5'),
              CoreSegmentedItem(value: 8, label: '8'),
              CoreSegmentedItem(value: 12, label: '12'),
              CoreSegmentedItem(value: 18, label: '18'),
              CoreSegmentedItem(value: 24, label: '24'),
            ],
            selected: {tabCount.value},
            onChanged: (value) {
              tabCount.value = value;
              selectedTab.value = 'tab_1';
            },
          ),
          const SizedBox(height: Sp.lg),
          CoreTabs(
            items: tabs,
            selectedId: selectedTab.value,
            onSelected: (id) => selectedTab.value = id,
            density: prefs.tabDensity,
          ),
          const SizedBox(height: Sp.md),
          CoreCard(
            child: CoreText.body(
              'Selected: ${tabs.firstWhere((t) => t.id == selectedTab.value, orElse: () => tabs.first).label}',
            ),
          ),
          const SizedBox(height: Sp.lg),
          const CoreText.label('DENSITY'),
          const SizedBox(height: Sp.sm),
          CoreSegmentedGrid<CoreTabsDensity>(
            items: [
              for (final density in CoreTabsDensity.values)
                CoreSegmentedItem(value: density, label: density.name),
            ],
            selected: {prefs.tabDensity},
            onChanged: (value) => ref
                .read(preferencesProvider.notifier)
                .update((p) => p.copyWith(tabDensity: value)),
          ),

          const CoreSectionHeader(title: 'Buttons'),
          for (final size in CoreButtonSize.values) ...[
            CoreText.caption(size.name.toUpperCase()),
            const SizedBox(height: Sp.sm),
            Wrap(
              spacing: Sp.sm,
              runSpacing: Sp.sm,
              children: [
                CoreButton(
                  label: 'Primary',
                  size: size,
                  onPressed: () {},
                  leading: Icons.play_arrow_rounded,
                ),
                CoreButton(
                  label: 'Secondary',
                  size: size,
                  variant: CoreButtonVariant.secondary,
                  onPressed: () {},
                ),
                CoreButton(
                  label: 'Ghost',
                  size: size,
                  variant: CoreButtonVariant.ghost,
                  onPressed: () {},
                ),
                CoreButton(
                  label: 'Destructive',
                  size: size,
                  variant: CoreButtonVariant.destructive,
                  onPressed: () {},
                ),
                CoreButton(label: 'Disabled', size: size),
              ],
            ),
            const SizedBox(height: Sp.lg),
          ],
          CoreButton.primary(
            label: 'Tap to load',
            fullWidth: true,
            loading: loading.value,
            onPressed: () async {
              loading.value = true;
              await Future<void>.delayed(const Duration(seconds: 2));
              loading.value = false;
            },
          ),

          const CoreSectionHeader(title: 'Numbers & rings'),
          Row(
            children: [
              CoreProgressRing(
                size: 132,
                progress: tempo.value / 260,
                secondaryProgress: minutes.value / 150,
                center: CoreAnimatedNumber(
                  value: '${tempo.value}',
                  style: CoreTextStyle.h2,
                  suffix: 'bpm',
                ),
              ),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: CoreStepperField(
                  label: 'Tempo',
                  value: tempo.value,
                  min: 40,
                  max: 260,
                  suffix: 'bpm',
                  onChanged: (value) => tempo.value = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          CoreSlider(
            label: 'Session length',
            value: minutes.value,
            min: 20,
            max: 150,
            suggestion: 60,
            formatValue: (v) => '${v.round()} min',
            onChanged: (value) => minutes.value = value,
          ),

          const CoreSectionHeader(title: 'Chips, badges, references'),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              for (final tag in const [
                'stretch',
                'alternatePicking',
                'sequencing',
                'legato',
              ])
                CoreChip(
                  label: tag,
                  selected: chips.value.contains(tag),
                  dotColor: colors.accentStrong,
                  onPressed: () {
                    final next = {...chips.value};
                    next.contains(tag) ? next.remove(tag) : next.add(tag);
                    chips.value = next;
                  },
                ),
              const CoreChip(label: 'Static', style: CoreChipStyle.filled),
            ],
          ),
          const SizedBox(height: Sp.md),
          const Row(
            children: [
              CoreBadge('12'),
              SizedBox(width: Sp.sm),
              CoreBadge('Today', muted: true),
              SizedBox(width: Sp.sm),
              CoreBookReference(page: 26, cdTrack: 11),
            ],
          ),

          const CoreSectionHeader(title: 'Surfaces'),
          CoreCard(
            glass: true,
            onPressed: () {},
            child: const CoreText.body('Glass card, pressable, corner accents'),
          ),
          const SizedBox(height: Sp.sm),
          const CoreCard(child: CoreText.body('Flat card, static')),
          const SizedBox(height: Sp.sm),
          const CoreCard(
            enhanced: true,
            child: CoreText.body('Enhanced flat card'),
          ),

          const CoreSectionHeader(title: 'List tiles'),
          CoreListTile(
            title: 'Example 11',
            subtitle: 'Scale fragments in G major · 18 fragments',
            leading: Icon(Icons.graphic_eq_rounded, color: colors.accentStrong),
            trailing: const CoreBadge('4'),
            onPressed: () {},
          ),
          const CoreDivider(),
          CoreListTile(
            title: 'Selected tile',
            subtitle: 'Shows the accent rail and selection wash',
            selected: true,
            onPressed: () {},
          ),
          const CoreDivider(),
          const CoreListTile(
            title: 'Static tile',
            subtitle: 'No callback, so no press response',
          ),

          const CoreSectionHeader(title: 'Overlays'),
          Wrap(
            spacing: Sp.sm,
            children: [
              CoreButton.secondary(
                label: 'Bottom sheet',
                onPressed: () => showCoreSheet<void>(
                  context: context,
                  title: 'A sheet',
                  subtitle: 'Draggable, velocity-aware dismissal',
                  builder: (_) => const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoreText.body(
                        'The barrier tracks the drag position rather than '
                        'fading on a timer.',
                      ),
                      SizedBox(height: Sp.xl),
                    ],
                  ),
                ),
              ),
              CoreButton.secondary(
                label: 'Dialog',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => CoreDialog(
                    title: 'Reset progress?',
                    message:
                        'This clears every session, day record and tempo '
                        'point. It cannot be undone.',
                    actions: [
                      CoreButton.ghost(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      CoreButton.destructive(
                        label: 'Reset',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const CoreSectionHeader(title: 'Empty state'),
          const SizedBox(
            height: 260,
            child: CoreEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing logged yet',
              message:
                  'Sessions you complete will show up here, including the days '
                  'you miss.',
            ),
          ),
        ],
      ),
    );
  }
}
