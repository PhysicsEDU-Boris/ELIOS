# ELIO Physics Lab — Flutter/Riverpod Integration Plan

**For:** AI coding agent / future you
**Target:** Your existing Flutter app (Riverpod + Firestore e-learning shell)
**Lives at:** `LearningSection.simulations` tab, alongside Guides / Video Lessons / Quiz
**Status:** Phase 1 (Torque) has working code from the previous pass — this doc
migrates it to Riverpod and specs out Phases 2–11 the same way.

---

## 0. How to use this document

Same rule as before: every numbered requirement is mandatory unless marked
`(optional)`. Work phase by phase, in order — each phase after Phase 0
follows the identical Engine → State → Notifier → Renderer → Wiring recipe,
so once Phase 2 (Density) is done, Phases 3–7 are close to mechanical.

Do not skip Phase 0. It extracts the shared widgets that every module reuses
— skipping it means every module reinvents its own formula box / slider /
warning banner, which is exactly the drift that caused the overlap bugs in
the original HTML build.

---

## Phase 0 — Shared Foundations

### 0.1 Riverpod pattern (applies to every module)

Each module gets **one immutable state class** + **one Notifier**. The state
class _is_ the engine — it holds the inputs and exposes pure computed
getters, mirroring the `TorqueEngine` you already have but immutable, so
Riverpod can diff it cheaply and `ref.watch` rebuilds only what changed.

```dart
// lib/physics/density/density_state.dart
class DensityState {
  final double massGrams;      // m, 100–2000 g
  final double volumeCm3;      // V, 100–1000 cm³

  const DensityState({this.massGrams = 1250, this.volumeCm3 = 500});

  double get density => massGrams / volumeCm3;

  WasteCategory get classification {
    final rho = density;
    if (rho >= 0.9 && rho <= 1.4) return WasteCategory.plastic;
    if (rho >= 2.4 && rho <= 2.6) return WasteCategory.glass;
    if (rho >= 2.7) return WasteCategory.metal;
    return WasteCategory.outOfRange;
  }

  DensityState copyWith({double? massGrams, double? volumeCm3}) =>
      DensityState(
        massGrams: massGrams ?? this.massGrams,
        volumeCm3: volumeCm3 ?? this.volumeCm3,
      );
}

// lib/physics/density/density_notifier.dart
class DensityNotifier extends Notifier<DensityState> {
  @override
  DensityState build() => const DensityState();

  void setMass(double v) =>
      state = state.copyWith(massGrams: v.clamp(100, 2000));

  void setVolume(double v) =>
      state = state.copyWith(volumeCm3: v.clamp(100, 1000));
}

final densityProvider =
    NotifierProvider<DensityNotifier, DensityState>(DensityNotifier.new);
```

Widgets become `ConsumerWidget`/`ConsumerStatefulWidget`:

```dart
final density = ref.watch(densityProvider);
final notifier = ref.read(densityProvider.notifier);
// density.density, density.classification are pure getters — no rebuild
// logic scattered across setState calls.
```

**Migrating Torque:** fold `TorqueEngine`'s mutable fields into an immutable
`TorqueState` the same way, replace the `StatefulWidget`'s local `_engine` +
`setState` calls with `TorqueNotifier` + `ref.watch`/`ref.read`. The
`TorquePainter` and drag-conversion math don't change — they just read from
`TorqueState` instead of `TorqueEngine`.

### 0.2 Shared widgets to extract (build once, reuse in every module)

Pull these out of `torque_simulation_page.dart` into
`lib/screens/tabs/elearning/simulations/widgets/`:

