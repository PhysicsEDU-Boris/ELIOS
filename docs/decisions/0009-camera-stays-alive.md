# 0009: The camera stays alive during a quiz; Gemma preloads (M2b part 1)

- Status: Accepted
- Date: 2026-10-14
- Milestone: M2b (Notion plan 1.2, stage 3b, second part)
- Code:
  - `lib/Screens/control_screen.dart` (stream wiring, Gemma preload)
  - `lib/services/live_scan_controller.dart` (ASKING-to-question timing)
  - `lib/widgets/live_scan_debug_overlay.dart`
- Tests:
  - `test/live_scan_controller_test.dart`
  - `test/widgets/live_scan_debug_overlay_test.dart`
  - `test/gemma_preload_test.dart`

## Context

Decision 0008 listed "camera pause during the quiz" as out of scope for M2a
("the camera still pauses while the quiz is open"). `control_screen.dart`
stopped the MaixCAM2 stream (`stop_stream` over the WebSocket) the instant a
quiz popup covered the screen, and restarted it (`start_stream`) on close.
The camera badge showed the cost of this: 0.2–0.4 fps for about 3 s after
every quiz closed, while the robot's stream reopened. The live-scan state
machine's presence tracking (decision 0008, "Presence, label wait and
hysteresis") and its wait-freeze fix (2026-10-14 commit) were both written
to keep working once frames resume during a quiz — this decision is what
finally lets them.

## Decision

### The stream never stops for a quiz

`control_screen.dart`'s only stop/resume mechanism for the MaixCAM2 path was
a `ref.listen<WasteQuizUiState>` block in `build()`: it called
`_robotNotifier.stopStream()` when the quiz phase left `idle` (and wasn't
minimized) and `_robotNotifier.startStream()` when it returned to `idle`.
That logic (and its "pause the video" comment) is removed; the listener now
only forwards the phase to `_liveScan?.onQuizPhase(...)`, which the live-scan
machine needs regardless (decision 0008).

**There is no other camera-stop code in this path.** Checked specifically,
per the task's three suspects:

- **"macOS: the camera controller is destroyed/swapped for a black box."**
  There is no native camera controller in the MaixCAM2 path at all — frames
  arrive as JPEGs over the robot's WebSocket, decoded with `Image.memory`.
  `CameraMacOSController` only exists in the **separate, unrelated** phone/
  device-camera scan screen (`device_scan_screen.dart`,
  `frame_source/phone_frame_source.dart`), which live scan doesn't use and
  this change doesn't touch.
- **"Android: `pausePreview()`."** Same answer: `pausePreview()`/
  `resumePreview()` exist only on `FrameSource` (used by the phone path);
  `MaixCamSource` implements them by calling `sendStopStreamCommand()`/
  `sendStartStreamCommand()`, but nothing in the live-scan/control-screen
  wiring ever calls `MaixCamSource.pausePreview()` — only the removed
  `ref.listen` block called `stopStream()` directly through
  `RobotControlNotifier`.
- **"MaixCAM2: the `stop_stream` command."** This is the one real mechanism,
  and it's what's removed. `control_screen.dart` still sends `start_stream`
  once, on connecting, and `stop_stream` once, on leaving the control screen
  entirely (`dispose()`) — neither is quiz-related.

**Robot firmware: does `stop_stream` also stop detections?** Yes. In
`elio_maixcam2.py`, `ws_frame_pusher()`'s entire body — the detector's
`forward_image`/`decode_seg`/`_update_lock` call **and** the frame push —
runs inside one `if ws_streaming and ws_clients:` block. Setting
`ws_streaming = False` (the `stop_stream` handler) stops both at once; there
is no way to keep detecting without streaming, or vice versa, in the current
firmware. Not changed in this PR (the app no longer sends `stop_stream` for
a quiz at all, so this doesn't need to change for M2b part 1).

### No "skip alternate frames" compromise needed

The task allowed, as a fallback, keeping the preview running but skipping
analysis on alternate frames during QUIZ if the "stream copy path" proved
too heavy. **Not needed.** All detection work happens on the MaixCAM2 itself;
the app only decodes an already-produced JPEG and reads an already-computed
`detections` list from each frame's JSON. `LiveScanController.onDetections`
is pure Dart math (score/area filters, the stabilizer, the state machine) —
nothing in the app's own per-frame path does image processing. So there is
no heavy client-side "analysis" to throttle, and every frame is processed
exactly as before, with no change to the anti-spam rules (0008).

### What this changes for the state machine

Nothing about the rules. The state machine already refuses to lock or ask
during ASKING or QUIZ (0008), and the wait-freeze fix (2026-10-14) made that
correct however long a quiz runs and whether or not frames keep arriving
during it. Continuous streaming during a quiz only means:

- the camera preview keeps showing instead of a 3 s stall after each close;
- presence tracking (`_lastSeen`) updates live during the quiz instead of
  only at the moment it closes;
- the robot's own detector keeps running the whole time (since detection and
  streaming can't be split on the firmware side, see above).

### Gemma preloads when live scan starts

`GemmaQuizService.warmUp()` already existed (`ensureReady(vision: ...)`
fire-and-forget, used by the phone-camera scan screen) but wasn't called for
the robot path. `control_screen.dart`'s `initState` now calls
`GemmaQuizService.instance.warmUp()` (no vision — the MaixCAM2 flow is
text-only, decision 0008's "Inputs") right after constructing the
`LiveScanController`, only when `liveScanEnabled`.

- **Doesn't block the UI or the camera:** `warmUp` is `void`, wraps
  `ensureReady` in `unawaited(...)`; nothing in `initState` awaits it.
- **Already loading or loaded: does nothing extra.** `ensureReady` is
  single-flight (`_readyFuture ??= ...`) and returns immediately if `_chat`
  is already set; calling `warmUp()` again (for example on a later visit to
  the control screen) is a cheap no-op once the model is ready.
- **A failed preload can't crash:** `_initialize`/`_install` catch every
  exception, set `progress.value` to `GemmaStatus.error`, and return `false`;
  nothing propagates out of `ensureReady`. The first quiz then loads exactly
  as before this change (showing "Memuat model Gemma ke memori…").

### Debug overlay: ASKING to question

`LiveScanController` records the clock time when a lock turns into a
successful ask (`startQuiz` returns true), and computes the elapsed time
once the question is shown (same moment `lastFirstTokenMs` is captured).
Exposed as `lastAskToQuestionMs`, shown in the overlay next to first token:
`first token 895 ms   question 9120 ms`. Same staleness note as
`lastFirstTokenMs`: only updates when a question actually shows, so it can
be stale after a BUSY/cancelled ask that's followed much later by a real one
with its own, different first-token time but a separately-tracked ask time —
both are captured at the same instant, so they can't go stale independently
of each other.

## Out of scope

- Hazard handling (M2b part 2, per decision 0008).
- Changing the robot firmware's `stop_stream` to split streaming from
  detection — not needed since the app no longer sends it for a quiz.
- The phone/device-camera scan path (`device_scan_screen.dart`) — unrelated,
  not touched.

## Consequences

- No camera badge stall after a quiz closes; the preview updates
  continuously, including while a quiz is open.
- The model should typically already be ready by the first lock, so the
  first quiz shouldn't show the loading message on a normal visit — not
  checked on the robot yet (see the PR's manual checklist).
- Continuous MaixCAM2 streaming now overlaps with Gemma generation the whole
  time a quiz is open, where before it didn't (the stream was paused for
  exactly that reason, "frees CPU and Wi-Fi for Gemma"). Not measurable
  without the device; flagged as a risk for the manual checklist.
