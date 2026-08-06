import 'package:flutter/foundation.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';

/// The prose in the exported report.
///
/// Deterministic: the same metrics always produce the same sentences, which is
/// what makes this testable and what stops the report reading like a horoscope.
/// Every branch is covered by a test, including the zero and one cases —
/// "1 days" or "0 minutes across 0 months" would undo the whole point of
/// writing sentences instead of printing a table.
@immutable
class ReportCopy {
  const ReportCopy({
    required this.headline,
    required this.durationLine,
    required this.progressLine,
    required this.closingLine,
  });

  final String headline;
  final String durationLine;

  /// Null when too few exercises have enough clean tempo points to say
  /// anything honest about progress.
  final String? progressLine;

  final String closingLine;
}

/// How many exercises must have two or more clean points before the report
/// will comment on tempo progress at all.
const int kProgressLineMinExercises = 3;

/// Below this many days a "months" clause is noise rather than information.
const int kMonthsClauseMinDays = 60;

ReportCopy buildReportCopy({
  required AnalyticsSummary summary,
  required DisciplineScore score,
  required String Function(String exerciseId) exerciseLabel,
}) => ReportCopy(
  headline: _headline(summary),
  durationLine: _durationLine(summary),
  progressLine: _progressLine(summary, exerciseLabel),
  closingLine: _closingLine(score),
);

String _headline(AnalyticsSummary summary) {
  final days = summary.window.days;
  final hours = _hoursOf(summary.totalMinutes);

  if (summary.totalMinutes == 0) {
    return 'No practice recorded in this period. The record starts whenever '
        'you do.';
  }

  if (summary.adherence >= 0.85 && summary.currentStreak >= 21) {
    return 'Over ${_plural(days, 'day')} you have logged '
        '${_plural(summary.totalSessions, 'session')} and '
        '${_plural(summary.totalMinutes, 'minute')} — roughly $hours — and you '
        'have not missed more than ${_plural(summary.maxGap, 'day')} in a row.';
  }

  if (summary.adherence >= 0.70) {
    final months = _months(days);
    final span = months >= 2
        ? 'In ${_plural(months, 'month')} of practice'
        : 'Over ${_plural(days, 'day')}';
    return '$span you have put in $hours across '
        '${_plural(summary.practiceDays, 'day')}, hitting '
        '${(summary.adherence * 100).round()}% of the minutes you planned.';
  }

  if (summary.adherence >= 0.50) {
    return 'You have practised on ${summary.practiceDays} of '
        '${_plural(days, 'day')} for a total of $hours. The minutes are there '
        'when you show up — showing up is the gap.';
  }

  return '${_plural(summary.practiceDays, 'practice day')} out of '
      '${_plural(days, 'day')}, $hours in total. Consistency is the lever '
      'here, not session length.';
}

String _durationLine(AnalyticsSummary summary) {
  final minutes = summary.totalMinutes;
  if (minutes == 0) {
    return 'No minutes logged yet.';
  }

  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final breakdown = hours == 0
      ? _plural(remainder, 'minute')
      : '${hours}h ${remainder}m';

  final average = summary.practiceDays == 0
      ? 0
      : (minutes / summary.practiceDays).round();

  final months = _months(summary.window.days);
  final monthsClause = summary.window.days >= kMonthsClauseMinDays && months > 0
      ? ' across ${_plural(months, 'month')}'
      : '';

  return '${_plural(minutes, 'minute')} = $breakdown, spread over '
      '${_plural(summary.practiceDays, 'day')} '
      '($average min/day average)$monthsClause.';
}

String? _progressLine(
  AnalyticsSummary summary,
  String Function(String exerciseId) exerciseLabel,
) {
  final tracked = summary.tempoProgress;
  if (tracked.length < kProgressLineMinExercises) return null;

  final mean =
      tracked.map((p) => p.deltaFraction).reduce((a, b) => a + b) /
      tracked.length;
  final best = tracked.first;

  if (best.delta <= 0) {
    return 'Your tracked tempos have not moved this period. That is normal — '
        'speed arrives in plateaus.';
  }

  final direction = mean >= 0 ? 'moved' : 'slipped';
  return 'Your tracked tempos $direction ${(mean.abs() * 100).round()}% on '
      'average; the biggest gain was ${exerciseLabel(best.exerciseId)}, from '
      '${best.startBpm} to ${best.bestBpm} bpm.';
}

String _closingLine(DisciplineScore score) => switch (score.grade) {
  ScoreGrade.exceptional =>
    'Discipline score ${score.score}. Nothing in the numbers needs fixing.',
  ScoreGrade.strong =>
    'Discipline score ${score.score}. The habit is established; the gaps are '
        'small enough to close without changing anything structural.',
  ScoreGrade.steady =>
    'Discipline score ${score.score}. The routine is working on the days you '
        'run it.',
  ScoreGrade.inconsistent =>
    'Discipline score ${score.score}. The sessions are good; there are not '
        'enough of them.',
  ScoreGrade.slipping =>
    'Discipline score ${score.score}. Shorten the session until you can hit '
        'it daily, then lengthen it again.',
};

/// "1 day", "3 days" — never "1 days".
String _plural(int count, String noun) =>
    '$count ${count == 1 ? noun : '${noun}s'}';

String _hoursOf(int minutes) {
  if (minutes < 60) return _plural(minutes, 'minute');
  final hours = minutes / 60;
  // One decimal below ten hours, whole hours above: "1.5 hours" is useful,
  // "127.3 hours" is false precision.
  if (hours < 10) {
    final rounded = (hours * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? _plural(rounded.round(), 'hour')
        : '$rounded hours';
  }
  return _plural(hours.round(), 'hour');
}

/// Whole months in a span of days, using the conventional 30-day month. The
/// report only ever uses this for prose, never for a metric.
int _months(int days) => days ~/ 30;
