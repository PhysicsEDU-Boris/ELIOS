# Changelog

All notable changes to ELIOS are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Milestones (M0 to M7) refer to the [Notion plan](https://app.notion.com/p/ELIOS-3f29675ed4f3800abef3fbb7daefe405).

Commit hashes below are from this repo's pushed history. The original local
history (which held committed API keys) was cleaned before the first push;
hashes updated after the history rewrite on 2026-10-08. The old-to-new map is
kept outside the repo.

## [Unreleased]

### Fixed
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
