/// The buckets a practice session is divided into.
///
/// The order of this enum is the order blocks appear in a generated routine:
/// warm-ups, then time feel, then the technical material in the order the
/// course unlocks it, and free play last.
enum PracticeCategory {
  warmupLeft,
  warmupRight,
  warmupSync,
  timeFeel,
  speedAccuracy,
  scalar,
  arpeggio,
  legato,
  sweep,
  chordal,
  freePlay;

  String get label => switch (this) {
    PracticeCategory.warmupLeft => 'Left-hand warm-up',
    PracticeCategory.warmupRight => 'Right-hand warm-up',
    PracticeCategory.warmupSync => 'Synchronisation',
    PracticeCategory.timeFeel => 'Time feel',
    PracticeCategory.speedAccuracy => 'Speed & accuracy',
    PracticeCategory.scalar => 'Scale fragments',
    PracticeCategory.arpeggio => 'Arpeggios',
    PracticeCategory.legato => 'Legato',
    PracticeCategory.sweep => 'Sweep picking',
    PracticeCategory.chordal => 'Chordal',
    PracticeCategory.freePlay => 'Free play',
  };

  String get shortLabel => switch (this) {
    PracticeCategory.warmupLeft => 'Left hand',
    PracticeCategory.warmupRight => 'Right hand',
    PracticeCategory.warmupSync => 'Sync',
    PracticeCategory.timeFeel => 'Time',
    PracticeCategory.speedAccuracy => 'Speed',
    PracticeCategory.scalar => 'Scales',
    PracticeCategory.arpeggio => 'Arps',
    PracticeCategory.legato => 'Legato',
    PracticeCategory.sweep => 'Sweep',
    PracticeCategory.chordal => 'Chords',
    PracticeCategory.freePlay => 'Free',
  };

  bool get isWarmup =>
      this == PracticeCategory.warmupLeft ||
      this == PracticeCategory.warmupRight ||
      this == PracticeCategory.warmupSync;
}

/// What the hands are actually being asked to do, independent of which chapter
/// an exercise came from. Used for analytics filtering.
enum TechniqueTag {
  stretch,
  fingerIndependence,
  mirrorShape,
  stringSkipping,
  alternatePicking,
  upstrokeStart,
  synchronization,
  subdivision,
  chromatic,
  sequencing,
  hammerPull,
  tapping,
  economyPicking,
  chordVoicing,
  improvisation;

  String get label => switch (this) {
    TechniqueTag.stretch => 'Stretch',
    TechniqueTag.fingerIndependence => 'Finger independence',
    TechniqueTag.mirrorShape => 'Mirror shapes',
    TechniqueTag.stringSkipping => 'String skipping',
    TechniqueTag.alternatePicking => 'Alternate picking',
    TechniqueTag.upstrokeStart => 'Upstroke start',
    TechniqueTag.synchronization => 'Synchronisation',
    TechniqueTag.subdivision => 'Subdivision',
    TechniqueTag.chromatic => 'Chromatic',
    TechniqueTag.sequencing => 'Sequencing',
    TechniqueTag.hammerPull => 'Hammer-on / pull-off',
    TechniqueTag.tapping => 'Tapping',
    TechniqueTag.economyPicking => 'Economy picking',
    TechniqueTag.chordVoicing => 'Chord voicing',
    TechniqueTag.improvisation => 'Improvisation',
  };
}

/// How an exercise is worked, which decides what the session screen shows and
/// what the focus note says.
enum ProcedureType {
  /// Slow until flawless, then +8 bpm, repeat.
  ladder,

  /// Hold a stated tempo for the whole item.
  fixedTempo,

  /// Rev up and back down, dynamics following speed.
  accelDecel,

  /// Moderate tempo with periodic fast flurries.
  burst,

  /// No click.
  freeTime,

  /// One minute per fragment, unbroken.
  hold;

  String get label => switch (this) {
    ProcedureType.ladder => 'Tempo ladder',
    ProcedureType.fixedTempo => 'Fixed tempo',
    ProcedureType.accelDecel => 'Accelerate & decelerate',
    ProcedureType.burst => 'Bursts',
    ProcedureType.freeTime => 'Free time',
    ProcedureType.hold => 'Hold',
  };

  /// A short paraphrase of the procedure in the app author's own words. These
  /// are summaries of *how to practise*, never quoted instructional text.
  String get hint => switch (this) {
    ProcedureType.ladder =>
      'Start slow enough to be flawless. Only raise the tempo once a full '
          'repetition is clean, then add 8 bpm.',
    ProcedureType.fixedTempo =>
      'Hold this tempo for the whole block. Accuracy at one speed, not a '
          'climb.',
    ProcedureType.accelDecel =>
      'Rev up gradually, then come back down. Let dynamics follow the speed.',
    ProcedureType.burst =>
      'Sit at a moderate tempo, then throw short fast flurries and settle '
          'back without breaking time.',
    ProcedureType.freeTime => 'No click. Play it musically.',
    ProcedureType.hold =>
      'One minute on each fragment, unbroken. Stopping resets the minute.',
  };

  bool get usesMetronome => this != ProcedureType.freeTime;
}

/// What kind of subdivision of a parent exercise a variant is.
enum VariantKind {
  part,
  variation,
  development,
  fragment;

  String get label => switch (this) {
    VariantKind.part => 'Part',
    VariantKind.variation => 'Variation',
    VariantKind.development => 'Development',
    VariantKind.fragment => 'Fragment',
  };
}
