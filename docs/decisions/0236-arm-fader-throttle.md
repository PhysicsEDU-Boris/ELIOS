# 0236 — Arm fader drags send ARM_POSE at most every 100 ms

Date: 19 November 2026. Branch `feat/arm-fader-throttle`, stacked on `feat/maixcam2-arm-bridge` (0235).

## Why

Phone test 19 Nov (APK `e575271` against the MaixCAM2 over USB): one gripper drag sent 66
`ARM_POSE`, one Height drag 55, one Reach drag 54, one per fader change. The MaixCAM2 (0235)
keeps only the newest target and streams it to the ESP32 at 20 Hz, so the poses in between were
planned, sent and acked for nothing, on the same WebSocket as the video.

## Decision

`FaderThrottle` (`lib/services/robot/fader_throttle.dart`) wraps the gripper, Height and Reach
fader callbacks on both Control layouts: the first change runs at once, then at most one per
100 ms, and the last change always runs, so the arm ends where the fader stops. The whole
`_armMove` (plan + send + commit) is throttled, not only the send: every planned path still starts
from the pose last sent, so the tank check covers the real move. STOP and leaving the screen drop a
waiting change.

Not changed: the BASIS joystick (already 20 Hz from `JoystickController`), HOME, PICK, RELEASE
(single presses).

## Effects

About 10 `ARM_POSE` per second of dragging. The fader's percentage and thumb follow the committed
pose, so they update at 10 Hz while dragging.

## Tests

`test/robot/fader_throttle_test.dart`: a 60 Hz, 1 s drag sends 9–11 calls with the first at once
and the last always; cancel drops the waiting call. Break-checked: without the throttle (60 sent)
and without the trailing call (last = 56) both fail.
