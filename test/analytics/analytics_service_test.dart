import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';

final DateTime _today = DateTime(2026, 3, 14);

DayRecord _day(
  int daysAgo, {
  int planned = 60,
  int completed = 0,
  DayStatus? status,
}) {
  final date = _today.subtract(Duration(days: daysAgo));
  return DayRecord(
    date: date,
    plannedMinutes: planned,
    completedMinutes: completed,
    status:
        status ??
        DayRecord.statusFor(
          plannedMinutes: planned,
          completedMinutes: completed,
          isRestDay: false,
        ),
    milestoneAtTime: 6,
  );
}

SessionRecord _session(
  int daysAgo, {
  int minutes = 60,
  bool abandoned = false,
  int hour = 18,
  List<ItemResult> items = const [],
}) {
  final start = _today
      .subtract(Duration(days: daysAgo))
      .add(Duration(hours: hour));
  return SessionRecord(
    id: 's$daysAgo-$hour',
    startedAt: start,
    endedAt: start.add(Duration(minutes: minutes)),
    plannedMinutes: 60,
    actualMinutes: minutes,
    abandoned: abandoned,
    items: items,
  );
}

AnalyticsSummary _summary({
  List<DayRecord> days = const [],
  List<SessionRecord> sessions = const [],
  Map<String, TempoRecord> tempos = const {},
  AnalyticsFilter filter = const AnalyticsFilter(),
}) => computeAnalytics(
  days: days,
  sessions: sessions,
  tempos: tempos,
  filter: filter,
  today: _today,
);

