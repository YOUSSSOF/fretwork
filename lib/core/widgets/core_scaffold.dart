import 'package:flutter/material.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/glass.dart';
import 'package:fretwork/core/widgets/core_ambient_glow.dart';
import 'package:fretwork/core/widgets/core_icon_button.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// The page shell: background, optional ambient glow, glass app bar, safe area.
///
/// The app bar is one of the ~6 permitted glass surfaces per screen (§4.3).
class CoreScaffold extends StatelessWidget {
  const CoreScaffold({
    required this.body,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBack = false,
    this.onBack,
    this.glow = false,
    this.bottomBar,
    this.floating,
    this.padded = true,
    this.extendBehindAppBar = true,
    super.key,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final bool glow;
  final Widget? bottomBar;
  final Widget? floating;
  final bool padded;
  final bool extendBehindAppBar;

  bool get _hasAppBar =>
      title != null || showBack || leading != null || actions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget content = body;
    if (padded) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: colors.surface0,
      extendBodyBehindAppBar: extendBehindAppBar,
      extendBody: true,
      body: Stack(
        children: [
          if (glow) const Positioned.fill(child: CoreAmbientGlow()),
          Positioned.fill(
            child: Column(
              children: [
                if (_hasAppBar)
                  _AppBar(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                    leading: leading,
                    showBack: showBack,
                    onBack: onBack,
                  )
                else
                  SizedBox(height: MediaQuery.paddingOf(context).top),
                Expanded(child: content),
              ],
            ),
          ),
          if (floating != null) Positioned.fill(child: floating!),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.leading,
    required this.showBack,
    required this.onBack,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return GlassSurface(
      bordered: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        padding: EdgeInsets.only(
          top: topInset,
          left: Sp.sm,
          right: Sp.sm,
          bottom: Sp.sm,
        ),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              if (showBack)
                CoreIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  semanticLabel: 'Back',
                )
              else if (leading != null)
                leading!
              else
                const SizedBox(width: Sp.sm),
              const SizedBox(width: Sp.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (title != null) CoreText.h3(title!, maxLines: 1),
                    if (subtitle != null)
                      CoreText.caption(subtitle!, maxLines: 1),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
