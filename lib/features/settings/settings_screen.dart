import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/data/backup_service.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_chip.dart';
import 'package:fretwork/core/widgets/core_list_tile.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_slider.dart';
import 'package:fretwork/core/widgets/core_stepper_field.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:fretwork/features/settings/widgets/home_layout_editor.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(preferencesProvider.notifier);

    return CoreScaffold(
      title: 'Settings',
      body: ListView(
        padding: EdgeInsets.only(bottom: context.shellBottomInset + Sp.xl),
        children: [
          const CoreSectionHeader(
            title: 'Practice',
            padding: EdgeInsets.only(top: Sp.lg, bottom: Sp.lg),
          ),
          _SessionLength(profile: profile),
          const SizedBox(height: Sp.lg),
          _RestDays(profile: profile),
          const SizedBox(height: Sp.lg),
          CoreCard(
            child: Column(
              children: [
                CoreStepperField(
                  label: 'Rest between blocks',
                  value: prefs.restBetweenBlocksSeconds,
                  min: 0,
                  max: 120,
                  step: 5,
                  suffix: 's',
                  onChanged: (value) => notifier.update(
                    (p) => p.copyWith(restBetweenBlocksSeconds: value),
                  ),
                ),
                const SizedBox(height: Sp.lg),
                CoreStepperField(
                  label: 'Rest between items',
                  value: prefs.restBetweenItemsSeconds,
                  min: 0,
                  max: 60,
                  step: 5,
                  suffix: 's',
                  onChanged: (value) => notifier.update(
                    (p) => p.copyWith(restBetweenItemsSeconds: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.lg),
          _Choice<TimerMode>(
            label: 'Default timer mode',
            hint:
                'Quick is one ring for the whole session. Detailed gives '
                'every item its own timer, tempo and controls.',
            values: TimerMode.values,
            labelFor: (mode) => mode.name,
            selected: prefs.timerMode,
            onChanged: (mode) =>
                notifier.update((p) => p.copyWith(timerMode: mode)),
          ),

          const CoreSectionHeader(title: 'Appearance'),
          _Accent(prefs: prefs),
          const SizedBox(height: Sp.lg),
          CoreCard(
            child: CoreSlider(
              label: 'Text scale',
              value: prefs.textScale,
              min: 0.85,
              max: 1.35,
              divisions: 10,
              formatValue: (v) => '${(v * 100).round()}%',
              onChanged: (value) =>
                  notifier.update((p) => p.copyWith(textScale: value)),
            ),
          ),
          const SizedBox(height: Sp.lg),
          _Choice<CoreTabsDensity>(
            label: 'Tab density',
            hint: 'Drives the padding and minimum width of variant tabs.',
            values: CoreTabsDensity.values,
            labelFor: (d) => d.name,
            selected: prefs.tabDensity,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(tabDensity: value)),
          ),
          const SizedBox(height: Sp.lg),
          _Choice<CardDensity>(
            label: 'Card density',
            values: CardDensity.values,
            labelFor: (d) => d.name,
            selected: prefs.cardDensity,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(cardDensity: value)),
          ),
          const SizedBox(height: Sp.lg),
          _Choice<ReduceMotionSetting>(
            label: 'Reduce motion',
            hint:
                'Haptics stay on either way — reduced motion is about what '
                'moves, not about removing feedback.',
            values: ReduceMotionSetting.values,
            labelFor: (v) => switch (v) {
              ReduceMotionSetting.followSystem => 'follow system',
              ReduceMotionSetting.on => 'on',
              ReduceMotionSetting.off => 'off',
            },
            selected: prefs.reduceMotion,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(reduceMotion: value)),
          ),
          const SizedBox(height: Sp.lg),
          _Toggle(
            label: 'Reduce blur',
            hint:
                'Replaces every glass surface with a solid one. Worth '
                'turning on if the app drops frames.',
            value: prefs.reduceBlur,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(reduceBlur: value)),
          ),

          const CoreSectionHeader(title: 'Home layout'),
          const HomeLayoutEditor(),

          const CoreSectionHeader(title: 'Metronome'),
          _Toggle(
            label: 'Metronome enabled',
            value: prefs.metronomeEnabled,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(metronomeEnabled: value)),
          ),
          const SizedBox(height: Sp.lg),
          _Choice<MetronomeSound>(
            label: 'Sound',
            values: MetronomeSound.values,
            labelFor: (s) => s.name,
            selected: prefs.metronomeSound,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(metronomeSound: value)),
          ),
          const SizedBox(height: Sp.lg),
          _Toggle(
            label: 'Accent beat one',
            value: prefs.accentBeatOne,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(accentBeatOne: value)),
          ),
          const SizedBox(height: Sp.lg),
          _Toggle(
            label: 'Haptic on every beat',
            hint: 'Off by default: a buzz on every sixteenth note is a lot.',
            value: prefs.hapticOnBeat,
            onChanged: (value) =>
                notifier.update((p) => p.copyWith(hapticOnBeat: value)),
          ),

          const CoreSectionHeader(title: 'Data'),
          const _DataSection(),

          const CoreSectionHeader(title: 'About'),
          CoreCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CoreText.title('Fretwork'),
                const SizedBox(height: Sp.xs),
                CoreText.bodySm(
                  'Practising since ${profile.startedAt.shortDayLabel}. '
                  'Milestone ${profile.milestone} of $kMaxMilestone.',
                ),
                const SizedBox(height: Sp.sm),
                const CoreText.caption(
                  'No account, no network, no analytics. Everything is stored '
                  'on this device.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionLength extends ConsumerStatefulWidget {
  const _SessionLength({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_SessionLength> createState() => _SessionLengthState();
}

class _SessionLengthState extends ConsumerState<_SessionLength> {
  late double _value = widget.profile.sessionMinutes.toDouble();

  @override
  Widget build(BuildContext context) {
    final suggested = UserProfile.suggestedMinutes(widget.profile.milestone);
    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoreSlider(
            label: 'Session length',
            value: _value,
            min: kMinSessionMinutes.toDouble(),
            max: kMaxSessionMinutes.toDouble(),
            divisions: kMaxSessionMinutes - kMinSessionMinutes,
            suggestion: suggested.toDouble(),
            formatValue: (v) => '${v.round()} min',
            onChanged: (value) => setState(() => _value = value),
            onChangeEnd: (value) => ref
                .read(profileProvider.notifier)
                .setSessionMinutes(value.round()),
          ),
          const SizedBox(height: Sp.sm),
          CoreText.caption(
            'The course suggests $suggested minutes at milestone '
            '${widget.profile.milestone}.',
          ),
        ],
      ),
    );
  }
}

