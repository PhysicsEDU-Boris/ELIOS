# Handoff — 31 Oct 2026

- Base: `feature/live-scan` at `ae67416`.
- Merged: #51 U4b essay rubric; #53 banks (decision 0060); #52 History/PDF crops (0070); #54 Android tester build (0040); #55 E1 (0041), with the "Bukan ini?" picker and background load phone-verified.
- Open PRs: #50 docs wrap-up (content carried into this docs sync); #47 firmware (motion disabled, `ARM_MOTION_ENABLED=false`); #24 (latency gate failed).

## Phone evidence — Edge 60 Fusion, GPU

- Load: 4.3–9.2 s cached or 41–50 s cold; identify: 19.8–23.9 s with the shorter prompt; questions: 20–41 s; essay grading: 16.5–25.4 s; memory: 3.3–3.7 GB.
- Thermal gate pauses at CRITICAL.
- The tester build keeps Gemma loaded after the scan screen closes (about 1.6 GB held until the app closes).
- Photo-size test: 512/384/256 px gave 24.8/24.3/23.6 s. Photo size does not change identify time in this test.
- See [Lane A handoff](handoff/lane-a.md) for details; its earlier measurements and pre-PR status predate the summary above.

## Owner data incident

- The 29 Oct owner History record was overwritten and is still unrecovered. Do not invent or reconstruct its missing answers from guesses.

## Next task — U4c combined native acceptance

- Back up the owner's records and read-verify the backup first. Prove a separate test store is active before interacting; never seed or reset the owner store.
- Complete real-Gemma/localhost-camera multi-question acceptance: MCQ explanation → next question, essay rubric during live frames, trophy math, quit/relaunch, saved review and complete native PDF export.
- Follow `CLAUDE.md` Mac build hygiene: reuse the retained app/model, inventory before building and verify one app registration afterwards. No physical robot movement or sharing recipient selection.
- Overall queue: U4c combined native acceptance, then U7 Firebase sync, then U8 documentation/Figma. See [NEXT_TASK.md](NEXT_TASK.md).

## Design file font (decision 0091, draft)

- `docs/design.md` now specifies Google Sans Flex and Google Sans Code and a new Status Chip. The app code is unchanged (still JetBrains Mono, Inter, Sora, Manrope). Radii now follow the M3 scale with continuous corners. Check the font licences before bundling.

## H1 home screen (31 Oct, draft PR #67)

- `lib/Screens/home_screen.dart` restyled to Figma 243:2358 (light and dark, tokens only, 48 dp targets, two columns from 840 dp); behaviour unchanged. Decision 0140, details in [lane-h.md](handoff/lane-h.md).
- Not checked: real 3D viewer, phone feel, native Mac window (no isolated test store documented, so the app was not launched).

## N4 profile top bar and drawer (1 Nov, draft PR, stacked on N3 #72)

- `elio_top_bar.dart` + `elio_drawer_host.dart` (custom drawer) wired in `HomeShell`; Home hamburger removed; decision 0143.
- Tests: `test/widgets/elio_drawer_host_test.dart` (15). `flutter test`: only the 2 `elio_tokens_test` failures, which also fail on the N3 base.
- Not checked: phone or Mac window, real photo avatar. Open: Learn shows two bars; no wide-layout rail.

## H1v4 gamified Home (2 Nov, draft PR, on top of N4 catch-up #75)

- #73 (N4) never reached `feature/live-scan`; #75 merges it (only `2dd92db`). #74 (L1 learn v2) is also missing there, not brought in.
- New Home from Figma 321:2358 with real scan data only; maths in `lib/models/home_stats.dart`, UI in `home_screen.dart` + `lib/Screens/home/`. Decision 0144 (residu in Anorganik, quest rewards display only, tree per level).
- Tests: `test/models/home_stats_test.dart` (17, break-checked), `test/screens/home_screen_test.dart` (15). `flutter test` +739 ~20 -2 (the 2 known `elio_tokens_test` failures).
- Phone (Edge 60 Fusion, tester APK, guest session, owner data untouched): Home = History (26 scans, 202 trophies, B3 8 / Anorganik 17 / Organik 1, 0 today). Shots in `docs/test-results/h1v4/`.
- Build hygiene: the 2.59 GB Gemma model sits in `assets/models/` in this checkout and gets bundled; move it out for an APK build and back after.
- Open: owner decision on quest rewards; History has no per-day filter; `trophiesFor(List)` returns 0 (callers pass trophies explicitly).
