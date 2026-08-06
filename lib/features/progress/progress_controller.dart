import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/user_profile.dart';

/// The user's progression state: milestone, session length, rest days.
///
/// Every content-visibility decision in the app reads from here. Writes are
/// persisted immediately — losing a milestone advance to a force-quit would be
/// worse than the write cost.
class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final store = ref.watch(storeProvider);
    final doc = store.read(BoxNames.profile, DocKeys.profile);
    if (doc == null) {
      return UserProfile(startedAt: ref.read(clockProvider).now());
    }
    return UserProfile.fromJson(doc);
  }

  Future<void> _write(UserProfile profile) async {
    state = profile;
    await ref
        .read(storeProvider)
        .write(BoxNames.profile, DocKeys.profile, profile.toJson());
  }

  Future<void> update(UserProfile Function(UserProfile current) change) {
    final next = change(state);
    if (next == state) return Future<void>.value();
    return _write(next);
  }

  /// Advancing is a deliberate, confirmed action taken on the milestone screen;
  /// this method assumes that confirmation has already happened.
  Future<void> setMilestone(int milestone) =>
      update((p) => p.copyWith(milestone: milestone.clamp(0, kMaxMilestone)));

  /// Rejects out-of-policy values rather than coercing them, so the UI can say
  /// why instead of silently changing what the user typed.
  Future<void> setSessionMinutes(int minutes) {
    if (minutes < kMinSessionMinutes || minutes > kMaxSessionMinutes) {
      return Future<void>.error(
        ArgumentError.value(
          minutes,
          'minutes',
          'Session length must be between $kMinSessionMinutes and '
              '$kMaxSessionMinutes minutes',
        ),
      );
    }
    return update((p) => p.copyWith(sessionMinutes: minutes));
  }

  Future<void> setRestWeekdays(Set<int> weekdays) =>
      update((p) => p.copyWith(restWeekdays: weekdays));

  Future<void> completeOnboarding({
    required int milestone,
    required int sessionMinutes,
    required Set<int> restWeekdays,
  }) => _write(
    state.copyWith(
      milestone: milestone.clamp(0, kMaxMilestone),
      sessionMinutes: sessionMinutes.clamp(
        kMinSessionMinutes,
        kMaxSessionMinutes,
      ),
      restWeekdays: restWeekdays,
      onboardingComplete: true,
    ),
  );

  Future<void> markOpenedOn(DateTime date) =>
      update((p) => p.copyWith(lastOpenedOn: date));

  Future<void> reset() =>
      _write(UserProfile(startedAt: ref.read(clockProvider).now()));
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);
