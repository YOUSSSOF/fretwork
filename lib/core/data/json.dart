/// Encoding helpers shared by every hand-written `toJson` / `fromJson`.
///
/// There is no codegen in this project, so these exist to keep the model files
/// short and to make the encoding rules (enums by `name`, dates as ISO-8601
/// UTC) impossible to get subtly wrong in one model but not another.
library;

/// Decodes an enum from its `name`, falling back to [fallback] when the stored
/// value is unknown — which happens whenever an enum entry is renamed or
/// removed between app versions. Never throws on read.
T enumFromName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

/// Nullable variant of [enumFromName].
T? enumFromNameOrNull<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

String dateToJson(DateTime date) => date.toUtc().toIso8601String();

DateTime dateFromJson(Object? raw, {DateTime? fallback}) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? dateFromJsonOrNull(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

int intFromJson(Object? raw, int fallback) => switch (raw) {
  final int v => v,
  final double v => v.round(),
  final String v => int.tryParse(v) ?? fallback,
  _ => fallback,
};

double doubleFromJson(Object? raw, double fallback) => switch (raw) {
  final double v => v,
  final int v => v.toDouble(),
  final String v => double.tryParse(v) ?? fallback,
  _ => fallback,
};

bool boolFromJson(Object? raw, bool fallback) => raw is bool ? raw : fallback;

String stringFromJson(Object? raw, String fallback) =>
    raw is String ? raw : fallback;

String? stringFromJsonOrNull(Object? raw) => raw is String ? raw : null;

List<String> stringListFromJson(Object? raw) => switch (raw) {
  final List<Object?> list => [
    for (final item in list)
      if (item is String) item,
  ],
  _ => const [],
};

List<T> listFromJson<T>(Object? raw, T Function(Map<String, Object?>) item) =>
    switch (raw) {
      final List<Object?> list => [
        for (final entry in list)
          if (entry is Map) item(Map<String, Object?>.from(entry)),
      ],
      _ => const [],
    };

Map<String, Object?> asMap(Object? raw) =>
    raw is Map ? Map<String, Object?>.from(raw) : const {};
