import 'package:flutter/foundation.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/utils/date_x.dart';

enum AnalyticsRange {
  week,
  month,
  quarter,
  thisMonth,
  allTime;

  String get label => switch (this) {
    AnalyticsRange.week => '7 days',
    AnalyticsRange.month => '30 days',
    AnalyticsRange.quarter => '90 days',
    AnalyticsRange.thisMonth => 'This month',
    AnalyticsRange.allTime => 'All time',
  };
}

@immutable
class DateWindow {
  const DateWindow({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  int get days => from.daysUntil(to) + 1;

  bool contains(DateTime date) {
    final day = date.dayStart;
    return !day.isBefore(from.dayStart) && !day.isAfter(to.dayStart);
  }
}

@immutable
class AnalyticsFilter {
  const AnalyticsFilter({
    this.range = AnalyticsRange.month,
    this.categories = const {},
    this.tags = const {},
    this.exerciseId,
    this.customFrom,
    this.customTo,
  });

  final AnalyticsRange range;

  /// Empty means "everything" rather than "nothing" — an empty filter chip row
  /// should show all the data, not none of it.
  final Set<PracticeCategory> categories;
  final Set<TechniqueTag> tags;

  final String? exerciseId;
  final DateTime? customFrom;
  final DateTime? customTo;

  bool allows(PracticeCategory category) =>
      categories.isEmpty || categories.contains(category);

  DateWindow windowFor(DateTime today, {DateTime? earliest}) {
    final end = today.dayStart;
    return switch (range) {
      AnalyticsRange.week => DateWindow(
        from: end.subtract(const Duration(days: 6)),
        to: end,
      ),
      AnalyticsRange.month => DateWindow(
        from: end.subtract(const Duration(days: 29)),
        to: end,
      ),
      AnalyticsRange.quarter => DateWindow(
        from: end.subtract(const Duration(days: 89)),
        to: end,
      ),
      AnalyticsRange.thisMonth => DateWindow(
        from: DateTime(end.year, end.month),
        to: end,
      ),
      AnalyticsRange.allTime => DateWindow(
        from: (earliest ?? end).dayStart,
        to: end,
      ),
    };
  }

  AnalyticsFilter copyWith({
    AnalyticsRange? range,
    Set<PracticeCategory>? categories,
    Set<TechniqueTag>? tags,
    String? exerciseId,
    bool clearExercise = false,
  }) => AnalyticsFilter(
    range: range ?? this.range,
    categories: categories ?? this.categories,
    tags: tags ?? this.tags,
    exerciseId: clearExercise ? null : (exerciseId ?? this.exerciseId),
    customFrom: customFrom,
    customTo: customTo,
  );
}

@immutable
class TempoProgress {
  const TempoProgress({
    required this.exerciseId,
    required this.startBpm,
    required this.bestBpm,
    required this.cleanPoints,
  });

  final String exerciseId;
  final int startBpm;
  final int bestBpm;
  final int cleanPoints;

  int get delta => bestBpm - startBpm;

  double get deltaFraction => startBpm <= 0 ? 0 : delta / startBpm;
}

@immutable
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.window,
    required this.totalMinutes,
    required this.plannedMinutes,
    required this.completedSessions,
    required this.abandonedSessions,
    required this.practiceDays,
    required this.missedDays,
    required this.restDays,
    required this.expectedDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.maxGap,
    required this.minutesByCategory,
    required this.minutesByDay,
    required this.minutesByWeekday,
    required this.sessionsByHour,
    required this.tempoProgress,
  });

  final DateWindow window;
  final int totalMinutes;
  final int plannedMinutes;
  final int completedSessions;
  final int abandonedSessions;
  final int practiceDays;
  final int missedDays;
  final int restDays;

  /// Days in the range that the user was expected to practise: the range
  /// minus rest days. Rest days are not failures.
  final int expectedDays;

  final int currentStreak;
  final int longestStreak;

  /// The longest run of consecutive non-rest days with no practice.
  final int maxGap;

  final Map<PracticeCategory, int> minutesByCategory;
  final Map<DateTime, int> minutesByDay;
  final Map<int, double> minutesByWeekday;
  final Map<int, int> sessionsByHour;
  final List<TempoProgress> tempoProgress;

  int get totalSessions => completedSessions + abandonedSessions;

  /// Minutes done over minutes planned, excluding rest days.
  double get adherence =>
      plannedMinutes <= 0 ? 0 : (totalMinutes / plannedMinutes).clamp(0, 1);

  /// Days practised over days expected.
  double get consistency =>
      expectedDays <= 0 ? 0 : (practiceDays / expectedDays).clamp(0, 1);

  double get averageMinutesPerPracticeDay =>
      practiceDays <= 0 ? 0 : totalMinutes / practiceDays;

  bool get isEmpty => totalSessions == 0 && totalMinutes == 0;
}

