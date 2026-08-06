import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/hive_boxes.dart';
import 'package:fretwork/core/utils/clock.dart';

/// Overridden in `main.dart` with the store opened during bootstrap. Reading it
/// without that override is a wiring bug, not a runtime condition to handle.
final hiveStoreProvider = Provider<HiveStore>(
  (ref) => throw StateError(
    'hiveStoreProvider must be overridden with the bootstrapped HiveStore',
  ),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());
