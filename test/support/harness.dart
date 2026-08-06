import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_theme.dart';

/// Wraps a widget in exactly the ambient state the app provides at runtime:
/// theme extensions (colours, type scale) and the motion scope. Widget tests
/// that skip this get a default Material theme and silently exercise the
/// fallback code paths instead of the real ones.
Widget harness(
  Widget child, {
  Preferences prefs = Preferences.defaults,
  bool reduceMotion = false,
  Size? size,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(prefs),
      home: MotionScope(
        reduced: reduceMotion,
        reduceBlur: prefs.reduceBlur,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: size == null
                ? child
                : Center(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: child,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
