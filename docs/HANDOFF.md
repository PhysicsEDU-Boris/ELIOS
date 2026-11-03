# Handoff — 2 Nov 2026

- Base: `feature/live-scan` at `c38809d` (#77 C1, #78 Control dispose, #79 theme toggle merged).
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

## R2 gamified Control (2 Nov, draft PR on `feature/live-scan`)

- Control rebuilt from Figma 358:2358 (light/dark): joystick for the same D-pad commands, faders, gear chips, power + round STOP, camera HUD (bands/pick zone/distance only with `dist_cm`), waiting/disconnected views with the real 2 s / 30-try retry, mission + "This drive" (real records, no reward), ELIO tip, Voice / Scan quiz toggles. Decision 0173; logic in `lib/models/control_session.dart`, UI in `lib/widgets/control/` + `control_layout.dart`.
- Tests: `test/widgets/control_layout_test.dart` (226, 8 sizes × 3 states × light/dark), `test/screens/control_r2_test.dart`, `test/models/control_session_test.dart`; break-checked (joystick without the gate fails). `flutter test` +1015 ~20 -2 (the 2 known `elio_tokens_test`).
- A/B fake log (`docs/test-results/r2/`): identical up to Exit; the base build did not disconnect on Exit (reproduced, cause not found), the new one does.
- Phone: owner session read-only (27 scans unchanged, no quiz answered), fake via `adb reverse`. **The phone now runs the R2 debug build dd429ed** (tester flags), dark mode. Phone has two Gemma copies (app files + external files), both pre-existing; not touched.
- Owner questions: mission reward; HUD crop hides the 20 cm band on phones; base-build Exit not disconnecting.

## Earlier on 2 Nov (merged)

- Theme switch + Android icon (#79, decision 0146); C1 Config (#77, decision 0145; open: Sound effects/Timer UI only); #78 Control dispose disconnect.
- N4 top bar/drawer (0143) and L1 Learn v2 (0170-0172) reached `feature/live-scan` via #75. L1 open: Kuis fisika score never saved (pre-existing).

## H1v4 gamified Home (2 Nov, draft PR, on top of N4 catch-up #75)

- #73 (N4) never reached `feature/live-scan`; #75 merges it (only `2dd92db`). #74 (L1 learn v2) was missing too; added to #75 on 2 Nov after the owner saw the old Learn on the phone.
- New Home from Figma 321:2358 with real scan data only; maths in `lib/models/home_stats.dart`, UI in `home_screen.dart` + `lib/Screens/home/`. Decision 0144 (residu in Anorganik, tree per level). Owner: quest rewards count toward trophies and levels (derived per day from 2 Nov 2026, in `ScanRecordStore.totalTrophies`).
- Tests: `test/models/home_stats_test.dart` (19, break-checked), `test/screens/home_screen_test.dart` (15). `flutter test` +741 ~20 -2 (the 2 known `elio_tokens_test` failures).
- Phone (Edge 60 Fusion, tester APK, guest session, owner data untouched): Home = History (26 scans, 202 trophies, B3 8 / Anorganik 17 / Organik 1, 0 today; before the quest-bonus change, which adds nothing to Oct records). Shots in `docs/test-results/h1v4/`.
- Build hygiene: the 2.59 GB Gemma model sits in `assets/models/` in this checkout and gets bundled; move it out for an APK build and back after.
- Open: History total now exceeds the sum of its rows (quest bonus); History has no per-day filter; `trophiesFor(List)` returns 0 (callers pass trophies explicitly).
