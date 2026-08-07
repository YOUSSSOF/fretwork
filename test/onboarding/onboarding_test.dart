import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/models/user_profile.dart';
import 'package:fretwork/core/motion/motion_scope.dart';
import 'package:fretwork/core/theme/app_theme.dart';
import 'package:fretwork/core/widgets/core_button.dart';
import 'package:fretwork/features/onboarding/onboarding_controller.dart';
import 'package:fretwork/features/onboarding/onboarding_screen.dart';
import 'package:fretwork/features/progress/progress_controller.dart';

import '../support/store.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final container = testContainer();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(Preferences.defaults),
        home: const MotionScope(
          reduced: true,
          reduceBlur: true,
          child: OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

CoreButton _continueButton(WidgetTester tester) => tester
    .widgetList<CoreButton>(find.byType(CoreButton))
    .firstWhere((b) => b.label == 'Continue' || b.label == 'Start practising');

void main() {
  group('OnboardingDraft', () {
    test('has no default milestone — the user must choose', () {
      const draft = OnboardingDraft();
      expect(draft.milestone, isNull);
      expect(draft.canLeaveMilestoneStep, isFalse);
    });

    test('resolves the session length from the milestone until overridden', () {
      const draft = OnboardingDraft(milestone: 6);
      expect(draft.resolvedMinutes, UserProfile.suggestedMinutes(6));

      const edited = OnboardingDraft(milestone: 6, sessionMinutes: 25);
      expect(edited.resolvedMinutes, 25);
    });

    test('flags a session well below the suggestion without blocking it', () {
      const low = OnboardingDraft(milestone: 6, sessionMinutes: 25);
      expect(low.isWellBelowSuggestion, isTrue);

      const fine = OnboardingDraft(milestone: 6, sessionMinutes: 45);
      expect(fine.isWellBelowSuggestion, isFalse);
    });
  });

  group('OnboardingNotifier', () {
    test('selecting a milestone anchors the suggested length', () {
      final container = testContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.selectMilestone(9);
      expect(
        container.read(onboardingProvider).resolvedMinutes,
        UserProfile.suggestedMinutes(9),
      );
    });

    test('a length the user has set survives changing the milestone', () {
      final container = testContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.selectMilestone(2);
      notifier.setSessionMinutes(50);
      notifier.selectMilestone(9);
      expect(container.read(onboardingProvider).sessionMinutes, 50);
    });

    test('clamps a length outside the policy range', () {
      final container = testContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.setSessionMinutes(5);
      expect(
        container.read(onboardingProvider).sessionMinutes,
        kMinSessionMinutes,
      );
      notifier.setSessionMinutes(999);
      expect(
        container.read(onboardingProvider).sessionMinutes,
        kMaxSessionMinutes,
      );
    });

    test('rest weekdays toggle both ways', () {
      final container = testContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.toggleRestWeekday(DateTime.sunday);
      expect(container.read(onboardingProvider).restWeekdays, {
        DateTime.sunday,
      });
      notifier.toggleRestWeekday(DateTime.sunday);
      expect(container.read(onboardingProvider).restWeekdays, isEmpty);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('cannot leave the milestone step without choosing', (
      tester,
    ) async {
      final container = await _pump(tester);
      addTearDown(container.dispose);

      // Step 0 -> 1.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(container.read(onboardingProvider).step, 1);

      expect(
        _continueButton(tester).onPressed,
        isNull,
        reason: 'Continue must be disabled until a milestone is chosen',
      );

      // The list is long enough that Part V is below the fold on a test-sized
      // viewport, so scroll it in rather than tapping into empty space.
      await tester.scrollUntilVisible(
        find.text('Part V — Scale Fragments & Sequences'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Part V — Scale Fragments & Sequences'));
      await tester.pumpAndSettle();

      expect(_continueButton(tester).onPressed, isNotNull);
      expect(container.read(onboardingProvider).milestone, 6);
    });

    testWidgets('the length step previews the split and reacts to the slider', (
      tester,
    ) async {
      final container = await _pump(tester);
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.selectMilestone(6);
      notifier.goToStep(2);
      await tester.pumpAndSettle();

      expect(find.text('YOUR SESSION'), findsOneWidget);
      expect(find.text('Scale fragments'), findsOneWidget);

      // A 20-minute session prices out time feel entirely.
      notifier.setSessionMinutes(20);
      await tester.pumpAndSettle();
      expect(find.text('Time feel'), findsNothing);
    });

    testWidgets('finishing writes the profile and marks onboarding complete', (
      tester,
    ) async {
      final container = await _pump(tester);
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.selectMilestone(6);
      notifier.setSessionMinutes(45);
      notifier.toggleRestWeekday(DateTime.sunday);
      notifier.goToStep(3);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start practising'));
      await tester.pumpAndSettle();

      final profile = container.read(profileProvider);
      expect(profile.onboardingComplete, isTrue);
      expect(profile.milestone, 6);
      expect(profile.sessionMinutes, 45);
      expect(profile.restWeekdays, {DateTime.sunday});
    });

    testWidgets('the final step shows a plan built from the choices', (
      tester,
    ) async {
      final container = await _pump(tester);
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.selectMilestone(2);
      notifier.setSessionMinutes(30);
      notifier.goToStep(3);
      await tester.pumpAndSettle();

      expect(find.text('Your first routine'), findsOneWidget);
      // Milestone 2 is warm-up only: that is the whole point of starting
      // there rather than dropping the user into a full session.
      expect(find.text('Left-hand warm-up'), findsOneWidget);
    });

    testWidgets('a rest day today is explained rather than shown as empty', (
      tester,
    ) async {
      final container = await _pump(tester);
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      notifier.selectMilestone(6);
      // Every weekday is a rest day, so whatever today is, it is one.
      for (final weekday in const [1, 2, 3, 4, 5, 6, 7]) {
        notifier.toggleRestWeekday(weekday);
      }
      notifier.goToStep(3);
      await tester.pumpAndSettle();

      expect(find.textContaining('rest days'), findsOneWidget);
    });
  });
}
