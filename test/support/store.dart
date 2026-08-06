import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/utils/clock.dart';

/// A container wired to an in-memory store and a pinned clock.
///
/// Synchronous by design: widget tests run on a fake clock that never completes
/// real disk I/O, so anything Hive-backed would hang rather than fail.
/// [MemoryDocumentStore] encodes and decodes exactly as the Hive store does, so
/// a model that survives here survives on disk too.
ProviderContainer testContainer({
  DateTime? now,
  DocumentStore? store,
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store ?? MemoryDocumentStore()),
      clockProvider.overrideWithValue(
        FixedClock(now ?? DateTime(2026, 3, 14, 9)),
      ),
      ...overrides,
    ],
  );
}