/// Builds the whole analytics picture from records.
///
/// Pure: no providers, no clock, no UI. Everything the screen and the PDF show
/// comes from here, so the two can never disagree.
AnalyticsSummary computeAnalytics({
  required List<DayRecord> days,
  required List<SessionRecord> sessions,
  required Map<String, TempoRecord> tempos,
  required AnalyticsFilter filter,
  required DateTime today,
}) {
  final earliest = days.isEmpty
      ? today
      : days.map((d) => d.date).reduce((a, b) => a.isBefore(b) ? a : b);
  final window = filter.windowFor(today, earliest: earliest);

  final inRange = [
    for (final day in days)
      if (window.contains(day.date)) day,
  ]..sort((a, b) => a.date.compareTo(b.date));

  final rangeSessions = [
    for (final session in sessions)
      if (window.contains(session.startedAt)) session,
  ];

  // Category filtering happens at the item level: a session that included one
  // scalar item should contribute its scalar minutes and nothing else.
  final minutesByCategory = <PracticeCategory, int>{};
  var filteredSeconds = 0;
  for (final session in rangeSessions) {
    for (final item in session.items) {
      if (item.skipped) continue;
      if (!filter.allows(item.category)) continue;
      minutesByCategory[item.category] =
          (minutesByCategory[item.category] ?? 0) + item.seconds;
      filteredSeconds += item.seconds;
    }
  }
  minutesByCategory.updateAll((_, seconds) => (seconds / 60).round());

  final filtering = filter.categories.isNotEmpty;
  final totalMinutes = filtering
      ? (filteredSeconds / 60).round()
      : inRange.fold<int>(0, (sum, d) => sum + d.completedMinutes);

  final plannedMinutes = inRange
      .where((d) => d.status != DayStatus.rest)
      .fold<int>(0, (sum, d) => sum + d.plannedMinutes);

  final practiceDays = inRange.where((d) => d.completedMinutes > 0).length;
  final missedDays = inRange.where((d) => d.status == DayStatus.missed).length;
  final restDays = inRange.where((d) => d.status == DayStatus.rest).length;

  final minutesByDay = <DateTime, int>{
    for (final day in inRange) day.date.dayStart: day.completedMinutes,
  };

  final weekdayTotals = <int, int>{};
  final weekdayCounts = <int, int>{};
  for (final day in inRange) {
    if (day.status == DayStatus.rest) continue;
    weekdayTotals[day.date.weekday] =
        (weekdayTotals[day.date.weekday] ?? 0) + day.completedMinutes;
    weekdayCounts[day.date.weekday] =
        (weekdayCounts[day.date.weekday] ?? 0) + 1;
  }
  final minutesByWeekday = <int, double>{
    for (final weekday in kAllWeekdays)
      weekday: (weekdayCounts[weekday] ?? 0) == 0
          ? 0
          : weekdayTotals[weekday]! / weekdayCounts[weekday]!,
  };

  final sessionsByHour = <int, int>{};
  for (final session in rangeSessions) {
    final hour = session.startedAt.hour;
    sessionsByHour[hour] = (sessionsByHour[hour] ?? 0) + 1;
  }

  return AnalyticsSummary(
    window: window,
    totalMinutes: totalMinutes,
    plannedMinutes: plannedMinutes,
    completedSessions: rangeSessions.where((s) => !s.abandoned).length,
    abandonedSessions: rangeSessions.where((s) => s.abandoned).length,
    practiceDays: practiceDays,
    missedDays: missedDays,
    restDays: restDays,
    expectedDays: inRange.length - restDays,
    currentStreak: currentStreak(days: days, today: today),
    longestStreak: longestStreak(days),
    maxGap: longestGap(inRange),
    minutesByCategory: minutesByCategory,
    minutesByDay: minutesByDay,
    minutesByWeekday: minutesByWeekday,
    sessionsByHour: sessionsByHour,
    tempoProgress: computeTempoProgress(tempos: tempos, window: window),
  );
}

