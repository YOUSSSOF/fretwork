import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/tablature.dart';

TabColumn _column({
  TabDuration duration = TabDuration.eighth,
  bool dotted = false,
  bool triplet = false,
}) => TabColumn(
  notes: const [TabNote(string: 0, fret: 5)],
  duration: duration,
  dotted: dotted,
  triplet: triplet,
);

void main() {
  group('TabDuration', () {
    test('beat values halve down the scale', () {
      expect(TabDuration.whole.beats, 4);
      expect(TabDuration.half.beats, 2);
      expect(TabDuration.quarter.beats, 1);
      expect(TabDuration.eighth.beats, 0.5);
      expect(TabDuration.sixteenth.beats, 0.25);
      expect(TabDuration.thirtySecond.beats, 0.125);
    });

    test('flag counts match what the renderer has to draw', () {
      expect(TabDuration.quarter.flags, 0);
      expect(TabDuration.eighth.flags, 1);
      expect(TabDuration.sixteenth.flags, 2);
      expect(TabDuration.thirtySecond.flags, 3);
    });

    test('only a whole note has no stem', () {
      for (final duration in TabDuration.values) {
        expect(duration.hasStem, duration != TabDuration.whole);
      }
    });
  });

  group('TabColumn beats', () {
    test('a dot adds half again', () {
      expect(_column(duration: TabDuration.quarter, dotted: true).beats, 1.5);
      expect(_column(dotted: true).beats, 0.75);
    });

    test('a triplet fits three in the space of two', () {
      final three = List.filled(3, _column(triplet: true));
      final total = three.fold<double>(0, (sum, c) => sum + c.beats);
      expect(total, closeTo(1.0, 0.0001));
    });

    test('dotted and triplet compose rather than fighting', () {
      final column = _column(
        duration: TabDuration.quarter,
        dotted: true,
        triplet: true,
      );
      expect(column.beats, closeTo(1.0, 0.0001));
    });
  });

  group('serialisation', () {
    test('rhythm survives a round trip', () {
      final column = _column(
        duration: TabDuration.sixteenth,
        dotted: true,
        triplet: true,
      );
      expect(TabColumn.fromJson(column.toJson()), column);
    });

    test('a column written before rhythm existed still reads', () {
      // Older documents have no duration key at all.
      final column = TabColumn.fromJson({
        'notes': [
          {'string': 0, 'fret': 5},
        ],
      });
      expect(column.duration, TabDuration.eighth);
      expect(column.dotted, isFalse);
      expect(column.notes.single.fret, 5);
    });

    test('an unknown duration falls back rather than throwing', () {
      final column = TabColumn.fromJson({
        'notes': const <Object?>[],
        'duration': 'hemidemisemiquaver',
      });
      expect(column.duration, TabDuration.eighth);
    });
  });

  group('copyWith', () {
    test('changes one field and leaves the rest', () {
      final column = _column(duration: TabDuration.quarter, dotted: true);
      final next = column.copyWith(duration: TabDuration.half);
      expect(next.duration, TabDuration.half);
      expect(next.dotted, isTrue);
      expect(next.notes, column.notes);
    });
  });
}
