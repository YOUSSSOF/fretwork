# Practice Companion — Flutter Implementation Plan

A single-user, offline guitar practice companion built around a structured technique
curriculum. The app gates lessons behind a progression system, regenerates a daily
practice routine every time the user advances, runs the session with a timer and
per-exercise metronome, and turns the resulting history into analytics and an
exportable PDF report.

**Suggested app name:** `Fretwork` (package `fretwork`). Avoid naming the app after
the source book — see §0.

---

## 0. Content & rights — read first

The curriculum this app schedules comes from a copyrighted instructional book that the
user owns. The app is a **personal practice tracker**, not a reproduction of the book.

**Rules for the seed data and every screen:**

- Store **metadata only**: exercise labels ("Example 9 — Development 1A"), technique
  tags, key/position, book page number, CD track number, tempo figures the book states,
  and **short original descriptions written by the app author in their own words**.
- **Never** bundle scanned pages, notation images, or transcribed tablature.
- Where the user needs the actual notation, the exercise detail screen shows a
  `CoreBookReference` widget: *"Book p. 26 · CD track 11"*. The book stays open next to
  the phone. That is the intended workflow.
- The "instruction / tip" content described in §18.5 must be **paraphrased summaries of
  the procedure** (e.g. "start slow, repeat until flawless, raise by 8 bpm"), not quoted
  text.
- Do not publish this app to a store with the curriculum seed included.

---

## 1. Product summary

| | |
|---|---|
| Platform | Flutter (Android + iOS), phone-first, tablet-tolerant |
| Network | **None.** No HTTP client, no analytics SDK, no crash reporter |
| Persistence | Hive (local, async), JSON-encoded documents |
| State | Riverpod + flutter_hooks |
| Routing | go_router with a stateful shell |
| Codegen | **None.** No build_runner, no freezed, no riverpod_generator |
| Theme | Dark-first only. Light theme is out of scope |
| Locale | English UI, LTR default; all layout uses directional insets so an RTL/Persian locale can be added later without rework |

### Core loop

1. **Onboarding** — user states how far through the course they are → progression level set → session length chosen (with a sane default per level) → routine generated.
2. **Home** — today's routine at a glance, one tap to start, streak + score.
3. **Session** — block-by-block timer, per-exercise metronome, tempo logging.
4. **History** — every day gets a record, including days with zero practice.
5. **Analytics** — trends, per-exercise tempo curves, discipline score, PDF export.
6. **Advance** — user marks the next chapter watched → new categories unlock → routine is recalculated and rebalanced.

---

## 2. Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  hooks_riverpod: ^2.5.1
  flutter_hooks: ^0.20.5
  go_router: ^14.2.0
  hive_ce: ^2.7.0            # maintained Hive fork
  hive_ce_flutter: ^2.1.0
  path_provider: ^2.1.3
  fl_chart: ^0.68.0          # analytics charts, pure Dart
  pdf: ^3.11.0               # PDF document construction
  printing: ^5.13.0          # share/save sheet for the PDF
  soundpool: ^2.4.1          # low-latency metronome clicks
  collection: ^1.18.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
  flutter_lints: ^4.0.0
```

**Metronome note:** `soundpool` is chosen for sub-10 ms click latency. If it proves
unreliable on a target device, swap to `flutter_soloud`. The engine is behind an
interface (`MetronomeEngine`) so this is a one-file change.

**No codegen means:** every model is a hand-written immutable Dart class with
`fromJson` / `toJson` / `copyWith`. Hive stores JSON strings, not generated adapters
(§8).

---

## 3. Project structure

Feature-based, single layer per feature. Each feature owns its models-facing service,
its providers, and its UI. There is no repository/datasource/usecase stack.

```
lib/
  main.dart
  app.dart                        # ProviderScope + MaterialApp.router
  bootstrap.dart                  # Hive init, box opening, seed migration

  core/
    theme/
      app_colors.dart             # palette + accent themes
      app_theme.dart              # ThemeData
      app_typography.dart         # TextTheme + scale
      app_spacing.dart            # spacing / radius / border tokens
      glass.dart                  # glass surface decoration helpers
    motion/
      motion_tokens.dart          # durations, curves, spring descriptions
      spring_curve.dart           # SpringCurve implementation
      motion_scope.dart           # reduce-motion inherited scope
      page_transitions.dart       # go_router custom transitions
    widgets/                      # ALL prefixed core_*
      core_text.dart
      core_button.dart
      core_icon_button.dart
      core_card.dart
      core_tabs.dart
      core_segmented_grid.dart
      core_section_header.dart
      core_chip.dart
      core_badge.dart
      core_progress_ring.dart
      core_slider.dart
      core_stepper_field.dart
      core_sheet.dart
      core_dialog.dart
      core_list_tile.dart
      core_empty_state.dart
      core_scaffold.dart
      core_ambient_glow.dart
      core_animated_number.dart
      core_pressable.dart
      core_divider.dart
      core_book_reference.dart
    models/                       # pure Dart, shared across features
      exercise.dart
      exercise_variant.dart
      course_part.dart
      technique_tag.dart
      practice_category.dart
      procedure_type.dart
      routine_day.dart
      routine_block.dart
      routine_item.dart
      session_record.dart
      day_record.dart
      tempo_record.dart
      user_profile.dart
      preferences.dart
    data/
      course_seed.dart            # const List<CoursePart> — the curriculum
      hive_boxes.dart             # box names + typed accessors
      json.dart                   # date/enum encoding helpers
    utils/
      duration_x.dart
      date_x.dart
      result.dart

  features/
    onboarding/
      onboarding_screen.dart
      onboarding_controller.dart
      widgets/
    home/
      home_screen.dart
      home_controller.dart
      widgets/
    routine/
      routine_service.dart        # the generator (pure functions)
      routine_controller.dart
      routine_screen.dart
      widgets/
    session/
      session_controller.dart
      session_screen.dart
      metronome/
        metronome_engine.dart
        metronome_controller.dart
      widgets/
    library/
      library_screen.dart
      exercise_detail_screen.dart
      library_controller.dart
      widgets/
    progress/                     # unlocking / course advancement
      progress_controller.dart
      milestone_screen.dart
    history/
      history_service.dart        # day rollover + backfill
      history_controller.dart
      history_screen.dart
    analytics/
      analytics_service.dart      # pure computation over records
      analytics_controller.dart
      analytics_screen.dart
      widgets/
      export/
        pdf_report_builder.dart
        report_copy.dart          # sentence templates
    settings/
      settings_screen.dart
      preferences_controller.dart
```

**Rule for Claude Code:** a feature may import from `core/` and from another feature's
`*_service.dart` only. Never import another feature's widgets or controllers. If two
features need the same widget, it moves to `core/widgets` with a `core_` prefix.

---

## 4. Design system → Flutter tokens

Ported from the supplied `DESIGN_SYSTEM.md`. Dark crimson is the default; the two
historical palettes ship as selectable accents (§16).

### 4.1 Colors — `app_colors.dart`

```dart
class AccentPalette {
  final String id, label;
  final Color a;   // primary accent
  final Color b;   // secondary accent / borders
  final Color c;   // page background
  final Color d;   // medium accent / highlights
  const AccentPalette(...);
}