/// Consecutive days back from today that count.
///
/// Rest days pass straight through: they neither break a streak nor extend it,
/// which is the only reading that makes rest days a real feature rather than a
/// penalty.
int currentStreak({required List<DayRecord> days, required DateTime today}) {
  final byKey = {for (final day in days) day.date.dayKey: day};
  var streak = 0;

  for (var cursor = today.dayStart; ; cursor = cursor.previousDay) {
    final record = byKey[cursor.dayKey];
    if (record == null) break;

    if (record.status == DayStatus.rest) continue;
    // Today counts once it has been earned, but an unearned today does not
    // break a streak that is still standing.
    if (cursor.isSameDayAs(today) && !record.countsForStreak) continue;
    if (!record.countsForStreak) break;
    streak++;
  }
  return streak;
}

int longestStreak(List<DayRecord> days) {
  if (days.isEmpty) return 0;
  final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));

  var best = 0;
  var run = 0;
  DateTime? previous;

  for (final day in sorted) {
    final contiguous = previous == null || previous.daysUntil(day.date) == 1;
    if (!contiguous) run = 0;
    previous = day.date;

    if (day.status == DayStatus.rest) continue;
    if (day.countsForStreak) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  return best;
}

/// The longest run of consecutive non-rest days with nothing practised.
int longestGap(List<DayRecord> days) {
  var best = 0;
  var run = 0;
  for (final day in days) {
    if (day.status == DayStatus.rest) continue;
    if (day.completedMinutes > 0) {
      run = 0;
    } else {
      run++;
      if (run > best) best = run;
    }
  }
  return best;
}

