import 'package:flutter/material.dart';

/// A selectable accent palette.
///
/// The four slots mirror the source design system:
/// [a] primary accent, [b] secondary accent / borders, [c] page background,
/// [d] medium accent / highlights.
@immutable
class AccentPalette {
  const AccentPalette({
    required this.id,
    required this.label,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
  });

  final String id;
  final String label;
  final Color a;
  final Color b;
  final Color c;
  final Color d;
}

const AccentPalette darkCrimson = AccentPalette(
  id: 'crimson',
  label: 'Dark Crimson',
  a: Color(0xFF5A0E12),
  b: Color(0xFF3B070A),
  c: Color(0xFF141010),
  d: Color(0xFF8B1E24),
);

const AccentPalette darkTeal = AccentPalette(
  id: 'teal',
  label: 'Dark Teal',
  a: Color(0xFF1B5B5C),
  b: Color(0xFF0F3D3E),
  c: Color(0xFF171717),
  d: Color(0xFF2A9D9A),
);

const AccentPalette neonGreen = AccentPalette(
  id: 'green',
  label: 'Neon Green',
  a: Color(0xFF3ECA43),
  b: Color(0xFF37B13B),
  c: Color(0xFF171717),
  d: Color(0xFF1F6522),
);

const List<AccentPalette> accentPalettes = [darkCrimson, darkTeal, neonGreen];

AccentPalette paletteById(String id) =>
    accentPalettes.firstWhere((p) => p.id == id, orElse: () => darkCrimson);

/// Semantic colours derived from the active [AccentPalette].
///
/// Widgets must read these through `context.colors` and never hardcode a
/// palette value, so switching the accent theme repaints everything.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors(this.palette);

  final AccentPalette palette;

  Color get surface0 => palette.c;

  Color get surface1 => Color.alphaBlend(
    const Color(0xFF000000).withValues(alpha: 0.20),
    surface0,
  );

  Color get surface2 => Color.alphaBlend(
    const Color(0xFF000000).withValues(alpha: 0.30),
    surface0,
  );

  Color get border => Colors.white.withValues(alpha: 0.10);

  Color get borderHover => Colors.white.withValues(alpha: 0.20);

  Color get textPrimary => Colors.white.withValues(alpha: 0.92);

  Color get textSecondary => Colors.white.withValues(alpha: 0.62);

  Color get textTertiary => Colors.white.withValues(alpha: 0.38);

  Color get accent => palette.a;

  Color get accentStrong => palette.d;

  Color get glowA => palette.b.withValues(alpha: 0.10);

  Color get selection => palette.a.withValues(alpha: 0.20);

  Color get danger => const Color(0xFFE0524F);

  Color get success => const Color(0xFF4FBF7B);

  LinearGradient get accentGradient => LinearGradient(
    colors: [palette.b, palette.a],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Stronger gradient used for indicators and section underlines, where the
  /// dim [palette.b] end would otherwise disappear against the background.
  LinearGradient get accentGradientBright => LinearGradient(
    colors: [palette.a, palette.d],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Distinct hue per practice category, derived so it stays in family with
  /// the active accent instead of clashing with it.
  Color categoryColor(int index, int total) {
    final base = HSLColor.fromColor(palette.d);
    const spread = 260.0;
    final hue = (base.hue + (index / (total == 0 ? 1 : total)) * spread) % 360;
    return HSLColor.fromAHSL(
      1,
      hue,
      base.saturation.clamp(0.35, 0.75),
      base.lightness.clamp(0.42, 0.62),
    ).toColor();
  }

  @override
  AppColors copyWith({AccentPalette? palette}) =>
      AppColors(palette ?? this.palette);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? const AppColors(darkCrimson);
}