| Widget            | Purpose                                                                                 | Source to extract from             |
| ----------------- | --------------------------------------------------------------------------------------- | ---------------------------------- |
| `SimModuleHeader` | tag chip + title + subtitle                                                             | `_buildHeader()`                   |
| `FormulaBox`      | dark gradient card, symbolic + substituted formula                                      | `_buildFormulaBox()`               |
| `SimCanvasFrame`  | rounded frame + note badge + optional risk badge, both `Positioned` with reserved space | `_buildSimulationCard()`           |
| `LabeledSlider`   | label + mono value + themed `Slider`                                                    | `_LabeledSlider`                   |
| `CalcBox`         | light-green live-calculation card with status row                                       | `_buildCalcBox()`                  |
| `ThresholdBanner` | animated warning banner, `Semantics(liveRegion: true)`                                  | `_buildWarningBanner()`            |
| `DeepExplainCard` | `ExpansionTile` with 📖 icon, bullet list, highlighted example box                      | `_buildDeepExplain()`              |
| `MetaChip`        | small icon+label pill                                                                   | already in `simulations_page.dart` |

Each takes plain data in (strings, colors, a `bool visible`) — **no engine
types in the widget signatures** — so they're reusable across all 7 modules
without import coupling.

### 0.3 Design tokens

Extract the repeated `Color(0xFF...)` consts from `simulations_page.dart` /
`torque_simulation_page.dart` into `lib/theme/elio_learning_colors.dart` and
import everywhere instead of redeclaring `_primary` etc. per file. Keep the
same values you already use elsewhere in the app (`_primary = 0xFF00694C`,
etc.) so the physics lab is visually indistinguishable from Guides/Quiz.

### 0.4 Folder structure

```
lib/
  physics/
    density/     density_state.dart, density_notifier.dart
    heat/        heat_state.dart, heat_notifier.dart
    torque/      torque_state.dart, torque_notifier.dart   (migrated)
    work_energy/ ...
    kinematics/  ...
    pwm/         ...
    power/       ...
    waste_deep_dive/
      porosity_state.dart, hooke_state.dart, nir_state.dart,
      eddy_current (illustrative, no state needed),
      vapor_pressure_state.dart, incinerator_state.dart,
      radiation_shielding_state.dart
    quiz/        physics_quiz_state.dart, physics_quiz_notifier.dart
  screens/tabs/elearning/simulations/
    simulations_page.dart          (module list — already built)
    torque_simulation_page.dart    (migrated to Riverpod)
    density_simulation_page.dart
    heat_simulation_page.dart
    work_energy_simulation_page.dart
    kinematics_simulation_page.dart
    pwm_simulation_page.dart
    power_simulation_page.dart
    waste_deep_dive_page.dart
    physics_quiz_page.dart
    widgets/    (Phase 0.2 shared widgets)
    painters/   (one CustomPainter per module, e.g. density_painter.dart)
```

### 0.5 Acceptance for Phase 0

- [ ] `TorqueEngine` migrated to `TorqueState` + `TorqueNotifier`; existing
      drag/slider behavior unchanged.
- [ ] All 8 shared widgets extracted and Torque page rebuilt on top of them
      with zero visual difference.
- [ ] Colors centralized in `elio_learning_colors.dart`.

---

## Phase 2 — Module A: Density & Waste Classification

**Formula:** `ρ = m / V` · **Inputs:** m [100–2000 g], V [100–1000 cm³]

### State

```dart
enum WasteCategory { plastic, glass, metal, outOfRange }

class DensityState {
  final double massGrams;
  final double volumeCm3;
  double get density => massGrams / volumeCm3;
  WasteCategory get classification { /* ranges: plastic 0.9–1.4,
      glass 2.4–2.6, metal ≥2.7 — see Phase 0.1 example */ }
}
```

### Notifier

`setMass(double)`, `setVolume(double)` — clamp to input ranges.

### Renderer (`density_simulation_page.dart` + `density_painter.dart`)

- Two bottles side by side (reference @ V=500/ρ=2.5, active @ current
  state), bottle height scales with volume, fill color/opacity scales with
  density — port the SVG bottle logic from the HTML version 1:1 into a
  `CustomPainter`.
- **Real drag-and-drop classification** (spec upgrade over v1's tap-only
  bins): wrap the three bin cards in `Draggable`/`DragTarget`, or simpler —
  keep tap-to-sort but add a physics-based _shake_ rejection animation
  (`AnimatedBuilder` + `Tween<Offset>`) when the tapped bin doesn't match
  `classification`.
