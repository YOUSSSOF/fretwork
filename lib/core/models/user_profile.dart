import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';

/// Hard limits on session length. Values outside are rejected in the UI with an
/// explanation — never silently coerced.
const int kMinSessionMinutes = 20;
const int kMaxSessionMinutes = 150;

/// The highest milestone in the course.
const int kMaxMilestone = 10;

@immutable
class UserProfile {
  const UserProfile({
    required this.startedAt,
    this.milestone = 0,
    this.sessionMinutes = 30,
    this.restWeekdays = const {},
    this.lastOpenedOn,
    this.onboardingComplete = false,
  });

  /// 0..10. The single source of truth for what content is unlocked.
  final int milestone;

  final int sessionMinutes;

  /// Weekday constants from [DateTime], e.g. `{DateTime.sunday}`.
  final Set<int> restWeekdays;

  final DateTime startedAt;
  final DateTime? lastOpenedOn;
  final bool onboardingComplete;

  bool isRestWeekday(DateTime date) => restWeekdays.contains(date.weekday);

  /// The session length the course suggests at a given milestone. The user can
  /// override it; this is what the onboarding slider starts on and what the
  /// "you are well below the suggestion" note compares against.
  static int suggestedMinutes(int milestone) => switch (milestone) {
    <= 4 => 30,
    5 => 45,
    6 => 60,
    7 || 8 => 75,
    _ => 90,
  };

  UserProfile copyWith({
    int? milestone,
    int? sessionMinutes,
    Set<int>? restWeekdays,
    DateTime? lastOpenedOn,
    bool? onboardingComplete,
  }) => UserProfile(
    milestone: milestone ?? this.milestone,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    restWeekdays: restWeekdays ?? this.restWeekdays,
    startedAt: startedAt,
    lastOpenedOn: lastOpenedOn ?? this.lastOpenedOn,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );

  Map<String, Object?> toJson() => {
    'milestone': milestone,
    'sessionMinutes': sessionMinutes,
    'restWeekdays': restWeekdays.toList()..sort(),
    'startedAt': dateToJson(startedAt),
    if (lastOpenedOn != null) 'lastOpenedOn': dateToJson(lastOpenedOn!),
    'onboardingComplete': onboardingComplete,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    milestone: intFromJson(json['milestone'], 0).clamp(0, kMaxMilestone),
    sessionMinutes: intFromJson(
      json['sessionMinutes'],
      30,
    ).clamp(kMinSessionMinutes, kMaxSessionMinutes),
    restWeekdays: {
      for (final raw in (json['restWeekdays'] as List<Object?>? ?? const []))
        if (raw is int && raw >= DateTime.monday && raw <= DateTime.sunday) raw,
    },
    startedAt: dateFromJson(json['startedAt'], fallback: DateTime.now()),
    lastOpenedOn: dateFromJsonOrNull(json['lastOpenedOn']),
    onboardingComplete: boolFromJson(json['onboardingComplete'], false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.milestone == milestone &&
          other.sessionMinutes == sessionMinutes &&
          setEquals(other.restWeekdays, restWeekdays) &&
          other.startedAt == startedAt &&
          other.lastOpenedOn == lastOpenedOn &&
          other.onboardingComplete == onboardingComplete;

  @override
  int get hashCode => Object.hash(
    milestone,
    sessionMinutes,
    Object.hashAllUnordered(restWeekdays),
    startedAt,
    lastOpenedOn,
    onboardingComplete,
  );
}
