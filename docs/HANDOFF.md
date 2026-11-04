# Handoff — 4 Nov 2026 (#89 and #90 merged)

## Merge order (owner merges; merge commits, not squash)

1. **#89** `claude/firmware-track-lock-4de19c` → `feature/live-scan`: firmware 0182 plus the 8 LOCK/SCAN commits of #88, which reached only the old `docs/segmentation-fps-options` branch.
2. **#90** `feat/lock-track-follow`: after #89 is merged, set its base to `feature/live-scan` (GitHub does this if #89's branch is deleted), then merge. It has everything newest (camera `9cd825b3`, APK `8c8953d`).
3. `main` stays the owner's call. New work branches from `feature/live-scan` after #90.
- Next (own sessions): depth estimation on the camera (Depth-Anything-V2-Small is on it, `nn.DepthAnything`, relative depth, fps not measured).
- AprilTags (`docs/test-results/0182/apriltag-print-readability-fx.md`): measured fx 487 px (firmware's 375 reads 23 % short); id 0 99 % to 200 mm; id 1 (6.17 mm, firmware wrongly says 10) lost past 150 mm by the 320x240 search, readable in full frame. Next (owner OK): fx 487 + id 1 6.17 mm; maybe full-res crop for id 1. Print sheet `docs/print/apriltags-arm-id0-id1-A4.pdf`.

## Camera tracks the LOCK box (4 Nov, `claude/firmware-track-lock-4de19c`, decision 0182)

- New `firmware/maixcam2/main.py` `m2c-track-v1` from the camera's live wifi-qr file: no seg model, clean 640x480 frames, `track_start`/`track_stop` (MixFormerV2), `Human_Hand` from HandLandmarks, rough AprilTag `arm_tags` (`dist_rough`). Tracker/hands/tags every 2nd frame.
- **Deployed on the camera** (owner OK), sha256 `9cd825b3…` (from `feat/lock-track-follow`); backup `/root/main.py.pre-track.bak` + `app.yaml.pre-track.bak`. Rollback: copy back, reopen ELIOS Clean Vision.
- fps 10.4 → 17 unlocked, 10.5 locked (8.2 with the tracker every frame). find_apriltags at 640x480 kills the process, so tags run on 320x240. A crash left `vi init failed` for other processes until the app was reopened.
- Box follows a moved pack; a box from an old frame tracks background at score 1.0 → app step 3 must send the box of the frame it gave Gemini. Landmark hand boxes fit the hand on the robot (162/259 frames). No tags in view yet.
- App step 3 (`feat/lock-track-follow`, stacked on #89): LOCK sends `track_start`, the green box follows the tracked box and hides 1.5 s after it is lost; live scan skips the tracked box. Phone test: follows push and lift-carry; a lost item is found again in under 1 s; box size after a flip stays approximate (owner chose no auto-refine; press LOCK again). Phone runs debug APK `8c8953d`; camera firmware (see sha above): re-find after ~1 s, still or flipped item holds one box (0 px change in 15 s), 2x size guard vs the previous box; LOCK name above the box; back to the 11:04 tracking (owner): tracker's own box with hold, 1 AI call per LOCK, no refine.
- Camera Wi-Fi now the owner's phone hotspot, 10.51.200.84 (joined by QR, 4 Nov); USB 10.73.69.1 works again. Same room, nothing locked: WIFIBOR -58..-73 dBm gave 2.4 fps, hotspot -46 dBm 13.3 fps, so low fps there was the Wi-Fi, not tracking or AI. Built after: preview JPEG 60, AI clean_image 80 every 0.7 s.
- fps now 32.7 unlocked / 17.3 locked: AprilTags (50 ms) only around a grip (`arm_tags` cmd), camera screen off while a phone is connected. Screen wake by tap checked on the robot.
- Refine cost measured: 19 AI calls in 2 min 20 s of constant handling (~8/min), none while still.

- 3 Nov: #84 live SSID/IP dashboard merged (0177). `feat/wifi-qr-setup` (0178): camera "Wi-Fi setup" joins a hotspot from a WIFI: QR with a 45 s rollback; app Config gets Robot Wi-Fi QR and Find ELIO. Fast NPU QR scan, glare luma steps, success to dashboard banner / failure back to scan. Robot-tested twice from STA (wrong password rolled back, real one joined); AP-to-STA not tested. A manual exposure/gain probe restarted the camera; touch came back with a `hyn_ts` re-bind.
- Devices now: camera in STA on the owner's hotspot `boris` (10.51.200.84), running the `feat/wifi-qr-setup` `main.py` in `elios_clean_m2c_v1` (old copy `/root/main.py.pre-wifiqr.bak`, AP files in `/boot/wifi_backup_ap/`). Phone: debug APK from that branch installed in place (data and Gemma model kept), Config camera = MaixCAM2, IP 10.51.200.84.
- 3 Nov: #80 R2, #81 R3 and #82 Q3 merged into `feature/live-scan` (`8b006d7`); `main` = `feature/live-scan` + the owner's module PDF upload (merge `07161c1`).
- `feat/cloud-ai-architecture` (from `main` `07161c1`) is the faster ELIOS AI work: MaixCAM2 in STA mode, cloud detector and cloud quiz generation replacing on-device Gemma. Step 1, the provider benchmark, is below; nothing in the app is built yet.
- Merged: #51 U4b essay rubric; #53 banks (decision 0060); #52 History/PDF crops (0070); #54 Android tester build (0040); #55 E1 (0041), with the "Bukan ini?" picker and background load phone-verified.
- Open PRs: #70 H2 and #71 N2 conflict with the base (rebase needed); #47 firmware (motion disabled); #24 (latency gate failed); docs-only #50, #62, #65, #66.

## Segmentation + FPS (3 Nov, `docs/segmentation-fps-options`, PR #87, decision 0180)

- Research: SAM 3 model is free (SAM License) but needs a GPU or a paid API (fal $0.005/image). FPS fixes (decode filter, JPEG quality, thread, binary frames) need the owner's OK for firmware; camera was offline, time split is an estimate.
- Built option B (owner's pick): identify gets a padded crop (box + 25 %/side) and returns `box_2d`; live scan re-crops popup + History photo from it; no backend/firmware change. Box tightness and added latency still to check on the phone (tester log `identified ... box=`).
- Phone test 3 Nov (fake MaixCAM, real camera offline): box works, 2.7 s, 1 of 3 runs answered; 2 got 503 from every Gemini model. Results `docs/test-results/0180/`.
- Camera Wi-Fi was dead 22:27-23:20 (camera clock): driver left loaded after a system stop, `wifi.sh start` refuses while loaded. Rebooted (owner OK), STA WIFIBOR 192.168.100.135 back; auto-start is `settings`, ELIOS app opened by hand. `wifi.sh` logs the Wi-Fi password to the journal.
- Real camera: cardboard box locked as E_Waste, Gemini "kardus" + matching box, 23 s (overload); 0012 showed the B3 card, so (owner) the AI may now clear a detector E_Waste with an explicit non-B3 bin and no hazard words (0180); real battery stayed B3 (correct). Phone: APK `4f27083`, MaixCAM2, 192.168.100.135 saved.

## LOCK button (3 Nov, `feat/lock-button`, stacked on PR #87, decision 0181)

- Owner plan: drop the .mud model; LOCK → Gemini box (1 call); camera tracks it after (MixFormerV2, model on the camera; ByteTrack needs a detector); camera hand_detector keeps arm safety; AprilTags (tag36h11 id 0, 18.52 mm) via find_apriltags; calibrate with robotic_hand_sim's HIL toolkit. Step 1 (this, app only): LOCK labels+boxes (no quiz, waste-only prompt), SCAN opens the quiz; keys on the video. firmware steps need the owner's OK at test time.

## Gemini cloud AI (3 Nov, `feat/gemini-cloud-ai`, decision 0179)

- On-device Gemma removed. `lib/services/ai_quiz_service.dart` POSTs identify, questions, essay grading and chat with the Firebase ID token to the `ai-backend` Vercel function (`ai-backend/`, team ELIOS, region sin1, https://ai-backend-seven-orpin.vercel.app/api/ai), which checks the token, holds `GEMINI_API_KEY` and runs the 0176 chain (`node --test` in `ai-backend/`, break-checked). Firebase Blaze skipped (200k IDR); Cloudflare dropped (Gemini refuses its locations; the `elios-ai` Worker was deleted 3 Nov).
- No AI answer: the quiz uses the bank and says so. ELIOS AI is the default source in every build. Thermal gate, model copy/sideload, Activate card states and the macOS LiteRT-LM phase are gone.
- Phone-verified 3 Nov: identify + 3 AI questions, ~1.6 s each, `source=ai`; a 3.5 Flash-Lite timeout fell to 3.1 Flash-Lite. Phone runs the debug APK from this branch. Free key for now; paid before students. Redeploy: `npx vercel deploy --prod --scope elios5` in `ai-backend/`.
- `macos/Podfile.lock` still lists the Gemma pods (`pod install` hit a Ruby error here); the next Mac build refreshes it. Phone Gemma files deleted 3 Nov (owner's OK): the pushed model, the app's copy and its 4 caches; app data 2.6 GB → 473 MB, scan records kept.
- Benchmark spike (0176): `tools/cloud_ai_bench/`; resume with the same command, free caps reset 15:00 WIB.

## Owner data incident

- The 29 Oct owner History record was overwritten and is still unrecovered. Do not invent or reconstruct its missing answers from guesses.

## Queue after the architecture change

- U4c combined native acceptance, U7 Firebase sync, U8 docs/Figma (see NEXT_TASK.md). wrongWhy texts for the bank are still unwritten.

## R2, Q3, R3 (merged #80-#82, 3 Nov)

- Details in decisions 0173-0175 and `docs/test-results/r2|q3|r3/`.