const darkCrimson = AccentPalette(
  id: 'crimson', label: 'Dark Crimson',
  a: Color(0xFF5A0E12), b: Color(0xFF3B070A),
  c: Color(0xFF141010), d: Color(0xFF8B1E24),
);
const darkTeal   = AccentPalette(id:'teal',  a:0xFF1B5B5C, b:0xFF0F3D3E, c:0xFF171717, d:0xFF2A9D9A);
const neonGreen  = AccentPalette(id:'green', a:0xFF3ECA43, b:0xFF37B13B, c:0xFF171717, d:0xFF1F6522);
```

Derived semantic colors (computed from the active palette, never hardcoded in widgets):

| Token | Value |
|---|---|
| `surface0` | `palette.c` |
| `surface1` | `Colors.black.withOpacity(0.20)` over surface0 |
| `surface2` | `Colors.black.withOpacity(0.30)` (enhanced glass) |
| `border` | `Colors.white.withOpacity(0.10)` |
| `borderHover` | `Colors.white.withOpacity(0.20)` |
| `textPrimary` | `Colors.white.withOpacity(0.92)` |
| `textSecondary` | `Colors.white.withOpacity(0.62)` |
| `textTertiary` | `Colors.white.withOpacity(0.38)` |
| `accentGradient` | `LinearGradient([palette.b, palette.a])` |
| `glowA` | `palette.b.withOpacity(0.10)` |
| `selection` | `palette.a.withOpacity(0.20)` |

### 4.2 Shape & spacing

The web design system uses `rounded-none`. Translate as **sharp geometry with one
exception**: containers and buttons use `BorderRadius.zero`; only circular elements
(progress rings, avatars, the metronome dial) are round. This is the visual signature —
do not soften it.

```dart
class Sp { static const xs=4.0, sm=8.0, md=12.0, lg=16.0, xl=24.0, xxl=32.0, huge=48.0; }
class Rd { static const none=BorderRadius.zero; static const pill=BorderRadius.all(Radius.circular(999)); }
```

Section header pattern → `CoreSectionHeader`: title text plus a 96×4 gradient underline
offset 8 px below, matching the web `<span>` accent bar.

### 4.3 Glass surfaces — `glass.dart`

```dart
Widget glassSurface({required Widget child, bool enhanced = false}) => ClipRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: enhanced ? 20 : 14, sigmaY: enhanced ? 20 : 14),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(enhanced ? .30 : .20),
        border: Border.all(color: AppColors.border),
        boxShadow: enhanced ? const [BoxShadow(blurRadius: 32, offset: Offset(0,8), color: Color(0x5E000000))] : null,
      ),
      child: child,
    ),
  ),
);
```

**Performance guard:** `BackdropFilter` is expensive. Cap the number of simultaneously
mounted glass surfaces at ~6 per screen; inside scrolling lists use a flat
`surface1` colour instead of a real blur, and reserve true glass for the app bar,
bottom sheet, and the session HUD. If a device drops frames, `Preferences.reduceBlur`
replaces all blurs with solid `surface1`.

### 4.4 Ambient glow

`CoreAmbientGlow` — a positioned stack of 2–3 blurred circles using `glowA`, drawn
behind content on the Home and Analytics screens. Implement with a `Container` +
`BoxDecoration(shape: circle)` inside an `ImageFiltered` blur, not a `BackdropFilter`.
Animate their offset on a 20–35 s loop (`float`), paused when `reduceMotion` is on.

### 4.5 Typography

Ship two families: a UI sans (Inter, bundled locally — no Google Fonts network call)
and a display face for numerals. All numeric readouts (tempo, timer, minutes) use
`FontFeature.tabularFigures()` so digits do not jitter as they change.

```dart
enum CoreTextStyle { display, h1, h2, h3, title, body, bodySm, label, caption, mono }
```

Base sizes (before the user's text-scale preference, §16):

| Style | Size | Weight | Colour |
|---|---|---|---|
| display | 40 | 800 | primary |
| h1 | 30 | 700 | primary |
| h2 | 24 | 700 | primary |
| h3 | 20 | 600 | primary |
| title | 17 | 600 | primary |
| body | 15 | 400 | secondary |
| bodySm | 13 | 400 | secondary |
| label | 13 | 600 | primary |
| caption | 11 | 500 | tertiary |
| mono | 15 | 500 | primary, tabular |

---

## 5. Motion system

This is the part the user cares most about. The target is **iOS-grade interaction
feel**: nothing appears or moves without physics, and no motion exists purely as
decoration. Fade-in-on-scroll entrance animations are explicitly *not* wanted.

### 5.1 Tokens — `motion_tokens.dart`

```dart
class Motion {
  // durations
  static const instant = Duration(milliseconds: 90);
  static const fast    = Duration(milliseconds: 160);
  static const base    = Duration(milliseconds: 240);
  static const slow    = Duration(milliseconds: 380);
  static const page    = Duration(milliseconds: 420);

  // curves
  static const standard  = Cubic(0.32, 0.72, 0.0, 1.0);   // iOS-like decel
  static const emphasize = Cubic(0.16, 1.0, 0.30, 1.0);
  static const exit      = Cubic(0.40, 0.0, 1.0, 1.0);

  // springs
  static const snappy  = SpringDescription(mass: 1, stiffness: 520, damping: 32);
  static const gentle  = SpringDescription(mass: 1, stiffness: 260, damping: 26);
  static const bouncy  = SpringDescription(mass: 1, stiffness: 420, damping: 18);
}
```

`SpringCurve` wraps a `SpringSimulation` so springs can be used anywhere a `Curve` is
accepted, including implicit animations.

### 5.2 Required interaction behaviours

| Interaction | Behaviour |
|---|---|
| Any tappable (`CorePressable`) | On pointer-down: scale → 0.968 and brightness −4 % over `instant`. On release: spring back with `Motion.snappy`. Cancel on drag-out. Wraps every button, card, list tile, tab. |
| Tab switch (`CoreTabs`) | Indicator travels with `Motion.emphasize` and **stretches**: its width interpolates to `max(fromWidth,toWidth) * 1.18` at the midpoint, then settles. Label colours crossfade over `fast`. |
| Tempo / number changes | `CoreAnimatedNumber` — digit rolls vertically (slide 40 % + fade) via `AnimatedSwitcher` with per-digit keys. Never a plain text swap. |
| Timer ring | Driven by a single `AnimationController` at 60 fps, **not** rebuilt from a per-second stream. The remaining-seconds label updates on a separate 1 Hz notifier so the ring stays smooth. |
| Block completion | Ring flashes to accent, scale pulse 1.0 → 1.06 → 1.0 with `Motion.bouncy`, `HapticFeedback.mediumImpact()`. |
| Metronome tempo drag | Rotary dial with rubber-band resistance past min/max; `HapticFeedback.selectionClick()` at each bpm step, `lightImpact` at each multiple of 8 (the +8 bpm ladder). |
| Exercise card → detail | Hero on the card's label + gradient bar; the rest of the detail content enters as a shared-axis Z transition (scale 0.94→1 + fade) over `page`. |
| Bottom sheets | Draggable with velocity-aware dismissal and rubber-band overscroll at the top. Barrier opacity tracks drag position 1:1. |
| Nav bar tab change | Icon does a 1.0 → 0.86 → 1.0 spring; the label slides up 2 px. No cross-page fade — use a shared-axis X transition between shell branches. |
| List reordering (Home widget order) | `ReorderableListView` with a lifted card: scale 1.03, shadow ramp, `HapticFeedback.selectionClick` on pick-up and on each swap. |
| Unlock a milestone | The newly unlocked category cards animate in with a staggered 40 ms spring scale, and the routine screen **cross-dissolves the old plan into the new one** rather than rebuilding abruptly. |
| Pull-to-refresh | Not used. There is no network. |

### 5.3 Entrance animations

Allowed only where they carry meaning:
- First paint of a **newly generated** routine (stagger, 40 ms per block).
- Newly unlocked content.

Everything else appears instantly. No scroll-triggered reveals anywhere.

### 5.4 Reduce motion

`MotionScope.of(context).reduced` (from `Preferences.reduceMotion`, defaulting to
`MediaQuery.disableAnimations`) collapses all durations to `Duration.zero` and disables
ambient float. Springs degrade to instant. Haptics stay on.

---

## 6. Core widget library

Every widget below lives in `core/widgets/` with a `core_` filename prefix and a `Core`
class prefix. None of them read Riverpod providers except for theme/prefs — they take
data via constructor.

### 6.1 `CoreText`
```dart
CoreText(String data, {CoreTextStyle style = CoreTextStyle.body, Color? color,
  int? maxLines, TextAlign? align, bool tabular = false, double? scaleOverride});
