import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/core/data/document_store.dart';
import 'package:fretwork/core/data/providers.dart';
import 'package:fretwork/core/models/session_snapshot.dart';

/// The session left in flight, if there is one.
///
/// Kept as its own notifier rather than a field on the session controller so
/// screens that are not the session screen — Home, most importantly — can tell
/// there is something to come back to without loading a session.
class ActiveSessionNotifier extends Notifier<SessionSnapshot?> {
  @override
  SessionSnapshot? build() {
    final stored = ref
        .watch(storeProvider)
        .read(BoxNames.activeSession, SessionSnapshot.storageKey);
    if (stored == null) return null;
    return SessionSnapshot.fromJson(stored);
  }

  Future<void> save(SessionSnapshot snapshot) async {
    state = snapshot;
    await ref
        .read(storeProvider)
        .write(
          BoxNames.activeSession,
          SessionSnapshot.storageKey,
          snapshot.toJson(),
        );
  }

  Future<void> clear() async {
    if (state == null) return;
    state = null;
    await ref
        .read(storeProvider)
        .delete(BoxNames.activeSession, SessionSnapshot.storageKey);
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, SessionSnapshot?>(
      ActiveSessionNotifier.new,
    );

/// The snapshot only if it is still worth offering — same day, non-empty plan.
///
/// A stale snapshot is left on disk rather than deleted on read: deciding to
/// throw data away is a write, and providers do not write while building.
final resumableSessionProvider = Provider<SessionSnapshot?>((ref) {
  final snapshot = ref.watch(activeSessionProvider);
  if (snapshot == null) return null;
  final now = ref.watch(clockProvider).now();
  return snapshot.isResumableOn(now) ? snapshot : null;
});
