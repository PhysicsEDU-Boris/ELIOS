# 0173 R2 gamified Control screen: joystick, link views, drive tally, Scan quiz pause, dist_cm-only HUD

Status: Draft (2 Nov 2026). UI only on top of 0026 (STOP, MotionGate), 0027 (arm protocol), 0145 (C1), 0146 (theme).
Figma J2jSbARJSyJCStNFeWkWDj, page 358:2358.

## Decision
- **Joystick** (`DriveJoystick`, `quantiseJoystick`, `driveCommand` in `lib/models/control_session.dart`):
  a new input for the D-pad's four commands, with no diagonals because the command set has none. Dead
  zone = 25 % of the base radius; outside it the larger axis wins (a tie goes to forward/back). Entering
  a direction sends that D-pad command once through `MotionGate.motor`. Changing direction sends motor
  0,0 and then the new command (the D-pad's release + press). Letting go, a pointer cancel, or going
  back into the dead zone sends `MotionGate.stopWheels` (0,0). A touch that stays in the dead zone sends
  nothing. Speed is the PWM fader; the gear chips set 25/50/75/100 and the fader still allows any value.
  The joystick claims vertical/horizontal drags so a scrolling page (portrait) doesn't move under it.
- **Link views** (`controlLink`): `Connecting...` (an attempt in flight) = the "waiting" design.
  `Reconnecting...` (the 2 s wait before the next try) and `Disconnected` = the "disconnected" design
  with the real numbers from `WebSocketService`: "Retrying in N s · attempt k of 30" (2 s, 30 tries).
  It shows "Auto-reconnect is off" or "Stopped retrying after 30 tries" when nothing is scheduled.
  Over `adb reverse` a refused attempt ends at once, so on the phone the waiting view only flashes.
  In both views the driving and arm controls are dimmed and absorb input. Their handlers are also
  gated on the link, so they send nothing. STOP stays live and is never dimmed or covered.
- **Power button**: Disconnected = the screen's existing `_connectAndStartStream` (also "Reconnect
  now"). Connected or connecting = C1's `configLinkProvider.disconnect` (also stops retries); the gate
  then goes to STOPPED (link_lost) as on any link loss. No new connection code.
- **Mission and "This drive"**: real `ScanRecord`s saved since this Control screen opened
  (`driveTally`), grouped by `HomeBin.of` (residu in Anorganik, 0144). "+N trophies" = those records'
  own trophies. The mission ("Sort 3 items") gives no reward, and the reward chip is hidden (owner
  question).
- **ELIO tip** (`controlTip`): rules over existing state only, in this order: waiting, disconnected,
  STOPPED, quiz open, no item, item in the pick band (`pickBandMinCm`–`pickBandMaxCm`, only with
  `dist_cm`), item locked (live scan ASKING), item seen. No Gemma call.
- **Scan quiz toggle**: the app has a pause for live-scan quizzes, `LiveScanController.setScanPaused`
  (used for STOPPED, 0026). The toggle reuses it: `setScanPaused(stopped || !scanQuizOn)`, and the
  old non-LIVE_SCAN path also checks the flag. Session-only (not saved). Frames still stream and show,
  robot commands are untouched, and an open quiz stays usable. The debug overlay shows the reason
  "stopped" while it is off.
- **Voice** = the quiz's existing `voiceOn` / `toggleVoice`.
- **HUD and `dist_cm` (0022)**: floor bands (20/30/40/60 cm), the pick zone and "<label> · <n> cm"
  are drawn only when a detection carries `dist_cm`. Without it the tag is the label alone, with no
  bands and no distance. Hands are never tagged. Band rows use the nominal level-camera geometry from
  0022 (lens 86.2 mm, V-FOV 51°), the same uncalibrated model as the firmware's `dist_cm`. The HUD
  keeps the last detector frame's boxes, because preview-only frames (every other one) carry none.
  The live scan still gets exactly the frames it got before.
- **Avatar** = `ElioAvatar` (made public from `ElioTopBar`) opening the existing `ElioDrawerHost` +
  `ElioSidebar` inside Control. Picking a tab pops Control (which disconnects, #78) and switches the tab.
- **Wi-Fi settings**: `Settings.ACTION_WIFI_SETTINGS` on the existing `elio/device_health` channel
  (Android only). No new dependency.

## Kept byte-for-byte
MotionGate, robot controller, message formats and ranges, STOP / Escape / Space, the 4 Hz heartbeat,
the J1 guard, `dispose` order (#78), pick/release/HOME (1 s hold) handlers, and STATUS / motion_done
handling. `StoppedBanner` is unchanged except that "Lanjutkan" sets `backgroundColor: transparent`:
the ELIO theme fills outlined buttons, which made it white on white.

## Proof
`docs/test-results/r2/`: the same fake_maixcam session on the base build (c38809d) and the new one
gives identical command logs up to Exit. On Exit the new build sends `motor 0,0` + `disconnect` (the
#78 behaviour). The base build, reproduced twice, logged "Stopping MaixCAM2 stream" but never
"Leaving robot control" and stayed connected. Its `dispose` is identical, so that is a base-build
problem (cause not found), not a protocol change.

## Consequences
- `drive_pad.dart`, `ArmSlider`, `SpeedSlider`, `GripperButtons` and the old leaf launcher on Control
  are gone; `QuizLauncherButton` stays for other screens.
- On phones the camera image is cover-cropped, so the 20 cm band and most of the pick zone fall below
  the visible area.