```
Applies the user's text-scale preference and clamps it to 0.85–1.35 so layouts never
break. Named constructors: `CoreText.h1`, `.h2`, `.title`, `.body`, `.caption`, `.mono`.

### 6.2 `CoreButton`
Variants: `primary` (accent gradient at 20 % + white/10 border), `secondary` (glass),
`ghost` (text only), `destructive`. Sizes: `sm` (36), `md` (44), `lg` (52).
States: enabled / disabled / loading (inline spinner replacing the label with a
size-preserving crossfade). Optional leading + trailing icon. Full-width flag.
Always wrapped in `CorePressable`. Zero radius, `hover/press` border brightening.

### 6.3 `CoreTabs` — explicit requirement

Tabs are the navigation pattern for exercise variants **at every count**, from two parts
up to Example 11's eighteen fragments. There is no fallback to another component. The
component must stay legible and non-overlapping by changing *layout mode*, never by
refusing to render.

```dart
CoreTabs({
  required List<CoreTabItem> items,   // { id, label, shortLabel?, badge?, marked? }
  required String selectedId,
  required ValueChanged<String> onSelected,
  CoreTabsDensity density = CoreTabsDensity.regular,  // from Preferences
  bool showIndexJump = true,
});
```

**Sizing.** Every label is measured with a `TextPainter` at the *selected* (600) weight
before first paint, so the row never reflows when selection changes. Tab width =
`max(measuredWidth + 2 * horizontalPad, minTabWidth)`. Density drives both:

| Density | horizontalPad | minTabWidth | height |
|---|---|---|---|
| compact | 12 | 56 | 44 |
| regular | 16 | 72 | 48 |
| large | 20 | 88 | 56 |

Height is never below 44 dp regardless of density — that is the touch-target floor.

**Two layout modes, chosen automatically:**

- **Fitted** — when `Σ tabWidths ≤ viewport`. Tabs are distributed evenly and centred.
  This covers 2–6 items in practice.
- **Scrollable** — when they don't fit. Tabs keep their *natural measured width* (they
  are never compressed to fit — that is what causes cramping and overlap) and the row
  scrolls horizontally. This mode has no item limit: 18 fragments, 40 fragments, it
  behaves the same.

**Scrollable-mode requirements** (this is where the quality lives):

- Selected tab auto-scrolls to centre with `Motion.emphasize`, clamped at the ends so
  the first and last tabs sit flush rather than floating mid-viewport.
- 24 dp gradient fade masks on whichever edges have overflow, appearing and
  disappearing with a `fast` crossfade as the user scrolls to either end. This is the
  only affordance that reliably tells someone there are more tabs.
- Physics: `BouncingScrollPhysics` with a light snap — on scroll-end, settle to the
  nearest tab boundary if within 20 % of a tab width, so the row never rests with a tab
  half-clipped at the edge.
- Swiping the content panel moves the selection, and the tab row follows; the two are
  driven by the same value so the indicator tracks the drag continuously rather than
  jumping on release.
- `shortLabel` is used automatically in scrollable mode when a set has more than 10
  items: "Fragment 7" renders as "Frag 7". Full labels stay in the detail panel header,
  so nothing is actually lost. Never truncate with an ellipsis — shorten deliberately or
  not at all.
- `marked: true` items (today's scheduled fragment) get a 4 dp accent dot above the
  label, so the user can find what the routine picked without hunting.

**Index jump** (`showIndexJump`, on by default, only rendered in scrollable mode): a
small chevron button pinned to the trailing edge that opens a `CoreSheet` with a
wrapping grid of all items for direct selection. This is a *supplement* to the tabs, not
a replacement — the tabs remain the primary control at all times. It exists because
scrubbing to fragment 14 of 18 is tedious, and the sheet turns that into one tap.

**Indicator.** 3 dp gradient bar under the label with the stretch animation from §5.2.
In scrollable mode the indicator travel is capped at 320 ms even across long distances,
otherwise jumping from fragment 1 to 18 feels sluggish. Unselected labels at
`textSecondary`, selected at `textPrimary`.

**Non-negotiables, covered by golden tests:** never wrap to a second row, never overlap,
never compress a tab below `minTabWidth`, never ellipsize. Tests run at 320 / 390 / 430 /
768 dp with 2, 5, 8, 12, 18 and 24 items, in all three densities, asserting zero overflow
and monotonically increasing tab origins.

### 6.4 `CoreSegmentedGrid`
The wrapping grid of selectable chips used *inside* the index-jump sheet, and reused
anywhere a flat multi-select is needed (analytics category and tag filters). Selected
chip gets the accent gradient border and a scale spring. Not a tab replacement.

### 6.5 Remaining widgets

| Widget | Notes |
|---|---|
| `CoreCard` | Glass or flat surface, optional gradient top-right / bottom-left corner accents that animate in on press (mirrors the web hover pattern) |
| `CoreSectionHeader` | Title + gradient underline + optional trailing action |
| `CoreChip` | Technique tags; filled / outlined; optional leading dot in category colour |
| `CoreBadge` | Small count/date badge, 28×8 gradient background |
| `CoreProgressRing` | Painter-based, 60 fps, supports two arcs (elapsed + block progress) and a centre slot |
| `CoreSlider` | Session length, tempo, text scale. Haptic detents |
| `CoreStepperField` | −/+ numeric field with long-press acceleration for bpm and minutes |
| `CoreSheet` | Draggable bottom sheet base (§5.2) |
| `CoreDialog` | Confirm/alert, zero radius, glass |
| `CoreListTile` | Leading icon slot, title/subtitle, trailing slot, pressable |
| `CoreEmptyState` | Icon + title + body + optional action |
| `CoreScaffold` | Page shell: background colour, ambient glow slot, glass app bar, safe areas |
| `CoreAmbientGlow` | §4.4 |
| `CoreAnimatedNumber` | §5.2 |
| `CorePressable` | §5.2 — the foundation of everything tappable |
| `CoreDivider` | 1 px `border` colour hairline |
| `CoreBookReference` | "Book p. 26 · CD track 11" pill (§0) |

---

## 7. Domain models

All pure Dart. Immutable, `const` where possible, `copyWith`, `fromJson`, `toJson`,
`==`/`hashCode` via a manual implementation or `Object.hash`. Enums serialise by
`name`, dates as ISO-8601 UTC strings.

### 7.1 Curriculum

```dart
enum PracticeCategory {
  warmupLeft, warmupRight, warmupSync,
  timeFeel,          // subdivision ladder against the click
  speedAccuracy,     // chromatic four-note-per-string work
  scalar,            // scale fragments + sequences
  arpeggio,          // alternate-picked arpeggios
  legato,
  sweep,
  chordal,
  freePlay,
}

