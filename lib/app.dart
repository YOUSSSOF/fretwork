import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_theme.dart';
import 'package:fretwork/features/history/history_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:fretwork/router.dart';

class FretworkApp extends ConsumerStatefulWidget {
  const FretworkApp({super.key});

  @override
  ConsumerState<FretworkApp> createState() => _FretworkAppState();
}

class _FretworkAppState extends ConsumerState<FretworkApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Backfill runs on launch and on every resume: the day can roll over while
    // the app sits in the background, and a missed day that is never recorded
    // silently improves the user's adherence.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rollover());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rollover();
  }

  void _rollover() {
    unawaited(ref.read(historyRolloverProvider).run());
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle(prefs));

    return MaterialApp.router(
      title: 'Fretwork',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(prefs),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          _MotionRoot(prefs: prefs, child: child ?? const SizedBox.shrink()),
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
