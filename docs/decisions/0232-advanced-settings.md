# 0232: Advanced settings on the phone Control screen

- Status: Accepted for the app. The arm values reach the MaixCAM2 as `CONFIG` but the firmware does not
  apply them yet (R1-fw, 0023).
- Date: 2026-11-19
- Builds on: [0229](0229-control-v2-layout.md) (phone Control v2), [0230](0230-sync-robotic-hand-sim.md)
  (sim protocol and joint table), [0231](0231-joystick-control.md) (joystick constants).
- Figma: file J2jSbARJSyJCStNFeWkWDj, page "ELIOS 3", section 08: `Phone/Advanced settings button` beside
  Panduan in 885:31003 / 892:31074, and "R3 / Light / Advanced settings — 1..6" (906:31223, 907:31246,
  907:31486, 909:31298, 909:31517, 909:31769), dark 909:31977. L2 v3 style: curved green header, leaf rail
  and card, status strip, ticket notes.
- Code: `lib/services/robot/robot_settings.dart`, `lib/Screens/advanced_settings_screen.dart`;
  `_AdvancedButton` in `phone_control.dart`; `_openAdvanced` in `control_screen.dart`.

## What a teacher can do

"Advanced" sits beside Guide on the phone Control top bar (icon only under 860 dp). It asks for a 4-digit
teacher PIN; the first time, the PIN is set. Six sections:

| Section | Editable | Where it takes effect |
|---|---|---|
| Arm axes | trim ±15° (0.5° steps) and INV per joint J1..J5; home, range and speed shown read only | `CONFIG` to the MaixCAM2 (not applied by the firmware yet) |
| Gripper | closed offset ±15°, INV; the width → servo map updates live | `CONFIG` |
| Drive & joystick | dead zone, curve, turn gain, speed up / slow down, P0, base speed (≤ 40°/s), base limit (≤ ±90°), reverse turn, reverse base | the app's `JoystickController`, from the next tick |
| Connection | read only: MaixCAM2 address, link state | — |
| Safety | read only: arm move and sort timeouts, heartbeat, slow-approach PWM, STOP repeats, hand pause | — |
| Backup | copy / paste settings as JSON, change PIN, reset to defaults | draft, then Save |

Edits are a draft. "Save to robot" stores them on the phone (`robot_settings_v1` in SharedPreferences) and,
with a live link and not STOPPED, sends `{"cmd":"CONFIG","seq":n,...toMap()}` through the gate's command
link. Back with unsaved edits asks first.

## Choices

- **Safety values are read only.** They are code constants (0026, 0230, 0231); changing a timeout from a
  phone is a safety change, not tuning.
- **The PIN is a classroom gate, not security.** It is stored in plain SharedPreferences and is never in
  the copied JSON or `CONFIG`.
- **Pasted settings are untrusted.** Any missing, wrong-type or out-of-range value falls back to the
  default (same limits as the screen; base speed never above the firmware's 40°/s).
- **No ESP32 health or firmware versions.** The MaixCAM2 does not forward `STAT` / `BOOT` yet; the
  Connection page says so instead of showing made-up numbers.
- **Calibration actions from the Figma page 6 (camera / AprilTag, axis direction test) are not built**:
  they need firmware commands that do not exist.
- **The landscape tablet (R2) layout has no Advanced button**; only the phone layout was asked for.

## Firmware follow-up (R1-fw)

The MaixCAM2 must map `CONFIG` to the sim protocol: trims and INV as the `C,SEQ,J,HOME,GAIN,...` mapping
(two-way mode) or applied to stream frames, and the gripper closed offset to the width map
`servo = 180 − (105 − offset) × width / 100`.

## Tests

- `test/robot/robot_settings_test.dart`: defaults equal 0231, flips and limits reach the joystick config,
  JSON round trip, untrusted paste falls back, PIN never shared, gripper map, persistence, live config
  change without a jump.
- `test/screens/advanced_settings_test.dart`: every section at 915×412 and 844×390, light and dark, without
  overflow; jog + Save stores and sends `CONFIG`; offline Save keeps it on the phone; discard on back;
  drive edits reach the joystick config; reset keeps the PIN; PIN create, wrong, right, too short, cancel.
- `test/widgets/phone_control_test.dart`: Advanced is on screen beside Guide and taps through.
- Break-checks: accepting any PIN, not sending on Save, and dropping the paste range check each fail a test.