enum TechniqueTag {
  stretch, fingerIndependence, mirrorShape, stringSkipping, alternatePicking,
  upstrokeStart, synchronization, subdivision, chromatic, sequencing,
  hammerPull, tapping, economyPicking, chordVoicing, improvisation,
}

enum ProcedureType {
  ladder,        // slow → flawless → +8 bpm → repeat
  fixedTempo,    // hold a stated tempo
  accelDecel,    // rev up and back down, dynamics follow speed
  burst,         // moderate tempo, periodic fast flurries
  freeTime,      // no click
  hold,          // one minute per fragment, unbroken
}

class CoursePart {
  final String id;              // 'part_v'
  final int order;              // 5
  final String label;           // 'Part V — Scale Fragments & Sequences'
  final int milestone;          // unlock level this part corresponds to
  final List<Exercise> exercises;
}

class Exercise {
  final String id;              // 'ex_11'
  final String partId;
  final String label;           // 'Example 11'
  final String title;           // 'Scale fragments in G major'
  final String summary;         // 1–2 original sentences
  final PracticeCategory category;
  final List<TechniqueTag> tags;
  final ProcedureType procedure;
  final int difficulty;         // 1..5
  final int defaultTempo;       // bpm, 0 = free time
  final int minTempo, maxTempo;
  final int subdivision;        // notes per beat: 1,2,3,4,6,8
  final String? keyCenter;      // 'G major'
  final String? position;       // '4th position'
  final int estimatedMinutes;   // per-visit ideal
  final int bookPage;
  final int? cdTrack;
  final List<ExerciseVariant> variants;
  final List<String> tips;      // paraphrased, shown on demand only
}

class ExerciseVariant {
  final String id;              // 'ex_11_frag_07'
  final String label;           // 'Fragment 7'
  final VariantKind kind;       // part | variation | development | fragment
  final String? note;           // short original description
  final int? tempo;             // if the book states one for this variant
  final int? bookPage;
}
```

### 7.2 Curriculum seed — `course_seed.dart`

A `const List<CoursePart>` covering the nine parts. Approximate exercise counts to
model (metadata only, per §0):

| Milestone | Part | Category | Exercises / variants |
|---|---|---|---|
| 1 | Preface & intro | — | practice-philosophy note, no drills |
| 2 | I — Warm-up (left hand) | warmupLeft | Ex. 1 (4 parts), Ex. 2 (2 parts), Ex. 3 |
| 3 | II — Warm-up (right hand) | warmupRight | Ex. 4 + 3 variations |
| 4 | III — Synchronisation | warmupSync | Ex. 5 (2 parts), Ex. 6 (2 parts) |
| 5 | IV — Speed & accuracy | timeFeel, speedAccuracy | Ex. 7; Ex. 8 (6 parts); Ex. 9 (developments 1A–1D, 2, 3, 4); Ex. 10 |
| 6 | V — Scale fragments | scalar | Ex. 11 (18 fragments + 4 developments); Ex. 12–16 |
| 7 | VI — Alternate-picked arpeggios | arpeggio | Ex. 17, Ex. 18 |
| 8 | VII — Legato | legato | Ex. 19 (6 fragments), Ex. 20, 21, 22, 23A/23B |
| 9 | VIII — Sweep picking | sweep | Ex. 24, 25, 26, 27A/27B |
| 10 | IX — Chordal & orchestration | chordal | Ex. 28A–D, 29–32, 33A/B, 34A/B, 35 |

Seed integrity test: every `Exercise.partId` resolves, every id is unique, every
`defaultTempo` sits inside `[minTempo, maxTempo]`, every part's milestone is unique
and contiguous.

### 7.3 Routine

```dart
class RoutineDay {
  final String id;              // 'yyyy-MM-dd'
  final DateTime date;
  final int milestone;          // milestone it was generated for
  final int plannedMinutes;
  final List<RoutineBlock> blocks;
  final int generationSeed;     // reproducible shuffles
  final DateTime generatedAt;
}

class RoutineBlock {
  final PracticeCategory category;
  final String label;           // 'Scale fragments'
  final int minutes;
  final List<RoutineItem> items;
}

class RoutineItem {
  final String exerciseId;
  final String? variantId;      // today's fragment / development
  final int minutes;
  final int targetTempo;        // last clean tempo, or default
  final ProcedureType procedure;
  final String focusNote;       // 'Start on an up-stroke today'
}
```

### 7.4 History & progress

```dart
enum DayStatus { completed, partial, missed, rest, upcoming }

class DayRecord {
  final String id;              // 'yyyy-MM-dd'
  final DateTime date;
  final int plannedMinutes;
  final int completedMinutes;
  final DayStatus status;
  final List<String> sessionIds;
  final int milestoneAtTime;
}

class SessionRecord {
  final String id;
  final DateTime startedAt, endedAt;
  final int plannedMinutes, actualMinutes;
  final List<ItemResult> items;
  final bool abandoned;
}

class ItemResult {
  final String exerciseId;
  final String? variantId;
  final PracticeCategory category;
  final int seconds;
  final int startTempo, endTempo;
  final bool clean;             // user marks "flawless at this tempo"
  final bool skipped;
}

class TempoRecord {              // one per exercise, append-only points
  final String exerciseId;
  final List<TempoPoint> points; // {date, bpm, clean}
  int get bestCleanTempo;
  int get lastTempo;
}

