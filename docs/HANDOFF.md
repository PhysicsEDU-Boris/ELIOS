# Handoff — 3 Nov 2026

- 3 Nov: MaixCAM2 dashboard shows the live SSID (AP/STA) and IP (decision 0177, `fix/dashboard-live-ip`); not deployed to the camera yet.
- 3 Nov: #80 R2, #81 R3 and #82 Q3 merged into `feature/live-scan` (`8b006d7`); `main` = `feature/live-scan` + the owner's module PDF upload (merge `07161c1`).
- `feat/cloud-ai-architecture` (from `main` `07161c1`) is the faster ELIOS AI work: MaixCAM2 in STA mode, cloud detector and cloud quiz generation replacing on-device Gemma. Step 1, the provider benchmark, is below; nothing in the app is built yet.
- Merged: #51 U4b essay rubric; #53 banks (decision 0060); #52 History/PDF crops (0070); #54 Android tester build (0040); #55 E1 (0041), with the "Bukan ini?" picker and background load phone-verified.
- Open PRs: #70 H2 and #71 N2 conflict with the base (rebase needed); #47 firmware (motion disabled); #24 (latency gate failed); docs-only #50, #62, #65, #66.

## Cloud AI benchmark spike (3 Nov, draft PR into `feature/live-scan`, decision 0176)

- `tools/cloud_ai_bench/bench.py` (stdlib + Pillow) benchmarks every Gemini model on the owner's free key; key only from `GEMINI_API_KEY`, never saved. No app change.
- Photos: 28 Roboflow images in `~/Desktop/elio_bench` (outside the repo, EXIF removed), not robot crops. Run stopped by the owner after 44 calls (daily caps of 20, 503s): too small to separate models.
- Answering models: 3.5 Flash-Lite 1.8 s, 3 Flash 2.2 s, 3.6 Flash 2.1 s (10/10 bins), Robotics ER 3.7 s; all bins right. 3.8 Flash and Gemma 4 API only 5xx; 2.5 models 404.
- Accepted (owner, 3 Nov): 3.5 Flash-Lite primary + automatic fallback chain (0176), not built yet. On-device Gemma is dropped from the plan (bank is the only offline fallback); its code stays until the cloud path ships. MaixCAM2 STA mode for internet: owner. Still open: free vs paid tier, backend for the key, finish the run.
- Resume: rerun the same command; it skips calls that already succeeded. Free caps reset 15:00 WIB.

## Phone evidence — Edge 60 Fusion, GPU

- Load: 4.3–9.2 s cached or 41–50 s cold; identify: 19.8–23.9 s with the shorter prompt; questions: 20–41 s; essay grading: 16.5–25.4 s; memory: 3.3–3.7 GB.
- Thermal gate pauses at CRITICAL.
- The tester build keeps Gemma loaded after the scan screen closes (about 1.6 GB held until the app closes).
- Photo-size test: 512/384/256 px gave 24.8/24.3/23.6 s. Photo size does not change identify time in this test.
- See [Lane A handoff](handoff/lane-a.md) for details; its earlier measurements and pre-PR status predate the summary above.

## Owner data incident

- The 29 Oct owner History record was overwritten and is still unrecovered. Do not invent or reconstruct its missing answers from guesses.

## Queue after the architecture change

- U4c combined native acceptance, U7 Firebase sync, U8 docs/Figma (see NEXT_TASK.md). wrongWhy texts for the bank are still unwritten.

## R2 gamified Control (merged #80, 3 Nov)

- Control rebuilt from Figma 358:2358 (light/dark): joystick for the same D-pad commands, faders, gear chips, power + round STOP, camera HUD (bands/pick zone/distance only with `dist_cm`), waiting/disconnected views with the real 2 s / 30-try retry, mission + "This drive" (real records, no reward), ELIO tip, Voice / Scan quiz toggles. Decision 0173; logic in `lib/models/control_session.dart`, UI in `lib/widgets/control/` + `control_layout.dart`.
- Tests: `test/widgets/control_layout_test.dart` (226, 8 sizes × 3 states × light/dark), `test/screens/control_r2_test.dart`, `test/models/control_session_test.dart`; break-checked (joystick without the gate fails). `flutter test` +1015 ~20 -2 (the 2 known `elio_tokens_test`).
- A/B fake log (`docs/test-results/r2/`): identical up to Exit; the base build did not disconnect on Exit (reproduced, cause not found), the new one does.
- Phone: owner session read-only (27 scans unchanged, no quiz answered), fake via `adb reverse`. Phone has two Gemma copies (app files + external files), both pre-existing; not touched.
- Owner questions: mission reward; HUD crop hides the 20 cm band on phones; base-build Exit not disconnecting.

## Q3 quiz popups + camera scan (merged #82, 3 Nov)

- One R3 popup everywhere (`lib/widgets/quiz/quiz_r3.dart`): question, loading (timer, 3 real steps), skeleton, essay input, review document + coach chat; explanation data from the bank (quote, section, page, id; wrongWhy optional, none written). Camera scan restyled, crop unchanged. Decision 0175.
- Tests: `phone_control_test` (all popup states, 3 sizes × light/dark), `scan_screen_test` (crop break-checked), `q3_explanation_data_test` (break-checked). `flutter test` only the 2 known failures.
- Phone: test store `scan_records_q3test.json` (deleted after), owner `scan_records.json` and the R3 test file byte-identical. **The phone runs the Q3 debug build, light mode, Phone camera, Question bank.** No real item was scanned (Gemma identify ran, nothing recognised). Results: `docs/test-results/q3/`.
- Open: who writes wrongWhy; R2 GO/logo; result card and History detail still the older look.

## R3 Control for phones (merged #81, 3 Nov)

- Phones in landscape (short side < 600 dp) get the R3 layout from Figma 393:2358 (`lib/widgets/control/phone/`: layout, quiz popups, Guide). One round STOP/GO button (GO = `MotionGate.resume` only), no logo in the top bar, nothing on the video, offline presses send nothing, skeleton, 5-step Guide (first run once per device, key `r3_phone_guide_shown`). R2 stays on tablets and the Mac. Decision 0174.
- Tests: `test/widgets/phone_control_test.dart`, `test/screens/control_phone_test.dart`; GO test break-checked. Results, side-by-sides and the difference list: `docs/test-results/r3/`.
- Phone (Edge 60 Fusion): debug build with `SCAN_RECORDS_FILE=scan_records_r3test.json` (separate store). Owner `scan_records.json` verified byte-identical (27 records); fake robot over `adb reverse`, removed after. Space/Esc not tested (no keyboard). The Gemma model was moved out and back for the builds; no copy.
- Open: painted card art and SVG export, 3D joystick, ELIOS AI badge art; essay input / identifying / hazard popups still the old Indonesian popup; owner question: should GO and the logo removal also apply to R2 tablet and Mac?

## Earlier on 2 Nov (merged)

- Theme switch + Android icon (#79, decision 0146); C1 Config (#77, decision 0145; open: Sound effects/Timer UI only); #78 Control dispose disconnect.
- N4 top bar/drawer (0143) and L1 Learn v2 (0170-0172) reached `feature/live-scan` via #75. L1 open: Kuis fisika score never saved (pre-existing).
