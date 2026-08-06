import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/document_store.dart';

/// Bumped when the backup envelope changes shape. Independent of the schema
/// version: a backup can be older than the app and still be importable.
const int kBackupVersion = 1;

@immutable
class BackupResult {
  const BackupResult.success(this.counts) : error = null, isSuccess = true;

  const BackupResult.failure(this.error) : counts = const {}, isSuccess = false;

  final bool isSuccess;
  final String? error;

  /// Rows restored per box, so the confirmation can say what actually landed
  /// rather than just "done".
  final Map<String, int> counts;

  String get summary => counts.entries
      .where((e) => e.value > 0)
      .map((e) => '${e.value} ${e.key}')
      .join(', ');
}

/// Serialises every box into one JSON document.
///
/// Raw rather than transformed: the point of a backup is to be restorable, so
/// it stores exactly what is on disk rather than a prettier shape that would
/// need a second migration path.
String exportBackup(DocumentStore store) {
  final payload = <String, Object?>{
    'version': kBackupVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'boxes': {for (final name in BoxNames.all) name: store.readAll(name)},
    'meta': {
      MetaKeys.schemaVersion: store.meta(MetaKeys.schemaVersion),
      MetaKeys.seedVersion: store.meta(MetaKeys.seedVersion),
    },
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

/// Restores a backup, replacing everything.
///
/// Validates before it touches anything: a half-applied import would leave the
/// app in a state neither the backup nor the previous data describes, and the
/// user has no way back from that.
Future<BackupResult> importBackup(DocumentStore store, String raw) async {
  final Map<String, Object?> payload;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const BackupResult.failure('That file is not a Fretwork backup.');
    }
    payload = Map<String, Object?>.from(decoded);
  } on FormatException {
    return const BackupResult.failure('That file is not valid JSON.');
  }

  final version = payload['version'];
  if (version is! int) {
    return const BackupResult.failure(
      'That file is missing its backup version, so it cannot be trusted.',
    );
  }
  if (version > kBackupVersion) {
    return BackupResult.failure(
      'That backup was made by a newer version of Fretwork (v$version). '
      'Update the app first.',
    );
  }

  final boxes = payload['boxes'];
  if (boxes is! Map) {
    return const BackupResult.failure('That backup has no data in it.');
  }

  // Parse everything up front. Anything malformed aborts before the first
  // write.
  final staged = <String, Map<String, Map<String, Object?>>>{};
  for (final name in BoxNames.all) {
    final box = boxes[name];
    if (box == null) continue;
    if (box is! Map) {
      return BackupResult.failure('The "$name" section is malformed.');
    }
    final rows = <String, Map<String, Object?>>{};
    for (final entry in box.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) {
        return BackupResult.failure('A row in "$name" is malformed.');
      }
      rows[key] = Map<String, Object?>.from(value);
    }
    staged[name] = rows;
  }

  if (staged.values.every((rows) => rows.isEmpty)) {
    return const BackupResult.failure('That backup is empty.');
  }

  await store.clearAll();
  final counts = <String, int>{};
  for (final entry in staged.entries) {
    for (final row in entry.value.entries) {
      await store.write(entry.key, row.key, row.value);
    }
    counts[entry.key] = entry.value.length;
  }

  return BackupResult.success(counts);
}
