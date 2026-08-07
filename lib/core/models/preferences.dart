import 'package:flutter/foundation.dart';
import 'package:fretwork/core/data/json.dart';
import 'package:fretwork/core/theme/app_spacing.dart';

enum TimerMode { quick, detailed }

enum ReduceMotionSetting { followSystem, on, off }

enum MetronomeSound { click, woodblock, beep }

/// Stable ids for the reorderable Home cards. The order of this enum is the
/// factory default order shown to a new user.
enum HomeCardId {
  todayRoutine,
  streak,
  score,
  nextMilestone,
  quickTimer,
  recentSessions;

  String get label => switch (this) {
    HomeCardId.todayRoutine => "Today's routine",
    HomeCardId.streak => 'Streak',
    HomeCardId.score => 'Discipline score',
    HomeCardId.nextMilestone => 'Next milestone',
    HomeCardId.quickTimer => 'Quick timer',
    HomeCardId.recentSessions => 'Recent sessions',
  };
}

@immutable
class Preferences {
  const Preferences({
    this.timerMode = TimerMode.detailed,
    this.accentPaletteId = 'crimson',
    this.textScale = 1.0,
    this.tabDensity = CoreTabsDensity.regular,
    this.cardDensity = CardDensity.regular,
    this.reduceMotion = ReduceMotionSetting.followSystem,
    this.reduceBlur = false,
    this.homeCardOrder = HomeCardId.values,
    this.hiddenHomeCards = const {},
    this.metronomeEnabled = true,
    this.metronomeSound = MetronomeSound.click,
    this.accentBeatOne = true,
    this.hapticOnBeat = false,
  });

  final TimerMode timerMode;
  final String accentPaletteId;
  final double textScale;
  final CoreTabsDensity tabDensity;
  final CardDensity cardDensity;
  final ReduceMotionSetting reduceMotion;
  final bool reduceBlur;
  final List<HomeCardId> homeCardOrder;
  final Set<HomeCardId> hiddenHomeCards;
  final bool metronomeEnabled;
  final MetronomeSound metronomeSound;
  final bool accentBeatOne;
  final bool hapticOnBeat;

  static const Preferences defaults = Preferences();

  /// The order actually rendered: stored order first, then any card added by a
  /// later app version that the stored list has never heard of.
  List<HomeCardId> get resolvedOrder => [
    ...homeCardOrder,
    ...HomeCardId.values.where((c) => !homeCardOrder.contains(c)),
  ];

  List<HomeCardId> get visibleCards =>
      resolvedOrder.where((c) => !hiddenHomeCards.contains(c)).toList();

  Preferences copyWith({
    TimerMode? timerMode,
    String? accentPaletteId,
    double? textScale,
    CoreTabsDensity? tabDensity,
    CardDensity? cardDensity,
    ReduceMotionSetting? reduceMotion,
    bool? reduceBlur,
    List<HomeCardId>? homeCardOrder,
    Set<HomeCardId>? hiddenHomeCards,
    bool? metronomeEnabled,
    MetronomeSound? metronomeSound,
    bool? accentBeatOne,
    bool? hapticOnBeat,
  }) => Preferences(
    timerMode: timerMode ?? this.timerMode,
    accentPaletteId: accentPaletteId ?? this.accentPaletteId,
    textScale: textScale ?? this.textScale,
    tabDensity: tabDensity ?? this.tabDensity,
    cardDensity: cardDensity ?? this.cardDensity,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    reduceBlur: reduceBlur ?? this.reduceBlur,
    homeCardOrder: homeCardOrder ?? this.homeCardOrder,
    hiddenHomeCards: hiddenHomeCards ?? this.hiddenHomeCards,
    metronomeEnabled: metronomeEnabled ?? this.metronomeEnabled,
    metronomeSound: metronomeSound ?? this.metronomeSound,
    accentBeatOne: accentBeatOne ?? this.accentBeatOne,
    hapticOnBeat: hapticOnBeat ?? this.hapticOnBeat,
  );

  Map<String, Object?> toJson() => {
    'timerMode': timerMode.name,
    'accentPaletteId': accentPaletteId,
    'textScale': textScale,
    'tabDensity': tabDensity.name,
    'cardDensity': cardDensity.name,
    'reduceMotion': reduceMotion.name,
    'reduceBlur': reduceBlur,
    'homeCardOrder': [for (final c in homeCardOrder) c.name],
    'hiddenHomeCards': [for (final c in hiddenHomeCards) c.name],
    'metronomeEnabled': metronomeEnabled,
    'metronomeSound': metronomeSound.name,
    'accentBeatOne': accentBeatOne,
    'hapticOnBeat': hapticOnBeat,
  };

  factory Preferences.fromJson(Map<String, Object?> json) {
    final order = [
      for (final name in stringListFromJson(json['homeCardOrder']))
        ?enumFromNameOrNull(HomeCardId.values, name),
    ];
    return Preferences(
      timerMode: enumFromName(
        TimerMode.values,
        json['timerMode'],
        TimerMode.detailed,
      ),
      accentPaletteId: stringFromJson(json['accentPaletteId'], 'crimson'),
      textScale: doubleFromJson(json['textScale'], 1).clamp(0.85, 1.35),
      tabDensity: enumFromName(
        CoreTabsDensity.values,
        json['tabDensity'],
        CoreTabsDensity.regular,
      ),
      cardDensity: enumFromName(
        CardDensity.values,
        json['cardDensity'],
        CardDensity.regular,
      ),
      reduceMotion: enumFromName(
        ReduceMotionSetting.values,
        json['reduceMotion'],
        ReduceMotionSetting.followSystem,
      ),
      reduceBlur: boolFromJson(json['reduceBlur'], false),
      homeCardOrder: order.isEmpty ? HomeCardId.values : order,
      hiddenHomeCards: {
        for (final name in stringListFromJson(json['hiddenHomeCards']))
          ?enumFromNameOrNull(HomeCardId.values, name),
      },
      metronomeEnabled: boolFromJson(json['metronomeEnabled'], true),
      metronomeSound: enumFromName(
        MetronomeSound.values,
        json['metronomeSound'],
        MetronomeSound.click,
      ),
      accentBeatOne: boolFromJson(json['accentBeatOne'], true),
      hapticOnBeat: boolFromJson(json['hapticOnBeat'], false),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          other.timerMode == timerMode &&
          other.accentPaletteId == accentPaletteId &&
          other.textScale == textScale &&
          other.tabDensity == tabDensity &&
          other.cardDensity == cardDensity &&
          other.reduceMotion == reduceMotion &&
          other.reduceBlur == reduceBlur &&
          listEquals(other.homeCardOrder, homeCardOrder) &&
          setEquals(other.hiddenHomeCards, hiddenHomeCards) &&
          other.metronomeEnabled == metronomeEnabled &&
          other.metronomeSound == metronomeSound &&
          other.accentBeatOne == accentBeatOne &&
          other.hapticOnBeat == hapticOnBeat;

  @override
  int get hashCode => Object.hash(
    timerMode,
    accentPaletteId,
    textScale,
    tabDensity,
    cardDensity,
    reduceMotion,
    reduceBlur,
    Object.hashAll(homeCardOrder),
    Object.hashAllUnordered(hiddenHomeCards),
    metronomeEnabled,
    metronomeSound,
    accentBeatOne,
    hapticOnBeat,
  );
}
