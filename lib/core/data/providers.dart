import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/utils/clock.dart';

/// Overridden in `main.dart` with the store opened during bootstrap. Reading it
/// without that override is a wiring bug, not a runtime condition to handle.
final storeProvider = Provider<DocumentStore>(
  (ref) => throw StateError(
    'storeProvider must be overridden with the bootstrapped DocumentStore',
  ),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());
