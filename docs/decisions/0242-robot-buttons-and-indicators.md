# 0242: Robot screen buttons and indicators (sorting rework, step 1)

- Status: Accepted; unit and widget tests only, not yet checked on the robot.
- Date: 2026-11-26
- Builds on: [0026](0026-emergency-stop-motion-gate.md) (STOP and the motion gate), [0181](0181-lock-button-ai-box.md) (LOCK/SCAN),
  [0183](0183-wide-16-9-stream-measured-fx.md) (arm tag search), [0235](0235-maixcam2-arm-bridge.md), [0240](0240-sim-control-settings.md).

## Goal

Owner, 26 Nov: make each robot-screen button do one job, and show what is happening.

## Decisions

| Ask | Before | Now |
|-----|--------|-----|
| Online/Offline is the MaixCAM2 only | Offline dropped the link, the gate went STOPPED (`link_lost`) and Online then needed GO | Offline pressed by the student: the next connection still sends STOP + motor 0,0 first, then clears that `link_lost` stop. A real Wi-Fi drop still needs GO |
| Go/Stop is the robot only | STOP also paused the live scan | STOP no longer pauses the scan; the gate still blocks every motion while STOPPED |
| STOP halts everything and the arm goes limp | STOP froze the arm, servos holding | The STOP button (and Esc/space) sends `STOP {"limp": true}`. The MaixCAM2 sends one all-empty frame (`,,,,,,CC`): the ESP32 (`EMPTY_MEANS_NO_SIGNAL`) stops every servo pulse and disables the base stepper driver. Streaming stops; pose unknown, HOME first (as after an ESP32 BOOT). Reconnect, watchdog and error STOPs still hold |
| No tag search on HOME / PICK UP | 5 s tag search after each press | Tags only while R1 grips or a bin run plays |
| Lock shows it is working | key looked idle for the ~2 s AI call | key spins and reads LOCKING… until the answer |
| Notifications from the top | SnackBars at the bottom, over the drive/arm controls | Control screen SnackBars float in the top 96 px (`snackBarFromTop`) and swipe up |
| Lock ends with the quiz | unlocked only after the bin run finished | unlocked when the quiz finishes or closes; the next scan starts unlocked |

## Not a power switch

Go/Stop never cuts electrical power: there is no relay, and the owner does not want a wireless power
cut (the robot's body switch is the only power switch). "Limp" cuts the servo signal; the servos
stay powered and stop holding.

## Risks

- A limp arm sags under gravity, onto the tank if it holds an item. HOME after a limp STOP is the
  firmware's direct HOME (like after a BOOT), not a planned path.
- The base stepper keeps its step count while released, unless it is turned by hand.

## Tests

`test_arm_bridge.py` (plain STOP holds, limp STOP sends the empty frame and stops streaming until
HOME), `motion_gate_test.dart` (only the button STOP is limp; Offline needs no GO), `arm_tag_switch_test.dart`,
`phone_control_test.dart` (LOCKING), `control_snackbar_test.dart` (top band). Break-checked against the old code.
