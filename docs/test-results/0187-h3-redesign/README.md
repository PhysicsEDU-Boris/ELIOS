# 0187 H3 redesign: test results (6 Nov 2026)

- `compare/`: Figma | app side-by-sides, frames 01-10, en/id x light/dark (`L10N_RENDER=1 flutter test test/history/h3_figma_harness_test.dart`).
- `phone/`: Motorola Edge 60 Fusion (Android 16), owner's real History (45 scans, 568 trophies).

## Phone test
- Build: `flutter build apk --debug --target-platform android-arm64` with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, APP_COMMIT `5385e16+mission+essayfix`: branch source plus the localized essay-keyboard fix (`d67aba3..dfb7f67`, applied uncommitted so the phone kept that fix, then removed). `adb install -r`, no data clear.
- Checked: list (hero Level 4, tiles with counts, day groups, real crops), Organic filter, detail (stats, tabs, cards), correct explanation (green hero), wrong explanation (red hero, two tiles, bin buddy card), essay (score chip, neutral tiles), mission read-aloud state, live switch English -> Bahasa Indonesia from the sidebar (all History text and the 15.12 time format), dark mode.
- Found and fixed: the mission finish line reused the AI `summary`, which on real records repeats the "why" paragraph at length. Now a fixed localized sentence (`h3MissionDone`); re-checked on the phone (`phone/id-light-mission-fixed.jpg`).
- Owner feedback (7 Nov): an empty band sat above the bottom nav on the History tab (other tabs have none). Cause: HomeShell re-reads padding from above its Scaffold, so the tab's `SafeArea` reserved the gesture-bar inset again. Fix: no bottom `SafeArea` when History is a tab (`showHeader: false`). Regression test fails on the old code (list ends 24 dp above the nav). Reinstalled (APP_COMMIT `5d27ac9+navband+essayfix`), checked: `phone/en-light-list-no-nav-band.jpg`.
- Owner data: private backup before install (History, R3 test History, photos, prefs). After testing both History files are byte-identical (md5) to the backup. Phone left in English, light mode, on Home, as found.
- Not checked on the phone: PDF export, skeleton/loading states, wide two-pane layout, offline translation note.
