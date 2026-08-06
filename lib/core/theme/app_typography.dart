import 'package:flutter/material.dart';

/// The type scale. Every piece of text in the app resolves to one of these —
/// there are no ad-hoc `TextStyle(fontSize: 14)` literals in feature code.
enum CoreTextStyle {
  display,
  h1,
  h2,
  h3,
  title,
  body,
  bodySm,
  label,
  caption,
  mono,
}

/// Which semantic colour a style defaults to.
enum _Ink { primary, secondary, tertiary }

@immutable
class _Spec {
  const _Spec(this.size, this.weight, this.ink, {this.height, this.tracking});
  final double size;
  final FontWeight weight;
  final _Ink ink;
  final double? height;
  final double? tracking;
}

const Map<CoreTextStyle, _Spec> _specs = {
  CoreTextStyle.display: _Spec(
    40,
    FontWeight.w800,
    _Ink.primary,
    height: 1.05,
    tracking: -0.8,
  ),
  CoreTextStyle.h1: _Spec(
    30,
    FontWeight.w700,
    _Ink.primary,
    height: 1.12,
    tracking: -0.5,
  ),
  CoreTextStyle.h2: _Spec(
    24,
    FontWeight.w700,
    _Ink.primary,
    height: 1.18,
    tracking: -0.3,
  ),
  CoreTextStyle.h3: _Spec(
    20,
    FontWeight.w600,
    _Ink.primary,
    height: 1.22,
    tracking: -0.2,
  ),
  CoreTextStyle.title: _Spec(17, FontWeight.w600, _Ink.primary, height: 1.3),
  CoreTextStyle.body: _Spec(15, FontWeight.w400, _Ink.secondary, height: 1.45),
  CoreTextStyle.bodySm: _Spec(
    13,
    FontWeight.w400,
    _Ink.secondary,
    height: 1.45,
  ),
  CoreTextStyle.label: _Spec(
    13,
    FontWeight.w600,
    _Ink.primary,
    height: 1.2,
    tracking: 0.2,
  ),
  CoreTextStyle.caption: _Spec(
    11,
    FontWeight.w500,
    _Ink.tertiary,
    height: 1.25,
    tracking: 0.4,
  ),
  CoreTextStyle.mono: _Spec(15, FontWeight.w500, _Ink.primary, height: 1.2),
};

/// Minimum and maximum user text scale. Clamped so no layout can break.
const double kMinTextScale = 0.85;
const double kMaxTextScale = 1.35;

/// Carries the user's text-scale preference and the resolved font family into
/// the widget tree via [Theme], so `CoreText` never has to read a provider.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({required this.scale, this.fontFamily});

  final double scale;
  final String? fontFamily;

  double get clampedScale => scale.clamp(kMinTextScale, kMaxTextScale);

  TextStyle resolve(
    CoreTextStyle style, {
    required Color primary,
    required Color secondary,
    required Color tertiary,
    Color? override,
    bool tabular = false,
    double? scaleOverride,
  }) {
    final spec = _specs[style]!;
    final effectiveScale = (scaleOverride ?? clampedScale).clamp(
      kMinTextScale,
      kMaxTextScale,
    );
    final ink = switch (spec.ink) {
      _Ink.primary => primary,
      _Ink.secondary => secondary,
      _Ink.tertiary => tertiary,
    };
    final useTabular = tabular || style == CoreTextStyle.mono;
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: spec.size * effectiveScale,
      fontWeight: spec.weight,
      height: spec.height,
      letterSpacing: spec.tracking,
      color: override ?? ink,
      fontFeatures: useTabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  @override
  AppTypography copyWith({double? scale, String? fontFamily}) => AppTypography(
    scale: scale ?? this.scale,
    fontFamily: fontFamily ?? this.fontFamily,
  );

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      scale: lerpDouble(scale, other.scale, t),
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppTypographyX on BuildContext {
  AppTypography get typography =>
      Theme.of(this).extension<AppTypography>() ??
      const AppTypography(scale: 1);
}
