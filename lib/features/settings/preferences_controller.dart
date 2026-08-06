import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/preferences.dart';

/// Preferences are read once at build (the box is already open, so this is a
/// memory read) and written back on every change. The UI reads them
/// synchronously — there is no loading state for settings.
class PrefsNotifier extends Notifier<Preferences> {
  @override
  Preferences build() {
    final store = ref.watch(storeProvider);
    final doc = store.read(BoxNames.preferences, DocKeys.prefs);
    return doc == null ? Preferences.defaults : Preferences.fromJson(doc);
  }

  Future<void> update(Preferences Function(Preferences current) change) async {
    final next = change(state);
    if (next == state) return;
    state = next;
    await _persist(next);
  }

  Future<void> reset() async {
    state = Preferences.defaults;
    await _persist(Preferences.defaults);
  }

  Future<void> _persist(Preferences prefs) => ref
      .read(storeProvider)
      .write(BoxNames.preferences, DocKeys.prefs, prefs.toJson());
}

final preferencesProvider = NotifierProvider<PrefsNotifier, Preferences>(
  PrefsNotifier.new,
);
