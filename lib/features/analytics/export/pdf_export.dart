import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/course_providers.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/features/analytics/analytics_controller.dart';
import 'package:fretwork/features/analytics/export/pdf_report_builder.dart';
import 'package:fretwork/features/history/history_controller.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:printing/printing.dart';

/// Gathers the report's inputs from the providers.
///
/// Split from the builder so the document can be produced in a test with no
/// Riverpod container at all. Takes the reader function rather than a `Ref` so
/// it works from both a widget (`WidgetRef`) and a provider (`Ref`).
ReportData buildReportData(T Function<T>(ProviderListenable<T>) read) {
  final profile = read(profileProvider);
  return ReportData(
    summary: read(analyticsProvider),
    score: read(disciplineScoreProvider),
    days: read(historyProvider),
    exercises: read(exerciseIndexProvider),
    startedAt: profile.startedAt,
    generatedAt: read(clockProvider).now(),
    milestone: profile.milestone,
    parts: [
      for (final part in read(courseProvider))
        if (part.id != 'part_free') part,
    ]..sort((a, b) => a.milestone.compareTo(b.milestone)),
  );
}

/// Builds the report and hands it to the platform share sheet.
///
/// Nothing is uploaded: `printing` renders locally and passes bytes to the
/// system sheet, which is the only place the report ever leaves the app — and
/// only because the user asked.
Future<void> exportPracticeReport(WidgetRef ref) async {
  final data = buildReportData(ref.read);
  final document = await buildPracticeReport(data);
  final bytes = await document.save();

  await Printing.sharePdf(
    bytes: bytes,
    filename:
        'fretwork-report-${data.generatedAt.toIso8601String().split('T').first}.pdf',
  );
}
