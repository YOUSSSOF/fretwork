import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/widgets/core_animated_number.dart';
import 'package:fretwork/core/widgets/core_book_reference.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/core/widgets/core_segmented_grid.dart';
import 'package:fretwork/core/widgets/core_stepper_field.dart';
import 'package:fretwork/core/widgets/core_text.dart';

import '../support/harness.dart';

void main() {
  group('CoreButton', () {
    testWidgets('does not fire while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          Center(
            child: CoreButton.primary(
              label: 'Start',
              loading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CoreButton));
      await tester.pump();
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('keeps its width when the spinner replaces the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Center(
            child: CoreButton.primary(label: 'Start session', onPressed: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(CoreButton));

      await tester.pumpWidget(
        harness(
          Center(
            child: CoreButton.primary(
              label: 'Start session',
              loading: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the spinner never stops, so nothing ever settles.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(find.byType(CoreButton)), before);
    });
  });

  group('CoreAnimatedNumber', () {
    testWidgets('renders one switcher per digit', (tester) async {
      await tester.pumpWidget(
        harness(
          const Center(
            child: CoreAnimatedNumber(value: '120', suffix: 'bpm'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSwitcher), findsNWidgets(3));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
    });

    testWidgets('rolls to the new value', (tester) async {
      await tester.pumpWidget(
        harness(const Center(child: CoreAnimatedNumber(value: '119'))),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        harness(const Center(child: CoreAnimatedNumber(value: '120'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('9'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('CoreStepperField', () {
    testWidgets('steps up and clamps at the maximum', (tester) async {
      var value = 118;
      await tester.pumpWidget(
        harness(
          Center(
            child: StatefulBuilder(
              builder: (context, setState) => CoreStepperField(
                value: value,
                min: 40,
                max: 120,
                step: 2,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 120);

      // At the ceiling the button disables rather than silently no-opping.
      await tester.tap(find.byIcon(Icons.add_rounded), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(value, 120);
    });

    testWidgets('accelerates while held', (tester) async {
      var value = 60;
      await tester.pumpWidget(
        harness(
          Center(
            child: StatefulBuilder(
              builder: (context, setState) => CoreStepperField(
                value: value,
                min: 40,
                max: 260,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add_rounded)),
      );
      // Pumped in frame-sized slices so the repeat timer fires the way it does
      // on a device, rather than collapsing two seconds into one jump.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();

      // A two-second hold should move well past what tapping could manage.
      expect(value, greaterThan(70));
    });
  });

  group('CoreSegmentedGrid', () {
    testWidgets('reports the chosen value', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        harness(
          Center(
            child: CoreSegmentedGrid<String>(
              items: const [
                CoreSegmentedItem(value: 'a', label: 'Alpha'),
                CoreSegmentedItem(value: 'b', label: 'Beta'),
                CoreSegmentedItem(value: 'c', label: 'Gamma', enabled: false),
              ],
              selected: const {'a'},
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(chosen, 'b');

      chosen = null;
      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();
      expect(chosen, isNull, reason: 'disabled items must not report');
    });
  });

  group('CoreBookReference', () {
    testWidgets('omits the CD track when there is not one', (tester) async {
      await tester.pumpWidget(
        harness(const Center(child: CoreBookReference(page: 26))),
      );
      expect(find.text('Book p. 26'), findsOneWidget);

      await tester.pumpWidget(
        harness(const Center(child: CoreBookReference(page: 26, cdTrack: 11))),
      );
      expect(find.text('Book p. 26 · CD track 11'), findsOneWidget);
    });
  });

  group('CoreText', () {
    testWidgets('clamps the user text scale at both ends', (tester) async {
      Future<double> sizeAt(double scale) async {
        await tester.pumpWidget(
          harness(Center(child: CoreText.body('Hello', scaleOverride: scale))),
        );
        return tester.widget<Text>(find.text('Hello')).style!.fontSize!;
      }

      expect(await sizeAt(5), 15 * 1.35);
      expect(await sizeAt(0.1), 15 * 0.85);
    });
  });
}
