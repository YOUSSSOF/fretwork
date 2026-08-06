import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/theme/app_colors.dart';
import 'package:fretwork/core/theme/app_typography.dart';

/// Dark-first, and only. A light theme is explicitly out of scope — the whole
/// surface treatment (glass over near-black, glow, low-alpha borders) assumes a
/// dark ground and would need a different design, not a palette flip.
abstract final class AppTheme {
  /// Set to `'Inter'` when the family is bundled in `assets/fonts`; null falls
  /// back to the platform sans, which is the correct behaviour rather than a
  /// silent mismatch.
  static const String? uiFontFamily = null;

  static ThemeData build(Preferences prefs) {
    final palette = paletteById(prefs.accentPaletteId);
    final colors = AppColors(palette);
    final scheme = ColorScheme.dark(
      primary: palette.d,
      onPrimary: Colors.white,
      secondary: palette.a,
      onSecondary: Colors.white,
      surface: colors.surface0,
      onSurface: colors.textPrimary,
      error: colors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.surface0,
      canvasColor: colors.surface0,
      splashFactory: NoSplash.splashFactory,
      // CorePressable owns every press response in the app; Material's ripple
      // and highlight would fight it.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      fontFamily: uiFontFamily,
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.d,
        selectionColor: colors.selection,
        selectionHandleColor: palette.d,
      ),
      extensions: [
        colors,
        AppTypography(scale: prefs.textScale, fontFamily: uiFontFamily),
      ],
    );
  }

  static SystemUiOverlayStyle overlayStyle(Preferences prefs) =>
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
}
