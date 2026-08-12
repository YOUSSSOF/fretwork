import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Bumped whenever the shape of a persisted document changes. [_migrations]
/// must gain a closure for every step.
const int kSchemaVersion = 3;

/// Bumped whenever `course_seed.dart` changes. On bump, stored routines are
/// re-validated and any item referencing a removed exercise id is dropped.
const int kSeedVersion = 1;

/// Opens every box and runs pending migrations. Called before `runApp`, so the
/// first frame already has profile and preferences in memory.
Future<DocumentStore> bootstrap() async {
  await Hive.initFlutter('fretwork');

  final opened = await Future.wait([
    for (final name in BoxNames.all) Hive.openBox<String>(name),
  ]);
  final metaBox = await Hive.openBox<dynamic>('meta');

  final store = HiveDocumentStore(
    boxes: {
      for (var i = 0; i < BoxNames.all.length; i++) BoxNames.all[i]: opened[i],
    },
    metaBox: metaBox,
  );

  await migrate(store);
  return store;
}

/// Ordered migration closures, keyed by the version they migrate *to*.
///
/// A fresh install skips them all: the store is empty, so there is nothing to
/// migrate and the version is simply stamped.
final Map<int, Future<void> Function(DocumentStore store)> _migrations = {
  // v2 added the `tabs` box. Opening a box that has never been written is
  // already a no-op, so there is nothing to move — the version bump exists so
  // the step is recorded rather than skipped silently.
  2: (store) async {},
  // v3 added the `activeSession` box, holding the one session in flight. Same
  // story as v2: an unwritten box needs no migration, and the bump records the
  // step rather than leaving a gap in the sequence.
  3: (store) async {},
};

@visibleForTesting
Future<void> migrate(DocumentStore store) async {
  final stored = store.meta(MetaKeys.schemaVersion);
  final from = stored is int ? stored : null;

  if (from == null) {
    await store.putMeta(MetaKeys.schemaVersion, kSchemaVersion);
    await store.putMeta(MetaKeys.seedVersion, kSeedVersion);
    return;
  }

  if (from > kSchemaVersion) {
    // The user has downgraded the app. Refusing to touch the data is the only
    // safe response — a newer schema may hold fields this build would drop.
    debugPrint(
      'Stored schema v$from is newer than app schema v$kSchemaVersion; '
      'skipping migration.',
    );
    return;
  }

  for (var version = from + 1; version <= kSchemaVersion; version++) {
    final migration = _migrations[version];
    if (migration != null) await migration(store);
    await store.putMeta(MetaKeys.schemaVersion, version);
  }
}
