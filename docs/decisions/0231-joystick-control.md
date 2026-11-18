# 0231: Joystick control: smooth drive and arm-base speed from the sticks (task J1)

- Status: Accepted for the app. Constants are starting values; the owner tunes them on the robot.
- Date: 2026-11-19
- Builds on: [0026](0026-emergency-stop-motion-gate.md) (MotionGate), [0021](0021-manual-driving-orchestration.md)
  (drive lock), [0027](0027-arm-serial-protocol.md), [0229](0229-control-v2-layout.md) (BASIS joystick).
  Arm numbers from 0230 (robotic_hand_sim 75ab797, branch `feat/sim-sync`).
- Code: `lib/services/robot/joystick_math.dart` (config and pure maths),
  `lib/services/robot/joystick_controller.dart` (20 Hz tick), wired in `control_screen.dart`.

## Before

The drive joystick was a D-pad: four directions past a 25 % dead zone, each a fixed `motor ±S,±S`
at the speed fader's value, and `motor 0,0` on let go. The BASIS joystick sent `servo base` ±2 deg every
100 ms while held. A light push and a full push did the same, and both started and stopped at full step.

## The pipeline (every 50 ms)

Stick axes x, y in [-1, 1] (screen y down; the drive vector is kept inside the unit circle).

1. Deadzone with rescale: `u = max(0, (|x| − d) / (1 − d))`, d = 0.08.
2. Curve: `y = sign(x) · ((1 − q)·u + q·u²)`, q = 0.7. Odd, 0 in the deadzone, 1 at full push.
3. Slew limit per output: up 2.0 /s, down 6.0 /s. A reversal brakes to 0 first. From rest a full push takes
   0.5 s; a let go stops in 4 ticks (0.15 s).
4. Drive mixer: `v` = forward, `w = 0.6 · turn`; `L = v + w`, `R = v − w`, both divided by
   `max(1, |L|, |R|)` so the turn ratio is kept. Optional minimum output P0 (0 until measured).
   `motor = round(L · speed fader)`: the fader is the top speed.
5. Arm base: the stick sets a speed, the app integrates it: `θ += fraction · 40 deg/s · dt`, θ clamped to
   ±90 deg, servo = round(θ + 90). θ stays a float. While the arm stick moves, the base is sent every tick;
   after it stops, one hold command at the stopped angle, then nothing.

Locks (checked every tick, nothing in the state machine changed):

- Drive: STOPPED, no link, or R1's drive lock. The output is a hard 0, the ramps reset, so on unlock it
  restarts from 0 (no jump), and one `motor 0,0` is sent if it was driving.
- Arm: STOPPED, no link, R1 sorting (`armBusy`) or a hand in view (`handPaused`). The base stick is ignored.

If the base was moved by someone else (HOME, the debug chevrons), the next push starts from that angle.
HOME's motion_done now also resets the app's base angle to 90 (the all-zero pose).

## Constants (all in `JoystickConfig`, all starting values)

| Name | Value | Why |
|---|---:|---|
| deadzone | 0.08 | no creep at rest, small enough not to waste travel |
| quadraticShare | 0.7 | fine control for a light push |
| slewUp / slewDown | 2.0 / 6.0 per s | gentle start, quick stop |
| turnGain | 0.6 | in-place turn at 60 % of the top speed |
| minDriveOutput (P0) | 0 | measure on the floor |
| armMaxRateDegPerSec | 40 | the firmware's base limit (0230); the config asserts ≤ 40 |
| armBaseMin / Max | ±90 deg | past ±90 the arm at home can hit the tank behind the base (0230) |
| armDirection, driveTurnSign | +1 | flip if the robot moves the wrong way |

## Departures from the J1 spec

- **No stick timeout.** A finger held still produces no pointer events, so a 300 ms timeout would stop the
  robot under a steady push. Let go, the widget being removed while held, the app going to the background,
  STOP and link loss all zero the stick instead.
- **`stop()` does not send.** Leaving the screen, `MotionGate.dispose` already sends `motor 0,0`, and the
  provider can't be read after unmount.
- **Time comes from `Timer.tick`**, not the wall clock: a late callback gets a longer dt (up to 0.1 s), and
  it runs the same in fake-time widget tests.
- **No serial line builder.** The app never writes the serial line; the MaixCAM2 builds the 0230 frame
  (six fields, CRC-8) from its stored angles. The app keeps sending `servo base=<int 0..180>`.
- **Base rate limit 40, not 60 deg/s**, and the range stays ±90 deg although the stepper base reaches ±180
  (tank keep-out).
- The landscape tablet layout has no arm stick; its drive joystick uses the same pipeline.

## References (from the owner's research report; not verified here)

Kim, Tendick, Ellis and Stark 1987 (rate vs position control); Mick et al. 2017, Frontiers in
Neurorobotics 11:55 (velocity control, quadratic preference); Zhang and Khurshid, arXiv 1911.04466
(input-scaled rate control, limit how fast the scale rises); Przystupa et al. 2024, arXiv 2410.21406 (odd
functions). None of them tests this robot: the constants are starting values.

## Tests

- `test/robot/joystick_math_test.dart`: the spec's shaping, slew, mixer and arm vectors.
- `test/robot/joystick_controller_test.dart`: follow, let go, dead zone, drive lock and ramp reset,
  background release, arm steady rate, hold, arm lock, resync, direction flip, range.
- Widget tests (`control_layout_test.dart`, `phone_control_test.dart`) now expect ramps, not fixed D-pad
  commands; both harnesses use the same controller.
- Break-checks, one rule removed at a time:
  - deadzone rescale: shaping vectors, arm float test fail;
  - slew limit: 3 slew vectors, 6 controller tests, 3 widget direction tests fail;
  - arm clamp: arm clamp test fails;
  - reversal rule: slew reversal test fails (the widget reversal test still passes: from 1.0 the down rate
    reaches 0 anyway).

## Robot checks for the owner

Wheels off the ground first: direction (flip `driveTurnSign`), deadzone until nothing creeps, then P0 on the
floor, then `quadraticShare` / `slewUp` until a light push is gentle and a full push doesn't jump. Arm clear
of objects: base direction (flip `armDirection`), servo 90 is centre, a full push sweeps 0→90 deg in about
2.5 s, a let go mid-sweep holds. Lock/unlock while holding the stick: nothing moves while locked, a gentle
start after.
