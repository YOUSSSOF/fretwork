import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';
import 'package:fretwork/features/history/history_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';

class AnalyticsFilterNotifier extends Notifier<AnalyticsFilter> {
  @override
  AnalyticsFilter build() => const AnalyticsFilter();

  void setRange(AnalyticsRange range) => state = state.copyWith(range: range);

  void toggleCategory(PracticeCategory category) {
    final next = {...state.categories};
    next.contains(category) ? next.remove(category) : next.add(category);
    state = state.copyWith(categories: next);
  }

  void clearCategories() => state = state.copyWith(categories: const {});

  void selectExercise(String? id) => state = id == null
      ? state.copyWith(clearExercise: true)
      : state.copyWith(exerciseId: id);
}

final analyticsFilterProvider =
    NotifierProvider<AnalyticsFilterNotifier, AnalyticsFilter>(
      AnalyticsFilterNotifier.new,
    );

/// Derived, never duplicated: the summary is recomputed from the records and
/// the filter rather than stored, so it cannot go stale.
final analyticsProvider = Provider<AnalyticsSummary>((ref) {
  return computeAnalytics(
    days: ref.watch(historyProvider),
    sessions: ref.watch(sessionRecordsProvider),
    tempos: ref.watch(tempoRecordsProvider),
    filter: ref.watch(analyticsFilterProvider),
    today: ref.watch(clockProvider).now(),
  );
});

final disciplineScoreProvider = Provider<DisciplineScore>((ref) {
  return computeDisciplineScore(
    days: ref.watch(historyProvider),
    sessions: ref.watch(sessionRecordsProvider),
    tempos: ref.watch(tempoRecordsProvider),
    today: ref.watch(clockProvider).now(),
  );
});
