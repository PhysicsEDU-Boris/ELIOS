# Q3 quiz popups and phone camera scan: test results (3 Nov 2026)

Decision [0175](../../decisions/0175-q3-quiz-scan-popups.md). Branch `feat/q3-quiz-scan` on `feat/r3-control-phone` (2cf2e35).

## Widget and unit tests
- `test/widgets/phone_control_test.dart`: every popup state at 915x412, 800x360, 932x430, light and dark (question, loading,
  identifying, skeleton, essay input, review right / wrong / wrong without wrongWhy, essay graded / pending, long text):
  no overflow, the compact STOP on top and tappable. Plus: headings, struck-through pick, options table, bin table, quote with
  section and page, source chip, no logo in the review header, document scroll, loading timer and steps, Minimise → Quiz Waiting,
  STOP from loading, skeleton and review.
- `test/screens/scan_screen_test.dart`: camera ready, model loading (indeterminate, Scan disabled), installing (real %),
  skeleton, bank mode; the crop rectangle unchanged (hard-coded from the pre-Q3 formula; break-checked: a 279 dp sidebar fails it).
- `test/services/q3_explanation_data_test.dart`: quote / section / page / id passthrough (MC and essay), wrongWhy or nothing,
  bin table only on a right answer, options table, old schema-2 records load, History/PDF source line. Break-checked against
  the old service and bank (5 of 7 fail on the old code; the 2 compatibility tests pass on both, as they should).
- Updated for the English R3 popup: `waste_quiz_popup_test.dart`, `control_layout_test.dart` (R2 sizes incl. portrait), `elios_layout_test.dart`.
- `flutter test`: +1186 ~20 -2 (only the 2 known `elio_tokens_test`). `flutter analyze`: 1 pre-existing info. Secret scan clean.

## Phone (Motorola Edge 60 Fusion, USB, debug APK 8f92773 family, tester flags, `SCAN_RECORDS_FILE=scan_records_q3test.json`)
- **Data safety.** Before: `scan_records.json` (27 records, sha256 53b5e2ca…) and `scan_records_r3test.json` (2 records the owner
  made with the R3 test build this morning, sha256 50234058…) backed up outside the repo; `scans/` listed. Home showed 0 scans
  (the empty Q3 store) before testing. After: both files byte-identical, `scans/` unchanged. Found: the R3 test build had written
  this morning's photos into the shared `scans/`; test builds now keep photos beside their own file (`scans_<file>/`).
  The Q3 test file and its exported PDF were deleted at the end. Signed-in owner account (no guest login exists).
- **Settings touched and restored:** camera source (Phone camera → MaixCAM2 for Control → Phone camera), Save as default config
  off for 127.0.0.1, theme (light → dark → light). Quiz source stayed Question bank.
- **Robot:** fake_maixcam (one_Plastic) over `adb reverse`; removed after. No real robot.
- Gemma model: moved out of `assets/models/` for each of 2 builds and back; no copy made. Logs in `logs/`, shots in `phone/`,
  Figma pairs in `side-by-side/`, a cold-start recording `phone/scan_coldstart.mp4`.

### Timings (tester log, `logs/gemma_timings.txt`)
| Step | Time |
|---|---|
| Model load, cached | 12.2 s |
| Model load, first after reinstall | 109.9 s |
| Identify (camera photo) | 41.0 s, 41.8 s; 23.0 s in Control |
| Question (Gemma, tester build) | 28.3–36.7 s; thermal SEVERE |
| Essay grade | 23.8 s |
| Coach chat reply | 43.8 s |

### Results
| Check | Result | Evidence |
|---|---|---|
| Camera cold start: skeleton → model loading (indeterminate) → ready, light and dark | pass | `light_scan_model_loading`, `light_scan_ready`, `dark_scan_*`, mp4 |
| Switch camera (back → front, chip follows) | pass | `light_scan_switch_camera_front` |
| Scan → popup skeleton → identify loading with timer and steps | pass | `light_quiz_skeleton_capture`, `light_quiz_identifying` |
| Identify a real item | not possible: no waste item in front of the phone; Gemma ran (41 s) and returned "not recognised" (ceiling, bed cover) | `light_scan_not_recognised_result` |
| Minimise during loading → Quiz Waiting → badge when ready | pass (camera and Control) | `light_quiz_minimised_waiting`, `light_quiz_button_ready`, `dark_control_*` |
| "Question ready" TTS when minimised | not verified: no audio check | |
| "Not this?" picker → new item → new question | pass | `light_not_this_picker`, `light_quiz_question_gemma` |
| MC right (Test mode item, Gemma question) | pass | `light_review_right`, `dark_review_right` |
| MC wrong: sad buddy, locked medal +0, strike-through, options table; no wrongWhy heading (none written) | pass | `light_review_wrong*` |
| Essay input (restyled), keyboard, grading 23.8 s, Score 10/10 review | pass | `light_q2`, `light_essay_typing_keyboard`, `light_review_essay` |
| Chat ask → Gemma reply at the bottom; Listen → "Playing"; Copy | pass; Copy tapped, clipboard not read back | `light_review_chat_reply`, `light_review_chat_playing` |
| Listen to explanation, Read it to me | pass (TTS engine started) | |
| Document scrolls (bin table highlighted) | pass | `light_review_scrolled` |
| Next question, Finish quiz → result, record in the test store | pass | `light_quiz_finished` |
| Export PDF (share sheet; not sent) | pass | `light_pdf_share_sheet` (targets hidden) |
| Reopen in History | pass (1 test record, 30 trophies) | `light_history_from_scan` |
| Hazardous confirm (Baterai bekas) → Continue quiz | pass | `dark_hazard_confirm` |
| Control: STOP from the loading popup (fake: STOP + 0,0), GO sends nothing, drive after GO | pass | `logs/control_fake_log.txt` |
| Control: STOP from the review popup | pass | same log |
| Control: popup skeleton on the phone | not captured: it lasts a frame in Control; widget tests only | |
| Bank question with quote, section and page on the phone | not shown: the tester build serves Gemma questions; widget and unit tests only | |

## Visual differences from Figma
| Difference | Fix or reason |
|---|---|
| Camera corners sit above the video centre (on 800x360 the top corners are cut) | Kept: the corners mark the unchanged identify crop (0041/0070), centred in the old 240 dp panel |
| "LIVE" without fps on the camera chip | The phone preview reports no frame rate; no invented number |
| Loading has 3 steps, not 4 | "Checking the answer" is not a separate event in the code (decision 0175) |
| Skeletons are static (no shimmer) | Not done |
| Result card ("Quiz complete", "Scan belum berhasil") is the older Indonesian card, white in dark | Not in the Q3 frames; kept as is |
| History's explanation is the older layout (now with quote and source) | Not in the Q3 frames |
| Text uses the theme font (Inter) | The theme does not ship Google Sans Flex |
| Glow Scan button, medals and bin icons drawn in code / reused SVGs | Flat, token colours; the bottle buddies and the ELIOS AI badge are exported SVGs |
