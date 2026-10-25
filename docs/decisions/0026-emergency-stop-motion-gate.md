# 0026: Emergency stop, one motion gate, link loss, heartbeat and watchdogs (E1)

- Status: Accepted for the app (built). The firmware parts are a spec: R1-fw, plus the ESP32 and
  Uno sketches, which are **not in this repo**.
- Date: 2026-10-24
- Builds on: [0020](0020-lock-rearm-rule.md), [0021](0021-manual-driving-orchestration.md) (e),
  [0022](0022-detection-protocol-distance-tags.md), [0023](0023-r1-command-link.md),
  [0024](0024-fake-maixcam-sim.md).
- Code:
  - `lib/services/robot/motion_gate.dart`;
  - `lib/Screens/control_screen.dart` (STOP button, keys, lifecycle, link hooks);
  - `lib/services/robot/r1_orchestrator.dart` (`emergencyStop`, `resumeAfterStop`);
  - `lib/services/websocket_service.dart` (motor 0,0 on disconnect, `arm_moving`);
  - `lib/services/live_scan_controller.dart` and `live_scan_state_machine.dart` (J1 guard, see 0020);
  - `tools/fake_maixcam/` (HEARTBEAT, watchdog log, `arm_moving`).
- Tests: `test/motion_gate_test.dart`, `test/live_scan_controller_test.dart` (J1 guard),
  `test/detection_protocol_test.dart`, `tools/fake_maixcam/test_fake_maixcam.py`.

## Why

Nothing could stop the robot:

- The app → MaixCAM2 → ESP32 (arm) / Uno (wheels) chain has no feedback, no heartbeat and no
  stop command, so the last motor or servo command stays in force when the app or the link dies.
- The D-pad and the arm sliders sent straight to the socket, with no check at all.

## The app (built)

**STOP button**

- A large red STOP on the Control screen (placement: see the U1 amendment below; an open quiz
  has its own STOP in its header). Escape triggers it too, and so does space when no text field has focus.
- Pressing it sends, at once, 0023 `STOP` (with `seq`) and `motor 0,0`, then `motor 0,0` four
  more times, 100 ms apart, fire-and-forget (the WiFi link is lossy).
- R1 takes its safe exit: `STOP` if the arm may be moving. Driving stays **locked**, and the
  student is told.

**STOPPED**

- Every motor, servo and R1 command is dropped, except `STOP`, `STATUS`, `HEARTBEAT` and
  `motor 0,0`.
- The button shows "ROBOT DIHENTIKAN" with the reason, and a **"Lanjutkan"** button: the
  deliberate second action.
- "Lanjutkan" also sends R1's `UNLOCK_DRIVE`; a reconnect alone never does.

**Log:** `emergency_stop {reason: button | link_lost | error}`, `emergency_resume`, and
`motion_blocked {kind, reason}`, in the live-scan JSONL (debug) and the console.

**One gate** (`MotionGate`): the D-pad, the PWM speed, the arm sliders and the gripper buttons
all go through it.

- It checks STOPPED, R1's drive lock (0023) and the link. R1 sorting also blocks manual servo
  commands.
- Dropped commands are counted in the debug overlay ("gerak diblokir N").
- A test fails if any file in `lib/` sends motor or servo commands around it.

**Motor 0,0 always goes out** (never gated, only lost without a link) on:

- D-pad release;
- leaving the screen;
- the app going inactive, hidden, paused or detached;
- every disconnect (`WebSocketService.disconnect` sends it before `disconnect`, which covers the
  config screen too).

**The D-pad sends once per press**: `motor L,R` on touch-down, and `0,0` on release or when the
touch is cancelled. Nothing repeats while it is held, so the robot drives on the last command
until the release arrives. See the Uno watchdog below for why the firmware must refresh it.

**Link loss**

- When the WebSocket watchdog or the socket reports the link gone, the app enters STOPPED
  (`link_lost`).
- On the reconnect, the first messages are `STOP` and `motor 0,0`, before the stream starts.
- STOPPED stays until "Lanjutkan".

**Heartbeat**

- `{"cmd": "HEARTBEAT"}` every 250 ms (4 Hz) while connected, also while STOPPED (it says the
  app is alive, not "move").
- It has no `seq` and gets no reply.
- Today's firmware ignores it: `ws_handler` in `main.py` is an `if/elif` chain with no `else`.
  The same holds for `STOP`, so **today the STOP button stops the wheels (`motor 0,0`), not the
  arm.**

## Firmware (spec)

