import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/day_record.dart';
import 'package:fretwork/core/models/tempo_record.dart';
import 'package:fretwork/core/utils/date_x.dart';

/// Every session ever logged, newest last.
///
/// A plain [Notifier] rather than an AsyncNotifier: the boxes are opened during
/// bootstrap, so reads are memory reads and the UI never needs a loading state
/// for history it already has.
class SessionRecordsNotifier extends Notifier<List<SessionRecord>> {
  @override
  List<SessionRecord> build() {
    final store = ref.watch(storeProvider);
    final records = [
      for (final doc in store.readAll(BoxNames.sessions).values)
        SessionRecord.fromJson(doc),
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return records;
  }

  Future<void> save(SessionRecord record) async {
    final next = [
      for (final existing in state)
        if (existing.id != record.id) existing,
      record,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    state = next;
    await ref
        .read(storeProvider)
        .write(BoxNames.sessions, record.id, record.toJson());
  }

  List<SessionRecord> forDay(DateTime date) => [
    for (final record in state)
      if (record.startedAt.isSameDayAs(date)) record,
  ];

  int completedMinutesOn(DateTime date) =>
      forDay(date).fold<int>(0, (sum, record) => sum + record.actualMinutes);
}

final sessionRecordsProvider =
    NotifierProvider<SessionRecordsNotifier, List<SessionRecord>>(
      SessionRecordsNotifier.new,
    );

/// Item keys already completed today.
///
/// A day that has been partially practised is never regenerated from scratch —
/// what was done is done, and only the pending part of the plan is
/// recalculated (§10.5).
final completedTodayProvider = Provider<Set<String>>((ref) {
  final clock = ref.watch(clockProvider);
  final today = clock.now();
  return {
    for (final record in ref.watch(sessionRecordsProvider))
      if (record.startedAt.isSameDayAs(today))
        for (final item in record.items)
          if (!item.skipped) item.key,
  };
});

class TempoRecordsNotifier extends Notifier<Map<String, TempoRecord>> {
  @override
  Map<String, TempoRecord> build() {
    final store = ref.watch(storeProvider);
    return {
      for (final entry in store.readAll(BoxNames.tempos).entries)
        entry.key: TempoRecord.fromJson(entry.value),
    };
  }

  /// Appends a point and persists. Append-only: a tempo the user backed off
  /// from is data, not a mistake to overwrite.
  Future<void> append(String exerciseId, TempoPoint point) async {
    final existing = state[exerciseId] ?? TempoRecord(exerciseId: exerciseId);
    final updated = existing.append(point);
    state = {...state, exerciseId: updated};
    await ref
        .read(storeProvider)
        .write(BoxNames.tempos, exerciseId, updated.toJson());
  }

  TempoRecord? forExercise(String exerciseId) => state[exerciseId];
}

final tempoRecordsProvider =
    NotifierProvider<TempoRecordsNotifier, Map<String, TempoRecord>>(
      TempoRecordsNotifier.new,
    );

/// Day records, keyed by `yyyy-MM-dd`.
class DayRecordsNotifier extends Notifier<Map<String, DayRecord>> {
  @override
  Map<String, DayRecord> build() {
    final store = ref.watch(storeProvider);
    return {
      for (final entry in store.readAll(BoxNames.days).entries)
        entry.key: DayRecord.fromJson(entry.value),
    };
  }

  Future<void> put(DayRecord record) async {
    state = {...state, record.id: record};
    await ref
        .read(storeProvider)
        .write(BoxNames.days, record.id, record.toJson());
  }

  Future<void> putAll(Iterable<DayRecord> records) async {
    if (records.isEmpty) return;
    state = {...state, for (final record in records) record.id: record};
    final store = ref.read(storeProvider);
    for (final record in records) {
      await store.write(BoxNames.days, record.id, record.toJson());
    }
  }

  DayRecord? forDate(DateTime date) => state[date.dayKey];

  List<DayRecord> get sorted =>
      state.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

final dayRecordsProvider =
    NotifierProvider<DayRecordsNotifier, Map<String, DayRecord>>(
      DayRecordsNotifier.new,
    );
