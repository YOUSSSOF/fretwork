import 'package:flutter/animation.dart';
import 'package:fretwork/core/motion/spring_curve.dart';

/// Motion tokens. Nothing in this app moves on a duration or curve that is not
/// named here — that is what keeps the whole surface feeling like one object.
abstract final class Motion {
  // Durations.
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration page = Duration(milliseconds: 420);

  // Curves.
  static const Cubic standard = Cubic(0.32, 0.72, 0.0, 1.0);
  static const Cubic emphasize = Cubic(0.16, 1.0, 0.30, 1.0);
  static const Cubic exit = Cubic(0.40, 0.0, 1.0, 1.0);

  // Springs.
  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 32,
  );
  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 26,
  );
  static const SpringDescription bouncy = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 18,
  );

  // Spring curves, built once — measuring settle time is not free.
  static final SpringCurve snappyCurve = SpringCurve(snappy);
  static final SpringCurve gentleCurve = SpringCurve(gentle);
  static final SpringCurve bouncyCurve = SpringCurve(bouncy);

  /// Per-item delay for the two entrance animations that are allowed (§5.3).
  static const Duration stagger = Duration(milliseconds: 40);

  /// Indicator travel in a scrollable tab row is capped so jumping from
  /// fragment 1 to fragment 18 does not feel sluggish.
  static const Duration indicatorTravelCap = Duration(milliseconds: 320);

  /// Ambient glow float loop.
  static const Duration ambientFloat = Duration(seconds: 26);
}
