# Changelog

All notable changes to ELIOS are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Milestones (M0 to M7) refer to the [Notion plan](https://app.notion.com/p/ELIOS-3f29675ed4f3800abef3fbb7daefe405).

Commit hashes below are from this repo's pushed history. The original local
history (which held committed API keys) was cleaned before the first push;
hashes updated after the history rewrite on 2026-10-08. The old-to-new map is
kept outside the repo.

## [Unreleased]

### Added
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
