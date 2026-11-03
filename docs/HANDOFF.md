# Handoff — 3 Nov 2026

- 3 Nov: #84 live SSID/IP dashboard merged (0177). `feat/wifi-qr-setup` (0178): camera "Wi-Fi setup" joins a hotspot from a WIFI: QR with a 45 s rollback; app Config gets Robot Wi-Fi QR and Find ELIO. Fast NPU QR scan, glare luma steps, success to dashboard banner / failure back to scan. Robot-tested twice from STA (wrong password rolled back, real one joined); AP-to-STA not tested. A manual exposure/gain probe restarted the camera; touch came back with a `hyn_ts` re-bind.
- Devices now: camera in STA on the owner's hotspot `boris` (10.51.200.84), running the `feat/wifi-qr-setup` `main.py` in `elios_clean_m2c_v1` (old copy `/root/main.py.pre-wifiqr.bak`, AP files in `/boot/wifi_backup_ap/`). Phone: debug APK from that branch installed in place (data and Gemma model kept), Config camera = MaixCAM2, IP 10.51.200.84.
- 3 Nov: #80 R2, #81 R3 and #82 Q3 merged into `feature/live-scan` (`8b006d7`); `main` = `feature/live-scan` + the owner's module PDF upload (merge `07161c1`).
- `feat/cloud-ai-architecture` (from `main` `07161c1`) is the faster ELIOS AI work: MaixCAM2 in STA mode, cloud detector and cloud quiz generation replacing on-device Gemma. Step 1, the provider benchmark, is below; nothing in the app is built yet.
- Merged: #51 U4b essay rubric; #53 banks (decision 0060); #52 History/PDF crops (0070); #54 Android tester build (0040); #55 E1 (0041), with the "Bukan ini?" picker and background load phone-verified.
- Open PRs: #70 H2 and #71 N2 conflict with the base (rebase needed); #47 firmware (motion disabled); #24 (latency gate failed); docs-only #50, #62, #65, #66.

## Gemini cloud AI (3 Nov, `feat/gemini-cloud-ai`, decision 0179)

- On-device Gemma removed. `lib/services/ai_quiz_service.dart` POSTs identify, questions, essay grading and chat with the Firebase ID token to the `ai-backend` Vercel function (`ai-backend/`, team ELIOS, region sin1, https://ai-backend-seven-orpin.vercel.app/api/ai), which checks the token, holds `GEMINI_API_KEY` and runs the 0176 chain (`node --test` in `ai-backend/`, break-checked). Firebase Blaze skipped (200k IDR); Cloudflare dropped (Gemini refuses its locations; the `elios-ai` Worker was deleted 3 Nov).
- No AI answer: the quiz uses the bank and says so. ELIOS AI is the default source in every build. Thermal gate, model copy/sideload, Activate card states and the macOS LiteRT-LM phase are gone.
- Phone-verified 3 Nov: identify + 3 AI questions, ~1.6 s each, `source=ai`; a 3.5 Flash-Lite timeout fell to 3.1 Flash-Lite. Phone runs the debug APK from this branch. Free key for now; paid before students. Redeploy: `npx vercel deploy --prod --scope elios5` in `ai-backend/`.
- `macos/Podfile.lock` still lists the Gemma pods (`pod install` hit a Ruby error here); the next Mac build refreshes it. Phone Gemma files deleted 3 Nov (owner's OK): the pushed model, the app's copy and its 4 caches; app data 2.6 GB → 473 MB, scan records kept.
- Free key capacity: about 1,060 calls/day (≈250 scans on Medium) and 45/min across the chain; resets 15:00 WIB daily, no weekly/monthly cap. Vercel Hobby limits reset monthly.
- Figma pipeline page 74:130 updated to Gemini (flows 1, 5, 6, architecture box). Notion ELIOS page has the 3 Nov night wrap-up.
- Benchmark spike (0176): `tools/cloud_ai_bench/`; resume with the same command, free caps reset 15:00 WIB.

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