class UserProfile {
  final int milestone;           // 0..10
  final int sessionMinutes;      // user-editable
  final Set<int> restWeekdays;   // e.g. {DateTime.sunday}
  final DateTime startedAt;
  final DateTime? lastOpenedOn;
  final bool onboardingComplete;
}
```

---

## 8. Persistence

Hive, opened during `bootstrap.dart` before `runApp`. **No generated adapters** —
every box is `Box<String>` holding `jsonEncode(model.toJson())`, keyed by the model id.
Volumes here are tiny (a few thousand rows over years), so JSON is fine and keeps the
build free of codegen.

| Box | Key | Value |
|---|---|---|
| `profile` | `'profile'` | `UserProfile` |
| `preferences` | `'prefs'` | `Preferences` |
| `routines` | `yyyy-MM-dd` | `RoutineDay` |
| `days` | `yyyy-MM-dd` | `DayRecord` |
| `sessions` | uuid | `SessionRecord` |
| `tempos` | exerciseId | `TempoRecord` |
| `rotation` | category name | `RotationCursor` |
| `meta` | `'schemaVersion'`, `'seedVersion'` | int |

**Migration:** `bootstrap.dart` compares `meta.schemaVersion` with the app constant and
runs ordered migration closures. `seedVersion` bumps when `course_seed.dart` changes;
on bump, re-validate stored routine items and drop any referencing removed exercise ids.

**Access:** a thin `HiveStore` class per feature, exposed as a Riverpod provider. All
reads/writes are `async`; nothing blocks the frame. Cache hot data (profile, prefs,
today's routine) in a Notifier so the UI reads synchronously after first load.

---

## 9. Progression & unlocking

`UserProfile.milestone` (0–10) is the single source of truth. Content visibility:

- `milestone >= part.milestone` → part **unlocked**, its exercises appear in the Library
  and become eligible for the routine.
- `milestone + 1 == part.milestone` → part shown as **next up**: visible, greyed, with a
  lock icon and a "Mark as watched" affordance.
- Beyond that → shown as a locked silhouette (label only, no exercise list), so the road
  ahead is visible but not browsable.

**Advancing** happens on the Milestone screen (`/progress`). It is a deliberate,
confirmed action:

1. User taps "I've finished Part VI".
2. Confirm sheet explains what changes: which categories unlock, how the routine
   rebalances, and the new recommended session length.
3. On confirm → profile updated → **routine regenerated for today and any future
   cached days** → the routine screen cross-dissolves to the new plan (§5.2) → a
   summary sheet lists the newly available exercises.

Milestone changes are recorded on `DayRecord.milestoneAtTime` so analytics can show
"you unlocked Legato on day 74" markers on charts.

Downgrading is allowed (in case the user over-reports) but warns that history is kept.

---

## 10. Routine generation — the core algorithm

Lives in `routine_service.dart` as **pure functions** with no I/O, so it is fully unit
testable. Signature:

```dart
RoutineDay generateRoutine({
  required DateTime date,
  required int milestone,
  required int sessionMinutes,
  required List<CoursePart> unlockedParts,
  required Map<PracticeCategory, RotationCursor> cursors,
  required Map<String, TempoRecord> tempos,
  required int seed,
});
```

### 10.1 Category weights by milestone

Weights are relative, applied before caps. Zero means the category is not yet unlocked.

| Milestone | warmL | warmR | warmSync | timeFeel | speedAcc | scalar | arp | legato | sweep | chordal | freePlay |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 70 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 30 |
| 3 | 35 | 35 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 30 |
| 4 | 22 | 22 | 21 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 35 |
| 5 | 10 | 10 | 10 | 12 | 38 | 0 | 0 | 0 | 0 | 0 | 20 |
| 6 | 6 | 6 | 6 | 8 | 26 | 32 | 0 | 0 | 0 | 0 | 16 |
| 7 | 5 | 5 | 5 | 7 | 18 | 25 | 20 | 0 | 0 | 0 | 15 |
| 8 | 4 | 4 | 5 | 6 | 14 | 19 | 16 | 18 | 0 | 0 | 14 |
| 9 | 4 | 4 | 4 | 5 | 11 | 15 | 13 | 15 | 16 | 0 | 13 |
| 10 | 3 | 3 | 4 | 5 | 9 | 13 | 11 | 13 | 14 | 13 | 12 |

The design intent, stated so it survives future edits: **warm-up shrinks as a share of
the session as real material unlocks** — it is preparation, not practice. Free play
never disappears, because technique that is never used musically stays locked in the
practice room.

### 10.2 Ideal session length by milestone

| Milestone | 2–4 | 5 | 6 | 7–8 | 9–10 |
|---|---|---|---|---|---|
| Suggested minutes | 30 | 45 | 60 | 75 | 90 |

User-editable, hard-clamped to **20–150 minutes**. Values outside are rejected in the
UI with an inline explanation, never silently coerced. If the user picks a value more
than 40 % below the suggestion, show a non-blocking note: consistency beats duration —
a shorter session done daily outperforms a long one done three times a week.

### 10.3 Allocation

```
1. weights   = weightTable[milestone] filtered to unlocked categories
2. raw[c]    = sessionMinutes * weights[c] / sum(weights)
3. apply caps:
     warmup total  -> clamp(raw, 6, 12)
     freePlay      -> clamp(raw, 5, 20)
     timeFeel      -> clamp(raw, 3, 8); dropped entirely if sessionMinutes < 30
     all others    -> min 4 (if below, drop the category for today and
                      record it in cursors as "owed" so it is prioritised tomorrow)
4. redistribute the delta proportionally across uncapped categories
5. round to whole minutes; assign any rounding remainder to the largest block
6. order blocks: warm-ups → timeFeel → speedAccuracy → scalar → arpeggio →
   legato → sweep → chordal → freePlay
```

### 10.4 Item selection inside a block

```
itemCount = clamp(blockMinutes ~/ 6, 1, 5)

for each slot:
  candidates = exercises in this category, unlocked
  order by: (a) least-recently-practised (from cursor)
            (b) "owed" flag from a dropped block
            (c) difficulty ascending if the user is new to the category (<5 sessions)
  pick, advance cursor (round-robin, wrapping)

for exercises with variants:
  advance a per-exercise variant cursor too
  -> Example 11's 18 fragments surface 3–5 per day and cycle over ~5 days
  -> developments rotate one per day: chromatic/diatonic -> accel-decel -> burst -> recombine

minutes per item = blockMinutes distributed proportionally to
                   exercise.estimatedMinutes, min 3, remainder to the first item

targetTempo = tempos[exerciseId]?.lastTempo ?? exercise.defaultTempo
focusNote:
  - warmupRight, alternating by date.day.isEven -> "Start on a down-stroke"
    / "Start on an up-stroke"   (this alternation is mandatory, not cosmetic)
  - ladder procedure -> "Flawless before +8 bpm"
  - hold procedure   -> "One minute each, no stopping"
