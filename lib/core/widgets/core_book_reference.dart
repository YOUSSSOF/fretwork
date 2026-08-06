import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// Points at the page in the user's own copy of the book.
///
/// The app is a practice tracker, not a reproduction: it stores labels, tempos
/// and page numbers, never notation. This pill is what stands in for the
/// notation, and the intended workflow is that the book is open next to the
/// phone.
class CoreBookReference extends StatelessWidget {
  const CoreBookReference({required this.page, this.cdTrack, super.key});

  final int page;
  final int? cdTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = cdTrack == null
        ? 'Book p. $page'
        : 'Book p. $page · CD track $cdTrack';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 12, color: colors.textTertiary),
          const SizedBox(width: Sp.xs),
          CoreText.caption(text, color: colors.textSecondary),
        ],
      ),
    );
  }
}
