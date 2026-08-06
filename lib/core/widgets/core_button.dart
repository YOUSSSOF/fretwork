import 'package:flutter/material.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/theme/app_typography.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';
import 'package:fretwork/core/widgets/core_text.dart';

enum CoreButtonVariant { primary, secondary, ghost, destructive }

enum CoreButtonSize {
  sm,
  md,
  lg;

  double get height => switch (this) {
    CoreButtonSize.sm => 36,
    CoreButtonSize.md => 44,
    CoreButtonSize.lg => 52,
  };

  double get horizontalPad => switch (this) {
    CoreButtonSize.sm => Sp.md,
    CoreButtonSize.md => Sp.lg,
    CoreButtonSize.lg => Sp.xl,
  };

  double get iconSize => switch (this) {
    CoreButtonSize.sm => 16,
    CoreButtonSize.md => 18,
    CoreButtonSize.lg => 20,
  };

  CoreTextStyle get textStyle => switch (this) {
    CoreButtonSize.sm => CoreTextStyle.caption,
    CoreButtonSize.md => CoreTextStyle.label,
    CoreButtonSize.lg => CoreTextStyle.title,
  };
}

class CoreButton extends StatelessWidget {
  const CoreButton({
    required this.label,
    this.onPressed,
    this.variant = CoreButtonVariant.primary,
    this.size = CoreButtonSize.md,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.loading = false,
    this.semanticLabel,
    super.key,
  });

  const CoreButton.primary({
    required this.label,
    this.onPressed,
    this.size = CoreButtonSize.md,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.loading = false,
    this.semanticLabel,
    super.key,
  }) : variant = CoreButtonVariant.primary;

  const CoreButton.secondary({
    required this.label,
    this.onPressed,
    this.size = CoreButtonSize.md,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.loading = false,
    this.semanticLabel,
    super.key,
  }) : variant = CoreButtonVariant.secondary;

  const CoreButton.ghost({
    required this.label,
    this.onPressed,
    this.size = CoreButtonSize.md,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.loading = false,
    this.semanticLabel,
    super.key,
  }) : variant = CoreButtonVariant.ghost;

  const CoreButton.destructive({
    required this.label,
    this.onPressed,
    this.size = CoreButtonSize.md,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.loading = false,
    this.semanticLabel,
    super.key,
  }) : variant = CoreButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final CoreButtonVariant variant;
  final CoreButtonSize size;
  final IconData? leading;
  final IconData? trailing;
  final bool fullWidth;
  final bool loading;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = !_enabled;

    final (
      Gradient? gradient,
      Color? fill,
      Color borderColor,
      Color ink,
    ) = switch (variant) {
      CoreButtonVariant.primary => (
        LinearGradient(
          colors: [
            colors.palette.b.withValues(alpha: 0.20),
            colors.palette.a.withValues(alpha: 0.20),
          ],
        ),
        null,
        colors.borderHover,
        colors.textPrimary,
      ),
      CoreButtonVariant.secondary => (
        null,
        colors.surface1,
        colors.border,
        colors.textPrimary,
      ),
      CoreButtonVariant.ghost => (
        null,
        Colors.transparent,
        Colors.transparent,
        colors.textSecondary,
      ),
      CoreButtonVariant.destructive => (
        null,
        colors.danger.withValues(alpha: 0.14),
        colors.danger.withValues(alpha: 0.45),
        colors.danger,
      ),
    };

    final content = _Content(
      label: label,
      size: size,
      leading: leading,
      trailing: trailing,
      loading: loading,
      ink: disabled ? ink.withValues(alpha: 0.38) : ink,
    );

    final body = AnimatedOpacity(
      duration: context.motion(Motion.fast),
      opacity: disabled ? 0.55 : 1,
      child: Container(
        height: size.height,
        padding: EdgeInsets.symmetric(horizontal: size.horizontalPad),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          color: fill,
          borderRadius: Rd.none,
          border: Border.all(color: borderColor),
        ),
        child: content,
      ),
    );

    return CorePressable(
      onPressed: _enabled ? onPressed : null,
      semanticLabel: semanticLabel ?? label,
      child: fullWidth ? SizedBox(width: double.infinity, child: body) : body,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.size,
    required this.leading,
    required this.trailing,
    required this.loading,
    required this.ink,
  });

  final String label;
  final CoreButtonSize size;
  final IconData? leading;
  final IconData? trailing;
  final bool loading;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          Icon(leading, size: size.iconSize, color: ink),
          const SizedBox(width: Sp.sm),
        ],
        Flexible(
          child: CoreText(
            label,
            style: size.textStyle,
            color: ink,
            maxLines: 1,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Sp.sm),
          Icon(trailing, size: size.iconSize, color: ink),
        ],
      ],
    );

    // The spinner replaces the label in place, so the button never resizes
    // mid-interaction and the row it sits in never reflows.
    return AnimatedSwitcher(
      duration: context.motion(Motion.fast),
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: size.iconSize,
              height: size.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(ink),
              ),
            )
          : KeyedSubtree(key: ValueKey(label), child: labelRow),
    );
  }
}
