import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/theme/app_spacing.dart';
import 'package:fretwork/core/widgets/core_tabs.dart';

import '../support/harness.dart';

/// The widths the plan calls out: small phone, iPhone-class, large phone,
/// tablet.
const List<double> _widths = [320, 390, 430, 768];
const List<int> _counts = [2, 5, 8, 12, 18, 24];

List<CoreTabItem> _items(int count) => [
  for (var i = 1; i <= count; i++)
    CoreTabItem(
      id: 'frag_$i',
      label: 'Fragment $i',
      shortLabel: 'Frag $i',
      marked: i == 3,
    ),
];

Future<void> _pumpTabs(
  WidgetTester tester, {
  required int count,
  required double width,
  required CoreTabsDensity density,
  String? selectedId,
  ValueChanged<String>? onSelected,
}) async {
  final items = _items(count);
  await tester.pumpWidget(
    harness(
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: CoreTabs(
            items: items,
            selectedId: selectedId ?? items.first.id,
            onSelected: onSelected ?? (_) {},
            density: density,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rendered geometry of each tab, in the tab row's own coordinate space.
List<Rect> _tabRects(WidgetTester tester) {
  final positioned = find.descendant(
    of: find.byType(CoreTabs),
    matching: find.byWidgetPredicate(
      (w) => w is Positioned && w.width != null && w.left != null,
    ),
  );
  final rects = <Rect>[];
  for (final element in positioned.evaluate()) {
    final widget = element.widget as Positioned;
    rects.add(Rect.fromLTWH(widget.left!, 0, widget.width!, 1));
  }
  return rects;
}

void main() {
  group('CoreTabs layout invariants', () {
    for (final density in CoreTabsDensity.values) {
      for (final width in _widths) {
        for (final count in _counts) {
          testWidgets(
            '$count items at ${width.toInt()}dp, ${density.name} density: '
            'no wrap, no overlap, no compression',
            (tester) async {
              tester.view.physicalSize = Size(width, 800);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);

              await _pumpTabs(
                tester,
                count: count,
                width: width,
                density: density,
              );

              final rects = _tabRects(tester);
              expect(
                rects.length,
                count,
                reason: 'every item must render exactly once',
              );

              // Never wraps: the row is exactly one tab tall.
              expect(
                tester.getSize(find.byType(CoreTabs)).height,
                density.height,
              );

              for (var i = 0; i < rects.length; i++) {
                // Never compressed below the density floor.
                expect(
                  rects[i].width,
                  greaterThanOrEqualTo(density.minTabWidth - 0.01),
                  reason: 'tab $i fell below minTabWidth',
                );
                if (i > 0) {
                  // Monotonically increasing origins, and no overlap.
                  expect(
                    rects[i].left,
                    greaterThan(rects[i - 1].left),
                    reason: 'tab origins must increase',
                  );
                  expect(
                    rects[i].left,
                    greaterThanOrEqualTo(rects[i - 1].right - 0.01),
                    reason: 'tab $i overlaps tab ${i - 1}',
                  );
                }
              }
            },
          );
        }
      }
    }
  });

  group('CoreTabs mode selection', () {
    testWidgets('a small set on a wide viewport is fitted and fills it', (
      tester,
    ) async {
      await _pumpTabs(
        tester,
        count: 3,
        width: 768,
        density: CoreTabsDensity.regular,
      );
      final rects = _tabRects(tester);
      expect(rects.last.right, closeTo(768, 0.5));
      // Fitted mode shares the viewport evenly.
      expect(rects[0].width, closeTo(rects[1].width, 0.01));
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    });

    testWidgets('a large set on a narrow viewport scrolls and offers a jump', (
      tester,
    ) async {
      await _pumpTabs(
        tester,
        count: 18,
        width: 320,
        density: CoreTabsDensity.regular,
      );
      final rects = _tabRects(tester);
      expect(rects.last.right, greaterThan(320));
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('short labels kick in past the threshold, not before', (
      tester,
    ) async {
      await _pumpTabs(
        tester,
        count: 8,
        width: 320,
        density: CoreTabsDensity.regular,
      );
      expect(find.text('Fragment 1'), findsOneWidget);
      expect(find.text('Frag 1'), findsNothing);

      await _pumpTabs(
        tester,
        count: 18,
        width: 320,
        density: CoreTabsDensity.regular,
      );
      expect(find.text('Frag 1'), findsOneWidget);
      expect(find.text('Fragment 1'), findsNothing);
    });
  });

  group('CoreTabs behaviour', () {
    testWidgets('never renders an ellipsis', (tester) async {
      await _pumpTabs(
        tester,
        count: 24,
        width: 320,
        density: CoreTabsDensity.large,
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.data, isNot(contains('…')));
      }
    });

    testWidgets('reports the tapped item', (tester) async {
      String? tapped;
      // Three items at 768 dp fit, so every tab is on screen and the tap
      // location is unambiguous. (At 390 dp these same labels already
      // overflow into scrollable mode.)
      await _pumpTabs(
        tester,
        count: 3,
        width: 768,
        density: CoreTabsDensity.regular,
        onSelected: (id) => tapped = id,
      );
      await tester.tap(find.text('Fragment 3'));
      await tester.pumpAndSettle();
      expect(tapped, 'frag_3');
    });

    testWidgets('scrolls the selected tab into view when it changes', (
      tester,
    ) async {
      final items = _items(18);
      var selected = items.first.id;

      await tester.pumpWidget(
        harness(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) => CoreTabs(
                  items: items,
                  selectedId: selected,
                  onSelected: (id) => setState(() => selected = id),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(SingleChildScrollView);
      final before = tester
          .widget<SingleChildScrollView>(scrollable)
          .controller!
          .offset;
      expect(before, 0);

      // Jump to a fragment well off-screen via the index sheet.
      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fragment 15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fragment 15'));
      await tester.pumpAndSettle();

      final after = tester
          .widget<SingleChildScrollView>(scrollable)
          .controller!
          .offset;
      expect(after, greaterThan(before));
    });

    testWidgets('marks the scheduled item with a dot', (tester) async {
      await _pumpTabs(
        tester,
        count: 5,
        width: 390,
        density: CoreTabsDensity.regular,
      );
      final dots = find.byWidgetPredicate(
        (w) =>
            w is Container && w.constraints?.maxWidth == CoreTabs.markerDotSize,
      );
      expect(dots, findsOneWidget);
    });

    testWidgets('renders nothing tall for an empty item list', (tester) async {
      await tester.pumpWidget(
        harness(CoreTabs(items: const [], selectedId: '', onSelected: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CoreTabs)).height,
        CoreTabsDensity.regular.height,
      );
    });
  });
}