- Bin highlight follows `classification` reactively via `ref.watch`.
- `FormulaBox`, `CalcBox`, `ThresholdBanner` (repurposed as "out of range"
  notice), `DeepExplainCard` — all from Phase 0.2.

### Content (Bahasa Indonesia — reuse verbatim from your v1 build)

- Tooltip: why HDPE floats vs PET sinks in a water-separation tank (real
  industrial recycling technique).
- Comprehension check before unlocking the module's quiz question.
- Deep-explain: ρ = m/V, water reference (1.0 g/cm³), plastic/glass/metal
  ranges, ELIO's load-cell + 3D camera application, "press bottles first"
  efficiency note.

### Unit tests

- Mid-range: m=1250, V=500 → ρ=2.50 (glass)
- Boundaries: ρ=0.9, 1.4, 2.4, 2.6, 2.7 exactly
- Extremes: m=100/V=1000 (ρ=0.1, out of range), m=2000/V=100 (ρ=20, metal)
- Distractor: `V/m` (swapped) must differ from `m/V` whenever m≠V

### Acceptance

- [ ] Drag/tap classification never silently fails to update the bin
      highlight.
- [ ] Bottle SVG-equivalent painter has no clipped/overlapping labels at
      360px and tablet widths.

---

## Phase 3 — Module B: Heat & Composting Thermodynamics

**Formula:** `Q = m·c·ΔT`, c = 4000 J/kg°C (fixed) · **Inputs:** m [1–5 kg],
ΔT [5–40 °C]

### State

```dart
enum CompostPhase { mesophilic, thermophilic, overheated }

class HeatState {
  final double massKg;
  final double deltaT;
  static const c = 4000.0;
  static const t0 = 25.0;

  double get heatJoules => massKg * c * deltaT;
  double get finalTemp => t0 + deltaT;
  CompostPhase get phase {
    final t = finalTemp;
    if (t > 60) return CompostPhase.overheated;
    if (t >= 55) return CompostPhase.thermophilic;
    return CompostPhase.mesophilic;
  }
}
```

Porosity is a **separate, linked** piece of state — see the cross-module
link requirement below.

### Cross-module link (spec upgrade over v1)

