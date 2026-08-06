import 'package:flutter/material.dart';
import 'package:fretwork/core/models/tablature.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_card.dart';
import 'package:fretwork/core/widgets/core_sheet.dart';
import 'package:fretwork/core/widgets/core_tab_staff.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:fretwork/features/library/tab/ascii_tab_parser.dart';
import 'package:fretwork/features/library/tab/tab_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The tablature panel on an exercise.
///
/// The app ships no notation — the seed carries page and track pointers only.
/// This is where the user keeps their own transcription of the figure they are
/// working on, so they can read it on the phone instead of holding the book
/// open with their picking hand.
class TabSection extends ConsumerWidget {
  const TabSection({
    required this.exerciseId,
    required this.variantId,
    required this.exerciseLabel,
    required this.variantLabel,
    super.key,
  });

  final String exerciseId;
  final String? variantId;
  final String exerciseLabel;
  final String? variantLabel;

  String get _key => variantId == null ? exerciseId : '$exerciseId:$variantId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tab = ref.watch(
      tabForProvider((exerciseId: exerciseId, variantId: variantId)),
    );

    if (tab == null || tab.isEmpty) {
      return CoreCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoreText.title('No tab saved yet'),
            const SizedBox(height: Sp.sm),
            CoreText.bodySm(
              'Fretwork does not ship the notation — it points at the page in '
              'your own copy. Paste or type your transcription here and it '
              'will be drawn as a proper stave you can read while practising.',
              color: colors.textSecondary,
            ),
            const SizedBox(height: Sp.lg),
            CoreButton.secondary(
              label: 'Add tab',
              leading: Icons.edit_outlined,
              fullWidth: true,
              onPressed: () => _openEditor(context, ref, null),
            ),
          ],
        ),
      );
    }

    return CoreCard(
      padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.md, Sp.sm, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
            child: Row(
              children: [
                Expanded(
                  child: CoreText.caption(
                    '${tab.measures.length} '
                    '${tab.measures.length == 1 ? 'bar' : 'bars'} · '
                    '${tab.noteCount} notes',
                  ),
                ),
                CoreButton.ghost(
                  label: 'Edit',
                  size: CoreButtonSize.sm,
                  onPressed: () => _openEditor(context, ref, tab),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.sm),
          CoreTabStaff(tablature: tab),
          const SizedBox(height: Sp.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
            child: CoreText.caption(
              'Scroll sideways to read on.',
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    Tablature? existing,
  ) => showCoreSheet<void>(
    context: context,
    title: existing == null ? 'Add tab' : 'Edit tab',
    subtitle: variantLabel == null
        ? exerciseLabel
        : '$exerciseLabel · $variantLabel',
    builder: (sheetContext) => _TabEditor(
      tabKey: _key,
      initial: existing,
      onSaved: (tablature) async {
        await ref.read(tablatureProvider.notifier).save(tablature);
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
      onDeleted: existing == null
          ? null
          : () async {
              await ref.read(tablatureProvider.notifier).delete(_key);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            },
    ),
  );
}

class _TabEditor extends StatefulWidget {
  const _TabEditor({
    required this.tabKey,
    required this.initial,
    required this.onSaved,
    required this.onDeleted,
  });

  final String tabKey;
  final Tablature? initial;
  final Future<void> Function(Tablature tablature) onSaved;
  final Future<void> Function()? onDeleted;

  @override
  State<_TabEditor> createState() => _TabEditorState();
}

class _TabEditorState extends State<_TabEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null ? _template : toAsciiTab(widget.initial!),
  );
  TabParseResult? _result;

  static const String _template = '''
e|------------------------|
B|------------------------|
G|------------------------|
D|------------------------|
A|------------------------|
E|------------------------|''';

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _result = parseAsciiTab(_controller.text, key: widget.tabKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final result = _result;
    final parsed = result?.tablature;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoreText.bodySm(
          'Paste standard ASCII tab — six lines, dashes for time, numbers for '
          'frets. Marks between notes are read too: h, p, b, ~, / and \\.',
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _controller,
          onChanged: (_) => _parse(),
          maxLines: 8,
          style: TextStyle(
            color: colors.textPrimary,
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.35,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface1,
            border: OutlineInputBorder(
              borderRadius: Rd.none,
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Rd.none,
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: Rd.none,
              borderSide: BorderSide(color: colors.accentStrong),
            ),
          ),
        ),
        const SizedBox(height: Sp.lg),
        // Live preview: what is typed is drawn as it will appear, so a
        // mistyped column is obvious before it is saved.
        if (result != null && !result.isSuccess)
          Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              color: colors.danger.withValues(alpha: 0.10),
              border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final error in result.errors)
                  CoreText.bodySm(error, color: colors.danger),
              ],
            ),
          )
        else if (parsed != null) ...[
          const CoreText.label('PREVIEW'),
          const SizedBox(height: Sp.sm),
          CoreTabStaff(tablature: parsed),
          for (final warning in result!.warnings)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: CoreText.caption(warning, color: colors.textTertiary),
            ),
        ],
        const SizedBox(height: Sp.lg),
        Row(
          children: [
            if (widget.onDeleted != null)
              Expanded(
                child: CoreButton.destructive(
                  label: 'Delete',
                  fullWidth: true,
                  onPressed: widget.onDeleted,
                ),
              ),
            if (widget.onDeleted != null) const SizedBox(width: Sp.sm),
            Expanded(
              flex: 2,
              child: CoreButton.primary(
                label: 'Save tab',
                fullWidth: true,
                onPressed: parsed == null ? null : () => widget.onSaved(parsed),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.sm),
      ],
    );
  }
}