List<TempoProgress> computeTempoProgress({
  required Map<String, TempoRecord> tempos,
  required DateWindow window,
}) {
  final result = <TempoProgress>[];
  for (final record in tempos.values) {
    final points = [
      for (final point in record.cleanPoints)
        if (window.contains(point.date)) point,
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (points.length < 2) continue;

    result.add(
      TempoProgress(
        exerciseId: record.exerciseId,
        startBpm: points.first.bpm,
        bestBpm: points.map((p) => p.bpm).reduce((a, b) => a > b ? a : b),
        cleanPoints: points.length,
      ),
    );
  }
  result.sort((a, b) => b.deltaFraction.compareTo(a.deltaFraction));
  return result;
}

enum ScoreGrade {
  exceptional,
  strong,
  steady,
  inconsistent,
  slipping;

  String get label => switch (this) {
    ScoreGrade.exceptional => 'Exceptional',
    ScoreGrade.strong => 'Strong',
    ScoreGrade.steady => 'Steady',
    ScoreGrade.inconsistent => 'Inconsistent',
    ScoreGrade.slipping => 'Slipping',
  };

  static ScoreGrade forScore(int score) {
    if (score >= 90) return ScoreGrade.exceptional;
    if (score >= 75) return ScoreGrade.strong;
    if (score >= 60) return ScoreGrade.steady;
    if (score >= 45) return ScoreGrade.inconsistent;
    return ScoreGrade.slipping;
  }
}

/// The rolling window the score is computed over.
const int kScoreWindowDays = 28;

/// Weights for the three score terms.
///
/// Showing up (adherence + consistency = 80 %) matters far more than getting
/// faster (20 %). Speed arrives in plateaus, and a score that punished flat
/// months would be lying to the user.
const double kAdherenceWeight = 0.45;
const double kConsistencyWeight = 0.35;
const double kTempoWeight = 0.20;

@immutable
class DisciplineScore {
  const DisciplineScore({
    required this.score,
    required this.adherence,
    required this.consistency,
    required this.tempoProgress,
    required this.hasTempoData,
  });

  final int score;
  final double adherence;
  final double consistency;
  final double tempoProgress;
  final bool hasTempoData;

  ScoreGrade get grade => ScoreGrade.forScore(score);

  /// One plain-English line naming the biggest single lever.
  ///
  /// Deliberately the *weakest* term rather than a compliment: a score card
  /// that only praises tells the user nothing they can act on.
  String get lever {
    if (consistency < adherence && consistency < 0.9) {
      return 'You hit your minutes on the days you practise — the gap is the '
          'days you skip.';
    }
    if (adherence < 0.9) {
      return 'You show up reliably — the gap is finishing the sessions you '
          'start.';
    }
    if (!hasTempoData) {
      return 'Adherence and consistency are both strong. Mark a few tempos '
          'clean and the third part of the score starts moving too.';
    }
    if (tempoProgress < 0.5) {
      return 'Showing up is not the problem. Your tracked tempos have not '
          'moved — try holding a slower tempo until it is flawless.';
    }
    return 'Nothing obvious to fix. Keep the routine and the numbers follow.';
  }
}

DisciplineScore computeDisciplineScore({
  required List<DayRecord> days,
  required List<SessionRecord> sessions,
  required Map<String, TempoRecord> tempos,
  required DateTime today,
}) {
  final window = DateWindow(
    from: today.dayStart.subtract(const Duration(days: kScoreWindowDays - 1)),
    to: today.dayStart,
  );

  final inRange = [
    for (final day in days)
      if (window.contains(day.date)) day,
  ];

  final planned = inRange
      .where((d) => d.status != DayStatus.rest)
      .fold<int>(0, (sum, d) => sum + d.plannedMinutes);
  final completed = inRange.fold<int>(0, (sum, d) => sum + d.completedMinutes);
  final restDays = inRange.where((d) => d.status == DayStatus.rest).length;
  final expected = inRange.length - restDays;
  final practised = inRange.where((d) => d.completedMinutes > 0).length;

  final adherence = planned <= 0 ? 0.0 : (completed / planned).clamp(0.0, 1.0);
  final consistency = expected <= 0
      ? 0.0
      : (practised / expected).clamp(0.0, 1.0);

  final progress = computeTempoProgress(tempos: tempos, window: window);
  // Insufficient data is not a failure. Defaulting to the neutral 0.5 means a
  // user who has not marked anything clean is neither rewarded nor punished
  // for it.
  final hasTempoData = progress.isNotEmpty;
  final tempoTerm = hasTempoData
      ? _normaliseTempoGain(
          progress.map((p) => p.deltaFraction).reduce((a, b) => a + b) /
              progress.length,
        )
      : 0.5;

  final score =
      (100 *
              (kAdherenceWeight * adherence +
                  kConsistencyWeight * consistency +
                  kTempoWeight * tempoTerm))
          .round()
          .clamp(0, 100);

  return DisciplineScore(
    score: score,
    adherence: adherence,
    consistency: consistency,
    tempoProgress: tempoTerm,
    hasTempoData: hasTempoData,
  );
}

/// Maps a mean bpm gain onto 0..1: +10 % is 1.0, flat is 0.5, −10 % is 0.0.
double _normaliseTempoGain(double meanFraction) =>
    (0.5 + meanFraction * 5).clamp(0.0, 1.0);
