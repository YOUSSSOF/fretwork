/// The curriculum, as **metadata only**.
///
/// Per §0 of the plan: this file stores exercise labels, technique tags, key
/// and position, tempo figures, page and track pointers, and short descriptions
/// written by the app author. It contains no scanned pages, no notation and no
/// transcribed tablature. Where the user needs the actual music, the exercise
/// detail screen shows a page reference and the book stays open next to the
/// phone — that is the intended workflow, not a limitation.
///
/// **Page numbers are real; CD-track numbers are still placeholders.** The
/// page pointers were indexed from the section headings of the owner's scanned
/// copy — see `score_index.dart` — so "Book p. 17" turns to the right page. A
/// few examples that begin mid-page may be one out. The track numbers are
/// still sequential guesses. Bump [kSeedVersion] in `bootstrap.dart` when
/// either is edited.
library;

import 'package:fretwork/core/models/exercise.dart';
import 'package:fretwork/core/models/practice_category.dart';

/// Free play is the app author's own addition, not part of the course. It
/// unlocks at the very first milestone — someone who has only read the preface
/// still owns a guitar — and it never disappears from the weights, because
/// technique that is never used musically stays locked in the practice room.
const CoursePart kFreePlayPart = CoursePart(
  id: 'part_free',
  order: 99,
  label: 'Free play',
  milestone: 1,
  blurb: 'Unstructured playing time. Always in the routine, never assessed.',
  exercises: [
    Exercise(
      id: 'fp_improvise',
      partId: 'part_free',
      label: 'Free play',
      title: 'Improvise over a groove',
      summary:
          'Play freely with no click and no target. The only rule is to use '
          'something from today\'s session in a musical context.',
      category: PracticeCategory.freePlay,
      tags: [TechniqueTag.improvisation],
      procedure: ProcedureType.freeTime,
      difficulty: 1,
      defaultTempo: 0,
      minTempo: 0,
      maxTempo: 0,
      subdivision: 1,
      estimatedMinutes: 8,
      bookPage: 0,
    ),
    Exercise(
      id: 'fp_apply',
      partId: 'part_free',
      label: 'Free play',
      title: "Apply today's technique",
      summary:
          'Take one shape or sequence from this session and force it into a '
          'riff or a solo line. If it does not fit, that is the useful part.',
      category: PracticeCategory.freePlay,
      tags: [TechniqueTag.improvisation],
      procedure: ProcedureType.freeTime,
      difficulty: 2,
      defaultTempo: 0,
      minTempo: 0,
      maxTempo: 0,
      subdivision: 1,
      estimatedMinutes: 8,
      bookPage: 0,
    ),
    Exercise(
      id: 'fp_repertoire',
      partId: 'part_free',
      label: 'Free play',
      title: 'Work on a song',
      summary:
          'Learn or refine a section of real repertoire. Counts as practice '
          'because it is the reason the rest of the session exists.',
      category: PracticeCategory.freePlay,
      tags: [TechniqueTag.improvisation],
      procedure: ProcedureType.freeTime,
      difficulty: 1,
      defaultTempo: 0,
      minTempo: 0,
      maxTempo: 0,
      subdivision: 1,
      estimatedMinutes: 10,
      bookPage: 0,
    ),
  ],
);

