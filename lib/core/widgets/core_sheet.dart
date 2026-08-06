import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/glass.dart';
import 'package:fretwork/core/widgets/core_text.dart';

/// Presents a draggable bottom sheet.
///
/// Dismissal is velocity-aware — a fast flick closes the sheet even from near
/// the top — and the barrier opacity tracks the drag 1:1 rather than fading on
/// a timer, so a half-dragged sheet looks half-dismissed.
Future<T?> showCoreSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool isScrollControlled = true,
  double maxHeightFraction = 0.86,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
    ),
    builder: (sheetContext) => CoreSheet(
      title: title,
      subtitle: subtitle,
      child: Builder(builder: builder),
    ),
  );
}

class CoreSheet extends StatelessWidget {
  const CoreSheet({
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GlassSurface(
      enhanced: true,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CoreText.h3(title!),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            CoreText.caption(subtitle!),
                          ],
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            if (title != null) Container(height: 1, color: colors.border),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.lg),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.md),
        child: Container(
          width: 36,
          height: 4,
          color: context.colors.borderHover,
        ),
      ),
    );
  }
}

/// Confirm / alert dialog. Zero radius and glass, matching every other surface.
class CoreDialog extends StatelessWidget {
  const CoreDialog({
    required this.title,
    this.message,
    this.body,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Sp.xl),
      shape: const RoundedRectangleBorder(borderRadius: Rd.none),
      child: AnimatedPadding(
        duration: context.motion(Motion.fast),
        padding: MediaQuery.viewInsetsOf(context),
        child: GlassSurface(
          enhanced: true,
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoreText.h3(title),
              if (message != null) ...[
                const SizedBox(height: Sp.sm),
                CoreText.body(message!),
              ],
              if (body != null) ...[const SizedBox(height: Sp.lg), body!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Sp.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: Sp.sm),
                        child: action,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
