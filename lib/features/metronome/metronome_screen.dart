import 'package:flutter/material.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_scaffold.dart';
import 'package:fretwork/core/widgets/core_section_header.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';
import 'package:fretwork/features/session/session_screen.dart';
import 'package:fretwork/features/session/widgets/metronome_dial.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The metronome on its own, free of a session.
///
/// The click is genuinely useful outside a routine — tuning up, working on
/// something that is not in the course, checking a tempo — and having to fake a
/// session to get at it was silly. This is also the only place the sound is
/// chosen, because that is a decision you make while listening to it.
class MetronomeScreen extends ConsumerStatefulWidget {
  const MetronomeScreen({super.key});

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Standalone use has no exercise, so open the full range.
      ref
          .read(metronomeProvider.notifier)
          .prepare(
            exerciseId: kStandaloneMetronomeId,
            tempo: ref.read(metronomeProvider).bpm,
            subdivision: ref.read(metronomeProvider).subdivision,
            minTempo: kMinBpm,
            maxTempo: kMaxBpm,
          );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app silences it, the same as a session.
    if (state != AppLifecycleState.resumed) {
      ref.read(metronomeProvider.notifier).stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);
    final prefs = ref.watch(preferencesProvider);
    final prefsNotifier = ref.read(preferencesProvider.notifier);

    return CoreScaffold(
      title: 'Metronome',
      subtitle: '${metronome.bpm} bpm',
      glow: true,
      body: ListView(
        padding: EdgeInsets.only(
          top: Sp.lg,
          bottom: context.shellBottomInset + Sp.xl,
        ),
        children: [
          Center(
            child: MetronomeDial(
              state: metronome,
              size: 240,
              onTempoChanged: notifier.setTempo,
            ),
          ),
          const SizedBox(height: Sp.xl),
          TempoStepRow(state: metronome, notifier: notifier),
          const SizedBox(height: Sp.lg),
          CoreButton.primary(
            label: metronome.running ? 'Stop' : 'Start',
            size: CoreButtonSize.lg,
            fullWidth: true,
            leading: metronome.running
                ? Icons.stop_rounded
                : Icons.play_arrow_rounded,
            onPressed: notifier.toggle,
          ),

          const CoreSectionHeader(title: 'Subdivision'),
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

          const CoreSectionHeader(title: 'Sound'),
          CoreCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreSegmentedGrid<MetronomeSound>(
                  items: [
                    for (final sound in MetronomeSound.values)
                      CoreSegmentedItem(value: sound, label: sound.name),
                  ],
                  selected: {prefs.metronomeSound},
                  onChanged: (sound) async {
                    // Saved as a preference, so it is still the chosen sound
                    // next time — in a session or here.
                    await prefsNotifier.update(
                      (p) => p.copyWith(metronomeSound: sound),
                    );
                    await notifier.reloadSound();
                  },
                ),
                const SizedBox(height: Sp.lg),
                _Toggle(
                  label: 'Accent beat one',
                  hint:
                      'Gives the downbeat its own pitch, so you can hear '
                      'where the bar restarts.',
                  value: prefs.accentBeatOne,
                  onChanged: (value) => prefsNotifier.update(
                    (p) => p.copyWith(accentBeatOne: value),
                  ),
                ),
                _Toggle(
                  label: 'Haptic on every beat',
                  hint: 'Off by default: a buzz on every sixteenth is a lot.',
                  value: prefs.hapticOnBeat,
                  onChanged: (value) => prefsNotifier.update(
                    (p) => p.copyWith(hapticOnBeat: value),
                  ),
                ),
                _Toggle(
                  label: 'Muted',
                  hint: 'Keeps the visual pulse for late-night practice.',
                  value: metronome.muted,
                  onChanged: notifier.setMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.lg),
          CoreText.caption(
            'Tempo, subdivision and sound are remembered.',
            color: context.colors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreText.body(label),
                CoreText.caption(hint, maxLines: 2),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.accentStrong,
            inactiveTrackColor: colors.surface2,
          ),
        ],
      ),
    );
  }
}