```

### 10.5 Regeneration triggers

Regenerate when: the date rolls over; the milestone changes; `sessionMinutes` changes;
`restWeekdays` changes; or the user taps **Reshuffle** on the routine screen (which
increments the seed but preserves cursors, so it re-rolls today without corrupting the
rotation).

A generated `RoutineDay` is persisted immediately so the plan is stable across app
restarts within the same day. A day already partially completed is **never**
regenerated — completed items are frozen and only pending blocks are recalculated.

### 10.6 Rest days

If `date.weekday` is in `restWeekdays`, generate a `RoutineDay` with zero blocks and
`DayStatus.rest`. Rest days do not break streaks and are excluded from adherence
denominators. The home screen shows a deliberate "Rest day — adaptation happens now"
card rather than an empty state.

---

## 11. Session runner

`session_controller.dart` — a `Notifier<SessionState>` driving the whole session.

```dart
class SessionState {
  final RoutineDay routine;
  final int blockIndex, itemIndex;
  final Duration itemRemaining, totalElapsed;
  final SessionPhase phase;     // idle | running | paused | resting | itemDone | complete
  final int currentTempo;
  final Map<String, ItemResult> results;
}
```

**Timing:** one `Ticker` (via `useSingleTickerProvider` in the screen, or a
`Stopwatch` + `Timer.periodic(16ms)` in the controller). Never derive elapsed time by
counting ticks — always read `Stopwatch.elapsed`, so backgrounding does not drift.
Persist `startedAt` and a running item log to Hive every 15 s so a crash or force-quit
loses at most a few seconds.

**Two timer modes** (user choice, remembered):

- **Quick** — one ring for the whole session, a single "next" control, no per-item
  ceremony. For when they just want to play.
- **Detailed** — per-item ring with the target tempo, procedure hint, book reference,
  a "mark clean" toggle, tempo stepper, skip, and +30 s. Optional configurable rest
  (default 45 s between blocks, 0 s between items) with a breathing-ring animation.

**Item completion** writes an `ItemResult`, appends a `TempoPoint` if the user marked
the tempo clean, and advances with the block-complete animation from §5.2.

**Interruptions:** keep-screen-awake while running. On app background, the timer keeps
counting from the wall clock; on resume, reconcile and, if more than 10 minutes elapsed
while backgrounded, offer "pause here?" rather than silently burning the session.

**Ending early** saves a `SessionRecord` with `abandoned: true` and whatever minutes
were completed — partial credit is real credit, and the analytics treat it as `partial`,
not `missed`.

---

## 12. Metronome

`MetronomeEngine` interface with a `SoundpoolMetronome` implementation.

**Scheduling:** a `Stopwatch`-anchored loop. Compute the next beat's absolute timestamp
from `beatIndex * (60000 / bpm) / subdivision`, sleep to just before it, then fire.
Never use `Timer.periodic(Duration(milliseconds: 60000 ~/ bpm))` — it drifts audibly
within a minute.

**Assets:** two short WAVs bundled locally, `click_hi.wav` (accent) and `click_lo.wav`.
Preload both into the pool at engine init.

**Features:**
- Range 40–260 bpm, per-exercise `minTempo`/`maxTempo` clamps.
- Subdivision from the exercise (1/2/3/4/6/8 notes per beat), with an accent on beat 1.
- Visual beat indicator synced to the audio callback, not to the scheduler's intent.
- **+8 bpm** button implementing the ladder procedure, with the light-impact haptic.
- **Tempo memory:** on every change, debounce 800 ms then persist `lastTempo` to that
  exercise's `TempoRecord`. Next time the exercise appears, it opens at that tempo.
- "Mark clean at this tempo" appends a `TempoPoint{clean: true}` — this is the single
  data point that powers the tempo-progression chart, so surface it prominently.
- Mute toggle that keeps the visual pulse (for late-night practice).
- Audio session config so the click ducks nothing and survives the screen locking.

If the metronome proves flaky on target hardware, ship the feature behind a preference
flag and keep the tempo *tracking* (stepper + memory + charts) regardless — the tracking
is the part analytics depend on.

---

## 13. History & day rollover

`history_service.dart` runs on every app launch and on resume:

```
last = profile.lastOpenedOn
for each date in (last .. today - 1):
    if a DayRecord exists -> leave it
    else if date is a rest weekday -> write DayRecord(status: rest)
    else -> write DayRecord(
              plannedMinutes: the routine that was generated (or the ideal for the
                              milestone at that time),
              completedMinutes: 0,
              status: missed)
profile.lastOpenedOn = today
```

This is the explicit requirement that **empty days are recorded and counted**. A missed
day is a data point, not an absence of one. The history screen shows a month calendar
heat map where missed days are visibly rendered (dim outline), not blank.

Guard against clock changes: ignore backfill if the computed gap is negative or exceeds
365 days, and log a `meta.clockAnomaly` flag instead.

---

## 14. Analytics

`analytics_service.dart` — pure functions over `List<DayRecord>` + `List<SessionRecord>`
+ `Map<String,TempoRecord>`. No UI imports. Fully unit tested.

### 14.1 Filters

Range: 7 / 30 / 90 days, this month, all time, custom. Category multi-select.
Technique-tag multi-select. Exercise picker for the tempo chart. Filters live in a
`AnalyticsFilter` state object and are shared by every card on the screen.

### 14.2 Metrics

| Metric | Definition |
|---|---|
| Total minutes | Σ `completedMinutes` in range |
| Sessions | count of non-abandoned + abandoned, shown separately |
| Practice days | days with `completedMinutes > 0` |
| Missed days | `status == missed` |
| Adherence | Σ completed / Σ planned, excluding rest days, clamped 0–1 |
| Consistency | practiceDays / expectedDays, where expectedDays = range minus rest days |
| Current streak | consecutive days back from today with ≥ 60 % of planned minutes; rest days pass through without breaking or extending |
| Longest streak | max over all history |
| Category split | minutes per `PracticeCategory`, as a donut + ranked list |
| Tempo progression | per exercise, `TempoPoint` line chart with clean points emphasised and a trend line; milestone unlocks marked as vertical annotations |
| Best tempos | table of `bestCleanTempo` per exercise, with delta over the selected range |
| Time of day | histogram of session start hours — surfaces whether the user practises better in the morning |
| Weekday pattern | average minutes per weekday, to expose the day they keep skipping |

### 14.3 Discipline score

A single 0–100 number, recomputed over a rolling 28 days:

```
A = adherence            (0..1)
C = consistency          (0..1)
P = tempoProgress        (0..1)   // mean normalised bpm gain across exercises
                                  // with >= 2 clean points; +10% gain maps to 1.0,
                                  // 0% to 0.5, -10% to 0.0; defaults to 0.5 when
                                  // there is insufficient data

score = round(100 * (0.45*A + 0.35*C + 0.20*P))
```

Grades: 90+ Exceptional · 75–89 Strong · 60–74 Steady · 45–59 Inconsistent ·
below 45 Slipping.

Weighting rationale, worth preserving in a code comment: showing up (A + C = 80 %)
matters far more than getting faster (20 %). Speed arrives in plateaus and a score that
punished flat months would be lying to the user.

Display it with `CoreAnimatedNumber` and a ring, plus one plain-English line explaining
the biggest single lever ("You hit your minutes on the days you practise — the gap is
the four days you skipped").

### 14.4 Charts

`fl_chart`: line (tempo progression, minutes over time), bar (weekday, category),
donut (category split). Custom-painted calendar heat map. All charts respect
`reduceMotion` and animate their draw-in only on first mount.

---

## 15. PDF export

`pdf_report_builder.dart` builds an A4 document; `printing` presents the share/save
sheet. No network, no server rendering.

**Pages:**

1. **Cover** — app name, user's start date, range covered, the discipline score ring
   drawn as vector, and the headline sentence (§15.1).
2. **Summary** — minutes / sessions / practice days / missed days / streaks, plus the
   minutes-in-days-and-months breakdown the user asked for.
3. **Category breakdown** — table + bar chart of minutes per category.
4. **Tempo progress** — table of exercises with start bpm, best clean bpm, delta, and a
   sparkline per row.
5. **Consistency** — calendar heat map for the range, missed days visible.
6. **Milestones** — dated list of course parts unlocked.

Charts are re-drawn with `pdf`'s own graphics primitives (a small shared
`ChartSpec` → both `fl_chart` and PDF renderers) rather than screenshotting widgets,
so the output is vector and legible at any zoom.

Embed a Unicode-capable font in the PDF explicitly — the default Helvetica will not
render non-Latin text if the UI is ever localised.

### 15.1 Sentence templates — `report_copy.dart`

Deterministic template selection based on the metrics, all values interpolated:

```
headline (choose by adherence + streak):
  A >= .85 && streak >= 21 ->
    "Over {days} days you've logged {sessions} sessions and {minutes} minutes —
     roughly {hours} hours — and you haven't missed more than {maxGap} days in a row."
  A >= .70 ->
    "In {months} months of practice you've put in {hours} hours across {practiceDays}
     days, hitting {adherencePct}% of the minutes you planned."
  A >= .50 ->
    "You've practised on {practiceDays} of {totalDays} days for a total of {hours}
     hours. The minutes are there when you show up — showing up is the gap."
  else ->
    "{practiceDays} practice days out of {totalDays}, {hours} hours total. Consistency
     is the lever here, not session length."