v1 only showed the anaerobic/methane warning inside the Waste Physics tab.
Wire it into Module B directly: add `porosityPercent` to `HeatState` (or
watch a shared `porosityProvider` if you want Phase 8's organic-card slider
and this module's warning to literally share one value — recommended, since
it's the same physical quantity). When `porosityPercent < 25 && finalTemp >
55`, show a distinct **"anaerob — risiko metana"** banner in Module B, not
just text.

### Renderer

- Compost pile with animated particles (speed scales with `finalTemp`,
  color shifts warmer as phase progresses) — `AnimationController` +
  `CustomPainter`, particles bounce inside pile bounds.
- Thermometer widget (custom painted bar + bulb) reflecting `finalTemp` on
  a 25–65°C scale.
- `ThresholdBanner` fires at thermophilic (55–60°C) and overheated (>60°C)
  boundaries, ±0.01 tolerance in tests.
- **Pause-when-offscreen**: wrap the particle `AnimationController` so it
  stops ticking when the module page isn't the active route — use
  `TickerProviderStateMixin` + check `ModalRoute.of(context)?.isCurrent`,
  or simplest: only start the controller in `didPushNext`/resume via
  `RouteAware`. This matters more in Flutter than the web build since
  off-screen widgets can still be kept alive in an `IndexedStack`.

### Content

- Mesophilic/thermophilic/maturation phase descriptions (Bahasa Indonesia,
  port from v1's `deep-explain`).
- ELIO application: IR sensor reading, "balik kompos" prompt, dry-twig
  porosity fix suggestion when anaerobic.

### Unit tests

- Mid-range: m=2, ΔT=20 → Q=160,000 J, finalTemp=45°C, mesophilic
- Boundary: finalTemp=55°C exactly → thermophilic; 60.01°C → overheated
- Porosity<25 & finalTemp>55 → anaerobic banner fires

---

## Phase 4 — Module D: Work & Gravitational Potential Energy

**Formula:** `W = Ep = m·g·h`, g=10 m/s² · **Inputs:** h [0.2–1.5 m],
m [0.5–5 kg]

### State

```dart
class WorkEnergyState {
  final double heightM;
  final double massKg;
  static const g = 10.0;
  static const batteryCapacityJ = 50000.0; // shared constant, see below

  double get workJoules => massKg * g * heightM;
  double get batteryPercentRemaining =>
      (100 - (workJoules / batteryCapacityJ) * 100).clamp(0, 100);
}
```

### Shared-constant requirement (spec upgrade over v1)

The original spec calls for tying Module A (organic waste is heavier per
volume) and Module D (heavier loads cost more energy) together with **one
literal shared value** instead of two independently-typed numbers in prose.
Define:

```dart
// lib/physics/shared_constants.dart
const double kTypicalOrganicLoadKg = 3.5; // used in both Module A and D copy
const double kBatteryCapacityJ = 50000.0; // used in D and G
```

Reference `kTypicalOrganicLoadKg` in both modules' example text so the
numbers can never drift out of sync again.

### Renderer

- Vertical rail + lifter that moves proportionally to `heightM` (0.2m→bottom,
  1.5m→top), newspaper stack payload scales visually with `massKg`.
- Work bar + battery bar, both simple painted gauges or
  `LinearProgressIndicator` dressed up with the shared design tokens.
- Height ruler with tick marks (0, 0.3, 0.6, 0.9, 1.2, 1.5 m).

### Content

- Ties to Module A via `kTypicalOrganicLoadKg` — "mengangkat organik
  setinggi plastik butuh usaha lebih besar" using the _same_ number in both
  places.
- Battery math: 50,000 J capacity, worked example lift counts.

### Unit tests

- Mid-range: m=1.5, h=0.8 → W=12.0 J, battery 96.0%
- Extremes: m=5, h=1.5 → W=75 J; m=0.5, h=0.2 → W=1.0 J

---

## Phase 5 — Module E: Kinematics (Constant Velocity + optional GLBB)

**Formula:** `v = s/t` · **Inputs:** s [2–20 m], v [0.1–1.0 m/s]

### State

```dart
class KinematicsState {
  final double distanceM;
  final double velocityMs;
  final double robotX;     // simulation clock output, meters traveled
  final double elapsedS;
  final bool isRunning;

  double get predictedTimeS => distanceM / velocityMs;

  KinematicsState tick(double dtSeconds, {double animSpeedFactor = 3}) {
    if (!isRunning) return this;
    final nextX = (robotX + velocityMs * dtSeconds * animSpeedFactor)
        .clamp(0, distanceM);
    final nextT = elapsedS + dtSeconds * animSpeedFactor;
    final arrived = nextX >= distanceM;
    return copyWith(
      robotX: nextX,
      elapsedS: nextT,
      isRunning: !arrived,
    );
  }
}
```

Per spec §4 Module E: the simulation clock (`tick`) lives in the **state**,
not the widget — this is the one place v1 got it wrong (computed
`robotX += v*dt*animSpeed` directly inside the renderer's `animate()`).
Keep it that way here: the Notifier owns `tick()`, the widget's
`Ticker`/`AnimationController` just calls `notifier.tick(dt)` every frame
and reads the result.

### Notifier

`setDistance`, `setVelocity`, `run()` (resets `robotX`/`elapsedS`, sets
`isRunning=true`), `tick(dt)`.

### Renderer

- Top-down "camera feed" canvas: grid background, dashed track, start
  marker, target marker at `distanceM`, robot sprite at `robotX`, live timer
  HUD.
- Drive the `tick()` calls from a `Ticker` in the widget's `State`, stop the
  ticker when `!isRunning` or when the route isn't current (same
  pause-when-offscreen rule as Phase 3).

### Content

- GLB vs GLBB distinction, GLBB **(optional)** toggle behind an expandable
  "bonus" section using `s = v₀t + ½at²` — gate it so it doesn't complicate
  the core lesson, per spec.

### Unit tests

- Mid-range: s=12, v=0.4 → t=30s
- `tick()` never overshoots `distanceM` regardless of large `dt` (clamp
  test with dt=5s)

---

## Phase 6 — Module F: PWM & Effective Motor Voltage

**Formula:** `V_avg = D·V_max`, V_max = 12V (fixed) · **Inputs:**
D [0–100%]

### State

```dart
class PwmState {
  final double dutyPercent;
  static const vMax = 12.0;

  double get averageVoltage => (dutyPercent / 100) * vMax;
  /// Linear approximation — NOT physically exact (real RPM vs duty isn't
  /// linear once load torque is considered). Label this in the UI, don't
  /// present it as measured fact.
  int get approxRpm => ((dutyPercent / 100) * 300).round();
}
```

### Renderer

- Animated square wave (`CustomPainter` + `Ticker`), period fixed, high
  portion scales with `dutyPercent`.
- Spinning wheel (rotation speed scales with `dutyPercent`) with RPM
  readout, explicitly labeled "Perkiraan (aproksimasi linear)" per spec's
  accuracy requirement.
- Duty-cycle indicator bar under the oscilloscope.

### Content

- Why PWM beats a linear voltage divider (switching loss vs resistive
  heat loss) — port v1's explanation.
- Caveat sentence: average voltage drop ≠ average current drop unless load
  is purely resistive — make sure the "40% current drop at 60% duty" claim
  in the copy carries this caveat explicitly (spec accuracy requirement).

### Unit tests

- D=60 → V_avg=7.2V, RPM≈180
- D=0 → V_avg=0; D=100 → V_avg=12.0

---

## Phase 7 — Module G: Power & Battery Budget

**Formula:** `P = V·I` (fixed presets), `E = P·t` · **Inputs:** toggles
(camera 10W, drive 36W, arm 18W), t [1–600 s]

### State

```dart
class PowerBudgetState {
  final bool cameraOn;
  final bool driveOn;
  final bool armOn;
  final double timeS;

  // reuse kBatteryCapacityJ from Phase 4's shared_constants.dart
  double get totalPowerW =>
      (cameraOn ? 10 : 0) + (driveOn ? 36 : 0) + (armOn ? 18 : 0);
  double get energyJoules => totalPowerW * timeS;
  double get remainingPercent =>
      (100 - (energyJoules / kBatteryCapacityJ) * 100).clamp(0, 100);
  double? get estimatedRuntimeS =>
      totalPowerW > 0 ? kBatteryCapacityJ / totalPowerW : null; // null = ∞
}
```

### Renderer

- Three toggle rows (camera/drive/arm) — reuse Material `Switch` or a
  themed custom toggle matching `_LevelChip`/`_InfoChip` visual language.
- Battery bar with percent label.
- **Scenario picker (recommended per spec):** three preset chips — "Mode
  Sortir" (arm+camera, drive off), "Mode Jelajah" (drive+camera, arm off),
  "Idle" (camera only) — each just calls the three toggle setters at once.

### Content

- Worked examples: camera-only runtime (~5000s), everything-on runtime
  (~781s), ELIO's actual power-saving behavior (drive off while sorting,
  camera off while driving).

### Unit tests

- All off → totalPowerW=0, estimatedRuntimeS=null (∞ case must not crash
  the UI — render "∞" not a NaN)
- Camera+drive+arm → 64W, t=600 → E=38,400 J

---

## Phase 8 — Waste Physics Deep-Dive (3 expandable cards)

Same Engine/State split, one sub-state per simulation inside each card.
Keep the three-card structure (Organic / Inorganic / B3) as
`ExpansionTile`s or your existing expandable-card widget if you already
have one elsewhere in the app.

### 8.1 Organic card — `PorosityState`

- `porosityPercent` [10–80] — **this is the same value Module B's cross-link
  reads**; make it one shared provider (`porosityProvider`) rather than two
  separate pieces of state, per Phase 3's cross-module requirement.
- Anaerobic threshold <25%, oxygen-diffusion arrow density/speed scales
  with porosity.
- Content: Fick's Law flux note, conduction `Q/t = k·A·ΔT/L`, Jurin's Law
  capillarity — keep as brief "Fisika Kunci" bullets, not full derivations.

### 8.2 Inorganic card — three sub-simulations

- **`HookeSpringState`**: `F = k·x`, k=50 N/m, x [2–20 cm] — spring coil
  painter compresses, force readout.
- **`NirReflectanceState`**: selectable plastic (PET 1660nm, HDPE 1730nm,
  PP 1410nm) → Gaussian reflectance curve, selected curve highlighted.
  ⚠ **verify these wavelengths against a real NIR sorting reference before
  shipping** — spec flags them as stated-as-fact to learners, same
  requirement carries over.
- **Eddy current**: illustrative only, no state needed — static/animated
  diagram, magnet attracts iron, eddy-current coil repels aluminum.

### 8.3 B3 (hazardous) card — three sub-simulations

- **`VaporPressureState`**: Clausius-Clapeyron _approximation_ — label
  clearly as simplified/qualitative in the UI copy, not a literal P–T
  curve (spec requirement, v1's exponential constant was arbitrary).
- **`IncineratorState`**: temp slider [200–1200°C], bond-destruction
  threshold at 1000°C, flame + gauge painter.
- **`RadiationShieldingState`**: `I = I₀·e^(−μx)`, shield thickness
  [0–20cm], μ*α≈5.0/μ*β≈1.5/μ_γ≈0.3 (illustrative — add the disclaimer that
  real attenuation coefficients depend on particle energy).

### Content requirement (carries over from spec §6)

Each card's closing paragraph must answer "why can't this be sorted with
the same method as the other two categories" — per-card, not just once at
the tab-level "Kesimpulan" section.

---

## Phase 9 — Physics Quiz Engine

Decide up front: **separate physics quiz from the existing waste-category
quiz** (`quiz_page.dart` currently serves `organic`/`inorganic`/`hazardous`
QuizSets from Firestore). Recommended: keep them separate — physics
formulas need per-question randomization (different numbers each attempt),
which is a different shape than your Firestore `QuizQuestion` model. Build
it as its own hardcoded quiz, matching `quiz_page.dart`'s visual language
but with local state instead of Firestore.

### State

```dart
enum QuizResult { unanswered, correct, wrong }

class PhysicsQuizQuestion {
  final String moduleId; // 'density', 'heat', 'torque', ...
  final Map<String, num> Function(Random) randomize;
  final String Function(Map<String, num>) prompt;
  final List<String> Function(Map<String, num>) options; // includes 1
      // correct + ≥2 conceptual-error distractors, not just scalar
      // multiples — see below
  final int correctIndex;
  final String Function(Map<String, num>) workedSolution;
}

class PhysicsQuizState {
  final Map<String, Map<String, num>> currentData; // per moduleId
  final Map<String, QuizResult> results;
  int get score => results.values.where((r) => r == QuizResult.correct).length;
  int get total => 7;
}
```

### Notifier

`answer(moduleId, selectedIndex)`, `resetQuestion(moduleId)`, `resetAll()`,
`randomizeAll()`. Instantiate the `PhysicsQuizState` **once at boot** via
`NotifierProvider` (not per-render) so switching tabs doesn't lose progress
— same requirement as spec §7's "persist session score across tab
switches", which Riverpod gives you for free as long as you don't
re-`.autoDispose()` the provider.

### Distractor requirement (spec upgrade — don't skip this)

At least 2 of the (recommend 4) wrong options per question must be
**conceptual-error distractors**, not arithmetic scalar multiples:

- Torque: `r·F` (forgot sin θ) — already exposed as
  `TorqueState.computeDistractorNoSinTheta()`-equivalent, wire it in here.
- Density: `V/m` (swapped m and V).
- Heat: `m + ΔT` or omitting `c` entirely.
- Work/Energy: `m·h` (forgot g).
- Kinematics: `s·v` (multiplied instead of divided).
- PWM: `V_max - D` type unit-confusion distractor.
- Power: `V+I` instead of `V·I`.

### Renderer

Reuse `quiz_page.dart`'s `_AnswerOption`/`_DifficultyChip`/result-card visual
language directly — same colors, same correct/wrong reveal animation — so
it reads as the same feature, just a different content source.

### Unit tests (per spec §9.2d)

For every module, confirm the conceptual-error distractor produces a
**different number** than the correct formula for at least one randomized
input set (guards against accidentally-identical options).

---

## Phase 10 — Progress tracking integration (optional)

If you want physics-lab progress to show up alongside your existing
`LearningProgress`/`CategoryProgress` system:

1. Add a lightweight `PhysicsProgress` extension rather than overloading
   `CategoryProgress` (which is keyed to `organic`/`inorganic`/`hazardous`
   waste categories — physics modules are a different taxonomy):
   ```dart
   class PhysicsProgress {
     final Set<String> viewedModuleIds;   // 'density', 'torque', ...
     final Map<String, int> quizBestScores; // per moduleId, out of 1
   }
   ```
2. Persist it the same way `ProgressService` does — SharedPreferences for
   guests, Firestore subcollection for signed-in users — but as its own
   doc (`users/{uid}/learning_progress/physics`) rather than cramming it
   into the existing `main` doc, so the two systems don't need to agree on
   schema.
3. Surface a small progress ring on the `SimulationsContent` header, same
   visual pattern as `_ProgressOverviewCard`.

This phase is optional — the module works standalone without it. Only do
this once Phases 2–9 are stable, since it touches shared persistence code.

---

## Phase 11 — QA / Acceptance Checklist

Run this after **every** phase, not just at the end:

### Functional

- [ ] Every slider updates state, live-calc text, and the painted canvas
      in the same frame (drag a slider end-to-end rapidly — no stale
      values).
- [ ] Every `ThresholdBanner` appears/disappears exactly at its documented
      boundary (test ±0.01).
- [ ] Switching tabs never leaves a `Ticker`/`AnimationController` running
      for a module that's no longer visible (check via Flutter DevTools'
      performance overlay — idle CPU should drop when leaving an animated
      module).
- [ ] Quiz "Coba Lagi" always re-randomizes (numbers differ from the
      previous attempt ≥9/10 times).

### Visual

- [ ] No layout breakage at 360px-equivalent (small phone) and
      tablet/landscape widths — test with `MediaQuery` overrides or
      physical devices, not just one simulator size.
- [ ] No color-only status signaling — every threshold state pairs color
      with an icon and text label (already the pattern in
      `_buildCalcBox`'s `statusIcon` — keep it everywhere).
- [ ] All interactive elements reachable via keyboard/switch-access
      (Flutter's semantics tree — check with TalkBack/VoiceOver, not just
      visually).

### Content accuracy

- [ ] Every "real-world" numeric claim (plastic densities, NIR
      wavelengths, compost phase temps, radiation coefficients) has a code
      comment marking it as (a) standard textbook figure or (b)
      illustrative simplification. Never present (b) as measured fact in
      the UI copy.

---

## Quick reference — formula table (unchanged from original spec)

| Module            | Formula          | Fixed constants                                  |
| ----------------- | ---------------- | ------------------------------------------------ |
| A — Density       | ρ = m / V        | —                                                |
| B — Heat          | Q = m·c·ΔT       | c = 4000 J/kg°C                                  |
| C — Torque        | τ = r·F·sin(θ)   | max safe = 8 N·m                                 |
| D — Work/Energy   | W = Ep = m·g·h   | g = 10 m/s²                                      |
| E — Kinematics    | v = s/t          | —                                                |
| F — PWM           | V_avg = D·V_max  | V_max = 12V                                      |
| G — Power         | P = V·I, E = P·t | camera 10W, drive 36W, arm 18W, battery 50,000 J |
| Waste — Hooke     | F = k·x          | k = 50 N/m                                       |
| Waste — Radiation | I = I₀·e^(−μx)   | μ*α≈5.0, μ*β≈1.5, μ_γ≈0.3 (illustrative)         |

## Language notes (unchanged)

- Learner-facing UI copy: Bahasa Indonesia.
- Code, class names, this doc: English.
- Formula variable names (`m`, `V`, `ρ`, `τ`, `r`, `F`, `θ`): never
  translated.
