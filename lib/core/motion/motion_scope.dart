import 'package:flutter/widgets.dart';

/// Carries the resolved reduce-motion decision down the tree.
///
/// When [reduced] is true every duration collapses to zero and ambient float
/// stops. Haptics deliberately stay on — reduced motion is about visual
/// vestibular load, not about removing feedback.
class MotionScope extends InheritedWidget {
  const MotionScope({
    required this.reduced,
    required this.reduceBlur,
    required super.child,
    super.key,
  });

  final bool reduced;
  final bool reduceBlur;

  static MotionScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionScope>() ??
      const MotionScope(
        reduced: false,
        reduceBlur: false,
        child: SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(MotionScope oldWidget) =>
      oldWidget.reduced != reduced || oldWidget.reduceBlur != reduceBlur;
}

extension MotionScopeX on BuildContext {
  bool get reduceMotion => MotionScope.of(this).reduced;

  bool get reduceBlur => MotionScope.of(this).reduceBlur;

  /// Collapses [duration] to zero when the user has asked for reduced motion.
  /// Every animation in the app routes its duration through this.
  Duration motion(Duration duration) =>
      MotionScope.of(this).reduced ? Duration.zero : duration;

  /// Springs degrade to instant under reduced motion.
  Curve motionCurve(Curve curve) =>
      MotionScope.of(this).reduced ? Curves.linear : curve;
}
