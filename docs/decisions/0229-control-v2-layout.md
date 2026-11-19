# 0229 — Phone Control v2: arm keys in KEMUDI, STOP in the camera row, BASIS joystick

Date: 19 November 2026. Branch `feat/control-v2-layout`, from `feature/live-scan`.
Figma: file J2jSbARJSyJCStNFeWkWDj, page "ELIOS 3", section "08 · Control · phone
landscape 915×412 (R3)": light 885:31003, dark 892:31074, as-built reference 880:30745.

## Decision

Phone landscape Control (`PhoneControlLayout`, R3) only. The tablet / Mac R2 layout is unchanged.

- **KEMUDI card**: the 25 / 50 / 75 / 100 gear chips are gone; the speed fader stays.
  LOCK (KUNCI), SCAN and the robot power key sit under the fader as round keycaps
  (`TransportKey`, same keys and handlers as before: `phone_lock`, `phone_scan`,
  `robot_power`). Power is now a keycap labelled Online / Connecting / Offline, green when online.
- **Card status chips**: the KEMUDI and LENGAN headers show only the title. The link status
  is already in the camera row's chip.
- **Camera row**: unchanged chips and toggles, with STOP (GO after a stop with a live link)
  at its right end, 44 dp. The row is 44 dp high, so the video is 14 dp shorter.
- **LENGAN card**: TINGGI and JANGKAU faders share the card width; below them the new
  **BASIS** joystick: a capsule in the drive joystick's style. Holding the knob left or
  right (past the same 25 % dead zone, `baseJoystickDir`) turns the base 2° every 100 ms
  through `MotionGate.servo('base', …)` (0..180, same as the debug sheet's nudge); letting
  go stops it. The centre line marks forward.
- Skeleton (loading) layout follows the same grid.

## Why

Owner request (19 Nov) after redesigning the screen in Figma from the as-built app: one
place for the arm actions, STOP always at the top, no duplicate offline labels, and a way
to turn the arm base from the phone (it was only in the debug sheet).

## Not 1:1 with Figma

- KUNCI uses the existing `center_focus_strong` / `center_focus_weak` icons, not the
  hand-drawn corner icon. SCAN keeps `quiz_outlined`.
- The BASIS knob shows `‹›` at rest and an arrow while held; there are no Min / Maju / Maks
  captions (they did not fit at 800×360).
- Short phones (height < 400) hide the keycap captions, as the old LOCK / SCAN keys did.

## Tests

`test/widgets/phone_control_test.dart`: BASIS sends `servo base` while held and calls
release on let-go (break-checked by disabling the callback); keycaps on screen, no gears
or status chips; offline drag of BASIS sends nothing. `test/models/control_session_test.dart`:
`baseJoystickDir`. The 0182 lock-label test now accepts the label inside the box when the
box touches the top of the (shorter) video. Not checked on a phone or the robot.
