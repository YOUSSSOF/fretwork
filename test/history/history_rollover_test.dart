import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/utils/clock.dart';
import 'package:fretwork/core/utils/date_x.dart';
import 'package:fretwork/features/history/history_controller.dart';
import 'package:fretwork/features/progress/progress_controller.dart';
import 'package:fretwork/features/session/records_controller.dart';

import '../support/store.dart';

Future<ProviderContainer> _ready(FixedClock clock) async {
  final container = testContainer(overrides: [clockProviderOverride(clock)]);
  await container
      .read(profileProvider.notifier)
      .completeOnboarding(
        milestone: 6,
        sessionMinutes: 60,
        restWeekdays: const {},
      );
  return container;
}

void main() {
  test('rollover backfills the days the app was not opened', () async {
    final clock = FixedClock(DateTime(2026, 3, 10, 9));
    final container = await _ready(clock);
    addTearDown(container.dispose);

    await container.read(historyRolloverProvider).run();
    expect(container.read(profileProvider).lastOpenedOn?.dayKey, '2026-03-10');

    clock.set(DateTime(2026, 3, 14, 9));
    await container.read(historyRolloverProvider).run();

    final days = container.read(dayRecordsProvider);
    expect(days.keys, containsAll(['2026-03-11', '2026-03-12', '2026-03-13']));
    expect(days['2026-03-12']!.status, DayStatus.missed);
    expect(container.read(profileProvider).lastOpenedOn?.dayKey, '2026-03-14');
  });

  test('rollover is idempotent within a day', () async {
    final clock = FixedClock(DateTime(2026, 3, 14, 9));
    final container = await _ready(clock);
    addTearDown(container.dispose);

    await container.read(historyRolloverProvider).run();
    final first = container.read(dayRecordsProvider).length;

    await container.read(historyRolloverProvider).run();
    expect(container.read(dayRecordsProvider).length, first);
  });

  test('rollover does nothing before onboarding is finished', () async {
    final clock = FixedClock(DateTime(2026, 3, 14, 9));
    final container = testContainer(overrides: [clockProviderOverride(clock)]);
    addTearDown(container.dispose);

    await container.read(historyRolloverProvider).run();
    expect(container.read(dayRecordsProvider), isEmpty);
  });

  test('a backwards clock is flagged and history is left alone', () async {
    final clock = FixedClock(DateTime(2026, 3, 14, 9));
    final container = await _ready(clock);
    addTearDown(container.dispose);

    await container.read(historyRolloverProvider).run();
    final before = container.read(dayRecordsProvider).length;

    clock.set(DateTime(2026, 3, 1, 9));
    await container.read(historyRolloverProvider).run();

    expect(container.read(storeProvider).meta(MetaKeys.clockAnomaly), isTrue);
    expect(
      container.read(dayRecordsProvider).length,
      lessThanOrEqualTo(before + 1),
      reason: 'no fabricated history',
    );
  });

  test("today's record is created so the calendar has no hole", () async {
    final clock = FixedClock(DateTime(2026, 3, 14, 9));
    final container = await _ready(clock);
    addTearDown(container.dispose);

    await container.read(historyRolloverProvider).run();
    final today = container.read(dayRecordsProvider)['2026-03-14'];
    expect(today, isNotNull);
    expect(today!.plannedMinutes, greaterThan(0));
  });
}
