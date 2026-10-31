# Changelog

All notable changes to ELIOS are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Milestones (M0 to M7) refer to the [Notion plan](https://app.notion.com/p/ELIOS-3f29675ed4f3800abef3fbb7daefe405).

Commit hashes below are from this repo's pushed history. The original local
history (which held committed API keys) was cleaned before the first push;
hashes updated after the history rewrite on 2026-10-08. The old-to-new map is
kept outside the repo.

## [Unreleased]

- Sidebar drawer rebuilt from the N1 Figma with a Dark mode switch (behind the dark mode option); behaviour unchanged (decision 0141).

- Home screen restyled to the H1 Figma design in light and dark (tokens, 48 dp targets, two columns from 840 dp); behaviour unchanged (decision 0140).

### Changed
- Design file font (decision 0091, draft): `docs/design.md` switches from JetBrains Mono and Inter to Google Sans Flex (headings, UI) and Google Sans Code (code), and the Status Chip is redefined in the MUI style. The corner radii follow the Material 3 scale with continuous corners (buttons and chips pill, inputs 12, cards 16, dialogs 28). Design only; the app still bundles the old fonts and uses the old 4px radii.

### Added
- E1 (decision 0041): "Bukan ini?" picker to correct a misnamed object (quiz and History use the corrected item, the photo is kept, B3 still asks for confirmation); Gemma loads in the background when the phone scan screen opens in the tester build; the tester build keeps the model loaded after the scan screen closes (about 1.6 GB); the identify photo is capped at 512 px, the prompt is shorter and drops the can example; the tester log adds the photo size and `queryMs`.
- Accepted-only question banks (decision 0060, PR #53): release and profile builds serve accepted items only; debug builds also serve drafts. Rejected, missing and unknown statuses are never served; bundled assets still contain all statuses.
- Separate History/PDF photo crop (decision 0070, PR #52): use the paired clean frame with a 5% margin per side, native pixels and JPEG quality 100. The identification crop is unchanged; existing supplied crops are retained when a separate clean photo is unavailable, and legacy photos are not rewritten.
- Android tester build (decision 0040, A1): `--dart-define=TESTER_BUILD=true` shows a Bank/Gemma source switch and a log panel; the model is sideloaded with adb push (not in the APK); lazy Gemma load; thermal gate pauses at CRITICAL; system-kill notice on relaunch; phone camera reads the YUV image stream and encodes JPEG in an isolate.
- Debug history seeding now preserves existing disk records and avoids duplicate samples.
- U4b native acceptance: clarify that keyTerms is an integer score, and include essay questions in the completion-message denominator.
- U4b essay grading: strict Gemma JSON parsing for the Accuracy /4, Key terms /3,
  Completeness /2, Clarity /1 rubric; consistent totals drive trophies, saved review,
  and PDF export, with score-only or pending fallback and no generated rubric rows.
- U4 quiz explanation overlays, local review history, and PDF export (decision 0031):
  - Question-by-question explanation lifecycle: `Question -> Answer submitted -> Result -> Detailed explanation -> Next question`.
  - Full-screen multiple-choice explanation overlay matching Figma node 96:130 with result banner, scrollable explanation page, comparison table, learning takeaways, and companion assistant chat.
  - Full-screen essay explanation overlay matching Figma node 96:246 with student response, score out of 10, rubric breakdown table (`Table 1. Scoring breakdown`), and improvement feedback.
  - Backward-compatible persistent schema version 2 storing structured `QuizExplanation` inside `RecordQuestion` in local storage (`scan_records.json`).
  - Scan History review (Figma node 100:170): inline "Lihat Penjelasan" expand toggle to reopen original saved explanations without re-querying AI models; accurate "Tersimpan lokal" status indicator.
  - Multi-page A4 PDF export service (`QuizPdfService`): generates professional educational reports with session metadata, question breakdown, comparison tables, and essay rubric breakdowns; accessible via "Export PDF" buttons in quiz result card and history details.

### Added
- G2b arm HOME, height control and debug overlays (decision 0027):
  - `RobotController.home()` sends `{"cmd":"HOME","seq":n}`; `SimulatedRobot` models 2-second travel to `[0.0, -42.5, 90.0]` and ack/motion_done sequence.
  - Parsed `ee_mm` and `at_home` from `STATUS` reply into `RobotState` and Riverpod `robotControlProvider`.
  - Student screen ARM HEIGHT slider wired to `servo part=height` (hand ±Z) via MotionGate instead of elbow, with neutral 90. Lateral control disabled.
  - `HomeButton` widget with 1-second hold-to-confirm and visual progress feedback on student top bar; instant `HOME` button in Debug Scan sheet.
  - Routed through `MotionGate`: blocked while STOPPED (not in `_allowedWhileStopped`), ignored during R1 SORTING, and hand-pause applies (`Human_Hand` -> `HOLD`).
  - Debug overlay displays tag chips for AprilTag IDs 0 and 1 only when detected with distance in mm, and real-time end-effector XYZ coordinates from `ee_mm`.

### Fixed
- U4 acceptance: paginate long PDF answers/explanations, keep unavailable essay grading pending with zero trophies across review/export, and preserve merged G2c HOME/history fixes.
- G2c acceptance fix: STATUS can update EE coordinates or invalidate HOME, but cannot confirm HOME or reset sliders; matching successful HOME completion remains the only confirmation path.
- G2c: HOME completion semantics, STATUS polling, and ScanRecordStore persistence:
  - Strict HOME completion: slider cache reset (reach=90, height=90, gripper=0) and `atHome: true` only occur upon matching successful `motion_done` sequence. `ack` alone marks accepted but does not claim completion. Handled errors, STOP, disconnects, and timeouts without claiming home completion.
  - Send debounced STATUS requests (~300 ms) after reach/height drag ends and immediately upon `motion_done` to keep `ee_mm` and EE xyz overlay display current; properly cleared stale coordinates on null/unavailable `ee_mm` or link loss.
  - Fixed `ScanRecordStore` persistence and serialized concurrent operations (`load`, `addRecord`, `clearRecords`, and disk writes) to prevent race conditions and data loss across rapid writes and app restarts.
  - Scan History UI fixes: changed sync badge and card subtitle to "Tersimpan lokal" and ensured difficulty chips display dynamic question count (e.g. `Easy · 2Q`).
- G1c: STOPPED never shrinks camera. In `control_layout.dart`, camera retains a minimum width of at least 240 px and identical dimensions with and without STOPPED across all test viewports and Mac window heights (480–640 px). Banner height is absorbed by controls spacing and scrolling rather than squeezing the camera.

### Added
- U2 result card, trophies, "Scan lagi", and saving into Scan History (decision 0030):
  - Result card on quiz finish: item name, category badge, "x dari N benar", trophies earned (+20 Piala),
    grade badge (Sempurna, Hebat, Bagus, Belajar Lagi, Coba Lagi), cumulative level & progress bar,
    and action buttons ("Scan lagi" and "Tutup").
  - Persistent ScanRecord generation with JPEG crop photo saved to documents directory, added to
    `ScanRecordStore.instance` upon session completion. Updates HistoryPill live count and history screen.
  - Live scan state machine `waitingForRescan` state: pauses locking while result card is displayed;
    "Scan lagi" re-arms scanning while preserving decision 0020 absent-to-rearm cooldown on quizzed items.
  - Debug "forget everything" action in Debug Scan sheet resets quizzed memory and state immediately.
  - R1 drop gating: when `--dart-define=R1=true`, displays "Robot sedang membuang ke tempat sampah..."
    and disables "Scan lagi" until R1 DROP motion completes and returns to idle.
  - Log events: `session_result` `{correct, total, trophies}` and `rescan_tapped`.
- G2a arm protocol (decision 0027): HOME, Cartesian reach/height controls, disabled lateral axis,
  six-field ESP32 servo line, boot/home assumptions, STATUS pose fields, and measured arm-tag poses.
  The fake now homes all five joints, reports simulated `ee_mm`/commanded `at_home`, and applies
  the simulator's effective hardware limits.
- H1 scan history, trophy rules, and student levels (decision 0028, Figma 100:170):
  - Pure trophy rules (`lib/models/trophy_rules.dart`): 10 trophies per correct answer, essay score
    awarded directly, grade percentage thresholds (Sempurna, Hebat, Bagus, Belajar Lagi, Coba Lagi),
    and 5 student levels (Lv1 Eco Starter 0-99, Lv2 Waste Spotter 100-249, Lv3 Bin Expert 250-499,
    Lv4 Eco Sorter 500-999, Lv5 Planet Guardian 1000+) with fractional level progress.
  - ScanRecord model and local JSON store (`lib/services/scan_record_store.dart`) persisted to
    app documents directory with sample data seeder for debug mode.
  - Scan History screen (`lib/Screens/scan_history_screen.dart`): responsive layout (side-by-side on
    wide viewports >= 750 px, list then detail on mobile), trophy progression bar, "Lokal" sync chip,
    category filters (All, B3, Recyclable, Organic), photo thumbnails, difficulty chips, and detailed
    question cards highlighting student vs correct answers.
  - History pill on control screen wired to real trophy count and opens scan history screen.
- G1 manual arm controls: ARM REACH moves the hand along ±Y without turning J1 or panning the
  camera; a debug-only Base ◀ ▶ nudge remains available. Added 0–100 gripper-width control,
  with PICK UP closing and RELEASE opening. The opt-in `G1_PICKUP_QUIZ_FLOW` starts the quiz
  when PICK UP is pressed; the default live-scan lock behavior is unchanged.
- G1b fixes: PICK UP crops from the `CapturedFrame` paired with its lock, not a later preview
  frame, and compact desktop layouts preserve the camera's minimum width while STOPPED.
- L1 fake MaixCAM2 robot motion: simulator-backed PICK / MOVE_TO_BIN / DROP with IK and 60 deg/s
  joint stepping, carried-card/gripper behavior, motor-driven base motion, servo-driven arm
  motion, and five R1 scenarios.
- E1 emergency stop (decision 0026):
  - A large red STOP button, plus Escape (and space outside text fields). It sends 0023 STOP
    and motor 0,0 (repeated), and R1 takes its safe exit.
  - STOPPED blocks every motion until "Lanjutkan".
  - One `MotionGate` for the D-pad, the sliders and the gripper (STOPPED, drive lock, link, R1
    sorting), with a blocked count in the debug overlay.
  - Motor 0,0 on D-pad release, screen leave, app background and every disconnect.
  - A link loss means STOPPED, and STOP + 0,0 first on the reconnect.
  - The app sends HEARTBEAT at 4 Hz.
  - The firmware watchdog spec (MaixCAM2 1 s, Uno 500 ms, ESP32 hold, physical e-stop).
- J1 guard (0020): while the arm moves (the app's servo sends, or the new per-frame
  `arm_moving`) and for ARM_SETTLE after, the live scan neither locks, re-arms nor counts
  absence. Quizzed objects are found again by label afterwards, so a J1 sweep no longer repeats
  a quiz.
- Fake MaixCAM2: HEARTBEAT, a simulated 1 s watchdog log, and `arm_moving`; scenarios
  `two_same_class` and the owner's `all_classes`.
- T1b fake MaixCAM2:
  - `make_crops.py` writes tight per-class crops from the training set (9 × 20 with the default
    seed).
  - Cards show a crop, else a whole photo cut to 4:3, else a text-free placeholder; the aspect
    is never stretched, and `size_mm` is the longer side. The photo choice is seeded and logged.
  - Nearer cards hide farther ones: more than 60 % hidden means no box; partly hidden means a
    reduced box.
  - Loading a scenario warns about events before 25 s and same-spot swaps under 8 s.
  - Scenarios: the six timed ones were fixed; added `organic_items`, `organic_mango` and nine
    `one_<label>` (decision 0024).
- R1 orchestration (`lib/services/robot/`, decision 0023): a platform-independent state machine
  SEARCHING → … → RESUME with every timeout. Driving is locked in the app and by `LOCK_DRIVE`;
  pick done needs motion_done and the object off its floor spot; Human_Hand pauses the arm;
  locks are ignored while sorting and settling; every exit stops the arm if needed and unlocks
  driving. `RobotController`, `MaixCamRobot` (0023 messages), `SimulatedRobot`, `ArmFeedback`
  and `ObjectIdentity` are included. In the app, only behind `--dart-define=R1=true`: a link
  probe and "robot tidak terhubung" in the debug overlay. The student flow is not on screen
  yet (M4).
- The fake MaixCAM2's command hook speaks 0023 (`seq`); it answers STATUS, LOCK/UNLOCK_DRIVE,
  HOLD and STOP.

- T1 fake MaixCAM2 (`tools/fake_maixcam/`): a Python WebSocket server with `main.py`'s protocol,
  rendering frames through the owner's robotic_hand_sim (`--sim-path`, not copied), with
  ground-truth detections, optional noise and P1 fields (`--old-firmware` turns them off), 10
  YAML scenarios, a label check against `main.py` and the app (no mismatch), and an R1 command
  hook (HOLD, J1_SWEEP; the rest TODO). No app or firmware change (decision 0024).
- P1 detection protocol: optional per-detection `track_id`, `dist_cm`, `lateral_cm` and
  per-frame `arm_tags` are parsed as nullable (`Detection`, `ArmTag`,
  `WebSocketService.armTags`). Missing or malformed values are null; old firmware is unchanged.
  `track_id` fills the stabilizer's `trackId` slot, but the live scan keeps box overlap for
  identity (`matchTrackIds: false`). Nothing uses the fields yet. Firmware distance/tag spec and
  robot topology in decision 0022; decision 0021 amended (`PICK_BAND_CM` 20-28, pick-done rule,
  J1 camera rule, topology, plan 2.6 superseded).
- M2d lock diagnostics (debug only): one rolling JSONL per app run with cooldown, re-arm,
  blocked-reason, candidate, too-large-box, below-min-score and busy events (rate-limited,
  `appCommit` on every line); the overlay shows why nothing locks and has a "Scan lagi" button
  (disabled while a quiz is open) (decision 0020).
- Debug-only question-source switch ("Bank soal" / "Gemma") under the LIVE_SCAN
  debug overlay, saved in app preferences; applies from the next scan. Release
  builds always use the bank; `GEMMA_QUESTIONS` now only sets the initial value.
  Gemma mode falls back to the fixed questions, never to the bank. The header
  reads "SOAL GEMMA" for Gemma questions, and every question logs one
  `question_source` line (source, item, object, pool, ms from scan, fallback)
  (decision 0018).
- M3.5 object bank `assets/quiz/object_bank_draft.json`: 13 objects (ponsel,
  laptop, perangkat elektronik, baterai, lampu TL/CFL, botol plastik, gelas
  plastik, toples kaca, kaleng aluminium, kardus, kertas, kulit pisang, kotak
  susu) with synonyms, 3-4 MC and 1 essay each, every item quoting the module.
  Owner review sheet `docs/quiz-review/object_bank_review.md` (decision 0017).
- Module tables 1.6, 2.6, 2.7, 2.9 and 4.7 are also extracted as one sentence
  per row (`rows`), checked against the PDF.
- M3.3 draft question bank `assets/quiz/question_bank_draft.json`: 56 items
  (7 pools x 6 multiple choice + 2 essays), each with a verbatim module quote,
  chunk id and PDF page; `scripts/validate_bank.py` checks them. Owner review
  sheet in `docs/quiz-review/question_bank_review.md`. Not bundled, not used by
  the quiz (decision 0015).
- M3.2 course module chunks: `scripts/extract_module.py` (pypdf, no network)
  turns the module PDF into 66 traceable chunks in
  `assets/module/module_chunks.json` (sub-chapters, summaries, Q&A, glossary,
  sources; PDF page, printed page, verbatim text). `assets/module/label_to_chunks.json`
  maps the 9 detector classes to bin, chunks, coverage and evidence. Bundled,
  not yet used by the quiz (decision 0014).
- M3.1 real-model quiz temperature test
  (`integration_test/quiz_temperature_test.dart`): 5 fixed prompts at 0.9 /
  0.4 / 0.3, logs valid JSON, option count, one correct key, duplicates, empty
  fields and duration per attempt. Results in `docs/test-results/m3-quiz-parse.md`.
- M2c detector-vs-Gemma category gate: when the detector class's bin differs
  from Gemma's raw category (residu counts as anorganik), no quiz runs until the
  user picks "Pakai detektor", "Pakai Gemma" or "Scan ulang". Hazard
  confirmation still wins. Each mismatch is logged as a hard example
  (`category_mismatch`, then `mismatch_choice`) with appCommit, frame, detector
  class/score, raw Gemma item/category, bins and the identify JPEG name.

### Changed
- U1: the Control screen follows Figma 43:30 (decision 0026 amendment): Exit, Debug Scan (debug
  builds) and History (placeholder trophy count) on top; arm height, D-pad, camera with PICK UP /
  RELEASE, the vertical speed slider with STOP under it, arm reach. Under 1100 px the camera
  (4:3) sits left of the controls and takes the space they leave; at 770x553 everything fits on
  one screen. Phones and windows that must scroll pin STOP bottom right. The quiz header has its own STOP. The
  ELIO leaf reopens a minimised quiz (was "Kuis AI"). The debug panel moved to the Debug Scan
  side sheet; "Scan lagi" is now "Reset scan (debug)".
- The control screen's D-pad, sliders and gripper buttons no longer send directly; the
  `RobotControlNotifier` setters only keep slider state (decision 0026).
- The question-source switch is no longer saved: every launch starts on the bank (0018
  amendment; the 24 Oct "Gemma" start came from a value saved in an earlier debug session).
- After a link drop and reconnect, the live scan forgets the quizzed objects of closed quizzes
  and resets the stabilizer, so a new object at the old spot can lock (0020, "Link drop").
- Live-scan re-arm (decision 0020): after the 15 s cooldown an object with a different label may
  lock while other objects stay in view; the same label waits until the quizzed object has been
  absent 2 s, and the quizzed object held in view is never asked again. Replaces the 2 s
  empty-scene rule and the 30 s same-label wait.
- Gemma question mode asks about one physics angle per question (density,
  heat, recycling energy, decomposition, electricity, UV, physical sorting,
  handling safety), chosen in code, fitting the object's bin and never repeated
  in a session. The level texts lost their "life-cycle assessment" example;
  replies mentioning LCA, siklus hidup or ekonomi sirkular are rejected and
  retried with another angle, then fall back to the fixed questions. The
  angle is logged per question (decision 0019).
- Quiz questions now come from the pre-written bank: the object's own, then
  its label pool, then fixed fallbacks. No question request goes to Gemma by
  default; Gemma only identifies the object (and grades essays when on).
  `--dart-define=GEMMA_QUESTIONS=true` restores generated questions, and
  `--dart-define=ESSAY_QUESTIONS=true` restores essays (both off). A session
  never repeats a question and ends early when none is left. The quiz header
  names the bank instead of Gemma. `scripts/validate_bank.py` also rejects
  source wording ("kutipan") and mixed units, and warns on true-looking wrong
  options (decision 0017).
- Multiple-choice questions now ask Gemma for `{"correct": "...", "wrong": [3 distractors]}`
  instead of 4 `options` plus `correctIndex` (decision 0013). The answer key is
  the `correct` field, so a 4th distractor is dropped safely; a distractor equal
  to the answer, an empty or non-string `correct`, or fewer than 3 distinct
  distractors is still rejected. Production temperature unchanged (0.9).
- Docs: HANDOFF records the 16 Oct real-model `gemma_cancel_test` run (4/4 passed) and two open findings (5-option quiz parse failures, 7-9 s image first token).
- M2c merged into feature/live-scan by PR #17 (4de8947) after the owner's manual retest on 16 Oct; open hardware gaps are listed in docs/HANDOFF.md.
- Firmware: `firmware/maixcam2/app.yaml` (MaixVision manifest) is tracked; the
  packaged zip in `firmware/maixcam2/dist/` is ignored as a build output.
- Docs: decision 0012 states the canonical three-bin policy and the mismatch
  gate; the module-grounded quiz plan requires page/section citations (planned).

### Fixed
- E1b (decision 0026):
  - STOP no longer covers the quiz's close/minimise buttons. STOP, the D-pad and the debug
    panel live in their own rail (right in landscape, bottom in portrait), and the STOPPED banner
    is a full-width strip on top. Tested at 800x632, 390x844 and 1024x768.
  - The "STOP" label no longer wraps.
  - While STOPPED the live scan no longer locks, identifies or opens a quiz (a reconnect
    re-quizzed the same bottle); an open quiz stays usable. `scan_paused` / `scan_resumed` are
    logged.
  - The fake MaixCAM2 logs every command, including STOP (with seq) and a rate-limited heartbeat
    line.
- The lamp bank object (`lampu_tl_cfl`) has `"label": "E_Waste"` again, so it is served on
  E_Waste boxes (decision 0025's side effect).
- Bank questions in a live scan follow the detector class, not Gemma's words. A Plastic box that
  Gemma called "Label" (kertas) got a paper question on 24 Oct; it now gets the plastic pool.
  `ScannedWaste.detectorLabel` carries the class. A bank object is used only if its `label` is
  that class. A same-bin class disagreement is logged as `class_mismatch` (no card). The Gemma
  question prompt names the detector class next to its category hint. The debug overlay shows
  Gemma's item and the detector class (decision 0025).
- The quiz type chip no longer says "Essay" on multiple-choice questions when
  essays are off.
- M2c cancel (16 Oct retest, scan 0): a close while the model is still loading
  no longer submits the photo (`submit_skipped` is logged instead). A call
  already running has its result discarded and keeps the Gemma slot busy until
  it really ends (capped at 8 s), so the next request never overlaps it.
- A user close is logged as `failure: cancelled` (not "AI belum siap…") and the
  live-scan overlay no longer shows ASK FAILED for it. Real failures unchanged.

### Added
- M2c traceability: every m2c-diagnostics JSONL record carries `appCommit`
  (`--dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`; `unknown` if unset).
- M2c debug diagnostics: locally saved exact vision input and correlated JSONL
  traces for frame/box/crop geometry, identification JSON, resolved hazard,
  crop/identify/question timings and lock-to-question latency. Artifacts stay
  in app support and are gitignored; release builds do not write them.
- M2c: live robot locks send their same-frame bounding-box crop to Gemma
  identification before generating a quiz. The popup shows “Looking…” while
  identifying; hazardous items require “Lanjut kuis” or “Scan ulang”. A B3
  classification from either detector or Gemma is preserved. All ten
  MaixCAM2 classes have explicit Indonesian names and categories (the hand
  stays ignored). Invalid crops/unrecognized images stop without a
  detector-label quiz; dismissed results cannot reopen a session. Live scan
  now preloads the image encoder. Decision 0012.

### Fixed
- Three-bin routing explicitly sends nonhazardous Gemma `residu` to inorganic,
  independent of item keywords. Raw model category is retained separately from
  the destination; detector/model/item hazard evidence still forces B3. Residu
  quiz context describes the compartment without claiming recyclability.
- M2c: Gemma crops paired clean camera pixels, never the annotated preview.
  Prepared MaixCAM2 firmware encodes originals before drawing, sends clean
  images only on nonempty fresh inference frames, and reports frame IDs/hash.
  Preview and controls remain compatible with old firmware; clean identification
  requires the update and otherwise shows a firmware notice. Not yet deployed
  or hardware-validated. See decision 0012 and firmware/maixcam2/README.md.
- M2b part 3 (PR #16 robot-test follow-up): tapping "Soal berikutnya" or
  skip no longer lets a still-playing voice (an answer verdict, essay
  grading, or chat reply) keep talking over the next question — both now
  stop TTS first, the same way closing the quiz already did. Found by
  analysing the PR #16 robot recording. Decision 0010 updated.
- M2b part 2 (PR #15 review): `GemmaQuizService.cancel()` and the
  "user request cancels an active scan" path now release the cancelled
  caller *before* awaiting the native stop, not after — a cancel during
  prefill can otherwise take up to 6 s to land (decision 0003), holding the
  caller up by that much. `_stopGeneration()` is now capped at 2 s so a
  hung native stop can't hang this either; a new `_stopInFlight` keeps the
  slot from starting a new generation until the old stop settles or times
  out, without holding up the cancelled caller itself. Decision 0003
  updated.

### Added
- M2b part 3: questions 2-N of a quiz session are now prefetched in the
  background, one at a time through the single Gemma slot, as soon as
  question 1 shows — "Soal berikutnya" takes the next one instantly instead
  of generating on tap. A user chat message or essay grading still takes
  priority (decision 0003): it pauses the prefetch, which resumes after and
  retries indefinitely rather than ever falling back — closing a bug where
  chatting during a quiz could turn questions 2-4 into "SOAL CADANGAN (AI
  ON-DEVICE BELUM SIAP)" even though the model was fully loaded and simply
  busy with the chat. A near-duplicate of an earlier question in the same
  session is rejected and retried; an unparseable background reply is
  retried too (both bounded, same 2-attempt budget `generateQuestion`
  always had). Closing the quiz cancels any in-flight prefetch and clears
  the buffer. Debug builds log the wait per "Soal berikutnya" tap (0 when
  served from the buffer); the overlay adds `next N ms`. Decision 0011.
- M2b part 2: the quiz now speaks the same auto-reply at most once per
  object (two chat messages sent before answering, for example, used to
  both trigger the identical reply and speak it twice); the manual
  "Listen" button is unaffected. The debug overlay adds `tts N`
  (utterances started), so a silent recording still shows TTS activity.
  The overlay's `first token`/`question` times no longer show the
  *previous* quiz's numbers while a new one is asking, or after a fallback
  question / failed generation that never streamed a token — both reset to
  "-" the instant a new ask starts. `GemmaQuizService.cancel()` now awaits
  `stopGeneration()` and logs (not throws) on failure, instead of firing it
  without awaiting. The stabilizer, state machine and controller default to
  a monotonic clock instead of wall-clock `DateTime.now`, closing a gap
  where only the production wiring (not the defaults themselves) was
  protected from a system clock change. Debug builds log one line per
  question load (label, index/total, type, load time, first token,
  fallback) so a slow question like the 11.3 s one in an earlier robot
  recording shows up without needing the overlay on screen. Decision 0010;
  decision 0003 updated for the `cancel()` change.
- M2b part 1: the MaixCAM2 video stream no longer stops when a quiz opens
  (it used to send `stop_stream`/`start_stream` around every quiz, which
  showed as the camera badge dropping to 0.2-0.4 fps for about 3 s after
  each close while it reconnected). The live-scan state machine already
  refuses to lock or ask during ASKING/QUIZ, so nothing new can be asked;
  only presence tracking and the preview keep running. Gemma now preloads
  when the live-scan control screen opens (`GemmaQuizService.warmUp()`), so
  the first quiz usually skips the "Memuat model Gemma ke memori..." wait;
  a failed preload falls back to loading on the first quiz, as before. The
  debug overlay adds the ASKING-to-question time next to first token.
  Decision 0009.
- M2a: live scan for the robot path, behind `--dart-define=LIVE_SCAN=true`
  (off by default; without it nothing changes). The detection stabilizer
  and a state machine (SEARCHING, LOCKING, ASKING, QUIZ, COOLDOWN) start
  one quiz per object. Locks during ASKING and QUIZ are dropped. A failed,
  busy or cancelled ask goes back to searching without a retry loop. It
  keeps the 0.55 score filter, ignores `Human_Hand`, and uses a monotonic
  clock. Debug overlay with state, fps, identify calls and first-token
  time. Decision 0008. Robot frames still don't reach Gemma's identify
  (planned for M2c).
- M1: detection stabilizer (`lib/services/detection_stabilizer.dart`, decision
  0007). It gives one lock per object: the same object held for 1.0 s (track id,
  or same label with box overlap of at least 0.65). Absences up to 600 ms keep
  the timer (one missed frame at 2 fps). A locked object re-arms after 1.5 s
  missing; a new label must hold 1.0 s before it replaces the lock, so a
  one-frame label flicker doesn't lock twice. A frame gap over 1.5 s drops an
  unlocked candidate but keeps a lock. It takes configurable ignored labels.
  Pure logic with 36 unit tests. Not wired into the app yet (M2); the
  parameters are provisional until tuned on a device.
- M0: stage 2 proven on the real model (macOS, Debug build), on
  `feature/live-scan` through PR #2. Includes a real timing table.
  `stopGeneration` stops decoding 2–38 ms after a cancel over 72 trials;
  a cancel during prefill takes effect only when prefill ends (known
  limit); an earlier 15-minute stall was the Mac sleeping (test
  environment). See decision 0003. The BUSY and user-request slot rules
  hold. Full `flutter test` passes except the 2 known stale widget tests.
  The stage 2 commit is documented, not split (0004); M0 findings are in
  0005.
- Stage 2: single Gemma slot, streaming and cancellation (`5289c8b`).
  Tested with a mock only at the time. Real proof is milestone M0 (above).
- Stage 1: `FrameSource` interface with `PhoneFrameSource` and
  `MaixCamSource` (`46eb5cc`). Analyze is clean and the macOS build works.
  Not run on a phone or a real robot yet.
- Stage 0: snapshot baseline before the live-scan work (`9fc7239`). Removes
  old planning docs, the UDP discovery and Wi-Fi provisioning providers and
  the hotspot wrapper (confirmed intended).
- Repo setup (M7): `.gitignore` for keys, signing files and the model;
  Firebase config templates; README; this changelog; pull request template;
  pipeline map; decision records; secret check with a pre-push hook.

### Changed
- `GemmaQuizService` exposes a read-only `lastFirstTokenMs` (for the M2a debug
  overlay); no behaviour change.
- `android/app/google-services.json` is no longer tracked. Use the template
  and the README "Firebase setup" section.

### Removed
- Temporary debug double-decoding block in `websocket_service` (`eb08ab3`).

### Fixed
- Live scan's "don't re-ask the same object" wait could be lost mid-quiz:
  the debug overlay reading the wait on every rebuild silently expired it
  once a quiz ran longer than 30 s (the camera pauses during a quiz, so the
  label's last-seen time never refreshed). Reading the wait is now a pure
  read; a wait only ever expires between quizzes, never while one is open,
  however long it runs.
- Live scan no longer re-asks the same object: a label that had a quiz waits
  until it has been out of the scene for 30 s (was 30 s from the quiz
  close). Any box of 0.50 or more (not a hand, not over 0.6 of the frame)
  now counts as "something in the scene", so a held item whose score dips
  under 0.70 no longer looks like an empty scene. A label that reached 0.70
  keeps its lock going down to 0.55, so items hovering at 0.55-0.69 lock in
  about a second. The debug overlay shows the waiting labels ("wait Plastic
  12s"). Decision 0008.
- Live scan no longer opens quiz after quiz: after a quiz closes, nothing is
  asked for 15 s and until the scene has had no lockable detection for 2 s,
  and the same label isn't asked again within 30 s. Any open quiz (also a
  minimized one, or one the live scan didn't start) shows QUIZ and blocks
  asks. Asks need a score of at least 0.70 (was 0.55), and boxes covering
  more than 0.6 of the frame are ignored. The debug overlay shows busy asks
  separately from identify calls. Decision 0008.
fix/detection-overlay
- Robot camera boxes: the app's detection overlay read the MaixCAM2 box
  centre as its top-left corner, so its box sat half a box down and right
  of the object. It now reads the centre. The MaixCAM2 already draws its
  box, mask and label into the video, so the app's overlay is no longer
  drawn over robot frames by default; it shows only in debug builds with
  `--dart-define=LIVE_SCAN=true`, next to the live-scan debug overlay.
- macOS builds with Xcode 27: the deployment target is 12.0 (was 10.15) for
  Runner, Flutter Assemble and every pod (Podfile `post_install`). Xcode 27
  rejects targets below 12.0.
- The robot connection uses the MaixCAM2 port 8765 by default (was 8080,
  where nothing listens). Saved settings with the old 8080 move to 8765; any
  other saved port is kept.
feature/live-scan
- A quiz left open on the robot screen no longer blocks detections the next
  time: `ControlScreen` dispose now dismisses the quiz popup (`008efae`).
- The macOS camera view swaps to a black box again when the quiz pauses it
  (`83c3bb8`).
- The 3D robot viewer loads in macOS release builds: `Release.entitlements`
  now has `com.apple.security.network.server`, needed for the viewer's local
  server on 127.0.0.1 (`d48d9ab`, decision 0006).
