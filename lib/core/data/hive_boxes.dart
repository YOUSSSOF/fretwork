import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box names. Every box except [meta] holds `jsonEncode(model.toJson())`
/// strings keyed by the model id — no generated adapters, per §8. Volumes are
/// tiny (a few thousand rows over years) so the encode cost is irrelevant and
/// the build stays free of codegen.
abstract final class BoxNames {
  static const String profile = 'profile';
  static const String preferences = 'preferences';
  static const String routines = 'routines';
  static const String days = 'days';
  static const String sessions = 'sessions';
  static const String tempos = 'tempos';
  static const String rotation = 'rotation';
  static const String meta = 'meta';

  static const List<String> documentBoxes = [
    profile,
    preferences,
    routines,
    days,
    sessions,
    tempos,
    rotation,
  ];
}

abstract final class MetaKeys {
  static const String schemaVersion = 'schemaVersion';
  static const String seedVersion = 'seedVersion';

  /// Set when day-rollover backfill sees an impossible clock delta (§13).
  static const String clockAnomaly = 'clockAnomaly';
}

abstract final class ProfileKeys {
  static const String profile = 'profile';
  static const String prefs = 'prefs';
}

/// Thin, synchronous-after-open accessor over the opened boxes.
///
/// Hive keeps opened boxes in memory, so reads do not hit disk; writes are
/// async and are never awaited on the frame path. Feature controllers own all
/// persistence — the UI never touches this class directly.
class HiveStore {
  const HiveStore({
    required this.profile,
    required this.preferences,
    required this.routines,
    required this.days,
    required this.sessions,
    required this.tempos,
    required this.rotation,
    required this.meta,
  });

  final Box<String> profile;
  final Box<String> preferences;
  final Box<String> routines;
  final Box<String> days;
  final Box<String> sessions;
  final Box<String> tempos;
  final Box<String> rotation;
  final Box<dynamic> meta;

  Box<String> boxNamed(String name) => switch (name) {
    BoxNames.profile => profile,
    BoxNames.preferences => preferences,
    BoxNames.routines => routines,
    BoxNames.days => days,
    BoxNames.sessions => sessions,
    BoxNames.tempos => tempos,
    BoxNames.rotation => rotation,
    _ => throw ArgumentError.value(name, 'name', 'Unknown document box'),
  };

  /// Reads and decodes one document. Returns null — rather than throwing — when
  /// the stored string is corrupt, so a single bad row cannot brick a launch.
  static Map<String, Object?>? readDoc(Box<String> box, String key) {
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
      return null;
    } on FormatException catch (error) {
      debugPrint('Corrupt document in ${box.name}[$key]: $error');
      return null;
    }
  }

  static Iterable<MapEntry<String, Map<String, Object?>>> readAll(
    Box<String> box,
  ) sync* {
    for (final key in box.keys) {
      if (key is! String) continue;
      final doc = readDoc(box, key);
      if (doc != null) yield MapEntry(key, doc);
    }
  }

  static Future<void> writeDoc(
    Box<String> box,
    String key,
    Map<String, Object?> value,
  ) => box.put(key, jsonEncode(value));

  Future<void> clearAll() async {
    for (final name in BoxNames.documentBoxes) {
      await boxNamed(name).clear();
    }
  }
}
