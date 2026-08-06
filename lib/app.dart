import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_theme.dart';
import 'package:fretwork/features/debug/gallery_screen.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';

class FretworkApp extends ConsumerWidget {
  const FretworkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle(prefs));

    return MaterialApp(
      title: 'Fretwork',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(prefs),
      themeMode: ThemeMode.dark,
      builder: (context, child) =>
          _MotionRoot(prefs: prefs, child: child ?? const SizedBox.shrink()),
      home: const GalleryScreen(),
    );
  }
}

/// Resolves the reduce-motion setting once, at the root, against the platform
/// accessibility flag, and publishes it to the whole tree.
class _MotionRoot extends StatelessWidget {
  const _MotionRoot({required this.prefs, required this.child});

  final Preferences prefs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final systemReduced = MediaQuery.disableAnimationsOf(context);
    final reduced = switch (prefs.reduceMotion) {
      ReduceMotionSetting.followSystem => systemReduced,
      ReduceMotionSetting.on => true,
      ReduceMotionSetting.off => false,
    };
    return MotionScope(
      reduced: reduced,
      reduceBlur: prefs.reduceBlur,
      child: child,
    );
  }
}
