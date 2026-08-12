import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box names. Every document box holds `jsonEncode(model.toJson())` strings
/// keyed by the model id — no generated adapters, per §8. Volumes are tiny (a
/// few thousand rows over years), so the encode cost is irrelevant and the
/// build stays free of codegen.
abstract final class BoxNames {
  static const String profile = 'profile';
  static const String preferences = 'preferences';
  static const String routines = 'routines';
  static const String days = 'days';
  static const String sessions = 'sessions';
  static const String tempos = 'tempos';
  static const String rotation = 'rotation';

  /// Tablature the user has transcribed. Empty on a fresh install — the app
  /// ships no notation.
  static const String tabs = 'tabs';

  /// At most one document: the session currently in flight, so closing the app
  /// mid-routine is recoverable.
  static const String activeSession = 'activeSession';

  static const List<String> all = [
    profile,
    preferences,
    routines,
    days,
    sessions,
    tempos,
    rotation,
    tabs,
    activeSession,
  ];
}

abstract final class MetaKeys {
  static const String schemaVersion = 'schemaVersion';
  static const String seedVersion = 'seedVersion';

  /// Set when day-rollover backfill sees an impossible clock delta (§13).
  static const String clockAnomaly = 'clockAnomaly';
}

abstract final class DocKeys {
  static const String profile = 'profile';
  static const String prefs = 'prefs';
}

/// Persistence, as an interface.
///
/// Reads are synchronous because every backing store keeps the documents in
/// memory; writes are async and are never awaited on the frame path. Feature
/// controllers own all persistence — the UI never touches this directly.
///
/// The interface exists so widget tests can run against [MemoryDocumentStore].
/// Hive does real disk I/O, and a `testWidgets` body runs on a fake clock that
/// never completes real file operations, so a Hive-backed widget test hangs
/// rather than failing.
abstract interface class DocumentStore {
  Map<String, Object?>? read(String box, String key);

  /// Every document in a box, keyed by its storage key. Corrupt rows are
  /// skipped rather than thrown, so one bad row cannot brick a launch.
  Map<String, Map<String, Object?>> readAll(String box);

  Future<void> write(String box, String key, Map<String, Object?> value);

  Future<void> delete(String box, String key);

  Future<void> clearAll();

  Object? meta(String key);

  Future<void> putMeta(String key, Object? value);
}

/// The production store.
class HiveDocumentStore implements DocumentStore {
  const HiveDocumentStore({required this.boxes, required this.metaBox});

  final Map<String, Box<String>> boxes;
  final Box<dynamic> metaBox;

  Box<String> _box(String name) {
    final box = boxes[name];
    if (box == null) {
      throw ArgumentError.value(name, 'box', 'Unknown document box');
    }
    return box;
  }

  @override
  Map<String, Object?>? read(String box, String key) =>
      _decode(_box(box).get(key), '$box[$key]');

  @override
  Map<String, Map<String, Object?>> readAll(String box) {
    final result = <String, Map<String, Object?>>{};
    final target = _box(box);
    for (final key in target.keys) {
      if (key is! String) continue;
      final decoded = _decode(target.get(key), '$box[$key]');
      if (decoded != null) result[key] = decoded;
    }
    return result;
  }

  @override
  Future<void> write(String box, String key, Map<String, Object?> value) =>
      _box(box).put(key, jsonEncode(value));

  @override
  Future<void> delete(String box, String key) => _box(box).delete(key);

  @override
  Future<void> clearAll() async {
    for (final name in BoxNames.all) {
      await _box(name).clear();
    }
  }

  @override
  Object? meta(String key) => metaBox.get(key);

  @override
  Future<void> putMeta(String key, Object? value) => metaBox.put(key, value);

  static Map<String, Object?>? _decode(String? raw, String where) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
      return null;
    } on FormatException catch (error) {
      debugPrint('Corrupt document at $where: $error');
      return null;
    }
  }
}

/// The test store. Encodes and decodes exactly as the Hive one does, so a model
/// that survives here survives on disk too.
class MemoryDocumentStore implements DocumentStore {
  final Map<String, Map<String, String>> _boxes = {
    for (final name in BoxNames.all) name: {},
  };
  final Map<String, Object?> _meta = {};

  Map<String, String> _box(String name) {
    final box = _boxes[name];
    if (box == null) {
      throw ArgumentError.value(name, 'box', 'Unknown document box');
    }
    return box;
  }

  @override
  Map<String, Object?>? read(String box, String key) {
    final raw = _box(box)[key];
    if (raw == null) return null;
    return Map<String, Object?>.from(jsonDecode(raw) as Map);
  }

  @override
  Map<String, Map<String, Object?>> readAll(String box) => {
    for (final entry in _box(box).entries)
      entry.key: Map<String, Object?>.from(jsonDecode(entry.value) as Map),
  };

  @override
  Future<void> write(String box, String key, Map<String, Object?> value) async {
    _box(box)[key] = jsonEncode(value);
  }

  @override
  Future<void> delete(String box, String key) async {
    _box(box).remove(key);
  }

  @override
  Future<void> clearAll() async {
    for (final box in _boxes.values) {
      box.clear();
    }
  }

  @override
  Object? meta(String key) => _meta[key];

  @override
  Future<void> putMeta(String key, Object? value) async {
    _meta[key] = value;
  }
}
