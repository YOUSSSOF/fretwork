import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_theme.dart';
import 'package:fretwork/features/splash/splash_screen.dart';

/// Mirrors how the app actually mounts the splash: in `MaterialApp.builder`,
/// above the Navigator. The shared `harness` puts its child inside a Scaffold,
/// which would supply the Material ancestor for free and hide the very bug
/// these tests exist to catch.
Widget _asMounted({required Widget home}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.build(Preferences.defaults),
  home: home,
  builder: (context, child) => MotionScope(
    reduced: false,
    reduceBlur: false,
    child: SplashGate(child: child ?? const SizedBox.shrink()),
  ),
);

void main() {
  group('SplashGate', () {
    testWidgets('the wordmark has a text style to inherit', (tester) async {
      await tester.pumpWidget(_asMounted(home: const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 1400));

      expect(find.text('F'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('F'), matching: find.byType(Material)),
        findsAtLeast(1),
        reason: 'without a Material ancestor the text renders unstyled',
      );

      final style = tester.widget<Text>(find.text('F')).style;
      expect(style?.fontSize, isNotNull);
      expect(style?.color, isNotNull);
      expect(
        style?.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: 'the debug fallback style underlines everything',
      );
    });

    testWidgets('it gets out of the way and lets the app through', (
      tester,
    ) async {
      await tester.pumpWidget(
        _asMounted(home: const Scaffold(body: Text('the app'))),
      );

      expect(find.text('the app'), findsOneWidget, reason: 'built underneath');
      expect(find.text('F'), findsOneWidget, reason: 'covered at first');

      await tester.pumpAndSettle();

      expect(find.text('F'), findsNothing);
      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('it never swallows taps meant for the app', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _asMounted(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('tap me'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('tap me'));
      expect(taps, 1);
    });
  });
}