duration line (always):
  "{minutes} minutes = {hours}h {remMinutes}m, spread over {practiceDays} days
   ({avgPerDay} min/day average){monthsClause}"
  monthsClause included only when the range spans >= 60 days:
   " across {months} months"

progress line (only when >= 3 exercises have 2+ clean tempo points):
  "Your tracked tempos moved {avgDeltaPct}% on average; the biggest gain was
   {exerciseLabel}, from {startBpm} to {bestBpm} bpm."

closing line (by score band): one sentence, factual, no cheerleading.
```

Pluralisation and zero-cases handled explicitly — never emit "1 days" or
"0 minutes across 0 months".

---

## 16. Preferences

Screen: `/settings`. Persisted in the `preferences` box, applied reactively app-wide.

| Group | Setting | Values | Default |
|---|---|---|---|
| Practice | Session length | 20–150 min | per milestone |
| | Rest weekdays | multi-select | none |
| | Rest between blocks | 0–120 s | 45 |
| | Rest between items | 0–60 s | 0 |
| | Default timer mode | quick / detailed | detailed |
| Appearance | Accent theme | Crimson / Teal / Green | Crimson |
| | Text scale | 0.85–1.35 | 1.0 |
| | Tab density | compact / regular / large (drives `CoreTabs` padding and min width) | regular |
| | Card density | compact / regular | regular |
| | Reduce motion | on / off / follow system | follow system |
| | Reduce blur | on / off | off |
| Home layout | Widget order | drag-to-reorder list of home cards: Today's routine, Streak, Score, Next milestone, Quick timer, Recent sessions | as listed |
| | Widget visibility | per-card toggle | all visible |
| Metronome | Enabled | on / off | on |
| | Sound | click / woodblock / beep | click |
| | Accent beat one | on / off | on |
| | Haptic on beat | on / off | off |
| Data | Export PDF | action | — |
| | Export raw JSON backup | action | — |
| | Import JSON backup | action with confirm | — |
| | Reset progress | destructive, double-confirm | — |

Home widget order is stored as `List<String>` of card ids and rendered through a
`ReorderableListView` in edit mode (§5.2 lift animation).

---

## 17. Routing

```dart
final router = GoRouter(
  initialLocation: '/home',
  redirect: (ctx, state) {
    final onboarded = ref.read(profileProvider).onboardingComplete;
    if (!onboarded && !state.uri.path.startsWith('/onboarding')) return '/onboarding';
    if (onboarded && state.uri.path.startsWith('/onboarding')) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/onboarding', builder: ...),          // full-screen, no shell
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => AppShell(shell: shell), // glass nav bar
      branches: [
        // 0 Home
        StatefulShellBranch(routes: [GoRoute(path: '/home', routes: [
          GoRoute(path: 'progress', builder: ...),        // milestone screen
        ])]),
        // 1 Routine
        StatefulShellBranch(routes: [GoRoute(path: '/routine', routes: [
          GoRoute(path: 'session', builder: ...),         // pushed over shell
        ])]),
        // 2 Library
        StatefulShellBranch(routes: [GoRoute(path: '/library', routes: [
          GoRoute(path: 'exercise/:id', builder: ...),
        ])]),
        // 3 Analytics
        StatefulShellBranch(routes: [GoRoute(path: '/analytics', routes: [
          GoRoute(path: 'history', builder: ...),
        ])]),
        // 4 Settings
        StatefulShellBranch(routes: [GoRoute(path: '/settings')]),
      ],
    ),
  ],
);
```

The session route is pushed **above** the shell (nav bar hidden) and blocks system-back
with a confirm sheet while a timer is running. Custom transitions from
`page_transitions.dart`: shared-axis X between shell branches, shared-axis Z for
push/pop within a branch, and a vertical cover transition for the session.

---

## 18. Screens

### 18.1 Onboarding — `/onboarding`

Four steps, horizontally paged with parallax between them (background glow moves at
0.4× page velocity).

1. **Welcome** — one screen, what the app does, one line about needing the book to hand.
2. **How far have you watched?** — a vertical list of the ten milestones, each a
   `CoreListTile` with part name and a one-line description of what it covers. Selecting
   one expands it inline (spring height animation) to show which categories it unlocks.
   Default selection: none — the user must choose.
3. **How long can you practise?** — `CoreSlider` 20–150 min, pre-set to the suggested
   value for the chosen milestone, with the suggestion marked on the track. Below it, a
   live preview of the resulting block split that **re-animates as the slider moves**
   (bars resize with `Motion.gentle`) — this is the moment that sells the app.
   Rest-day picker underneath.
4. **Your first routine** — the generated plan, blocks staggering in, with a primary
   "Start practising" button.

### 18.2 Home — `/home`

Reorderable cards (§16):

- **Today** — date, planned minutes, block chips, progress arc if partially done,
  primary `Start session` button. This is the "quick access to the routine" requirement;
  it is the first thing on the screen.
- **Streak** — current + longest, flame-free minimal design, with the week's day dots.
- **Discipline score** — ring + grade + the one-line lever sentence.
- **Next milestone** — what's locked next, and a "Mark as watched" entry point.
- **Quick timer** — a free-standing timer independent of the routine, for ad-hoc work.
- **Recent sessions** — last three, tap to open in history.

### 18.3 Routine — `/routine`

Today's plan in full: blocks as expandable cards showing their items, minutes, target
tempo, procedure and book reference. Actions: `Start`, `Reshuffle`, `Adjust length`
(opens a sheet with the slider and live preview), and a week strip at the top to inspect
past days' plans (read-only) and tomorrow's (regenerates on the day, labelled as
provisional).

### 18.4 Session — `/routine/session`

Full-bleed, nav bar hidden, glow background. Top: block name + item counter.
Centre: `CoreProgressRing` with the remaining time in tabular mono, the exercise label,
variant label and focus note. Below: metronome dial with bpm, subdivision, `+8`,
mute, and the `Mark clean` toggle. Bottom bar: pause, skip, +30 s, end.

A thin segmented progress rail along the very top shows all blocks and fills as the
session advances — the user should always know how much is left without doing maths.

Swipe up on the HUD reveals the instruction sheet (§18.5) without pausing the timer.

### 18.5 Library — `/library` and `/library/exercise/:id`

Library: parts as sections (`CoreSectionHeader`), exercises as cards showing category
dot, label, title, difficulty pips, tags, and a lock state. Filter chips by category and
tag; search by label/title.

Exercise detail:
- Header: label, title, category, tags, book reference pill.
- **Variants** — `CoreTabs` at every count: Example 1's four parts render fitted,
  Example 8's six parts fitted, Example 9's developments and Example 11's eighteen
  fragments render scrollable with short labels and the index-jump sheet. Selecting a
  variant swaps the detail panel with a shared-axis Z transition, and the panel is
  horizontally swipeable so the tabs and content stay in sync. Today's scheduled variant
  carries the `marked` dot.
- **Practice panel** — target tempo, subdivision, procedure, estimated minutes, and a
  `Practice now` button that starts a one-item ad-hoc session.
- **Tempo history** — sparkline of this exercise's clean points, best tempo badge.
- **Instructions & tips** — collapsed by default, opened via a small `Tips` button that
  presents a `CoreSheet`. Explicitly **not** always-on-screen, per the requirement.
  Content is paraphrased procedure guidance plus the book page pointer.

### 18.6 Analytics — `/analytics`, History — `/analytics/history`

Analytics: sticky filter bar, then score card, totals row, minutes-over-time line,
category donut, weekday bars, tempo-progression chart with an exercise picker, best-tempo
table, and an `Export PDF` button in the app bar.

History: month calendar heat map with missed days visible; tapping a day opens a sheet
with that day's plan, what was completed, per-item tempos and any note. Month paging
with a horizontal spring transition.

### 18.7 Milestone — `/home/progress`

Vertical timeline of the ten parts with unlocked / next / locked states, each showing
what it contributes to the routine. The advance flow from §9 lives here.

---

## 19. Riverpod graph

All providers hand-written (no generator). Keep them small and layered.

```
// infrastructure
hiveStoreProvider            Provider<HiveStore>              (overridden in bootstrap)
clockProvider                Provider<Clock>                  (injectable for tests)