| Part | Rule | Where |
|---|---|---|
| a | The MaixCAM2 accepts `HEARTBEAT` (no reply). Any app message counts as alive. | R1-fw (`main.py`) |
| b | **MaixCAM2 watchdog:** no app message for **1 s** → `0,0` to the Uno, and arm HOLD to the ESP32 (resend the current angles; **never** an empty field, which detaches a servo). Log it. Clear when messages return; the app then sends STOP + 0,0 anyway. | R1-fw |
| b2 | While the app is alive, the MaixCAM2 **resends the current wheel command to the Uno every ≤ 200 ms**. This keeps the Uno watchdog (c) from cutting a held D-pad press, and covers the D-pad sending once per press. | R1-fw |
| b3 | `STOP` (0023): stop sending new angles (the arm holds), wheels 0, abandon the running command; ack. Also on the client disconnect (0023). | R1-fw |
| b4 | Per-frame `arm_moving` (bool): true while the MaixCAM2 is still sending a motion's angles, from the 60 deg/s time it already computes for `motion_done`. | R1-fw |
| c | **Uno watchdog:** no wheel command for **500 ms** → wheels off. | Uno sketch (not in this repo) |
| d | **ESP32:** keep holding the last angles when commands stop; never detach on a timeout (the arm would drop). | ESP32 sketch (not in this repo; today's behaviour, keep it) |
| e | **A physical e-stop** (a switch cutting servo and motor power) for any arm test with people near. The software stop depends on WiFi, the MaixCAM2 and two UARTs. | Hardware |

## arm_moving (per frame, optional)

- `"arm_moving": true | false`.
- It is parsed like the P1 fields: anything but a bool counts as `null` (unknown, today's
  firmware).
- The app's J1 guard uses it, together with its own servo sends (0020).
- The fake MaixCAM2 sends it while J1 moves (`p1: true` only).

## Amendment 24 Oct (E1b): placement, scanning while STOPPED

Found on the Mac (800x632, fake MaixCAM2):

- STOP covered the quiz's close (X) and minimise buttons, so a student could not close a quiz.
- The STOPPED banner covered the chat.
- "STOP" wrapped as "STO" / "P".
- After a reconnect while STOPPED, the live scan quizzed the same bottle again.

**Layout** (`lib/widgets/control_layout.dart`)

- STOP, the D-pad and the debug panel get their own **rail**: on the right in landscape, at the
  bottom in portrait.
- The STOPPED banner is a **full-width strip on top**.
- The camera, the sliders and the quiz popup lay out in the remaining area only. So the quiz
  modal never covers the rail, and STOP never covers the quiz.
- STOP is a fixed 96 px circle. Its one-line "STOP" label scales down instead of wrapping.
- "Scan lagi" is the first item of the debug panel, so it is never scrolled away.
- Escape and space still stop.
- Tested at 800x632, 390x844 and 1024x768, with a quiz open and with the banner: STOP, the
  quiz's X and minimise, an answer, the D-pad, "Scan lagi" and "Lanjutkan" are all on top where
  they sit.
- Side effect: in an 800 px window the quiz area is 580 px wide, so the quiz shows one pane (its
  chat behind its button) instead of two.

**Scanning while STOPPED**

- Whatever the reason, frames still stream and show, but the live scan analyses none: nothing
  locks, identifies or opens a quiz (`LiveScanController.setScanPaused`). Without live scan, the
  detection-triggered quiz path is skipped as well.
- **A quiz already open stays open and usable.** Answering is not motion, and an identification
  already running counts as open.
- After "Lanjutkan", the quizzed objects are found again by label and their absence restarts, as
  after the J1 guard. Then 0020's cooldown and re-arm rules apply as usual.
- Logged as `scan_paused` / `scan_resumed`. The overlay says "menunggu: robot dihentikan
  (STOP)".

## Amendment 25 Oct (U1): STOP under the speed slider, a STOP in the quiz header

The Control screen now follows Figma 43:30 (file `J2jSbARJSyJCStNFeWkWDj`); E1b's rail is gone.

- **STOP** is a 74 x 74 red square under the vertical Speed (PWM) slider, with "STOP" on one
  line (scaled down, never wrapped). Escape and space still trigger it.
- **Quiz-header STOP:** an open quiz covers the screen, STOP included, so the quiz header has a
  compact red STOP pill next to minimise and X. It calls the same emergency stop.
- The STOPPED strip and "Lanjutkan" are unchanged: a full-width strip on top of everything,
  the quiz included.
- **No clipping:** wide (1100 px and up) is one row; narrower puts the camera on top and the
  controls below (wrapping on a phone); the whole screen scrolls when short. The leaf button
  that reopens a minimised quiz sits in that flow at the bottom right, so it covers nothing.
- **Debug items** leave the screen: in debug builds only, "Debug Scan" opens a side sheet with
  the live-scan readout, the bank/Gemma switch, "Reset scan (debug)" (was "Scan lagi") and the
  phone-camera scan. Release builds show none of it.
- Tested at 1366x768, 1024x768, 800x632, 770x553 and 390x844, with no quiz, a quiz open or
  minimised, each with and without STOPPED (`test/widgets/control_layout_test.dart`).
