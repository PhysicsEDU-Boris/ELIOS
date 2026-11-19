# 0188: Haptic and click feedback on Control inputs

- Status: Accepted
- Date: 2026-11-07
- Base: `feature/live-scan`

## Problem

Control-screen inputs gave no physical feedback. On a phone in landscape the
driver looks at the camera, not the controls, so it was unclear whether a press
registered. Android InkWells clicked; Switch, Slider, the joystick and every
iOS control were silent.

## Decision

One helper, `controlFeedback()` in `r2_controls.dart`: Flutter's built-in
`HapticFeedback.selectionClick()` plus `SystemSound.play(SystemSoundType.click)`.
No package, no setting. The OS still mutes the click when touch sounds are off.

- Buttons (TransportKey, power, gear chips, pills, glow buttons, STOP): once per tap
  via `withFeedback`; their InkWell `enableFeedback` is off so Android does not click twice.
- Toggles (RockerToggle, compact Switch, phone icon toggles): once per change.
- Sliders (ControlFader): once when a drag/tap starts, not per value step.
- Joystick: once per new direction, not per pointer move.
- HOME: once when the hold confirms. Disabled controls stay silent.

Handlers are unchanged; MotionGate (0026) still decides what is sent.

## Validation

`test/widgets/control_feedback_test.dart` records platform-channel calls for a
button, disabled button, toggle, slider drag, joystick and STOP. It fails on the
old widgets and passes now. Full suite: same single pre-existing
`elio_tokens_test.dart` failure; analyzer: same two pre-existing infos.

Robot/phone check: open Control, tap LOCK/SCAN/PICK UP, flip Scan quiz and
Voice, drag Speed/Gripper, push the joystick in each direction, press STOP.
Each should give one short tick (and a click if touch sounds are on).