// persisted state
profileProvider              NotifierProvider<ProfileNotifier, UserProfile>
preferencesProvider          NotifierProvider<PrefsNotifier, Preferences>

// curriculum (static)
courseProvider               Provider<List<CoursePart>>       (from course_seed)
unlockedPartsProvider        Provider<List<CoursePart>>       (course ∩ milestone)
exerciseByIdProvider         Provider.family<Exercise?, String>

// routine
rotationCursorsProvider      NotifierProvider<CursorsNotifier, Map<PracticeCategory, RotationCursor>>
todayRoutineProvider         AsyncNotifierProvider<RoutineNotifier, RoutineDay>
routineForDateProvider       FutureProvider.family<RoutineDay?, DateTime>

// session
sessionProvider              NotifierProvider<SessionNotifier, SessionState?>
metronomeProvider            NotifierProvider<MetronomeNotifier, MetronomeState>

// history & analytics
dayRecordsProvider           AsyncNotifierProvider<DaysNotifier, List<DayRecord>>
sessionRecordsProvider       AsyncNotifierProvider<SessionsNotifier, List<SessionRecord>>
tempoRecordsProvider         AsyncNotifierProvider<TemposNotifier, Map<String,TempoRecord>>
analyticsFilterProvider      NotifierProvider<FilterNotifier, AnalyticsFilter>
analyticsProvider            Provider<AnalyticsSummary>       (pure, derived)
disciplineScoreProvider      Provider<DisciplineScore>
```

**Rules:** UI never writes to Hive directly. Controllers own persistence. Derived data
is a `Provider`, never duplicated state. Hooks (`useAnimationController`,
`useTextEditingController`, `useMemoized`, `useEffect`) handle all local widget state —
no `StatefulWidget` outside `core/widgets` unless a `TickerProvider` genuinely demands
it.

---

## 20. Testing

| Layer | Tests |
|---|---|
| Seed | ids unique, references resolve, tempo ranges valid, milestones contiguous |
| Routine generator | weights sum correctly at every milestone; caps respected; 20 and 150 minute extremes produce valid plans; cursors advance and wrap; same seed → same plan; partially-completed days are not regenerated; rest days produce empty plans |
| History rollover | gaps backfill as missed; rest weekdays backfill as rest; DST and timezone shifts; negative/absurd clock deltas ignored |
| Analytics | adherence with zero planned minutes; streak across rest days; score bounds 0–100; tempo progress with insufficient data defaults to 0.5 |
| Report copy | every template branch renders; pluralisation; zero/one edge cases |
| Widgets | `CoreTabs` golden tests at 320/390/430/768 dp × {2, 5, 8, 12, 18, 24} items × three densities — assert no overflow, no overlap, no wrap, monotonic tab origins, correct mode selection, and that the selected tab is centred (or end-clamped) after selection |
| Metronome | scheduler beat timestamps stay within ±5 ms of ideal over 120 s at 200 bpm |

---

## 21. Build phases

Each phase ends compiling, running, and testable. Do not start a phase before the
previous one is green.

**Phase 1 — Foundation.** Project scaffold, dependencies, `bootstrap.dart`, Hive init,
theme tokens, motion tokens, `SpringCurve`, `MotionScope`, `CorePressable`, `CoreText`,
`CoreButton`, `CoreCard`, `CoreScaffold`. Deliverable: a themed empty app with one
demo screen proving the press physics feel right. **Do not proceed until the press
animation feels correct on a device** — everything else inherits it.

**Phase 2 — Core widget library.** All remaining `core_*` widgets, with `CoreTabs` and
`CoreSegmentedGrid` built to spec and golden-tested. Deliverable: a hidden
`/debug/gallery` route showing every widget in every state.

**Phase 3 — Models & seed.** All pure Dart models with JSON round-trip tests. Full
`course_seed.dart` for all nine parts. Hive stores and migration scaffold.

**Phase 4 — Routing & shell.** go_router, shell with glass nav bar, custom transitions,
placeholder screens, onboarding redirect guard.

**Phase 5 — Onboarding & progression.** Onboarding flow including the live block-split
preview, profile persistence, milestone screen, unlock/advance flow.

**Phase 6 — Routine engine.** `routine_service.dart` plus its full test suite, then the
routine screen and the Today card on Home. This is the highest-risk logic — write the
tests first.

**Phase 7 — Session & metronome.** Timer controller, quick and detailed modes, session
screen, metronome engine, tempo persistence, session records.

**Phase 8 — History.** Day rollover and backfill, history screen, calendar heat map,
day-detail sheet.

**Phase 9 — Analytics.** Analytics service and tests, filters, charts, discipline score.

**Phase 10 — PDF export.** Chart spec abstraction, report builder, copy templates.

**Phase 11 — Preferences.** Settings screen, text/tab/card density plumbing, home
reordering, accent theme switching, backup export/import.

**Phase 12 — Polish.** Motion audit against §5.2 on a physical device, frame profiling
with blur budget check, empty and error states, accessibility labels, app icon and
splash.

---

## 22. Decisions left open

Flag these to the user rather than guessing:

1. **UI language.** Plan assumes English LTR with directional layout so Persian RTL can
   be added later. Confirm before Phase 4 — retrofitting is cheap now, expensive later.
2. **Metronome scope.** Ships in Phase 7. If it slips, tempo *tracking* still ships and
   analytics are unaffected.
3. **Notifications.** Not in scope (a daily practice reminder would need
   `flutter_local_notifications`). Add later as an isolated feature if wanted.
4. **Tablet layout.** Phone-first. Above 900 dp, the Library and Analytics screens
   should adopt a two-pane master/detail — spec it in Phase 12 if needed.
5. **Free-play tracking.** Currently a timed block with no exercise. Consider letting
   the user tag it ("wrote a riff", "learned a song") for richer analytics.
