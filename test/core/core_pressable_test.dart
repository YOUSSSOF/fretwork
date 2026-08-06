import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/widgets/core_pressable.dart';

import '../support/harness.dart';

/// Reads the x-axis scale straight out of the matrix.
///
/// Not `getMaxScaleOnAxis()`: that also considers the untouched z axis, so it
/// reports 1.0 for any shrink and would pass no matter what the widget did.
double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byType(CorePressable),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.storage[0];
}

void main() {
  group('CorePressable', () {
    testWidgets('scales down on pointer-down and springs back on release', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Center(
            child: CorePressable(
              onPressed: () {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(_scaleOf(tester), closeTo(1, 0.001));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CorePressable)),
      );
      // The first pump starts the ticker (elapsed 0); the second advances it a
      // full Motion.instant, by which point the press is fully seated.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(_scaleOf(tester), closeTo(0.968, 0.005));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), closeTo(1, 0.005));
    });

    testWidgets('cancels without firing when the pointer drags away', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          Center(
            child: CorePressable(
              onPressed: () => taps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CorePressable)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await gesture.moveBy(const Offset(0, 400));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, 0);
      expect(_scaleOf(tester), closeTo(1, 0.005));
    });

    testWidgets('does not react when no callback is supplied', (tester) async {
      await tester.pumpWidget(
        harness(
          const Center(
            child: CorePressable(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CorePressable)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(tester), closeTo(1, 0.001));
      await gesture.up();
    });

    testWidgets('jumps straight to the pressed state under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          reduceMotion: true,
          Center(
            child: CorePressable(
              onPressed: () {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CorePressable)),
      );
      await tester.pump();
      expect(_scaleOf(tester), closeTo(0.968, 0.005));
      await gesture.up();
      await tester.pump();
      expect(_scaleOf(tester), closeTo(1, 0.001));
    });
  });
}
