import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/models/tablature.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_tab_staff.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// Enters tab by tapping frets rather than typing dashes.
///
/// On a phone this is the difference between transcribing a page in ten
/// minutes and giving up: pick a string, tap a fret, and the column advances.
/// The ASCII field is still there for pasting something you already have —
/// this is for entering something you are reading off the page.
class TabGridEditor extends StatefulWidget {
  const TabGridEditor({
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final Tablature initial;
  final ValueChanged<Tablature> onChanged;

  /// Frets offered on the pad. Past the twelfth everything repeats, and a
  /// scrolling pad of 24 is harder to hit than two rows of 13.
  static const int maxFret = 24;

  @override
  State<TabGridEditor> createState() => _TabGridEditorState();
}

class _TabGridEditorState extends State<TabGridEditor> {
  late final List<TabColumn> _columns = _flatten(widget.initial);
  int _string = 0;
  TabDuration _duration = TabDuration.eighth;
  bool _dotted = false;
  bool _triplet = false;
  TabArticulation _articulation = TabArticulation.none;

  static List<TabColumn> _flatten(Tablature tab) => [
    for (final measure in tab.measures) ...measure.columns,
  ];

  /// Re-bars the flat column list into measures of four beats.
  ///
  /// Bar lines are derived from the rhythm rather than entered by hand: the
  /// user is reading note values off a page, and asking them to also count
  /// bars is asking them to do the computer's job.
  Tablature _rebuild() {
    final measures = <TabMeasure>[];
    var current = <TabColumn>[];
    var beats = 0.0;

    for (final column in _columns) {
      current.add(column);
      beats += column.beats;
      if (beats >= 4) {
        measures.add(TabMeasure(columns: current));
        current = <TabColumn>[];
        beats = 0;
      }
    }
    if (current.isNotEmpty) measures.add(TabMeasure(columns: current));

    return Tablature(
      key: widget.initial.key,
      measures: measures,
      tuning: widget.initial.tuning,
      title: widget.initial.title,
    );
  }

  void _emit() => widget.onChanged(_rebuild());

  void _addNote(int fret, {bool muted = false}) {
    HapticFeedback.selectionClick();
    setState(() {
      _columns.add(
        TabColumn(
          notes: [
            TabNote(
              string: _string,
              fret: fret,
              muted: muted,
              articulation: _articulation,
            ),
          ],
          duration: _duration,
          dotted: _dotted,
          triplet: _triplet,
        ),
      );
      // Articulations apply to the join, so they are one-shot rather than
      // sticky — leaving 'h' on would hammer every note that followed.
      _articulation = TabArticulation.none;
    });
    _emit();
  }

  /// Adds to the previous column instead of starting a new one, which is how
  /// a chord is entered.
  void _stackNote(int fret) {
    if (_columns.isEmpty) return _addNote(fret);
    HapticFeedback.selectionClick();
    setState(() {
      final last = _columns.removeLast();
      _columns.add(
        last.copyWith(
          notes: [
            ...last.notes.where((n) => n.string != _string),
            TabNote(string: _string, fret: fret),
          ],
        ),
      );
    });
    _emit();
  }

  void _undo() {
    if (_columns.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(_columns.removeLast);
    _emit();
  }

  void _clear() {
    setState(_columns.clear);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preview = _rebuild();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isEmpty)
          Container(
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface1,
              border: Border.all(color: colors.border),
            ),
            child: CoreText.bodySm(
              'Pick a string, then tap a fret.',
              color: colors.textTertiary,
            ),
          )
        else
          CoreTabStaff(tablature: preview),

        const SizedBox(height: Sp.lg),
        const CoreText.label('STRING'),
        const SizedBox(height: Sp.sm),
        Row(
          children: [
            // Reversed so the high string is on the left, matching the stave.
            for (var s = kStringCount - 1; s >= 0; s--)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: Sp.xs),
                  child: _Key(
                    label: widget.initial.tuning[s],
                    selected: s == _string,
                    onPressed: () => setState(() => _string = s),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: Sp.lg),
        const CoreText.label('NOTE VALUE'),
        const SizedBox(height: Sp.sm),
        CoreSegmentedGrid<TabDuration>(
          items: [
            for (final duration in TabDuration.values)
              CoreSegmentedItem(value: duration, label: duration.label),
          ],
          selected: {_duration},
          onChanged: (value) => setState(() => _duration = value),
        ),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.xs,
          children: [
            _Toggle(
              label: 'dotted',
              on: _dotted,
              onPressed: () => setState(() => _dotted = !_dotted),
            ),
            _Toggle(
              label: 'triplet',
              on: _triplet,
              onPressed: () => setState(() => _triplet = !_triplet),
            ),
            for (final articulation in const [
              TabArticulation.hammerOn,
              TabArticulation.pullOff,
              TabArticulation.slideUp,
              TabArticulation.slideDown,
              TabArticulation.bend,
              TabArticulation.vibrato,
            ])
              _Toggle(
                label: articulation.glyph,
                on: _articulation == articulation,
                onPressed: () => setState(
                  () => _articulation = _articulation == articulation
                      ? TabArticulation.none
                      : articulation,
                ),
              ),
          ],
        ),

        const SizedBox(height: Sp.lg),
        const CoreText.label('FRET'),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.xs,
          runSpacing: Sp.xs,
          children: [
            for (var fret = 0; fret <= TabGridEditor.maxFret; fret++)
              SizedBox(
                width: 40,
                child: _Key(
                  label: '$fret',
                  selected: false,
                  onPressed: () => _addNote(fret),
                  onLongPress: () => _stackNote(fret),
                ),
              ),
            SizedBox(
              width: 40,
              child: _Key(
                label: 'x',
                selected: false,
                onPressed: () => _addNote(0, muted: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.xs),
        CoreText.caption(
          'Long-press a fret to add it to the previous column as a chord.',
          color: colors.textTertiary,
        ),

        const SizedBox(height: Sp.lg),
        Row(
          children: [
            Expanded(
              child: CoreButton.secondary(
                label: 'Undo',
                leading: Icons.undo_rounded,
                fullWidth: true,
                onPressed: _columns.isEmpty ? null : _undo,
              ),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: CoreButton.ghost(
                label: 'Clear',
                fullWidth: true,
                onPressed: _columns.isEmpty ? null : _clear,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CorePressable(
      onPressed: onPressed,
      onLongPress: onLongPress,
      haptic: false,
      pressedScale: 0.9,
      semanticLabel: label,
      child: Container(
        height: Layout.touchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.selection : colors.surface1,
          border: Border.all(
            color: selected ? colors.accentStrong : colors.border,
          ),
        ),
        child: CoreText.label(
          label,
          color: selected ? colors.textPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.onPressed,
  });

  final String label;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CorePressable(
      onPressed: onPressed,
      pressedScale: 0.92,
      semanticLabel: label,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
        decoration: BoxDecoration(
          color: on ? colors.selection : Colors.transparent,
          border: Border.all(color: on ? colors.accentStrong : colors.border),
        ),
        child: CoreText.label(
          label,
          color: on ? colors.textPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}
