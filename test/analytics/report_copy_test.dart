import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';
import 'package:fretwork/features/analytics/export/report_copy.dart';

final DateTime _today = DateTime(2026, 3, 14);

AnalyticsSummary _summary({
  int days = 30,
  int totalMinutes = 600,
  int plannedMinutes = 1000,
  int practiceDays = 15,
  int sessions = 15,
  int streak = 3,
  int maxGap = 2,
  List<TempoProgress> tempoProgress = const [],
}) => AnalyticsSummary(
  window: DateWindow(
    from: _today.subtract(Duration(days: days - 1)),
    to: _today,
  ),
  totalMinutes: totalMinutes,
  plannedMinutes: plannedMinutes,
  completedSessions: sessions,
  abandonedSessions: 0,
  practiceDays: practiceDays,
  missedDays: days - practiceDays,
  restDays: 0,
  expectedDays: days,
  currentStreak: streak,
  longestStreak: streak,
  maxGap: maxGap,
  minutesByCategory: const {PracticeCategory.scalar: 600},
  minutesByDay: const {},
  minutesByWeekday: const {},
  sessionsByHour: const {},
  tempoProgress: tempoProgress,
);

DisciplineScore _score(int score) => DisciplineScore(
  score: score,
  adherence: 0.8,
  consistency: 0.8,
  tempoProgress: 0.5,
  hasTempoData: true,
);

ReportCopy _copy({AnalyticsSummary? summary, DisciplineScore? score}) =>
    buildReportCopy(
      summary: summary ?? _summary(),
      score: score ?? _score(70),
      exerciseLabel: (id) => 'Example ${id.split('_').last}',
    );

void main() {
  group('headline', () {
    test('the strong branch needs both high adherence and a long streak', () {
      final copy = _copy(
        summary: _summary(
          totalMinutes: 900,
          plannedMinutes: 1000,
          streak: 25,
          maxGap: 1,
        ),
      );
      expect(
        copy.headline,
        contains('have not missed more than 1 day in a row'),
      );
    });

    test('high adherence with a short streak falls to the next branch', () {
      final copy = _copy(
        summary: _summary(totalMinutes: 900, plannedMinutes: 1000, streak: 3),
      );
      expect(copy.headline, contains('% of the minutes you planned'));
    });

    test('the middling branch names showing up as the gap', () {
      final copy = _copy(
        summary: _summary(totalMinutes: 550, plannedMinutes: 1000),
      );
      expect(copy.headline, contains('showing up is the gap'));
    });

    test('the weakest branch names consistency as the lever', () {
      final copy = _copy(
        summary: _summary(totalMinutes: 200, plannedMinutes: 1000),
      );
      expect(copy.headline, contains('Consistency is the lever'));
    });

    test('an empty period says so instead of dividing by zero', () {
      final copy = _copy(
        summary: _summary(
          totalMinutes: 0,
          plannedMinutes: 0,
          practiceDays: 0,
          sessions: 0,
          streak: 0,
        ),
      );
      expect(copy.headline, contains('No practice recorded'));
      expect(copy.durationLine, 'No minutes logged yet.');
    });
  });

  group('pluralisation', () {
    test('never emits "1 days"', () {
      final copy = _copy(
        summary: _summary(
          days: 1,
          totalMinutes: 60,
          plannedMinutes: 60,
          practiceDays: 1,
          sessions: 1,
        ),
      );
      final all = [
        copy.headline,
        copy.durationLine,
        copy.closingLine,
      ].join(' ');
      expect(all, isNot(contains('1 days')));
      expect(all, isNot(contains('1 sessions')));
      expect(all, isNot(contains('1 minutes')));
      expect(all, isNot(contains('1 hours')));
      expect(all, isNot(contains('1 months')));
    });

    test('uses plural forms for counts above one', () {
      final copy = _copy(summary: _summary(days: 30, practiceDays: 15));
      expect(copy.durationLine, contains('15 days'));
    });

    test('a single practice day reads correctly', () {
      final copy = _copy(
        summary: _summary(
          totalMinutes: 45,
          plannedMinutes: 60,
          practiceDays: 1,
          sessions: 1,
        ),
      );
      expect(copy.durationLine, contains('spread over 1 day '));
    });
  });

  group('duration line', () {
    test('breaks minutes into hours and minutes', () {
      final copy = _copy(summary: _summary(totalMinutes: 125, practiceDays: 5));
      expect(copy.durationLine, contains('125 minutes = 2h 5m'));
      expect(copy.durationLine, contains('25 min/day average'));
    });

    test('under an hour it does not claim an hours breakdown', () {
      final copy = _copy(summary: _summary(totalMinutes: 45, practiceDays: 1));
      expect(copy.durationLine, contains('45 minutes = 45 minutes'));
      expect(copy.durationLine, isNot(contains('h ')));
    });

    test('the months clause appears only for long ranges', () {
      final short = _copy(summary: _summary(days: 30));
      expect(short.durationLine, isNot(contains('across')));

      final long = _copy(summary: _summary(days: 120));
      expect(long.durationLine, contains('across 4 months'));
    });

    test('never says "across 0 months"', () {
      final copy = _copy(summary: _summary(days: 59));
      expect(copy.durationLine, isNot(contains('0 months')));
    });

    test('a zero average is not emitted as a division by zero', () {
      final copy = _copy(summary: _summary(totalMinutes: 30, practiceDays: 0));
      expect(copy.durationLine, contains('0 min/day average'));
    });
  });

  group('progress line', () {
    TempoProgress progress(String id, int start, int best) => TempoProgress(
      exerciseId: id,
      startBpm: start,
      bestBpm: best,
      cleanPoints: 2,
    );

    test('is withheld below the minimum number of tracked exercises', () {
      final copy = _copy(
        summary: _summary(
          tempoProgress: [progress('ex_8', 80, 96), progress('ex_9', 80, 88)],
        ),
      );
      expect(copy.progressLine, isNull);
    });

    test('names the biggest gain once there is enough data', () {
      final copy = _copy(
        summary: _summary(
          tempoProgress: [
            progress('ex_11', 80, 100),
            progress('ex_8', 80, 88),
            progress('ex_9', 90, 95),
          ],
        ),
      );
      expect(copy.progressLine, isNotNull);
      expect(copy.progressLine, contains('Example 11'));
      expect(copy.progressLine, contains('from 80 to 100 bpm'));
    });

    test('says so plainly when nothing moved, without inventing progress', () {
      final copy = _copy(
        summary: _summary(
          tempoProgress: [
            progress('ex_8', 80, 80),
            progress('ex_9', 90, 90),
            progress('ex_10', 70, 70),
          ],
        ),
      );
      expect(copy.progressLine, contains('have not moved'));
      expect(copy.progressLine, contains('plateaus'));
    });
  });

  group('closing line', () {
    test('every grade band has its own sentence', () {
      final seen = <String>{};
      for (final band in [95, 80, 65, 50, 20]) {
        final copy = _copy(score: _score(band));
        expect(copy.closingLine, contains('Discipline score $band'));
        seen.add(copy.closingLine);
      }
      expect(seen, hasLength(5), reason: 'each band should read differently');
    });
  });
}
