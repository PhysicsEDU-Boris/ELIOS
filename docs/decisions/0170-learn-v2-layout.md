# 0170 Learn tab v2 layout (L1)

Status: draft PR, owner review pending. Figma file J2jSbARJSyJCStNFeWkWDj, page "L1 Learn screens" (293:2358), v2 rows only.

## Decision
- One component file, `lib/widgets/learn/learn_ui.dart`, mirrors the Figma components (Bin card, Lesson card + grid, Progress summary, Section header, Guide lesson row, Video card, Quiz card, Simulation row, Slider, Collapsible header, Level chip). Colours come only from `ElioTokens.light/dark` through the theme (`context.elio`), text from the theme `TextTheme`, shapes from the M3 scale with continuous corners (`RoundedSuperellipseBorder`, 12/16/28), touch targets 48 dp.
- Learn pages are pushed with `learnRoute()`, which wraps them in `ElioTheme`, so dark comes from the saved theme mode (routes do not inherit the shell's theme).
- Screens: hub (`elearning_tab.dart`, 309:4863), one generic module page (`module_page.dart`, 309:5927), lesson page for videos and guides (`lesson_page.dart`, 310:5798), My progress (`progress_page.dart`, 310:6126), quiz list/question/result (`quiz_page.dart`), physics quiz (`quiz/physics_quiz_page.dart`, 310:6089), all 8 simulation pages through one `SimulationPageScaffold` (310:5964: summary card with canvas, meta, title, Rumus/Durasi/Status, then Materi / Rumus / Simulasi tabs holding the existing sections).
- Every title, duration, score and percentage comes from Firestore or the progress providers. Module progress = finished lessons plus the quiz, divided by lessons + 1. The overall figure keeps `weightedProgressFor` with the real totals.
- Lesson page plays the video by opening the existing YouTube player page (simpler than an inline player; fullscreen and rotation unchanged, watch progress saved where it was). Guides open the existing Syncfusion viewer (cache unchanged); only its app bar and a new pager bar (previous / page x of n / next) are restyled.
- The old list widgets (`GuidesContent`, `VideoLessonsContent`, `SimulationsContent`, filter chips, the Learn "ELIO" app bar with its notification bell) are removed. Home keeps its notification button.
- Physics calculations, painters and slider ranges are untouched. Two text-only layout fixes in sim pages: the kinematics timer row wraps (it overflowed inside the narrower card).

## Differences from Figma
- Headings use the theme's `titleLarge` (JetBrains Mono, tokens) instead of the Figma sans; the font switch is decision 0091 (draft).
- Simulation pages keep their own tag text ("MODUL A · MATERI") in the summary card; the live painter canvas stays in the Simulasi tab, the static Figma canvas is the summary image.
- Deep-dive and the physics quiz have no Figma canvas: they use the Intro cover and the mascot.

## Not done
- Wide layouts (600 dp and up) are only centred at 600 dp, no two-pane layout.
