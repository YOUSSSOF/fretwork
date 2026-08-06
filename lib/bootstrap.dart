import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/hive_boxes.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Bumped whenever the shape of a persisted document changes. [_migrations]
/// must gain a closure for every step.
const int kSchemaVersion = 1;

/// Bumped whenever `course_seed.dart` changes. On bump, stored routines are
/// re-validated and any item referencing a removed exercise id is dropped.
const int kSeedVersion = 1;

/// Opens every box and runs pending migrations. Called before `runApp`, so the
/// first frame already has profile and preferences in memory.
Future<HiveStore> bootstrap() async {
  await Hive.initFlutter('fretwork');

  final boxes = await Future.wait([
    for (final name in BoxNames.documentBoxes) Hive.openBox<String>(name),
  ]);
  final meta = await Hive.openBox<dynamic>(BoxNames.meta);

  final store = HiveStore(
    profile: boxes[0],
    preferences: boxes[1],
    routines: boxes[2],
    days: boxes[3],
    sessions: boxes[4],
    tempos: boxes[5],
    rotation: boxes[6],
    meta: meta,
  );

  await _migrate(store);
  return store;
}

/// Ordered migration closures, keyed by the version they migrate *to*.
///
/// A fresh install skips them all: the box is empty, so there is nothing to
/// migrate, and the version is simply stamped.
final Map<int, Future<void> Function(HiveStore store)> _migrations = {};

Future<void> _migrate(HiveStore store) async {
  final stored = store.meta.get(MetaKeys.schemaVersion);
  final from = stored is int ? stored : null;

  if (from == null) {
    await store.meta.put(MetaKeys.schemaVersion, kSchemaVersion);
    await store.meta.put(MetaKeys.seedVersion, kSeedVersion);
    return;
  }

  if (from > kSchemaVersion) {
    // The user has downgraded the app. Refusing to touch the data is the only
    // safe response — a newer schema may contain fields this build would drop.
    debugPrint(
      'Stored schema v$from is newer than app schema v$kSchemaVersion; '
      'skipping migration.',
    );
    return;
  }

  for (var version = from + 1; version <= kSchemaVersion; version++) {
    final migration = _migrations[version];
    if (migration != null) await migration(store);
    await store.meta.put(MetaKeys.schemaVersion, version);
  }
}
