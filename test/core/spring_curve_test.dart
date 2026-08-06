import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/motion/motion_tokens.dart';
import 'package:fretwork/core/motion/spring_curve.dart';

void main() {
  group('SpringCurve', () {
    test('starts at 0 and ends at 1', () {
      final curve = SpringCurve(Motion.snappy);
      expect(curve.transform(0), closeTo(0, 0.001));
      expect(curve.transform(1), closeTo(1, 0.01));
    });

    test('settles within a duration usable by an AnimationController', () {
      for (final description in [Motion.snappy, Motion.gentle, Motion.bouncy]) {
        final curve = SpringCurve(description);
        expect(curve.settleDuration, greaterThan(Duration.zero));
        expect(curve.settleDuration, lessThan(const Duration(seconds: 4)));
      }
    });

    test('overshoot scales with how underdamped the spring is', () {
      double peak(SpringCurve curve) {
        var max = 0.0;
        for (var i = 0; i <= 100; i++) {
          final v = curve.transform(i / 100);
          if (v > max) max = v;
        }
        return max;
      }

      final snappyPeak = peak(SpringCurve(Motion.snappy));
      final gentlePeak = peak(SpringCurve(Motion.gentle));
      final bouncyPeak = peak(SpringCurve(Motion.bouncy));

      // All three are underdamped by design — a critically damped press feels
      // dead. Overshoot tracks the damping ratio, so the order is gentle
      // (0.81) < snappy (0.70) < bouncy (0.44), and the tightest of them never
      // overshoots far enough to read as a wobble.
      expect(gentlePeak, greaterThan(1.0));
      expect(snappyPeak, greaterThan(gentlePeak));
      expect(bouncyPeak, greaterThan(snappyPeak));
      expect(gentlePeak, lessThan(1.05));
      expect(bouncyPeak, lessThan(1.35));
    });

    test('never runs away — values stay in a sane band', () {
      final curve = SpringCurve(Motion.bouncy);
      for (var i = 0; i <= 100; i++) {
        final v = curve.transform(i / 100);
        expect(v, inInclusiveRange(-0.5, 1.5));
      }
    });
  });
}