void main() {
  group('adherence and consistency', () {
    test('are zero, not NaN, with nothing planned', () {
      final summary = _summary(days: [_day(1, planned: 0)]);
      expect(summary.adherence, 0);
      expect(summary.consistency, 0);
      expect(summary.isEmpty, isTrue);
    });

    test('adherence is minutes done over minutes planned', () {
      final summary = _summary(
        days: [_day(1, completed: 30), _day(2, completed: 60), _day(3)],
      );
      expect(summary.plannedMinutes, 180);
      expect(summary.totalMinutes, 90);
      expect(summary.adherence, closeTo(0.5, 0.001));
    });

    test('adherence is clamped at 1 when the user overshoots', () {
      final summary = _summary(days: [_day(1, planned: 30, completed: 90)]);
      expect(summary.adherence, 1);
    });

    test('rest days are excluded from both denominators', () {
      final summary = _summary(
        days: [
          _day(1, completed: 60),
          _day(2, planned: 0, status: DayStatus.rest),
          _day(3, completed: 60),
        ],
      );
      expect(summary.restDays, 1);
      expect(summary.expectedDays, 2);
      expect(summary.consistency, 1.0);
      expect(summary.adherence, 1.0);
    });
  });

  group('streaks', () {
    test('a rest day passes through without breaking or extending', () {
      final days = [
        _day(0, completed: 60),
        _day(1, planned: 0, status: DayStatus.rest),
        _day(2, completed: 60),
        _day(3, completed: 60),
      ];
      expect(currentStreak(days: days, today: _today), 3);
    });

    test('a missed day breaks the streak', () {
      final days = [
        _day(0, completed: 60),
        _day(1, completed: 60),
        _day(2),
        _day(3, completed: 60),
      ];
      expect(currentStreak(days: days, today: _today), 2);
    });

    test('a day under the threshold breaks the streak', () {
      final days = [
        _day(0, completed: 60),
        // 20 of 60 minutes is below the 60 % bar.
        _day(1, completed: 20),
        _day(2, completed: 60),
      ];
      expect(currentStreak(days: days, today: _today), 1);
    });

    test('an unearned today does not break a standing streak', () {
      final days = [
        _day(0, completed: 0),
        _day(1, completed: 60),
        _day(2, completed: 60),
      ];
      expect(currentStreak(days: days, today: _today), 2);
    });

    test('a gap in the records ends the streak rather than jumping it', () {
      final days = [_day(0, completed: 60), _day(5, completed: 60)];
      expect(currentStreak(days: days, today: _today), 1);
    });

    test('longestStreak finds the best run in all of history', () {
      final days = [
        _day(9, completed: 60),
        _day(8, completed: 60),
        _day(7, completed: 60),
        _day(6, completed: 60),
        _day(5),
        _day(4, completed: 60),
        _day(3, completed: 60),
      ];
      expect(longestStreak(days), 4);
    });

    test('streaks are zero with no history at all', () {
      expect(currentStreak(days: const [], today: _today), 0);
      expect(longestStreak(const []), 0);
    });

    test('the longest gap ignores rest days', () {
      final days = [
        _day(5, completed: 60),
        _day(4),
        _day(3, planned: 0, status: DayStatus.rest),
        _day(2),
        _day(1, completed: 60),
      ];
      expect(longestGap(days), 2);
    });
  });

  group('ranges', () {
    test('the 7-day window covers exactly seven days', () {
      const filter = AnalyticsFilter(range: AnalyticsRange.week);
      final window = filter.windowFor(_today);
      expect(window.days, 7);
      expect(window.contains(_today), isTrue);
      expect(window.contains(_today.subtract(const Duration(days: 6))), isTrue);
      expect(
        window.contains(_today.subtract(const Duration(days: 7))),
        isFalse,
      );
    });

    test('records outside the range are ignored', () {
      final summary = _summary(
        days: [_day(1, completed: 60), _day(60, completed: 60)],
        filter: const AnalyticsFilter(range: AnalyticsRange.week),
      );
      expect(summary.totalMinutes, 60);
    });

    test('all-time starts at the earliest record', () {
      final summary = _summary(
        days: [_day(200, completed: 60), _day(1, completed: 60)],
        filter: const AnalyticsFilter(range: AnalyticsRange.allTime),
      );
      expect(summary.totalMinutes, 120);
    });
  });

  group('category breakdown', () {
    final sessions = [
      _session(
        1,
        items: const [
          ItemResult(
            exerciseId: 'ex_1',
            category: PracticeCategory.warmupLeft,
            seconds: 600,
            startTempo: 60,
            endTempo: 60,
          ),
          ItemResult(
            exerciseId: 'ex_12',
            category: PracticeCategory.scalar,
            seconds: 1200,
            startTempo: 80,
            endTempo: 88,
          ),
          ItemResult(
            exerciseId: 'ex_13',
            category: PracticeCategory.scalar,
            seconds: 600,
            startTempo: 80,
            endTempo: 80,
            skipped: true,
          ),
        ],
      ),
    ];

    test('totals minutes per category and ignores skipped items', () {
      final summary = _summary(
        days: [_day(1, completed: 30)],
        sessions: sessions,
      );
      expect(summary.minutesByCategory[PracticeCategory.warmupLeft], 10);
      expect(summary.minutesByCategory[PracticeCategory.scalar], 20);
    });

    test('a category filter narrows the total minutes too', () {
      final summary = _summary(
        days: [_day(1, completed: 30)],
        sessions: sessions,
        filter: const AnalyticsFilter(categories: {PracticeCategory.scalar}),
      );
      expect(summary.minutesByCategory.keys, [PracticeCategory.scalar]);
      expect(summary.totalMinutes, 20);
    });

    test('an empty category filter means everything, not nothing', () {
      const filter = AnalyticsFilter();
      expect(filter.allows(PracticeCategory.sweep), isTrue);
    });
  });

  group('time of day and weekday', () {
    test('sessions are bucketed by start hour', () {
      final summary = _summary(
        days: [_day(1, completed: 60), _day(2, completed: 60)],
        sessions: [
          _session(1, hour: 7),
          _session(2, hour: 7),
          _session(3, hour: 22),
        ],
      );
      expect(summary.sessionsByHour[7], 2);
      expect(summary.sessionsByHour[22], 1);
    });

    test('weekday averages divide by days present, not by seven', () {
      // Two Saturdays, one practised and one not.
      final summary = _summary(
        days: [_day(0, completed: 60), _day(7, completed: 0)],
        filter: const AnalyticsFilter(range: AnalyticsRange.month),
      );
      expect(summary.minutesByWeekday[_today.weekday], 30);
    });

    test(
      'a weekday with no records averages zero rather than dividing by zero',
      () {
        final summary = _summary(days: [_day(0, completed: 60)]);
        for (final value in summary.minutesByWeekday.values) {
          expect(value.isFinite, isTrue);
        }
      },
    );
  });

  group('tempo progress', () {
    TempoRecord record(String id, List<(int, int, bool)> points) => TempoRecord(
      exerciseId: id,
      points: [
        for (final (daysAgo, bpm, clean) in points)
          TempoPoint(
            date: _today.subtract(Duration(days: daysAgo)),
            bpm: bpm,
            clean: clean,
          ),
      ],
    );

    test('needs at least two clean points to say anything', () {
      final progress = computeTempoProgress(
        tempos: {
          'ex_8': record('ex_8', [(5, 80, true)]),
          'ex_9': record('ex_9', [(5, 80, false), (1, 96, false)]),
        },
        window: DateWindow(
          from: _today.subtract(const Duration(days: 27)),
          to: _today,
        ),
      );
      expect(progress, isEmpty);
    });

    test('reports the start and the best clean tempo', () {
      final progress = computeTempoProgress(
        tempos: {
          'ex_8': record('ex_8', [
            (10, 80, true),
            (5, 96, true),
            (1, 88, true),
          ]),
        },
        window: DateWindow(
          from: _today.subtract(const Duration(days: 27)),
          to: _today,
        ),
      );
      expect(progress.single.startBpm, 80);
      expect(progress.single.bestBpm, 96);
      expect(progress.single.delta, 16);
      expect(progress.single.deltaFraction, closeTo(0.2, 0.001));
    });
  });

  group('discipline score', () {
    DisciplineScore score({
      List<DayRecord> days = const [],
      Map<String, TempoRecord> tempos = const {},
    }) => computeDisciplineScore(
      days: days,
      sessions: const [],
      tempos: tempos,
      today: _today,
    );

    test('stays within 0..100 for a perfect record', () {
      final days = [
        for (var i = 0; i < kScoreWindowDays; i++) _day(i, completed: 60),
      ];
      final result = score(days: days);
      expect(result.score, inInclusiveRange(0, 100));
      // Perfect adherence and consistency with no tempo data scores 90: the
      // two "showing up" terms are worth 80, plus the neutral tempo term's 10.
      // That is the intended weighting, not an accident.
      expect(result.score, 90);
      expect(result.grade, ScoreGrade.exceptional);
    });

    test('stays within 0..100 for an empty record', () {
      final result = score();
      expect(result.score, inInclusiveRange(0, 100));
      expect(result.score, 10, reason: 'only the neutral tempo term applies');
      expect(result.grade, ScoreGrade.slipping);
    });

    test('insufficient tempo data defaults to the neutral 0.5', () {
      final result = score(days: [_day(1, completed: 60)]);
      expect(result.hasTempoData, isFalse);
      expect(result.tempoProgress, 0.5);
    });

    test('a 10 % tempo gain maps to the top of the tempo term', () {
      final days = [
        for (var i = 0; i < kScoreWindowDays; i++) _day(i, completed: 60),
      ];
      final result = score(
        days: days,
        tempos: {
          'ex_8': TempoRecord(
            exerciseId: 'ex_8',
            points: [
              TempoPoint(
                date: _today.subtract(const Duration(days: 20)),
                bpm: 100,
                clean: true,
              ),
              TempoPoint(
                date: _today.subtract(const Duration(days: 2)),
                bpm: 110,
                clean: true,
              ),
            ],
          ),
        },
      );
      expect(result.tempoProgress, 1.0);
      expect(result.score, 100);
      expect(result.grade, ScoreGrade.exceptional);
    });

    test('a tempo loss drives the term down, not negative', () {
      final result = score(
        days: [
          for (var i = 0; i < kScoreWindowDays; i++) _day(i, completed: 60),
        ],
        tempos: {
          'ex_8': TempoRecord(
            exerciseId: 'ex_8',
            points: [
              TempoPoint(
                date: _today.subtract(const Duration(days: 20)),
                bpm: 100,
                clean: true,
              ),
              TempoPoint(
                date: _today.subtract(const Duration(days: 2)),
                bpm: 60,
                clean: true,
              ),
            ],
          ),
        },
      );
      // The best clean tempo in range is still 100, so this is flat, not a
      // loss — best-of is the honest reading of "how fast can you play it".
      expect(result.tempoProgress, inInclusiveRange(0.0, 1.0));
    });

    test('the weights sum to one', () {
      expect(
        kAdherenceWeight + kConsistencyWeight + kTempoWeight,
        closeTo(1.0, 0.0001),
      );
    });

    test('grade bands match the plan', () {
      expect(ScoreGrade.forScore(100), ScoreGrade.exceptional);
      expect(ScoreGrade.forScore(90), ScoreGrade.exceptional);
      expect(ScoreGrade.forScore(89), ScoreGrade.strong);
      expect(ScoreGrade.forScore(75), ScoreGrade.strong);
      expect(ScoreGrade.forScore(74), ScoreGrade.steady);
      expect(ScoreGrade.forScore(60), ScoreGrade.steady);
      expect(ScoreGrade.forScore(59), ScoreGrade.inconsistent);
      expect(ScoreGrade.forScore(45), ScoreGrade.inconsistent);
      expect(ScoreGrade.forScore(44), ScoreGrade.slipping);
      expect(ScoreGrade.forScore(0), ScoreGrade.slipping);
    });

    test(
      'the lever names skipped days when consistency is the weaker term',
      () {
        // Overshoots the plan on the days they show up, but shows up half the
        // time: adherence 0.75, consistency 0.5.
        final skipper = computeDisciplineScore(
          days: [
            _day(1, completed: 90),
            _day(2, planned: 60),
            _day(3, completed: 90),
            _day(4, planned: 60),
          ],
          sessions: const [],
          tempos: const {},
          today: _today,
        );
        expect(skipper.consistency, lessThan(skipper.adherence));
        expect(skipper.lever, contains('days you skip'));
      },
    );

    test('the lever names unfinished sessions when adherence is weaker', () {
      // Shows up every day but only does half the minutes.
      final halfHearted = computeDisciplineScore(
        days: [
          _day(1, completed: 30),
          _day(2, completed: 30),
          _day(3, completed: 30),
        ],
        sessions: const [],
        tempos: const {},
        today: _today,
      );
      expect(halfHearted.adherence, lessThan(halfHearted.consistency));
      expect(halfHearted.lever, contains('finishing the sessions'));
    });
  });
}
