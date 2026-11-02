# Handoff — 2 Nov 2026

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

## C1 Config screen (2 Nov, draft PR on `feature/live-scan`)

- Config + Settings sheet from Figma 337:2358; decision 0145 (settings audit, battery "—", saved quiz source, real Cancel/failure reason). Logic in `config_link_provider.dart`, UI in `lib/Screens/config/`.
- Tests: `test/screens/config_screen_test.dart` (28), `test/services/config_connection_test.dart` (10). `flutter test` +818 ~20 -2 (the 2 known `elio_tokens_test` failures).
- Phone: owner session (no guest; nothing recorded), fake robot via `adb reverse` (phone had no Wi-Fi). Shots + notes in `docs/test-results/c1/`. **The phone now runs the C1 debug build** (was the H1v4 tester build); reinstall a tester build when needed.
- Merged as #77; Connect opens Control (owner). Fix PR: leaving Control with a quiz open now disconnects (was a debug-build reconnect loop).
- Open: Sound effects and Timer are UI only; AI Error/Paused not seen on the phone; dark divider fix not on the phone build.

## N4 profile top bar and drawer (1 Nov, draft PR, stacked on N3 #72)

- `elio_top_bar.dart` + `elio_drawer_host.dart` (custom drawer) wired in `HomeShell`; Home hamburger removed; decision 0143.
- Tests: `test/widgets/elio_drawer_host_test.dart` (15). `flutter test`: only the 2 `elio_tokens_test` failures, which also fail on the N3 base.
- Not checked: phone or Mac window, real photo avatar. Open: no wide-layout rail (Learn's second bar removed by L1).

## L1 Learn tab v2 (1 Nov, draft PR, stacked on `feat/n3-bottom-nav`)

- Hub, module, lesson, quiz, My progress and all 9 simulations rebuilt from Figma L1 v2 (light and dark, tokens via theme); components in `lib/widgets/learn/learn_ui.dart`; illustrations in `assets/illustrations/learn/`. Decisions 0170-0172.
- N4 (#73) was merged into `feat/n3-bottom-nav`, not `feature/live-scan`, so the PR targets `feat/n3-bottom-nav`.
- Tests: `test/screens/learn_v2_test.dart` (36). `flutter test`: 765 pass, 2 known `elio_tokens_test` failures.
- Phone (Edge 60 Fusion): video, PDF, sliders, progress, dark mode pass; see `docs/test-results/l1/README.md`.
- Open: turn the phone inside the video player once; error screen only widget-tested (Firestore cache hides it offline); Kuis fisika score is never saved (pre-existing).

## H1v4 gamified Home (2 Nov, draft PR, on top of N4 catch-up #75)

- #73 (N4) never reached `feature/live-scan`; #75 merges it (only `2dd92db`). #74 (L1 learn v2) was missing too; added to #75 on 2 Nov after the owner saw the old Learn on the phone.
- New Home from Figma 321:2358 with real scan data only; maths in `lib/models/home_stats.dart`, UI in `home_screen.dart` + `lib/Screens/home/`. Decision 0144 (residu in Anorganik, tree per level). Owner: quest rewards count toward trophies and levels (derived per day from 2 Nov 2026, in `ScanRecordStore.totalTrophies`).
- Tests: `test/models/home_stats_test.dart` (19, break-checked), `test/screens/home_screen_test.dart` (15). `flutter test` +741 ~20 -2 (the 2 known `elio_tokens_test` failures).
- Phone (Edge 60 Fusion, tester APK, guest session, owner data untouched): Home = History (26 scans, 202 trophies, B3 8 / Anorganik 17 / Organik 1, 0 today; before the quest-bonus change, which adds nothing to Oct records). Shots in `docs/test-results/h1v4/`.
- Build hygiene: the 2.59 GB Gemma model sits in `assets/models/` in this checkout and gets bundled; move it out for an APK build and back after.
- Open: History total now exceeds the sum of its rows (quest bonus); History has no per-day filter; `trophiesFor(List)` returns 0 (callers pass trophies explicitly).
