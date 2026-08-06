import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_theme.dart';
import 'package:fretwork/features/home/home_screen.dart';
import 'package:fretwork/features/library/library_screen.dart';
import 'package:fretwork/features/onboarding/onboarding_screen.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_screen.dart';
import 'package:fretwork/features/session/session_controller.dart';
import 'package:fretwork/features/settings/settings_screen.dart';
import 'package:fretwork/features/shell/app_shell.dart';
import 'package:fretwork/router.dart';

import '../support/store.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  bool onboarded = true,
}) async {
  final container = testContainer();
  if (onboarded) {
    await container
        .read(profileProvider.notifier)
        .completeOnboarding(
          milestone: 6,
          sessionMinutes: 60,
          restWeekdays: const {},
        );
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.build(Preferences.defaults),
        routerConfig: container.read(routerProvider),
        builder: (context, child) => MotionScope(
          reduced: true,
          reduceBlur: true,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('an un-onboarded user is redirected to onboarding', (
    tester,
  ) async {
    final container = await _pumpApp(tester, onboarded: false);
    addTearDown(container.dispose);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('an onboarded user lands on home inside the shell', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    addTearDown(container.dispose);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('completing onboarding moves the user into the shell', (
    tester,
  ) async {
    final container = await _pumpApp(tester, onboarded: false);
    addTearDown(container.dispose);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await container
        .read(profileProvider.notifier)
        .completeOnboarding(
          milestone: 2,
          sessionMinutes: 30,
          restWeekdays: const {},
        );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the nav bar switches branches', (tester) async {
    final container = await _pumpApp(tester);
    addTearDown(container.dispose);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Routine'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineScreen), findsOneWidget);
  });

  testWidgets('each branch keeps its own navigation state', (tester) async {
    final container = await _pumpApp(tester);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    // Go deep in the analytics branch, leave, come back.
    router.go(Routes.history);
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.history);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.history,
      reason: 'the analytics branch should still be where it was left',
    );
  });

  testWidgets('the session route hides the nav bar', (tester) async {
    final container = await _pumpApp(tester);
    addTearDown(container.dispose);

    container.read(routerProvider).go(Routes.session);
    // Not pumpAndSettle: the session screen runs a continuous ticker for the
    // ring and an ambient glow, so nothing ever settles there by design.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Routine'), findsNothing);

    // Stop the session's timers before the framework's pending-timer check.
    await container.read(sessionProvider.notifier).end();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the debug gallery is reachable before onboarding', (
    tester,
  ) async {
    final container = await _pumpApp(tester, onboarded: false);
    addTearDown(container.dispose);

    container.read(routerProvider).go(Routes.gallery);
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
  });

  test('Routes.exercise builds a path the router can match', () {
    expect(Routes.exercise('ex_11'), '/library/exercise/ex_11');
  });
}
