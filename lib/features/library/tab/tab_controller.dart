import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/tablature.dart';

/// Tablature the user has entered, keyed by `exerciseId` or
/// `exerciseId:variantId`.
///
/// Nothing here ships with the app. The curriculum seed carries page and track
/// pointers, not notation, and this box stays empty until the user transcribes
/// something themselves.
class TablatureNotifier extends Notifier<Map<String, Tablature>> {
  @override
  Map<String, Tablature> build() {
    final store = ref.watch(storeProvider);
    return {
      for (final entry in store.readAll(BoxNames.tabs).entries)
        entry.key: Tablature.fromJson(entry.value),
    };
  }

  Future<void> save(Tablature tablature) async {
    final stamped = Tablature(
      key: tablature.key,
      measures: tablature.measures,
      tuning: tablature.tuning,
      title: tablature.title,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = {...state, stamped.key: stamped};
    await ref
        .read(storeProvider)
        .write(BoxNames.tabs, stamped.key, stamped.toJson());
  }

  Future<void> delete(String key) async {
    final next = {...state}..remove(key);
    state = next;
    await ref.read(storeProvider).delete(BoxNames.tabs, key);
  }

  /// The tab for a variant, falling back to the exercise's own tab when the
  /// variant has none of its own — most exercises are one figure with
  /// variations, so the parent transcription is usually the right answer.
  Tablature? resolve(String exerciseId, String? variantId) {
    if (variantId != null) {
      final exact = state['$exerciseId:$variantId'];
      if (exact != null) return exact;
    }
    return state[exerciseId];
  }
}

final tablatureProvider =
    NotifierProvider<TablatureNotifier, Map<String, Tablature>>(
      TablatureNotifier.new,
    );

/// The tab to show for a given exercise/variant pair.
final tabForProvider =
    Provider.family<Tablature?, ({String exerciseId, String? variantId})>((
      ref,
      target,
    ) {
      ref.watch(tablatureProvider);
      return ref
          .read(tablatureProvider.notifier)
          .resolve(target.exerciseId, target.variantId);
    });