class _RestDays extends ConsumerWidget {
  const _RestDays({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CoreText.label('REST DAYS'),
          const SizedBox(height: Sp.sm),
          const CoreText.bodySm(
            'Rest days do not break a streak and are excluded from adherence.',
          ),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              for (final weekday in kAllWeekdays)
                CoreChip(
                  label: weekdayShortName(weekday),
                  selected: profile.restWeekdays.contains(weekday),
                  onPressed: () {
                    final next = {...profile.restWeekdays};
                    next.contains(weekday)
                        ? next.remove(weekday)
                        : next.add(weekday);
                    ref.read(profileProvider.notifier).setRestWeekdays(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Accent extends ConsumerWidget {
  const _Accent({required this.prefs});

  final Preferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CoreText.label('ACCENT'),
          const SizedBox(height: Sp.md),
          CoreSegmentedGrid<String>(
            items: [
              for (final palette in accentPalettes)
                CoreSegmentedItem(
                  value: palette.id,
                  label: palette.label,
                  dotColor: palette.d,
                ),
            ],
            selected: {prefs.accentPaletteId},
            onChanged: (id) => ref
                .read(preferencesProvider.notifier)
                .update((p) => p.copyWith(accentPaletteId: id)),
          ),
        ],
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.values,
    required this.labelFor,
    required this.selected,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final List<T> values;
  final String Function(T value) labelFor;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return CoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoreText.label(label.toUpperCase()),
          if (hint != null) ...[
            const SizedBox(height: Sp.xs),
            CoreText.bodySm(hint!),
          ],
          const SizedBox(height: Sp.md),
          CoreSegmentedGrid<T>(
            items: [
              for (final value in values)
                CoreSegmentedItem(value: value, label: labelFor(value)),
            ],
            selected: {selected},
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CoreCard(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
      child: CoreListTile(
        title: label,
        subtitle: hint,
        padding: EdgeInsets.zero,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.accentStrong,
          inactiveTrackColor: colors.surface2,
        ),
        onPressed: () => onChanged(!value),
      ),
    );
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        CoreButton.secondary(
          label: 'Export a JSON backup',
          leading: Icons.download_outlined,
          fullWidth: true,
          onPressed: () => _exportBackup(context, ref),
        ),
        const SizedBox(height: Sp.sm),
        CoreButton.secondary(
          label: 'Import a JSON backup',
          leading: Icons.upload_outlined,
          fullWidth: true,
          onPressed: () => _importBackup(context, ref),
        ),
        const SizedBox(height: Sp.sm),
        CoreButton.destructive(
          label: 'Reset all progress',
          leading: Icons.delete_outline_rounded,
          fullWidth: true,
          onPressed: () => _resetEverything(context, ref),
        ),
      ],
    );
  }
}

Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
  final json = exportBackup(ref.read(storeProvider));
  await Clipboard.setData(ClipboardData(text: json));
  if (!context.mounted) return;

  await showCoreSheet<void>(
    context: context,
    title: 'Backup copied',
    subtitle: '${(json.length / 1024).toStringAsFixed(1)} KB of JSON',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoreText.body(
          'The backup is on your clipboard. Paste it somewhere you trust — a '
          'note, a file, a message to yourself. It contains your whole '
          'practice history.',
        ),
        const SizedBox(height: Sp.lg),
        CoreButton.primary(
          label: 'Done',
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        const SizedBox(height: Sp.sm),
      ],
    ),
  );
}

Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final colors = context.colors;

  final raw = await showCoreSheet<String>(
    context: context,
    title: 'Import a backup',
    subtitle: 'This replaces everything currently stored',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoreText.body(
          'Paste a backup below. Nothing is written until it has been checked, '
          'so a bad paste cannot leave you half-restored.',
        ),
        const SizedBox(height: Sp.lg),
        TextField(
          controller: controller,
          maxLines: 6,
          style: TextStyle(color: colors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: '{ "version": 1, ... }',
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.surface1,
            border: OutlineInputBorder(
              borderRadius: Rd.none,
              borderSide: BorderSide(color: colors.border),
            ),
          ),
        ),
        const SizedBox(height: Sp.lg),
        Row(
          children: [
            Expanded(
              child: CoreButton.ghost(
                label: 'Cancel',
                fullWidth: true,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: CoreButton.destructive(
                label: 'Replace everything',
                fullWidth: true,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.sm),
      ],
    ),
  );

  controller.dispose();
  if (raw == null || raw.trim().isEmpty) return;

  final result = await importBackup(ref.read(storeProvider), raw);
  if (!context.mounted) return;

  if (result.isSuccess) {
    // Everything downstream reads through these, so invalidating the roots
    // rebuilds the whole app against the restored data.
    ref.invalidate(storeProvider);
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => CoreDialog(
      title: result.isSuccess ? 'Backup restored' : 'Could not import',
      message: result.isSuccess
          ? 'Restored ${result.summary}. Reopen the app to be sure everything '
                'is showing the restored data.'
          : result.error,
      actions: [
        CoreButton.primary(
          label: 'OK',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// Double-confirmed, and the second step spells out what is lost. A single
/// "are you sure?" is not enough friction for something irreversible.
Future<void> _resetEverything(BuildContext context, WidgetRef ref) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => CoreDialog(
      title: 'Reset all progress?',
      message:
          'This deletes every session, day record, tempo point and routine. '
          'Your milestone and settings go back to their defaults.',
      actions: [
        CoreButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        CoreButton.destructive(
          label: 'Continue',
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  if (first != true || !context.mounted) return;

  final second = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => CoreDialog(
      title: 'This cannot be undone',
      message:
          'Export a backup first if there is any chance you want this history '
          'back. There is no other copy.',
      actions: [
        CoreButton.ghost(
          label: 'Keep my data',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        CoreButton.destructive(
          label: 'Delete everything',
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  if (second != true) return;

  await ref.read(storeProvider).clearAll();
  ref.invalidate(storeProvider);
}
