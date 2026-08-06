import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/app.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/features/analytics/analytics_screen.dart';
import 'package:fretwork/features/history/history_controller.dart';
import 'package:fretwork/features/home/home_screen.dart';
import 'package:fretwork/features/library/library_screen.dart';
import 'package:fretwork/features/onboarding/onboarding_controller.dart';
import 'package:fretwork/features/onboarding/onboarding_screen.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/routine/routine_controller.dart';
import 'package:fretwork/features/routine/routine_screen.dart';
import 'package:fretwork/features/session/metronome/metronome_controller.dart';
import 'package:fretwork/features/session/metronome/metronome_engine.dart';
import 'package:fretwork/features/session/records_controller.dart';
import 'package:fretwork/features/settings/preferences_controller.dart';
import 'package:fretwork/features/settings/settings_screen.dart';

import 'support/store.dart';

/// End-to-end smoke tests against the real `FretworkApp`.
///
/// Everything below the root is production wiring — the real router, the real
/// providers, the real screens. Only the document store, the clock and the
/// audio engine are substituted, because none of the three can work in a test
/// VM. If the app cannot boot, these fail before any narrower test gets the
/// chance to pass while the whole thing is broken.
Future<ProviderContainer> _boot(WidgetTester tester) async {
  final store = MemoryDocumentStore();
  // Reduced motion, so pumpAndSettle can actually settle: the ambient glow
  // behind Home, Analytics and onboarding runs a 26-second float loop that by
  // design never ends.
  await store.write(
    BoxNames.preferences,
    DocKeys.prefs,
    const Preferences(reduceMotion: ReduceMotionSetting.on).toJson(),
  );

  final container = testContainer(
    store: store,
    overrides: [
      metronomeEngineProvider.overrideWithValue(const SilentMetronome()),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FretworkApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a fresh install lands on onboarding', (tester) async {
    final container = await _boot(tester);
    addTearDown(container.dispose);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Fretwork'), findsOneWidget);
  });

  testWidgets('onboarding through to a usable home screen', (tester) async {
    final container = await _boot(tester);
    addTearDown(container.dispose);

    final onboarding = container.read(onboardingProvider.notifier);
    onboarding
      ..selectMilestone(6)
      ..setSessionMinutes(60)
      ..goToStep(3);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start practising'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    // The Today card is the whole point of the home screen.
    expect(find.text("TODAY'S ROUTINE"), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);

    final routine = container.read(todayRoutineProvider);
    expect(routine.blocks, isNotEmpty);
    expect(routine.plannedMinutes, greaterThan(0));
  });

  testWidgets('every shell branch renders', (tester) async {
    final container = await _boot(tester);
    addTearDown(container.dispose);

    await container
        .read(profileProvider.notifier)
        .completeOnboarding(
          milestone: 8,
          sessionMinutes: 75,
          restWeekdays: const {},
        );
    await tester.pumpAndSettle();

    for (final (label, screen) in <(String, Type)>[
      ('Routine', RoutineScreen),
      ('Library', LibraryScreen),
      ('Analytics', AnalyticsScreen),
      ('Settings', SettingsScreen),
      ('Home', HomeScreen),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        find.byType(screen),
        findsOneWidget,
        reason: '$label did not open',
      );
    }
  });

  testWidgets('the day rollover runs on launch and records today', (
    tester,
  ) async {
    final container = await _boot(tester);
    addTearDown(container.dispose);

    await container
        .read(profileProvider.notifier)
        .completeOnboarding(
          milestone: 6,
          sessionMinutes: 60,
          restWeekdays: const {},
        );
    await tester.pumpAndSettle();
    await container.read(historyRolloverProvider).run();
    await tester.pumpAndSettle();

    expect(container.read(dayRecordsProvider), isNotEmpty);
  });

  testWidgets('changing the accent repaints without losing the route', (
    tester,
  ) async {
    final container = await _boot(tester);
    addTearDown(container.dispose);

    await container
        .read(profileProvider.notifier)
        .completeOnboarding(
          milestone: 6,
          sessionMinutes: 60,
          restWeekdays: const {},
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    await container
        .read(preferencesProvider.notifier)
        .update((p) => p.copyWith(accentPaletteId: 'green'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
  });
}
