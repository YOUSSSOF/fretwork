import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/course_seed.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/practice_category.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/features/analytics/analytics_service.dart';
import 'package:fretwork/features/analytics/export/pdf_report_builder.dart';

final DateTime _today = DateTime(2026, 3, 14);

DayRecord _day(int daysAgo, {int completed = 60, DayStatus? status}) {
  final date = _today.subtract(Duration(days: daysAgo));
  return DayRecord(
    date: date,
    plannedMinutes: 60,
    completedMinutes: completed,
    status:
        status ??
        DayRecord.statusFor(
          plannedMinutes: 60,
          completedMinutes: completed,
          isRestDay: false,
        ),
    milestoneAtTime: 6,
  );
}

ReportData _data({
  List<DayRecord> days = const [],
  List<SessionRecord> sessions = const [],
  Map<String, TempoRecord> tempos = const {},
}) {
  final summary = computeAnalytics(
    days: days,
    sessions: sessions,
    tempos: tempos,
    filter: const AnalyticsFilter(range: AnalyticsRange.quarter),
    today: _today,
  );
  return ReportData(
    summary: summary,
    score: computeDisciplineScore(
      days: days,
      sessions: sessions,
      tempos: tempos,
      today: _today,
    ),
    days: days,
    exercises: buildExerciseIndex(),
    startedAt: DateTime(2026, 1, 1),
    generatedAt: _today,
    milestone: 6,
    parts: [for (final part in kCourseParts) part],
  );
}

void main() {
  // The builder loads the embedded font through the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a six-page report from a populated history', () async {
    final days = [
      for (var i = 0; i < 60; i++) _day(i, completed: i % 4 == 0 ? 0 : 55),
    ];
    final sessions = [
      for (var i = 0; i < 20; i++)
        SessionRecord(
          id: 's$i',
          startedAt: _today
              .subtract(Duration(days: i))
              .add(const Duration(hours: 19)),
          endedAt: _today
              .subtract(Duration(days: i))
              .add(const Duration(hours: 20)),
          plannedMinutes: 60,
          actualMinutes: 55,
          items: const [
            ItemResult(
              exerciseId: 'ex_11',
              variantId: 'ex_11_frag_01',
              category: PracticeCategory.scalar,
              seconds: 1800,
              startTempo: 88,
              endTempo: 96,
              clean: true,
            ),
            ItemResult(
              exerciseId: 'ex_1',
              category: PracticeCategory.warmupLeft,
              seconds: 900,
              startTempo: 60,
              endTempo: 60,
            ),
          ],
        ),
    ];
    final tempos = {
      for (final id in ['ex_11', 'ex_8', 'ex_12'])
        id: TempoRecord(
          exerciseId: id,
          points: [
            TempoPoint(
              date: _today.subtract(const Duration(days: 40)),
              bpm: 80,
              clean: true,
            ),
            TempoPoint(
              date: _today.subtract(const Duration(days: 5)),
              bpm: 96,
              clean: true,
            ),
          ],
        ),
    };

    final document = await buildPracticeReport(
      _data(days: days, sessions: sessions, tempos: tempos),
    );
    final bytes = await document.save();

    expect(document.document.pdfPageList.pages, hasLength(6));
    expect(bytes.length, greaterThan(1000));
    // A PDF starts with %PDF.
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  test('builds a report from an empty history without throwing', () async {
    final document = await buildPracticeReport(_data());
    final bytes = await document.save();

    expect(document.document.pdfPageList.pages, hasLength(6));
    expect(bytes.length, greaterThan(1000));
  });

  test('builds a report where every day is a rest day', () async {
    final days = [
      for (var i = 0; i < 30; i++)
        _day(i, completed: 0, status: DayStatus.rest),
    ];
    final document = await buildPracticeReport(_data(days: days));
    expect((await document.save()).length, greaterThan(1000));
  });
}
