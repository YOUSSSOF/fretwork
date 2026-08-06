import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/models/preferences.dart';
import 'package:fretwork/core/theme/app_spacing.dart';

void main() {
  group('Preferences', () {
    test('round-trips through JSON', () {
      const original = Preferences(
        restBetweenBlocksSeconds: 30,
        restBetweenItemsSeconds: 10,
        timerMode: TimerMode.quick,
        accentPaletteId: 'teal',
        textScale: 1.2,
        tabDensity: CoreTabsDensity.large,
        cardDensity: CardDensity.compact,
        reduceMotion: ReduceMotionSetting.on,
        reduceBlur: true,
        homeCardOrder: [HomeCardId.score, HomeCardId.todayRoutine],
        hiddenHomeCards: {HomeCardId.quickTimer},
        metronomeEnabled: false,
        metronomeSound: MetronomeSound.beep,
        accentBeatOne: false,
        hapticOnBeat: true,
      );

      expect(Preferences.fromJson(original.toJson()), original);
    });

    test('falls back to defaults for an empty document', () {
      expect(Preferences.fromJson(const {}), Preferences.defaults);
    });

    test('ignores enum values removed by a later version', () {
      final json = Preferences.defaults.toJson()
        ..['timerMode'] = 'holographic'
        ..['metronomeSound'] = 'kazoo';
      final prefs = Preferences.fromJson(json);
      expect(prefs.timerMode, TimerMode.detailed);
      expect(prefs.metronomeSound, MetronomeSound.click);
    });

    test('clamps out-of-range stored values instead of trusting them', () {
      final json = Preferences.defaults.toJson()
        ..['textScale'] = 9.0
        ..['restBetweenBlocksSeconds'] = 9999;
      final prefs = Preferences.fromJson(json);
      expect(prefs.textScale, 1.35);
      expect(prefs.restBetweenBlocksSeconds, 120);
    });

    test('resolvedOrder appends cards a stored order has never seen', () {
      const prefs = Preferences(homeCardOrder: [HomeCardId.score]);
      expect(prefs.resolvedOrder.first, HomeCardId.score);
      expect(prefs.resolvedOrder.toSet(), HomeCardId.values.toSet());
    });

    test('visibleCards drops hidden cards but keeps order', () {
      const prefs = Preferences(hiddenHomeCards: {HomeCardId.streak});
      expect(prefs.visibleCards, isNot(contains(HomeCardId.streak)));
      expect(prefs.visibleCards.first, HomeCardId.todayRoutine);
    });
  });
}