/// The nine course parts plus the preface. Milestones are unique and
/// contiguous, 1 through 10 — the seed integrity test enforces both.
const List<CoursePart> kCourseParts = [
  CoursePart(
    id: 'part_0',
    order: 0,
    label: 'Preface & Introduction',
    milestone: 1,
    blurb:
        'How the course is meant to be practised. No drills — read it, then '
        'move on.',
  ),

  // ── Part I ────────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_i',
    order: 1,
    label: 'Part I — Warm-up: Left Hand',
    milestone: 2,
    blurb:
        'Fretting-hand preparation: stretches, finger independence and mirror '
        'shapes across the neck.',
    exercises: [
      Exercise(
        id: 'ex_1',
        partId: 'part_i',
        label: 'Example 1',
        title: 'Four-finger chromatic warm-up',
        summary:
            'One finger per fret, ascending and descending across all six '
            'strings. The foundation every later exercise assumes.',
        category: PracticeCategory.warmupLeft,
        tags: [
          TechniqueTag.chromatic,
          TechniqueTag.fingerIndependence,
          TechniqueTag.stretch,
        ],
        procedure: ProcedureType.ladder,
        difficulty: 1,
        defaultTempo: 60,
        minTempo: 40,
        maxTempo: 160,
        subdivision: 4,
        position: '5th position',
        estimatedMinutes: 4,
        bookPage: 2,
        cdTrack: 1,
        variants: [
          ExerciseVariant(
            id: 'ex_1_part_a',
            label: 'Part A',
            kind: VariantKind.part,
            note: 'Ascending, 1-2-3-4 on every string.',
            bookPage: 2,
          ),
          ExerciseVariant(
            id: 'ex_1_part_b',
            label: 'Part B',
            kind: VariantKind.part,
            note: 'Descending, 4-3-2-1 on every string.',
            bookPage: 2,
          ),
          ExerciseVariant(
            id: 'ex_1_part_c',
            label: 'Part C',
            kind: VariantKind.part,
            note: 'Ascending across strings, descending down the neck.',
            bookPage: 2,
          ),
          ExerciseVariant(
            id: 'ex_1_part_d',
            label: 'Part D',
            kind: VariantKind.part,
            note: 'Mixed direction, changing position each pass.',
            bookPage: 2,
          ),
        ],
        tips: [
          'Keep every finger that is not playing hovering close to the string '
              'rather than flying away.',
          'Fret just behind the wire — pressing harder does not make it '
              'cleaner, only slower.',
        ],
      ),
      Exercise(
        id: 'ex_2',
        partId: 'part_i',
        label: 'Example 2',
        title: 'Finger-independence pairs',
        summary:
            'Isolated finger pairings, including the weak 3–4 combination, '
            'held at one tempo rather than climbed.',
        category: PracticeCategory.warmupLeft,
        tags: [TechniqueTag.fingerIndependence, TechniqueTag.stretch],
        procedure: ProcedureType.fixedTempo,
        difficulty: 2,
        defaultTempo: 72,
        minTempo: 50,
        maxTempo: 140,
        subdivision: 2,
        position: '5th position',
        estimatedMinutes: 3,
        bookPage: 3,
        cdTrack: 2,
        variants: [
          ExerciseVariant(
            id: 'ex_2_part_a',
            label: 'Part A',
            kind: VariantKind.part,
            note: 'Adjacent pairs: 1-2, 2-3, 3-4.',
            bookPage: 3,
          ),
          ExerciseVariant(
            id: 'ex_2_part_b',
            label: 'Part B',
            kind: VariantKind.part,
            note: 'Split pairs: 1-3, 2-4, 1-4.',
            bookPage: 3,
          ),
        ],
        tips: [
          'If 3–4 collapses, slow down until it does not. Speed practised badly '
              'is badness practised.',
        ],
      ),
      Exercise(
        id: 'ex_3',
        partId: 'part_i',
        label: 'Example 3',
        title: 'Mirror shapes and stretches',
        summary:
            'Symmetrical shapes moved up and down the neck, opening the hand '
            'gradually as the frets narrow.',
        category: PracticeCategory.warmupLeft,
        tags: [TechniqueTag.mirrorShape, TechniqueTag.stretch],
        procedure: ProcedureType.ladder,
        difficulty: 2,
        defaultTempo: 66,
        minTempo: 40,
        maxTempo: 150,
        subdivision: 4,
        position: 'Moving',
        estimatedMinutes: 4,
        bookPage: 4,
        cdTrack: 3,
        tips: [
          'Start at the 9th fret where the stretch is easy and work back toward '
              'the nut, not the other way round.',
        ],
      ),
    ],
  ),

  // ── Part II ───────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_ii',
    order: 2,
    label: 'Part II — Warm-up: Right Hand',
    milestone: 3,
    blurb:
        'Picking-hand preparation: strict alternate picking, string crossing '
        'and starting on an upstroke.',
    exercises: [
      Exercise(
        id: 'ex_4',
        partId: 'part_ii',
        label: 'Example 4',
        title: 'Alternate-picking warm-up',
        summary:
            'Strict down-up across single strings and string crossings. The '
            'variations change where the pattern starts.',
        category: PracticeCategory.warmupRight,
        tags: [
          TechniqueTag.alternatePicking,
          TechniqueTag.upstrokeStart,
          TechniqueTag.stringSkipping,
        ],
        procedure: ProcedureType.ladder,
        difficulty: 2,
        defaultTempo: 70,
        minTempo: 40,
        maxTempo: 200,
        subdivision: 4,
        estimatedMinutes: 5,
        bookPage: 5,
        cdTrack: 4,
        variants: [
          ExerciseVariant(
            id: 'ex_4_base',
            label: 'Base',
            kind: VariantKind.part,
            note: 'Down-stroke start, one string at a time.',
            bookPage: 5,
          ),
          ExerciseVariant(
            id: 'ex_4_var_1',
            label: 'Variation 1',
            kind: VariantKind.variation,
            note: 'Up-stroke start. Harder than it looks.',
            bookPage: 5,
          ),
          ExerciseVariant(
            id: 'ex_4_var_2',
            label: 'Variation 2',
            kind: VariantKind.variation,
            note: 'Two strings, crossing on every fourth note.',
            bookPage: 5,
          ),
          ExerciseVariant(
            id: 'ex_4_var_3',
            label: 'Variation 3',
            kind: VariantKind.variation,
            note: 'String skipping — skip one string on each crossing.',
            bookPage: 5,
          ),
        ],
        tips: [
          'Alternate the starting stroke day to day. Only ever starting on a '
              'down-stroke builds a hand that can only start on a down-stroke.',
          'Keep the pick travelling the same short distance whatever the tempo.',
        ],
      ),
    ],
  ),

  // ── Part III ──────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_iii',
    order: 3,
    label: 'Part III — Synchronisation',
    milestone: 4,
    blurb:
        'Getting the two hands to agree: the fret and the pick landing on the '
        'same instant, at every speed.',
    exercises: [
      Exercise(
        id: 'ex_5',
        partId: 'part_iii',
        label: 'Example 5',
        title: 'Hand synchronisation drill',
        summary:
            'Slow, deliberate pairing of fretting and picking so the two land '
            'together rather than nearly together.',
        category: PracticeCategory.warmupSync,
        tags: [TechniqueTag.synchronization, TechniqueTag.alternatePicking],
        procedure: ProcedureType.ladder,
        difficulty: 2,
        defaultTempo: 64,
        minTempo: 40,
        maxTempo: 180,
        subdivision: 4,
        estimatedMinutes: 4,
        bookPage: 9,
        cdTrack: 5,
        variants: [
          ExerciseVariant(
            id: 'ex_5_part_a',
            label: 'Part A',
            kind: VariantKind.part,
            note: 'One note per pick stroke, single string.',
            bookPage: 9,
          ),
          ExerciseVariant(
            id: 'ex_5_part_b',
            label: 'Part B',
            kind: VariantKind.part,
            note: 'Across strings, watching the crossing point.',
            bookPage: 9,
          ),
        ],
        tips: [
          'Listen for the fret buzz that appears when the pick arrives early. '
              'That is the whole diagnostic.',
        ],
      ),
      Exercise(
        id: 'ex_6',
        partId: 'part_iii',
        label: 'Example 6',
        title: 'Accelerate and decelerate',
        summary:
            'Rev the same figure up and back down without breaking time, with '
            'dynamics following the speed.',
        category: PracticeCategory.warmupSync,
        tags: [TechniqueTag.synchronization, TechniqueTag.subdivision],
        procedure: ProcedureType.accelDecel,
        difficulty: 3,
        defaultTempo: 80,
        minTempo: 50,
        maxTempo: 200,
        subdivision: 4,
        estimatedMinutes: 4,
        bookPage: 10,
        cdTrack: 6,
        variants: [
          ExerciseVariant(
            id: 'ex_6_part_a',
            label: 'Part A',
            kind: VariantKind.part,
            note: 'Eighths to sixteenths and back.',
            bookPage: 10,
          ),
          ExerciseVariant(
            id: 'ex_6_part_b',
            label: 'Part B',
            kind: VariantKind.part,
            note: 'Adds triplets to the ladder.',
            bookPage: 10,
          ),
        ],
      ),
    ],
  ),

  // ── Part IV ───────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_iv',
    order: 4,
    label: 'Part IV — Speed & Accuracy',
    milestone: 5,
    blurb:
        'Subdivision against the click, and four-note-per-string chromatic '
        'work with a set of developments.',
    exercises: [
      Exercise(
        id: 'ex_7',
        partId: 'part_iv',
        label: 'Example 7',
        title: 'Subdivision ladder',
        summary:
            'One pitch, one click, climbing through quarters, eighths, '
            'triplets and sixteenths without the pulse moving.',
        category: PracticeCategory.timeFeel,
        tags: [TechniqueTag.subdivision, TechniqueTag.alternatePicking],
        procedure: ProcedureType.fixedTempo,
        difficulty: 2,
        defaultTempo: 80,
        minTempo: 50,
        maxTempo: 140,
        subdivision: 4,
        estimatedMinutes: 4,
        bookPage: 10,
        cdTrack: 7,
        tips: [
          'The tempo does not change. Only the number of notes between clicks '
              'changes — that is the entire point.',
        ],
      ),
      Exercise(
        id: 'ex_8',
        partId: 'part_iv',
        label: 'Example 8',
        title: 'Four notes per string, chromatic',
        summary:
            'Chromatic runs of four notes per string in six permutations, '
            'covering every finger order.',
        category: PracticeCategory.speedAccuracy,
        tags: [
          TechniqueTag.chromatic,
          TechniqueTag.alternatePicking,
          TechniqueTag.fingerIndependence,
        ],
        procedure: ProcedureType.ladder,
        difficulty: 3,
        defaultTempo: 76,
        minTempo: 50,
        maxTempo: 220,
        subdivision: 4,
        position: '5th position',
        estimatedMinutes: 6,
        bookPage: 11,
        cdTrack: 8,
        variants: [
          ExerciseVariant(
            id: 'ex_8_part_1',
            label: 'Part 1',
            shortLabel: 'P1',
            kind: VariantKind.part,
            note: '1-2-3-4',
            bookPage: 11,
          ),
          ExerciseVariant(
            id: 'ex_8_part_2',
            label: 'Part 2',
            shortLabel: 'P2',
            kind: VariantKind.part,
            note: '1-3-2-4',
            bookPage: 11,
          ),
          ExerciseVariant(
            id: 'ex_8_part_3',
            label: 'Part 3',
            shortLabel: 'P3',
            kind: VariantKind.part,
            note: '1-4-2-3',
            bookPage: 11,
          ),
          ExerciseVariant(
            id: 'ex_8_part_4',
            label: 'Part 4',
            shortLabel: 'P4',
            kind: VariantKind.part,
            note: '2-1-4-3',
            bookPage: 11,
          ),
          ExerciseVariant(
            id: 'ex_8_part_5',
            label: 'Part 5',
            shortLabel: 'P5',
            kind: VariantKind.part,
            note: '4-3-2-1',
            bookPage: 11,
          ),
          ExerciseVariant(
            id: 'ex_8_part_6',
            label: 'Part 6',
            shortLabel: 'P6',
            kind: VariantKind.part,
            note: '3-4-1-2',
            bookPage: 11,
          ),
        ],
        tips: [
          'Flawless before +8 bpm. A pass with one fluffed note does not count '
              'as a pass.',
        ],
      ),
      Exercise(
        id: 'ex_9',
        partId: 'part_iv',
        label: 'Example 9',
        title: 'Developments on the chromatic run',
        summary:
            'The Example 8 material recombined: diatonic versions, an '
            'accelerate-decelerate pass, bursts, and a recombination.',
        category: PracticeCategory.speedAccuracy,
        tags: [
          TechniqueTag.chromatic,
          TechniqueTag.sequencing,
          TechniqueTag.alternatePicking,
        ],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 84,
        minTempo: 50,
        maxTempo: 220,
        subdivision: 4,
        estimatedMinutes: 6,
        bookPage: 12,
        cdTrack: 9,
        variants: [
          ExerciseVariant(
            id: 'ex_9_dev_1a',
            label: 'Development 1A',
            shortLabel: 'Dev 1A',
            kind: VariantKind.development,
            note: 'Chromatic, ascending only.',
            bookPage: 12,
          ),
          ExerciseVariant(
            id: 'ex_9_dev_1b',
            label: 'Development 1B',
            shortLabel: 'Dev 1B',
            kind: VariantKind.development,
            note: 'Chromatic, descending only.',
            bookPage: 12,
          ),
          ExerciseVariant(
            id: 'ex_9_dev_1c',
            label: 'Development 1C',
            shortLabel: 'Dev 1C',
            kind: VariantKind.development,
            note: 'Diatonic, ascending.',
            bookPage: 12,
          ),
          ExerciseVariant(
            id: 'ex_9_dev_1d',
            label: 'Development 1D',
            shortLabel: 'Dev 1D',
            kind: VariantKind.development,
            note: 'Diatonic, descending.',
            bookPage: 12,
          ),
          ExerciseVariant(
            id: 'ex_9_dev_2',
            label: 'Development 2',
            shortLabel: 'Dev 2',
            kind: VariantKind.development,
            note: 'Accelerate and decelerate through the pattern.',
            tempo: 90,
            bookPage: 12,
          ),
          ExerciseVariant(
            id: 'ex_9_dev_3',
            label: 'Development 3',
            shortLabel: 'Dev 3',
            kind: VariantKind.development,
            note: 'Bursts: moderate tempo with short fast flurries.',
            tempo: 96,
            bookPage: 12,
          ),
          ExerciseVariant(
            id: 'ex_9_dev_4',
            label: 'Development 4',
            shortLabel: 'Dev 4',
            kind: VariantKind.development,
            note: 'Recombination of the previous developments.',
            bookPage: 12,
          ),
        ],
      ),
      Exercise(
        id: 'ex_10',
        partId: 'part_iv',
        label: 'Example 10',
        title: 'String-skipping accuracy',
        summary:
            'The same picking discipline with a string deliberately missed '
            'out, which exposes any wasted pick travel.',
        category: PracticeCategory.speedAccuracy,
        tags: [TechniqueTag.stringSkipping, TechniqueTag.alternatePicking],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 72,
        minTempo: 48,
        maxTempo: 200,
        subdivision: 4,
        estimatedMinutes: 5,
        bookPage: 14,
        cdTrack: 10,
      ),
    ],
  ),

  // ── Part V ────────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_v',
    order: 5,
    label: 'Part V — Scale Fragments & Sequences',
    milestone: 6,
    blurb:
        'Eighteen short scale fragments plus their developments, and the '
        'sequences built from them.',
    exercises: [
      Exercise(
        id: 'ex_11',
        partId: 'part_v',
        label: 'Example 11',
        title: 'Scale fragments in G major',
        summary:
            'Eighteen short fragments of the scale, each drilled to fluency on '
            'its own before being joined up.',
        category: PracticeCategory.scalar,
        tags: [TechniqueTag.sequencing, TechniqueTag.alternatePicking],
        procedure: ProcedureType.hold,
        difficulty: 3,
        defaultTempo: 88,
        minTempo: 50,
        maxTempo: 220,
        subdivision: 4,
        keyCenter: 'G major',
        position: '4th position',
        estimatedMinutes: 8,
        bookPage: 17,
        cdTrack: 11,
        variants: [
          ExerciseVariant(
            id: 'ex_11_frag_01',
            label: 'Fragment 1',
            shortLabel: 'Frag 1',
            kind: VariantKind.fragment,
            bookPage: 17,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_02',
            label: 'Fragment 2',
            shortLabel: 'Frag 2',
            kind: VariantKind.fragment,
            bookPage: 17,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_03',
            label: 'Fragment 3',
            shortLabel: 'Frag 3',
            kind: VariantKind.fragment,
            bookPage: 17,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_04',
            label: 'Fragment 4',
            shortLabel: 'Frag 4',
            kind: VariantKind.fragment,
            bookPage: 17,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_05',
            label: 'Fragment 5',
            shortLabel: 'Frag 5',
            kind: VariantKind.fragment,
            bookPage: 17,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_06',
            label: 'Fragment 6',
            shortLabel: 'Frag 6',
            kind: VariantKind.fragment,
            bookPage: 17,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_07',
            label: 'Fragment 7',
            shortLabel: 'Frag 7',
            kind: VariantKind.fragment,
            bookPage: 18,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_08',
            label: 'Fragment 8',
            shortLabel: 'Frag 8',
            kind: VariantKind.fragment,
            bookPage: 18,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_09',
            label: 'Fragment 9',
            shortLabel: 'Frag 9',
            kind: VariantKind.fragment,
            bookPage: 18,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_10',
            label: 'Fragment 10',
            shortLabel: 'Frag 10',
            kind: VariantKind.fragment,
            bookPage: 18,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_11',
            label: 'Fragment 11',
            shortLabel: 'Frag 11',
            kind: VariantKind.fragment,
            bookPage: 18,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_12',
            label: 'Fragment 12',
            shortLabel: 'Frag 12',
            kind: VariantKind.fragment,
            bookPage: 18,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_13',
            label: 'Fragment 13',
            shortLabel: 'Frag 13',
            kind: VariantKind.fragment,
            bookPage: 19,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_14',
            label: 'Fragment 14',
            shortLabel: 'Frag 14',
            kind: VariantKind.fragment,
            bookPage: 19,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_15',
            label: 'Fragment 15',
            shortLabel: 'Frag 15',
            kind: VariantKind.fragment,
            bookPage: 19,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_16',
            label: 'Fragment 16',
            shortLabel: 'Frag 16',
            kind: VariantKind.fragment,
            bookPage: 19,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_17',
            label: 'Fragment 17',
            shortLabel: 'Frag 17',
            kind: VariantKind.fragment,
            bookPage: 20,
          ),
          ExerciseVariant(
            id: 'ex_11_frag_18',
            label: 'Fragment 18',
            shortLabel: 'Frag 18',
            kind: VariantKind.fragment,
            bookPage: 20,
          ),
          ExerciseVariant(
            id: 'ex_11_dev_1',
            label: 'Development 1',
            shortLabel: 'Dev 1',
            kind: VariantKind.development,
            note: 'Fragments joined in pairs.',
            bookPage: 20,
          ),
          ExerciseVariant(
            id: 'ex_11_dev_2',
            label: 'Development 2',
            shortLabel: 'Dev 2',
            kind: VariantKind.development,
            note: 'Fragments in reverse order.',
            bookPage: 20,
          ),
          ExerciseVariant(
            id: 'ex_11_dev_3',
            label: 'Development 3',
            shortLabel: 'Dev 3',
            kind: VariantKind.development,
            note: 'Bursts across fragment boundaries.',
            bookPage: 21,
          ),
          ExerciseVariant(
            id: 'ex_11_dev_4',
            label: 'Development 4',
            shortLabel: 'Dev 4',
            kind: VariantKind.development,
            note: 'Full recombination across the neck.',
            bookPage: 21,
          ),
        ],
        tips: [
          'One minute on each fragment, unbroken. If you stop, the minute '
              'starts again.',
          'Three to five fragments a day is enough — the whole set cycles in '
              'under a week.',
        ],
      ),
      Exercise(
        id: 'ex_12',
        partId: 'part_v',
        label: 'Example 12',
        title: 'Three-note sequences',
        summary:
            'The scale in groups of three, ascending and descending. The first '
            'sequence where the picking pattern shifts against the grouping.',
        category: PracticeCategory.scalar,
        tags: [TechniqueTag.sequencing, TechniqueTag.alternatePicking],
        procedure: ProcedureType.ladder,
        difficulty: 3,
        defaultTempo: 80,
        minTempo: 50,
        maxTempo: 210,
        subdivision: 3,
        keyCenter: 'G major',
        estimatedMinutes: 5,
        bookPage: 21,
        cdTrack: 12,
      ),
      Exercise(
        id: 'ex_13',
        partId: 'part_v',
        label: 'Example 13',
        title: 'Four-note sequences',
        summary:
            'Groups of four through the same scale, which keeps the pick '
            'direction aligned and exposes the fretting hand instead.',
        category: PracticeCategory.scalar,
        tags: [TechniqueTag.sequencing, TechniqueTag.alternatePicking],
        procedure: ProcedureType.ladder,
        difficulty: 3,
        defaultTempo: 84,
        minTempo: 50,
        maxTempo: 220,
        subdivision: 4,
        keyCenter: 'G major',
        estimatedMinutes: 5,
        bookPage: 23,
        cdTrack: 13,
      ),
      Exercise(
        id: 'ex_14',
        partId: 'part_v',
        label: 'Example 14',
        title: 'Position shifts',
        summary:
            'Moving the same scale between positions mid-phrase, so the shift '
            'lands in time rather than whenever the hand arrives.',
        category: PracticeCategory.scalar,
        tags: [TechniqueTag.sequencing, TechniqueTag.synchronization],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 76,
        minTempo: 50,
        maxTempo: 190,
        subdivision: 4,
        keyCenter: 'G major',
        position: 'Moving',
        estimatedMinutes: 5,
        bookPage: 26,
        cdTrack: 14,
      ),
      Exercise(
        id: 'ex_15',
        partId: 'part_v',
        label: 'Example 15',
        title: 'Three-octave scale',
        summary:
            'The full three-octave form, ascending and descending in one '
            'unbroken line.',
        category: PracticeCategory.scalar,
        tags: [TechniqueTag.sequencing, TechniqueTag.alternatePicking],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 80,
        minTempo: 50,
        maxTempo: 210,
        subdivision: 4,
        keyCenter: 'G major',
        estimatedMinutes: 5,
        bookPage: 28,
        cdTrack: 15,
      ),
      Exercise(
        id: 'ex_16',
        partId: 'part_v',
        label: 'Example 16',
        title: 'Sequences with string skipping',
        summary:
            'Scale sequences with skips built in, joining the Part IV picking '
            'work to the Part V material.',
        category: PracticeCategory.scalar,
        tags: [
          TechniqueTag.sequencing,
          TechniqueTag.stringSkipping,
          TechniqueTag.alternatePicking,
        ],
        procedure: ProcedureType.burst,
        difficulty: 5,
        defaultTempo: 88,
        minTempo: 50,
        maxTempo: 220,
        subdivision: 4,
        keyCenter: 'G major',
        estimatedMinutes: 5,
        bookPage: 29,
        cdTrack: 16,
      ),
    ],
  ),

  // ── Part VI ───────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_vi',
    order: 6,
    label: 'Part VI — Alternate-Picked Arpeggios',
    milestone: 7,
    blurb:
        'Arpeggios picked strictly rather than swept, where every string '
        'crossing has to be earned.',
    exercises: [
      Exercise(
        id: 'ex_17',
        partId: 'part_vi',
        label: 'Example 17',
        title: 'Triad arpeggios, alternate picked',
        summary:
            'Major and minor triads across three strings with strict '
            'alternation through every crossing.',
        category: PracticeCategory.arpeggio,
        tags: [TechniqueTag.alternatePicking, TechniqueTag.stringSkipping],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 76,
        minTempo: 46,
        maxTempo: 200,
        subdivision: 3,
        keyCenter: 'A minor',
        estimatedMinutes: 6,
        bookPage: 33,
        cdTrack: 17,
      ),
      Exercise(
        id: 'ex_18',
        partId: 'part_vi',
        label: 'Example 18',
        title: 'Seventh arpeggios and inversions',
        summary:
            'Four-note arpeggios and their inversions, still alternate picked, '
            'across five strings.',
        category: PracticeCategory.arpeggio,
        tags: [TechniqueTag.alternatePicking, TechniqueTag.sequencing],
        procedure: ProcedureType.ladder,
        difficulty: 5,
        defaultTempo: 72,
        minTempo: 46,
        maxTempo: 200,
        subdivision: 4,
        keyCenter: 'A minor',
        estimatedMinutes: 6,
        bookPage: 36,
        cdTrack: 18,
      ),
    ],
  ),

  // ── Part VII ──────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_vii',
    order: 7,
    label: 'Part VII — Legato',
    milestone: 8,
    blurb:
        'Hammer-ons, pull-offs and tapping: volume and evenness from the '
        'fretting hand alone.',
    exercises: [
      Exercise(
        id: 'ex_19',
        partId: 'part_vii',
        label: 'Example 19',
        title: 'Legato fragments',
        summary:
            'Six short legato figures, each held until the hammered notes '
            'match the picked one in volume.',
        category: PracticeCategory.legato,
        tags: [TechniqueTag.hammerPull, TechniqueTag.fingerIndependence],
        procedure: ProcedureType.hold,
        difficulty: 3,
        defaultTempo: 72,
        minTempo: 46,
        maxTempo: 190,
        subdivision: 4,
        estimatedMinutes: 6,
        bookPage: 37,
        cdTrack: 19,
        variants: [
          ExerciseVariant(
            id: 'ex_19_frag_1',
            label: 'Fragment 1',
            shortLabel: 'Frag 1',
            kind: VariantKind.fragment,
            bookPage: 37,
          ),
          ExerciseVariant(
            id: 'ex_19_frag_2',
            label: 'Fragment 2',
            shortLabel: 'Frag 2',
            kind: VariantKind.fragment,
            bookPage: 37,
          ),
          ExerciseVariant(
            id: 'ex_19_frag_3',
            label: 'Fragment 3',
            shortLabel: 'Frag 3',
            kind: VariantKind.fragment,
            bookPage: 37,
          ),
          ExerciseVariant(
            id: 'ex_19_frag_4',
            label: 'Fragment 4',
            shortLabel: 'Frag 4',
            kind: VariantKind.fragment,
            bookPage: 37,
          ),
          ExerciseVariant(
            id: 'ex_19_frag_5',
            label: 'Fragment 5',
            shortLabel: 'Frag 5',
            kind: VariantKind.fragment,
            bookPage: 37,
          ),
          ExerciseVariant(
            id: 'ex_19_frag_6',
            label: 'Fragment 6',
            shortLabel: 'Frag 6',
            kind: VariantKind.fragment,
            bookPage: 37,
          ),
        ],
        tips: [
          'If the hammered notes are quieter than the picked note, the problem '
              'is finger height, not finger strength.',
        ],
      ),
      Exercise(
        id: 'ex_20',
        partId: 'part_vii',
        label: 'Example 20',
        title: 'Legato across strings',
        summary:
            'Carrying a legato line across string changes without a picked '
            'note giving the join away.',
        category: PracticeCategory.legato,
        tags: [TechniqueTag.hammerPull, TechniqueTag.synchronization],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 76,
        minTempo: 46,
        maxTempo: 200,
        subdivision: 4,
        estimatedMinutes: 5,
        bookPage: 39,
        cdTrack: 20,
      ),
      Exercise(
        id: 'ex_21',
        partId: 'part_vii',
        label: 'Example 21',
        title: 'Legato sequences',
        summary:
            'The Part V sequences played legato, which changes where the '
            'accents fall.',
        category: PracticeCategory.legato,
        tags: [TechniqueTag.hammerPull, TechniqueTag.sequencing],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 80,
        minTempo: 50,
        maxTempo: 210,
        subdivision: 4,
        estimatedMinutes: 5,
        bookPage: 41,
        cdTrack: 21,
      ),
      Exercise(
        id: 'ex_22',
        partId: 'part_vii',
        label: 'Example 22',
        title: 'Introduction to tapping',
        summary:
            'The picking hand joins the fretting hand on the fingerboard, '
            'starting with single tapped notes.',
        category: PracticeCategory.legato,
        tags: [TechniqueTag.tapping, TechniqueTag.hammerPull],
        procedure: ProcedureType.fixedTempo,
        difficulty: 4,
        defaultTempo: 70,
        minTempo: 46,
        maxTempo: 180,
        subdivision: 3,
        estimatedMinutes: 5,
        bookPage: 43,
        cdTrack: 22,
      ),
      Exercise(
        id: 'ex_23',
        partId: 'part_vii',
        label: 'Example 23',
        title: 'Extended tapping figures',
        summary:
            'Longer tapped patterns in two settings, one across a single '
            'string and one moving between them.',
        category: PracticeCategory.legato,
        tags: [TechniqueTag.tapping, TechniqueTag.stringSkipping],
        procedure: ProcedureType.ladder,
        difficulty: 5,
        defaultTempo: 72,
        minTempo: 46,
        maxTempo: 190,
        subdivision: 3,
        estimatedMinutes: 5,
        bookPage: 44,
        cdTrack: 23,
        variants: [
          ExerciseVariant(
            id: 'ex_23_a',
            label: '23A',
            kind: VariantKind.part,
            note: 'Single string.',
            bookPage: 44,
          ),
          ExerciseVariant(
            id: 'ex_23_b',
            label: '23B',
            kind: VariantKind.part,
            note: 'Moving between strings.',
            bookPage: 44,
          ),
        ],
      ),
    ],
  ),

  // ── Part VIII ─────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_viii',
    order: 8,
    label: 'Part VIII — Sweep Picking',
    milestone: 9,
    blurb:
        'One continuous pick stroke across strings, and the fretting-hand '
        'muting that makes it sound like separate notes.',
    exercises: [
      Exercise(
        id: 'ex_24',
        partId: 'part_viii',
        label: 'Example 24',
        title: 'Three-string sweeps',
        summary:
            'The smallest sweep shape, slowly, until the notes stop ringing '
            'into each other.',
        category: PracticeCategory.sweep,
        tags: [TechniqueTag.economyPicking, TechniqueTag.synchronization],
        procedure: ProcedureType.ladder,
        difficulty: 4,
        defaultTempo: 64,
        minTempo: 40,
        maxTempo: 190,
        subdivision: 3,
        keyCenter: 'A minor',
        estimatedMinutes: 6,
        bookPage: 45,
        cdTrack: 24,
        tips: [
          'A sweep that sounds like a chord is a failed sweep. Roll the '
              'fretting finger and let each note stop as the next begins.',
        ],
      ),
      Exercise(
        id: 'ex_25',
        partId: 'part_viii',
        label: 'Example 25',
        title: 'Five-string sweeps',
        summary:
            'Full major and minor sweep shapes with the top-note pull-off '
            'included.',
        category: PracticeCategory.sweep,
        tags: [TechniqueTag.economyPicking, TechniqueTag.hammerPull],
        procedure: ProcedureType.ladder,
        difficulty: 5,
        defaultTempo: 60,
        minTempo: 40,
        maxTempo: 190,
        subdivision: 4,
        keyCenter: 'A minor',
        estimatedMinutes: 6,
        bookPage: 47,
        cdTrack: 25,
      ),
      Exercise(
        id: 'ex_26',
        partId: 'part_viii',
        label: 'Example 26',
        title: 'Sweep sequences',
        summary:
            'Sweep shapes chained through a progression, so the shape changes '
            'without the picking stopping.',
        category: PracticeCategory.sweep,
        tags: [TechniqueTag.economyPicking, TechniqueTag.sequencing],
        procedure: ProcedureType.ladder,
        difficulty: 5,
        defaultTempo: 66,
        minTempo: 40,
        maxTempo: 200,
        subdivision: 4,
        keyCenter: 'A minor',
        estimatedMinutes: 6,
        bookPage: 47,
        cdTrack: 26,
      ),
      Exercise(
        id: 'ex_27',
        partId: 'part_viii',
        label: 'Example 27',
        title: 'Sweeps with tapped extensions',
        summary:
            'Sweep shapes extended by a tapped note above, in two settings.',
        category: PracticeCategory.sweep,
        tags: [TechniqueTag.economyPicking, TechniqueTag.tapping],
        procedure: ProcedureType.burst,
        difficulty: 5,
        defaultTempo: 68,
        minTempo: 40,
        maxTempo: 200,
        subdivision: 4,
        estimatedMinutes: 6,
        bookPage: 48,
        cdTrack: 27,
        variants: [
          ExerciseVariant(
            id: 'ex_27_a',
            label: '27A',
            kind: VariantKind.part,
            note: 'Minor shapes.',
            bookPage: 48,
          ),
          ExerciseVariant(
            id: 'ex_27_b',
            label: '27B',
            kind: VariantKind.part,
            note: 'Major shapes.',
            bookPage: 48,
          ),
        ],
      ),
    ],
  ),

  // ── Part IX ───────────────────────────────────────────────────────────────
  CoursePart(
    id: 'part_ix',
    order: 9,
    label: 'Part IX — Chordal & Orchestration',
    milestone: 10,
    blurb:
        'Voicings, inversions and arrangement — what the technique is '
        'ultimately for.',
    exercises: [
      Exercise(
        id: 'ex_28',
        partId: 'part_ix',
        label: 'Example 28',
        title: 'Triad voicings across the neck',
        summary:
            'The same triad in four voicings and registers, so a chord can be '
            'placed where the arrangement needs it.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing],
        procedure: ProcedureType.freeTime,
        difficulty: 3,
        defaultTempo: 0,
        minTempo: 0,
        maxTempo: 0,
        subdivision: 1,
        estimatedMinutes: 6,
        bookPage: 48,
        cdTrack: 28,
        variants: [
          ExerciseVariant(
            id: 'ex_28_a',
            label: '28A',
            kind: VariantKind.part,
            note: 'Root position.',
            bookPage: 48,
          ),
          ExerciseVariant(
            id: 'ex_28_b',
            label: '28B',
            kind: VariantKind.part,
            note: 'First inversion.',
            bookPage: 48,
          ),
          ExerciseVariant(
            id: 'ex_28_c',
            label: '28C',
            kind: VariantKind.part,
            note: 'Second inversion.',
            bookPage: 48,
          ),
          ExerciseVariant(
            id: 'ex_28_d',
            label: '28D',
            kind: VariantKind.part,
            note: 'Spread voicings.',
            bookPage: 48,
          ),
        ],
      ),
      Exercise(
        id: 'ex_29',
        partId: 'part_ix',
        label: 'Example 29',
        title: 'Seventh chords and extensions',
        summary: 'Four-note voicings and the extensions built on them.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing],
        procedure: ProcedureType.freeTime,
        difficulty: 4,
        defaultTempo: 0,
        minTempo: 0,
        maxTempo: 0,
        subdivision: 1,
        estimatedMinutes: 5,
        bookPage: 48,
        cdTrack: 29,
      ),
      Exercise(
        id: 'ex_30',
        partId: 'part_ix',
        label: 'Example 30',
        title: 'Arpeggiated chord figures',
        summary: 'Voicings broken into picked patterns rather than strummed.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing, TechniqueTag.alternatePicking],
        procedure: ProcedureType.fixedTempo,
        difficulty: 4,
        defaultTempo: 76,
        minTempo: 50,
        maxTempo: 170,
        subdivision: 3,
        estimatedMinutes: 5,
        bookPage: 49,
        cdTrack: 30,
      ),
      Exercise(
        id: 'ex_31',
        partId: 'part_ix',
        label: 'Example 31',
        title: 'Voice leading through a progression',
        summary:
            'Moving between chords by the shortest distance, which is what '
            'makes a progression sound arranged rather than shifted.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing],
        procedure: ProcedureType.freeTime,
        difficulty: 4,
        defaultTempo: 0,
        minTempo: 0,
        maxTempo: 0,
        subdivision: 1,
        estimatedMinutes: 5,
        bookPage: 51,
        cdTrack: 31,
      ),
      Exercise(
        id: 'ex_32',
        partId: 'part_ix',
        label: 'Example 32',
        title: 'Pedal-tone figures',
        summary:
            'A held note against a moving line, the cheapest way to make two '
            'parts out of one guitar.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing, TechniqueTag.stringSkipping],
        procedure: ProcedureType.fixedTempo,
        difficulty: 4,
        defaultTempo: 80,
        minTempo: 50,
        maxTempo: 180,
        subdivision: 4,
        estimatedMinutes: 5,
        bookPage: 130,
        cdTrack: 32,
      ),
      Exercise(
        id: 'ex_33',
        partId: 'part_ix',
        label: 'Example 33',
        title: 'Two-part writing',
        summary:
            'Independent lines played together, in two settings of increasing '
            'separation.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing, TechniqueTag.fingerIndependence],
        procedure: ProcedureType.freeTime,
        difficulty: 5,
        defaultTempo: 0,
        minTempo: 0,
        maxTempo: 0,
        subdivision: 1,
        estimatedMinutes: 6,
        bookPage: 132,
        cdTrack: 33,
        variants: [
          ExerciseVariant(
            id: 'ex_33_a',
            label: '33A',
            kind: VariantKind.part,
            note: 'Close position.',
            bookPage: 132,
          ),
          ExerciseVariant(
            id: 'ex_33_b',
            label: '33B',
            kind: VariantKind.part,
            note: 'Open position.',
            bookPage: 133,
          ),
        ],
      ),
      Exercise(
        id: 'ex_34',
        partId: 'part_ix',
        label: 'Example 34',
        title: 'Orchestration study',
        summary: 'Arranging a single idea across registers, in two settings.',
        category: PracticeCategory.chordal,
        tags: [TechniqueTag.chordVoicing, TechniqueTag.improvisation],
        procedure: ProcedureType.freeTime,
        difficulty: 5,
        defaultTempo: 0,
        minTempo: 0,
        maxTempo: 0,
        subdivision: 1,
        estimatedMinutes: 6,
        bookPage: 134,
        cdTrack: 34,
        variants: [
          ExerciseVariant(
            id: 'ex_34_a',
            label: '34A',
            kind: VariantKind.part,
            note: 'Low register.',
            bookPage: 134,
          ),
          ExerciseVariant(
            id: 'ex_34_b',
            label: '34B',
            kind: VariantKind.part,
            note: 'High register.',
            bookPage: 135,
          ),
        ],
      ),
      Exercise(
        id: 'ex_35',
        partId: 'part_ix',
        label: 'Example 35',
        title: 'Final study',
        summary:
            'A piece that puts the whole course together. Treat it as '
            'repertoire, not as a drill.',
        category: PracticeCategory.chordal,
        tags: [
          TechniqueTag.chordVoicing,
          TechniqueTag.sequencing,
          TechniqueTag.improvisation,
        ],
        procedure: ProcedureType.freeTime,
        difficulty: 5,
        defaultTempo: 0,
        minTempo: 0,
        maxTempo: 0,
        subdivision: 1,
        estimatedMinutes: 10,
        bookPage: 138,
        cdTrack: 35,
      ),
    ],
  ),
];

/// Everything the app knows about: the course, plus free play.
const List<CoursePart> kCourseSeed = [...kCourseParts, kFreePlayPart];

/// Every exercise across every part, keyed by id.
Map<String, Exercise> buildExerciseIndex([
  List<CoursePart> parts = kCourseSeed,
]) => {
  for (final part in parts)
    for (final exercise in part.exercises) exercise.id: exercise,
};
