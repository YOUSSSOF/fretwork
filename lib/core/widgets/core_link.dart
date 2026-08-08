import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL in the user's browser, or copies it if that fails.
///
/// Handing a URL to the system browser is not a network client — the app still
/// makes no requests of its own, and nothing about the user leaves with it. The
/// fallback matters more than it looks: on a device with no browser, or one
/// that refuses the intent, a link that does nothing at all reads as a bug.
class CoreLink extends StatelessWidget {
  const CoreLink({
    required this.url,
    this.label,
    this.icon = Icons.open_in_new_rounded,
    super.key,
  });

  /// The address to open. Shown as-is unless [label] says otherwise.
  final String url;

  /// What to show instead of the raw URL.
  final String? label;

  final IconData icon;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');

    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: url));
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Could not open a browser — $url copied instead'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = label ?? url;

    return CorePressable(
      onPressed: () => _open(context),
      semanticLabel: 'Open $text',
      child: Padding(
        // Vertical padding only: the tap target needs to clear the minimum
        // without the underline floating away from the text it belongs to.
        padding: const EdgeInsets.symmetric(vertical: Sp.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.accentStrong, width: 1),
                ),
              ),
              child: CoreText.bodySm(text, color: colors.accentStrong),
            ),
            const SizedBox(width: Sp.xs),
            Icon(icon, size: 13, color: colors.accentStrong),
          ],
        ),
      ),
    );
  }
}
