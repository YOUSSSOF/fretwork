import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/user_profile.dart';

/// The choices being assembled during onboarding.
///
/// Held separately from [UserProfile] so nothing is persisted until the user
/// finishes — a half-answered onboarding should not leave a half-configured
/// app behind if they close it.
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.step = 0,
    this.milestone,
    this.sessionMinutes,
    this.restWeekdays = const {},
  });

  final int step;

  /// Null until the user picks. There is deliberately no default: guessing how
  /// far through the course someone is would misconfigure the whole app.
  final int? milestone;

  final int? sessionMinutes;
  final Set<int> restWeekdays;

  bool get canLeaveMilestoneStep => milestone != null;

  int get resolvedMinutes =>
      sessionMinutes ?? UserProfile.suggestedMinutes(milestone ?? 2);

  int get suggestedMinutes => UserProfile.suggestedMinutes(milestone ?? 2);

  /// The user has chosen a session well below what the course suggests. Worth a
  /// non-blocking note, never a block — a short session done daily beats a long
  /// one done three times a week.
  bool get isWellBelowSuggestion => resolvedMinutes < suggestedMinutes * 0.6;

  OnboardingDraft copyWith({
    int? step,
    int? milestone,
    int? sessionMinutes,
    Set<int>? restWeekdays,
  }) => OnboardingDraft(
    step: step ?? this.step,
    milestone: milestone ?? this.milestone,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    restWeekdays: restWeekdays ?? this.restWeekdays,
  );
}

class OnboardingNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void goToStep(int step) => state = state.copyWith(step: step.clamp(0, 3));

  void selectMilestone(int milestone) {
    state = state.copyWith(
      milestone: milestone,
      // Re-anchor the length on the new milestone's suggestion unless the user
      // has already moved the slider themselves.
      sessionMinutes:
          state.sessionMinutes ?? UserProfile.suggestedMinutes(milestone),
    );
  }

  void setSessionMinutes(int minutes) => state = state.copyWith(
    sessionMinutes: minutes.clamp(kMinSessionMinutes, kMaxSessionMinutes),
  );

  void toggleRestWeekday(int weekday) {
    final next = {...state.restWeekdays};
    next.contains(weekday) ? next.remove(weekday) : next.add(weekday);
    state = state.copyWith(restWeekdays: next);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingDraft>(
      OnboardingNotifier.new,
    );

/// Categories the chosen milestone would unlock, for the preview and the
/// expanded milestone rows.
final categoriesAtMilestoneProvider =
    Provider.family<Set<PracticeCategory>, int>((ref, milestone) {
      return {
        for (final part in ref.watch(courseProvider))
          if (part.milestone <= milestone)
            for (final exercise in part.exercises) exercise.category,
      };
    });
