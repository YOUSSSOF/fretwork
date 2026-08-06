import 'package:flutter/widgets.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_typography.dart';

/// Every string in the app renders through this.
///
/// It reads the user's text-scale preference from the theme (not from a
/// provider) and clamps it to 0.85–1.35 so no accessibility setting can break a
/// layout. Numeric readouts pass `tabular: true` so digits keep a fixed advance
/// width and a ticking timer does not jitter.
class CoreText extends StatelessWidget {
  const CoreText(
    this.data, {
    this.style = CoreTextStyle.body,
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  });

  const CoreText.display(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.display;

  const CoreText.h1(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.h1;

  const CoreText.h2(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.h2;

  const CoreText.h3(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.h3;

  const CoreText.title(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.title;

  const CoreText.body(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.body;

  const CoreText.bodySm(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.bodySm;

  const CoreText.label(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.label;

  const CoreText.caption(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = false,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.caption;

  const CoreText.mono(
    this.data, {
    this.color,
    this.maxLines,
    this.align,
    this.tabular = true,
    this.scaleOverride,
    this.overflow,
    this.softWrap,
    this.weight,
    super.key,
  }) : style = CoreTextStyle.mono;

  final String data;
  final CoreTextStyle style;
  final Color? color;
  final int? maxLines;
  final TextAlign? align;
  final bool tabular;
  final double? scaleOverride;
  final TextOverflow? overflow;
  final bool? softWrap;
  final FontWeight? weight;

  /// Resolves the same [TextStyle] this widget would render with — for callers
  /// that need to measure text (e.g. `CoreTabs`) before laying it out.
  static TextStyle styleOf(
    BuildContext context,
    CoreTextStyle style, {
    Color? color,
    bool tabular = false,
    FontWeight? weight,
    double? scaleOverride,
  }) {
    final colors = context.colors;
    final resolved = context.typography.resolve(
      style,
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
      tertiary: colors.textTertiary,
      override: color,
      tabular: tabular,
      scaleOverride: scaleOverride,
    );
    return weight == null ? resolved : resolved.copyWith(fontWeight: weight);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      maxLines: maxLines,
      textAlign: align,
      softWrap: softWrap,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
      style: styleOf(
        context,
        style,
        color: color,
        tabular: tabular,
        weight: weight,
        scaleOverride: scaleOverride,
      ),
    );
  }
}
