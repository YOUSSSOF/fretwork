import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/data/backup_service.dart';
import 'package:fretwork/core/data/document_store.dart';

Future<DocumentStore> _populated() async {
  final store = MemoryDocumentStore();
  await store.write(BoxNames.profile, DocKeys.profile, {
    'milestone': 6,
    'sessionMinutes': 60,
  });
  await store.write(BoxNames.days, '2026-03-14', {
    'id': '2026-03-14',
    'completedMinutes': 55,
  });
  await store.write(BoxNames.days, '2026-03-13', {
    'id': '2026-03-13',
    'completedMinutes': 0,
  });
  await store.write(BoxNames.tempos, 'ex_11', {
    'exerciseId': 'ex_11',
    'points': [],
  });
  await store.putMeta(MetaKeys.schemaVersion, 1);
  return store;
}

void main() {
  group('exportBackup', () {
    test('captures every box and is valid JSON', () async {
      final json = exportBackup(await _populated());
      final decoded = jsonDecode(json) as Map<String, Object?>;

      expect(decoded['version'], kBackupVersion);
      expect(decoded['exportedAt'], isA<String>());

      final boxes = decoded['boxes']! as Map<String, Object?>;
      expect(boxes.keys, containsAll(BoxNames.all));
      expect((boxes[BoxNames.days]! as Map).keys, hasLength(2));
    });

    test('an empty store still produces a well-formed backup', () {
      final json = exportBackup(MemoryDocumentStore());
      final decoded = jsonDecode(json) as Map<String, Object?>;
      expect(decoded['version'], kBackupVersion);
    });
  });

  group('importBackup', () {
    test('round-trips an exported backup', () async {
      final source = await _populated();
      final json = exportBackup(source);

      final target = MemoryDocumentStore();
      final result = await importBackup(target, json);

      expect(result.isSuccess, isTrue);
      expect(result.counts[BoxNames.days], 2);
      expect(target.read(BoxNames.profile, DocKeys.profile)?['milestone'], 6);
      expect(target.readAll(BoxNames.days), hasLength(2));
    });

    test('replaces existing data rather than merging into it', () async {
      final target = MemoryDocumentStore();
      await target.write(BoxNames.days, '2020-01-01', {'id': 'stale'});

      await importBackup(target, exportBackup(await _populated()));

      expect(target.readAll(BoxNames.days).keys, isNot(contains('2020-01-01')));
    });

    test('rejects text that is not JSON', () async {
      final result = await importBackup(MemoryDocumentStore(), 'not json');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('not valid JSON'));
    });

    test('rejects JSON that is not a backup', () async {
      final result = await importBackup(MemoryDocumentStore(), '[1, 2, 3]');
      expect(result.isSuccess, isFalse);
    });

    test('rejects a backup with no version', () async {
      final result = await importBackup(
        MemoryDocumentStore(),
        jsonEncode({'boxes': <String, Object?>{}}),
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('backup version'));
    });

    test('refuses a backup from a newer app rather than mangling it', () async {
      final result = await importBackup(
        MemoryDocumentStore(),
        jsonEncode({
          'version': kBackupVersion + 5,
          'boxes': {
            BoxNames.days: {'2026-03-14': <String, Object?>{}},
          },
        }),
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('newer version'));
    });

    test('rejects an empty backup instead of wiping everything', () async {
      final target = MemoryDocumentStore();
      await target.write(BoxNames.days, '2026-03-14', {'id': 'keep'});

      final result = await importBackup(
        target,
        jsonEncode({'version': 1, 'boxes': <String, Object?>{}}),
      );

      expect(result.isSuccess, isFalse);
      expect(
        target.readAll(BoxNames.days),
        hasLength(1),
        reason: 'a rejected import must not have deleted anything',
      );
    });

    test('a malformed row aborts before anything is written', () async {
      final target = MemoryDocumentStore();
      await target.write(BoxNames.days, '2026-03-14', {'id': 'keep'});

      final result = await importBackup(
        target,
        jsonEncode({
          'version': 1,
          'boxes': {
            BoxNames.days: {'2026-03-15': 'this should be an object'},
          },
        }),
      );

      expect(result.isSuccess, isFalse);
      expect(
        target.read(BoxNames.days, '2026-03-14'),
        isNotNull,
        reason: 'validation happens before the store is cleared',
      );
    });

    test('ignores boxes the current version does not know about', () async {
      final target = MemoryDocumentStore();
      final result = await importBackup(
        target,
        jsonEncode({
          'version': 1,
          'boxes': {
            BoxNames.days: {
              '2026-03-14': {'id': '2026-03-14'},
            },
            'boxFromTheFuture': {
              'x': {'y': 1},
            },
          },
        }),
      );

      expect(result.isSuccess, isTrue);
      expect(target.readAll(BoxNames.days), hasLength(1));
    });

    test('the result summarises what was restored', () async {
      final result = await importBackup(
        MemoryDocumentStore(),
        exportBackup(await _populated()),
      );
      expect(result.summary, contains('2 days'));
      expect(result.summary, contains('1 profile'));
    });
  });
}
