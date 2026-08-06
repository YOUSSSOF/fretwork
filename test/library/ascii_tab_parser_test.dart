import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/tablature.dart';
import 'package:fretwork/features/library/tab/ascii_tab_parser.dart';

Tablature _parse(String input) {
  final result = parseAsciiTab(input, key: 'ex_1');
  expect(result.isSuccess, isTrue, reason: result.errors.join(' '));
  return result.tablature!;
}

void main() {
  group('parseAsciiTab', () {
    test('reads a single note onto the right string', () {
      final tab = _parse('''
e|-------|
B|-------|
G|-------|
D|-------|
A|-------|
E|---3---|''');

      final note = tab.measures.single.columns.single.notes.single;
      // String 0 is the low E in the model, whatever order the text is in.
      expect(note.string, 0);
      expect(note.fret, 3);
    });

    test('keeps string order when the text is written high-string-first', () {
      final tab = _parse('''
e|---1---|
B|-------|
G|-------|
D|-------|
A|-------|
E|---6---|''');

      final notes = tab.measures.single.columns.single.notes;
      expect(notes.firstWhere((n) => n.fret == 6).string, 0);
      expect(notes.firstWhere((n) => n.fret == 1).string, 5);
    });

    test('reads two-digit frets as one note, not two', () {
      final tab = _parse('''
e|--------|
B|--------|
G|--------|
D|--------|
A|--------|
E|--12----|''');

      final columns = tab.measures.single.columns;
      expect(columns, hasLength(1));
      expect(columns.single.notes.single.fret, 12);
    });

    test('groups simultaneous notes into one column', () {
      final tab = _parse('''
e|---3---|
B|---3---|
G|---0---|
D|---0---|
A|---2---|
E|---3---|''');

      expect(tab.measures.single.columns, hasLength(1));
      expect(tab.measures.single.columns.single.notes, hasLength(6));
    });

    test('reads sequential notes as separate columns in order', () {
      final tab = _parse('''
e|-----------|
B|-----------|
G|-----------|
D|-----------|
A|---5-7-----|
E|---------8-|''');

      final columns = tab.measures.single.columns;
      expect(columns, hasLength(3));
      expect(columns[0].notes.single.fret, 5);
      expect(columns[1].notes.single.fret, 7);
      expect(columns[2].notes.single.fret, 8);
    });

    test('splits measures on bar lines', () {
      final tab = _parse('''
e|-----|-----|
B|-----|-----|
G|-----|-----|
D|-----|-----|
A|--5--|--7--|
E|-----|-----|''');

      expect(tab.measures, hasLength(2));
      expect(tab.measures[0].columns.single.notes.single.fret, 5);
      expect(tab.measures[1].columns.single.notes.single.fret, 7);
    });

    test('reads dead notes', () {
      final tab = _parse('''
e|-------|
B|-------|
G|-------|
D|-------|
A|-------|
E|---x---|''');

      final note = tab.measures.single.columns.single.notes.single;
      expect(note.muted, isTrue);
      expect(note.label, 'x');
    });

    test('reads the articulation mark before a note', () {
      final tab = _parse('''
e|------------|
B|------------|
G|------------|
D|------------|
A|------------|
E|--5h7p5-----|''');

      final columns = tab.measures.single.columns;
      expect(columns[0].notes.single.articulation, TabArticulation.none);
      expect(columns[1].notes.single.articulation, TabArticulation.hammerOn);
      expect(columns[2].notes.single.articulation, TabArticulation.pullOff);
    });

    test('reads slides and bends', () {
      final tab = _parse(r'''
e|-------------|
B|-------------|
G|-------------|
D|-------------|
A|-------------|
E|--5/7\5b7----|''');

      final frets = tab.measures.single.columns
          .map((c) => c.notes.single.articulation)
          .toList();
      expect(frets[1], TabArticulation.slideUp);
      expect(frets[2], TabArticulation.slideDown);
      expect(frets[3], TabArticulation.bend);
    });

    test('handles multiple systems as one continuous piece', () {
      final tab = _parse('''
e|-----|
B|-----|
G|-----|
D|-----|
A|--5--|
E|-----|

e|-----|
B|-----|
G|-----|
D|-----|
A|--7--|
E|-----|''');

      expect(tab.measures, hasLength(2));
      expect(tab.columnCount, 2);
    });

    test('picks up a non-standard tuning from the labels', () {
      final tab = _parse('''
e|-----|
B|-----|
G|-----|
D|-----|
A|--5--|
D|-----|''');

      expect(tab.tuning.first, 'D');
    });

    test('tolerates lines of uneven length', () {
      final tab = _parse('''
e|----------------|
B|-------|
G|-----|
D|-------------|
A|--5--|
E|--------|''');

      expect(tab.measures.single.columns.single.notes.single.fret, 5);
    });
  });

  group('parseAsciiTab rejections', () {
    test('rejects empty input', () {
      final result = parseAsciiTab('   \n  ', key: 'ex_1');
      expect(result.isSuccess, isFalse);
      expect(result.errors.single, contains('nothing to parse'));
    });

    test('rejects prose that is not tab at all', () {
      final result = parseAsciiTab(
        'Play the chromatic run four times.',
        key: 'ex_1',
      );
      expect(result.isSuccess, isFalse);
    });

    test('rejects the wrong number of string lines', () {
      final result = parseAsciiTab('''
e|-----|
B|-----|
G|-----|''', key: 'ex_1');
      expect(result.isSuccess, isFalse);
      expect(result.errors.single, contains('six string lines'));
    });

    test('rejects a stave with no notes on it', () {
      final result = parseAsciiTab('''
e|-----|
B|-----|
G|-----|
D|-----|
A|-----|
E|-----|''', key: 'ex_1');
      expect(result.isSuccess, isFalse);
      expect(result.errors.single, contains('No notes found'));
    });
  });

  group('round trip', () {
    test('parsed tab renders back to something that parses the same', () {
      const source = '''
e|-----------|
B|-----------|
G|-----------|
D|-------5-7-|
A|---5-7-----|
E|-8---------|''';

      final first = _parse(source);
      final second = _parse(toAsciiTab(first));

      expect(second.columnCount, first.columnCount);
      expect(
        second.measures
            .expand((m) => m.columns)
            .map((c) => c.notes.map((n) => '${n.string}:${n.fret}').join()),
        first.measures
            .expand((m) => m.columns)
            .map((c) => c.notes.map((n) => '${n.string}:${n.fret}').join()),
      );
    });

    test('survives a JSON round trip', () {
      final tab = _parse('''
e|-----------|
B|-----------|
G|-----------|
D|-----------|
A|---5h7-----|
E|-8---------|''');

      expect(Tablature.fromJson(tab.toJson()), tab);
    });
  });
}
