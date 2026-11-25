# 0240: Bring robotic_hand_sim's control settings into ELIOS

- Status: Accepted. Sections 1–5 and 7–8 built (24–25 Nov); section 6 (tank height) open.
- Date: 2026-11-24
- Source: `github.com/3dbore/robotic_hand_sim` at `fce805d` (24 Nov 2026), the camera HIL app
  `arm-hil-toolkit-2.py` plus `hil/config.py`, `hil/motion.py`, `hil/kinematics.py` and
  `slave_code/6-axis-esp32-twoway-tmc2208/`.
- Builds on: [0230](0230-sync-robotic-hand-sim.md) (protocol and joint table),
  [0232](0232-advanced-settings.md) (Advanced settings), [0233](0233-bin-tag-check.md) (bin sequences),
  [0234](0234-arm-kinematics-in-app.md) (planning in the app), [0235](0235-maixcam2-arm-bridge.md)
  (MaixCAM2 bridge).

## Goal

The arm should move the same way from ELIOS as it does from the PC HIL app: the same speed per
joint, the same acceleration and deceleration ramps, the same bin sequences (with each step's own
speed profile) and the same AprilTag centring of the base. A sequence recorded and tuned on the PC
should play the same way on the robot through the app.

## Where things run today

```
ELIOS app (phone) --WS :8765--> MaixCAM2 main.py + arm_bridge.py --UART2 9600--> ESP32 --> servos + NEMA17
PC HIL app (robotic_hand_sim) -------------------USB serial----------------------------> ESP32
```

- The app plans manual moves (`lib/services/robot/arm_pose.dart`, 0234) and sends `ARM_POSE`.
- The bridge plays every leg itself and streams `F0..F5,CC` at 20 Hz (0235). So **the motion
  profile must be applied on the MaixCAM2**; the app only chooses and stores the settings.
- Only one of the PC app and the bridge may drive the ESP32 at a time.

## Gap table

| Setting | robotic_hand_sim (`fce805d`) | ELIOS today | To do |
|---|---|---|---|
| Trim per axis, ±15° | all 6 axes, wire only | 5 axes in `RobotSettings.trims`, sent in `CONFIG`, applied by the bridge | none |
| Invert per axis | all 6 axes | 5 axes + `gripInverted` | none |
| Gripper close offset, ±15° | `grip_closed_offset` | `gripClosedOffset` | none |
| Max speed per joint (°/s) | `max` box on each Joints row, 1 .. `speed × 0.8` | fixed `speed × 0.8` (`_speedMargin`) | **add** (section 1) |
| Accel / decel share per joint | Detail panel, 5–95 %, default 33 % | none: one smoothstep for every axis | **add** (section 1) |
| Speed graph per joint | `ProfilePlot` in Detail | none | **add** (section 2) |
| Speed profile saved per sequence step | `Step.motion`, replayed with the step | `load_sequences` drops `motion` | **add** (section 3) |
| Bin sequences | Left-Tank-New, Mid-Tank, Right-Tank-New | `bin_sequences.json`: old `Left-Tank-Throw` on B3 only | **update** (section 4) |
| Tag centring of the base + slip correction | `_align_done`, `_slipped`, `base_corr` | tag ids only feed the DROP guard | **add** (section 5) |
| Mirror a sequence (left ↔ right) | Sequences tab button | none | not needed in the app: sequences are authored on the PC |
| Tank keep-out height | `TANK_Z_MM = 150` | `tankZMm = 167` (app and bridge) | keep 167 for now (section 6) |
| Base gear ratio 60T→92T | firmware `BASE_GEAR_RATIO = 92/60` | firmware only | re-flash the ESP32; no app change |

## 1. Per-joint speed profile

Port `clean_axis`, `default_profile` and `ProfiledMotion` from `arm-hil-toolkit-2.py` unchanged.

### Data

```json
{"Gripper":     {"vmax": 72.0, "accel": 0.33, "decel": 0.33},
 "Wrist Yaw":   {"vmax": 36.0, "accel": 0.33, "decel": 0.33},
 "Wrist Pitch": {"vmax": 36.0, "accel": 0.33, "decel": 0.33},
 "Arm B":       {"vmax": 24.0, "accel": 0.33, "decel": 0.33},
 "Arm A":       {"vmax": 24.0, "accel": 0.33, "decel": 0.33},
 "Arm Base":    {"vmax": 32.0, "accel": 0.33, "decel": 0.33}}
```

Keyed by axis name, exactly as `Step.motion` in `hil_sequences.json`, so the same dict works for
the live setting, for sequence steps and over the wire.

### Rules (`clean_axis`)

- `vmax` is clamped to `1 .. floor(speed × 0.8 × 10) / 10` (the caps above: 72 / 36 / 36 / 24 / 24 / 32).
  Never above that: the firmware's own limit (`AXIS_MAX_SPEED_DEG_PER_SEC`) would clip the move and
  the joints would stop arriving together.
- `accel` and `decel` are clamped to 0.05 .. 0.95. If `accel + decel > 1`, both are scaled by
  `1 / (accel + decel)` (the ramps cannot overlap).
- When the user raises one ramp, the other is lowered to at most `1 − that ramp` (`_edit_profile`).
- A missing or partial profile is filled with the defaults (`complete_profile`).

### Motion (`ProfiledMotion`, per leg)

All joints still start and arrive together; the slowest one sets the time.

```
vp_i  = 1 / (1 − (ta_i + td_i) / 2)                  # peak / mean speed of axis i
T     = max_i(|Δ_i| × vp_i / vmax_i), at least 0.15 s (0 if nothing moves)
u     = t / T                                         # 0..1
s_i(u) = vp_i u² / (2 ta_i)                           if u < ta_i
       = 1 − vp_i (1 − u)² / (2 td_i)                 if u > 1 − td_i
       = vp_i (ta_i / 2 + u − ta_i)                   otherwise
cmd_i = start_i + (goal_i − start_i) × s_i(u)
```

- A profile change during a move applies from the next leg, never mid-leg (the command would jump).
- `arm_bridge.leg_seconds` and `arm_pose.dart`'s leg time (today `1.5 × |Δ| / (speed × 0.8)`)
  must both use `T` above, or the app's timeouts and the bridge's `motion_done` drift apart.
  Pin both against shared golden values (as `test/fixtures/arm_kinematics_golden.json` does for
  the kinematics).

**Bridge done 24 Nov, defaults only** (not deployed): `arm_bridge.py` has `vmax_cap`, `clean_axis`
(also turns NaN / inf into the default), `complete_profile`, `DEFAULT_PROFILE`, `leg_seconds(a, b,
profile)` and `ramp(u, ta, td)`; every leg (ARM_POSE, HOME, bin sequences) uses `ArmBridge.profile`,
which is `DEFAULT_PROFILE` until `CONFIG` and step profiles land. Pinned to the sim by
`test/fixtures/arm_profile_golden.json` (made by `tools/arm_kinematics/make_profile_golden.py` from
the sim's own `ProfiledMotion`; 12 legs: default, the tank base ramp, and every clamp) in
`test_arm_bridge.py` `SpeedProfile`. With the defaults a leg takes `1.4925 × Δ / cap` instead of the
old `1.5 × Δ / (speed × 0.8)` (0.5 % shorter), so the app's unchanged estimate in `arm_pose.dart`
stays slightly long, which is safe until step 4.

### Protocol

- `CONFIG` (app → MaixCAM2) gains `"profile"`: the dict above. The bridge validates it with the
  same rules, stores it with the trims in its config file, and uses it for `ARM_POSE` and HOME legs.
- A bad or missing `profile` falls back to the defaults; it never rejects the whole `CONFIG`
  (trims and invert must still apply).
- `STATUS` returns the profile in use, so the app can show what the robot actually has.

## 2. App UI

In Advanced settings (0232), a new section **Speed and ramps**, one row per joint in display
order (Base, Arm A, Arm B, Wrist Pitch, Wrist Yaw, Gripper), like the sim's Joints rows:

- `max` stepper or slider, °/s, 1 .. cap, step 1 (the sim uses 5 with one decimal);
- **Detail** expands: `accel %` and `decel %` (5–95), a small graph of speed over time
  (ramp up, cruise at `vmax`, ramp down, with the time a 30° move takes, as `ProfilePlot`) and **Reset**;
- one line of help: "All joints arrive together, so the slowest one sets the move time."

Store it in `RobotSettings` (`robot_settings_v1` in SharedPreferences) next to the trims, and send
it with the next `CONFIG`. Follow the L2 v3 style of 0232; the Figma section 08 frames need a new
card for it.

**Done 24 Nov** (sections 1 and 2, app and bridge; not deployed, no Figma frame yet):

- `lib/services/robot/arm_profile.dart`: `cleanAxis`, `completeArmProfile`, `defaultArmProfile`,
  `profileRamp`, pinned by `test/robot/arm_profile_test.dart` to the same golden file as the bridge.
- `arm_pose.dart`: `legSeconds(a, b, profile)` and `ArmPose.profile` (set from settings in
  `control_screen.dart`), so move timeouts match the MaixCAM2. `armSpeedMargin` is now public.
- `RobotSettings.profile`: saved, copied in Backup, sent in `CONFIG` as `profile`; a pasted profile is
  clamped per axis, never rejected.
- Advanced settings: a **Speed & ramps** section (id 6, key `adv_tab_6`, second in the rail): per
  joint, Base first, top speed 1..cap, speed-up and slow-down 5–95 % (the other ramp gives way),
  a ramp graph with the time of a 30° move, and Reset. Strings in English and Indonesian.
- Bridge: `CONFIG.profile` sets `ArmBridge.profile` (manual moves and HOME), saved in the config file
  and returned in `STATUS`. A CONFIG without one (an older app) means the defaults.
- Checks: `flutter analyze` clean, `flutter test` 2115 pass, MaixCAM2 tests 60 pass.

## 3. Speed profile per sequence step

- `load_sequences` keeps each step's `motion` (complete it with the defaults; old steps without one
  play at the defaults, as the sim does).
- `_play_steps` applies a step's profile to the legs that reach that step, including the planner's
  extra legs (arm first / base first) in front of it.
- The live `CONFIG` profile is for manual moves only. During `MOVE_TO_BIN` / `DROP` each step's
  own profile wins; after the sequence ends the live profile is used again (`_end_run` → `_push_profile`).

**Done 24 Nov** (not deployed): `load_sequences` makes each leg `(pose, hold, profile)` with the step's
`motion` completed (missing or bad → defaults); `_play_steps` gives the planner's extra legs the step's
profile; `_next_leg` uses a leg's own profile, else `ArmBridge.profile` (manual moves, HOME). Tests in
`test_arm_bridge.py` `SpeedProfile` (29 pass; break-checked). With the owner's base ramp (accel 0.72,
decel 0.18) the bin moves take a little longer, all still under the app's 30 s `armTimeout`:

| Bin | MOVE_TO_BIN before → now | DROP before → now |
|---|---|---|
| b3 | 10.3 → 11.0 s | 17.7 → 19.1 s |
| anorganik | 12.1 → 13.1 s | 22.5 → 24.2 s |
| organik | 14.0 → 14.9 s | 18.6 → 20.1 s |

A slower step profile could pass 30 s; step 4 should derive the app's wait from the same leg time.

## 4. Bin sequences

Replace `firmware/maixcam2/bin_sequences.json` with the owner's current `hil_sequences.json`
(Left-Tank-New, Mid-Tank, Right-Tank-New) and map the bins:

| Bin | Tag (`BIN_TAG_IDS`) | Sequence | `state_point` (closed, at the bin) | `release` (gripper opens) |
|---|---|---|---|---|
| b3 | 4 | Left-Tank-New | Pose 2 | Pose 3 |
| anorganik | 2 | Mid-Tank | Pose 3 | Pose 4 |
| organik | 3 | Right-Tank-New | Pose 2 | Pose 3 |

The tag ids in the recorded steps match this table. All three sequences pass the tank planner at
both 150 and 167 mm (checked 24 Nov with `hil.kinematics.plan`, every step from home).
Deploy `main.py`, `arm_bridge.py` and `bin_sequences.json` together (MaixVision package, bump the version).

**Done 24 Nov** (file only, not deployed): `bin_sequences.json` replaced; `test_arm_bridge.py` gains
`test_every_bin_moves_and_drops`; `test_fake_maixcam.py` updated for the three bins. Right-Tank-New
ends with the base at 75.3 (sim −14.7°), not at home: after an organik DROP the arm is not at home.

## 5. Tag centring of the base

The base is an open-loop stepper with no homing switch, so it can slip. The sim corrects this with
the hand camera. Run it on the MaixCAM2, which has the camera and owns the motion.

### Saved data (already in each tagged step)

`tag.tags[0]`: `id`, `x_px`, `offset_norm` (+ = right of the centre line), `offset_deg`; `tag.image`
(`[w, h]`); `tag.hfov_deg`. Use `offset_norm`, not `offset_deg`: the target angle is re-derived with
the current FOV (`saved_offset_deg`), so captures made at another FOV (Left-Tank-New at 83°, the
others at 60°) still work.

### Constants

| Name | Value | Meaning |
|---|---|---|
| `CAM_HFOV_DEG` | 83.0 | horizontal FOV of the MaixCAM2 (placeholder in the sim; measure it) |
| `AZ_SIGN` | −1 | tag left of its line → Arm Base plus |
| `TAG_MAX_AGE_S` | 1.0 | detection at most this old |
| `TAG_SETTLE_S` | 0.4 | and taken at least this long after the arm stopped |
| `ALIGN_TOL_DEG` | 1.0 | close enough |
| `ALIGN_GAIN` | 0.8 | share of the error corrected per move |
| `ALIGN_MAX_STEP_DEG` | 10 | biggest single correction |
| `ALIGN_MAX_MOVES` | 8 | then give up |
| `ALIGN_WAIT_S` | 4.0 | give up when no tag for this long |
| `ALIGN_RETRIGGER_DEG` | 2.0 | re-centre during the hold if it drifts this far |
| `ALIGN_MAX_CORR_DEG` | 30 | largest slip correction ever |

### Loop (`_align_done`, `_slipped`), when a step with a tag has arrived and before its hold

```
h(u, w)  = atan2(u − w/2, (w/2) / tan(HFOV/2))           # deg, + = right
target   = atan(offset_norm × tan(HFOV/2))
err      = AZ_SIGN × (h(live tag cx, frame w) − target)
|err| ≤ TOL            → centred: start the hold
moves ≥ MAX_MOVES      → give up, carry on (report it)
no tag for WAIT_S      → carry on (report it)
err grew by > TOL after a correction → undo that correction, stop (AZ_SIGN or HFOV is wrong)
otherwise: step = clamp(GAIN × err, ±MAX_STEP); base_corr = clamp(base_corr + step, ±MAX_CORR);
           re-plan this step with Arm Base + base_corr (through the tank planner)
```

- `base_corr` is added to Arm Base on every later step, tagged or not, until a tagged step measures
  it again or the user clears it ("Zero slip"). Keep it across sequences; reset it on ESP32 `BOOT`
  and on HOME.
- While a centred step holds, keep watching; if the tag drifts past `RETRIGGER`, centre again.
- Every corrected goal goes through the tank planner. If the base is at its limit, stop and report.
- Report to the app in `motion_done` / `STATUS`: `centred`, `err_deg`, `base_corr`.
  Show "Base slip correction +2.4°" and a **Zero slip** button in the app.
- `main.py` already detects tags with `cx` (`find_arm_tags`); pass `(id, cx, frame width, time)` to
  the bridge instead of ids only, and keep tag search on during `MOVE_TO_BIN` / `DROP`.

## 6. Tank height

The sim lowered `TANK_Z_MM` from 167 to 150 mm; ELIOS (app and bridge) still uses 167. 167 is the
safer of the two and the owner's sequences pass at both, so keep 167 until the owner confirms the
real tank height. Change it in `arm_kinematics.dart`, `arm_bridge.py` and the golden file together.

## Tests

- Profile maths: `clean_axis` clamps and ramp rescaling; `T` and `s(u)` against golden values
  produced by `arm-hil-toolkit-2.py`'s `ProfiledMotion` (several profiles, the three tank sequences).
  `s` is continuous at `ta` and `1 − td`, `s(0) = 0`, `s(1) = 1`, and no axis exceeds its `vmax`.
- Bridge: `CONFIG` with a bad profile keeps trims; a step's `motion` is used for its legs; the live
  profile is back after the sequence; leg time equals the app's.
- Centring with a fake tag source: converges inside `ALIGN_MAX_MOVES`; a reversed `AZ_SIGN` stops after
  one correction; no tag → carries on after `ALIGN_WAIT_S`; `base_corr` never passes ±30°; a corrected
  goal into the tank is refused.
- Bin sequences: all three load; every leg passes the planner.

## Order of work

1. Section 4 (bin sequences): no code, unblocks organik and anorganik straight away.
2. Section 1 in the bridge + golden tests, with the defaults only (same as today, but with ramps).
3. Section 3 (per-step profiles in sequences).
4. Sections 1 and 2 in the app (settings UI, `CONFIG.profile`, leg time in `arm_pose.dart`).
5. Section 5 (tag centring), first on the bench with the arm lifted, then on the robot.

## Open

- Real horizontal FOV of the MaixCAM2 at the capture resolution (83° is a placeholder; 60° was used
  for two of the captures).
- Real tank height (150 or 167 mm).
- Is the robot's ESP32 flashed with the `fce805d` firmware (gear ratio 92/60)?
- Should the speed and ramps section be teacher-PIN protected like the other Advanced settings?

## 7. Bin run after the bin check, and the fake MaixCAM2 (24 Nov)

Owner, 24 Nov: the item goes to the bin after the first quiz (the bin check, 0224), to the RIGHT bin
(the AI's), whatever the student picked; the arm moves only after the answer is revealed. Owner
choices: the arm starts on **Got it**; with the gripper open it **waits for AMBIL**.

- `lib/services/robot/bin_run.dart` (`BinRun`, tests `test/robot/bin_run_test.dart`): Got it →
  MOVE_TO_BIN (right bin) → 1 s look (tag search on, for the MaixCAM2's DROP guard) → DROP; one more
  look on `bin_not_confirmed`; a failure sends HOME and says why. Not in R1 builds.
- Control screen: KUNCI and SCAN wait while the quiz is open and while the run is pending (the box
  stays locked from SCAN until the item is dropped, then it unlocks); manual arm keys wait while the
  arm runs (`MotionGate.armBusy`); STOP or a lost link ends the run. The bin check ticket says
  "Ambil sampahnya dulu…" (gripper open) or "Setelah Mengerti, lengan membawanya…" (closed); the
  result card's "robot is dropping" notice and disabled Scan lagi now cover the run too.
- Fake MaixCAM2: legs use `arm_bridge.py`'s maths (ramps, holds, gripper as a timed axis, step
  `motion`, `CONFIG.profile`); picking up is manual (closing the gripper at an item grips it);
  `--show` opens robotic_hand_sim's own 3D `Scene` (`arm_view.py`). End to end on 24 Nov
  (`r1_full_sort`): manual grip, MOVE_TO_BIN anorganik 12.5 s, DROP 19.6 s, bottle dropped in
  anorganik. The fake plans with the sim's tank (150 mm), the robot with 167 mm, so a leg can differ.
- Not run with the app against the fake yet (needs a robot build of the app), nor on the robot.

**Section 5 done 25 Nov** (bridge only, not on the robot yet): `arm_bridge.py` keeps each step's saved
tag (`load_sequences` legs are `(pose, hold, profile, tag)`, tag = `(id, offset_norm)`), and when a tagged
step arrives it runs the sim's centring before the hold (`_aligned`, `_shift`, constants as in the table
above). `base_corr` is added to every later sequence step, kept across sequences, cleared on HOME and on an
ESP32 `BOOT`; `motion_done` carries `base_corr` and an `align` list (`centred`, `no_tag`, `diverged`,
`max_moves`, `corr_limit`, `blocked`), `STATUS` returns `base_corr`. `main.py` searches tags whenever a bin
sequence plays or the arm is at a bin (`ArmBridge.wants_tags`, not only when the app asks) and passes each
tag's `cx` and the frame width. Tests: `test_arm_bridge.py` `TagCentring` (6, break-checked with AZ_SIGN
flipped and without the correction on later steps). Not built: the app's "Zero slip" button and slip
display (HOME clears it); the fake MaixCAM2 does not centre. A tagged step with no tag in view waits
`ALIGN_WAIT_S` (4 s) before it carries on, so a sort with the camera covered takes longer.

## 8. Owner, 25 Nov: 3 s wait, sliders, robot prompt, UART4

- **3 s wait.** `BinRun.delay` (3 s): Got it with the gripper closed, or AMBIL after Got it, starts a
  `countdown`; MOVE_TO_BIN goes out when it ends. The countdown counts as busy (manual arm keys, KUNCI and
  SCAN wait; STOP or a lost link cancels it, and the arm pose stays known because nothing moved). The
  ticket says so ("the arm waits 3 s…").
- **Sliders moved on their own or stuck** (the 0236 throttle made it visible). Two causes: (1) every reply
  with `servo` overwrote the arm's goal: the `motion_done` of an older, superseded ARM_POSE and a STATUS
  sent mid-move both carry a pose the arm is only passing through, so the thumb snapped back and the next
  plan started from it; (2) the thumb was drawn from the commanded value, which changes only on a send
  (every 100 ms) and never for a refused move. Fix: `ArmPose.movingSeq` (the latest ARM_POSE's seq, from
  `RobotController.lastArmSeq`); `onServo` takes a reply's pose only when no manual move is on its way or
  it is that move's own `motion_done`; an error for it, STOP, HOME, a lost link clear it. `ControlFader`
  keeps the finger's value while dragging and shows the commanded value again on release. Tests:
  `arm_pose_test.dart` (2), `control_feedback_test.dart` (1), break-checked.
- **Robot identify prompt.** `identifyItem(robot: true)` (LOCK only; phone and Contribute unchanged): the
  photo is from the arm's camera; the robot's arm, gripper and cables are not the item, and an item held
  in the gripper is. Same JSON, same image size; no timing measured.
- **UART.** Owner: UART4 = ESP32 (servos), UART2 = Arduino (wheels). `main.py` opens `/dev/ttyS4` for the
  arm after `pinmap` A21 → UART4_TX, A22 → UART4_RX (0230's pin table; a failed pinmap is logged, not
  fatal). The wheels: the board carried an on-device patch (19 Nov, not in git; backed up on the board)
  driving the Arduino (`codeMotorSlave.ino`, L298N, one char F/B/L/R/S) on UART2 instead of the arm.
  It is merged into `main.py` on its own UART (`/dev/ttyS2`, 9600): `drive_char` (deadband 10, forward vs
  turn), 500 ms watchdog to `S`, `S` when the last client leaves; Arduino lines are logged. Test:
  `test_clean_stream.py` `DriveTest`.
- Picking stays manual: AMBIL closes the gripper, LEPAS opens it, and LOCK / SCAN work before or after the
  item is picked up.

## 9. FPS and the video lag guard (owner, 25 Nov)

Measured on the MaixCAM2 over USB (Mac client; the phone path adds `adb reverse` + an SSH tunnel):

| | Before (v2) | After (v3) |
|---|---|---|
| Stream | 6–8 fps (`jpeg+send` ~100 ms a frame) | 19.9 fps (camera's own rate; bare pipeline also 19.8) |
| STATUS reply while streaming | median 240–450 ms | median 2 ms, p90 4 ms |
| Reader taking 4 frames/s (no read-ahead) | frames queue, reply up to 4.3 s | board sends 4/s and skips the rest, reply max 0.76 s |

Causes, in order of size:

1. **`uart.read(-1, 0)` blocks ~35 ms holding the GIL** even with nothing received. The arm thread polled
   UART4 and UART2 every 50 ms, so the video pusher and the WS handlers waited for the GIL most of the time.
   Fix: `uart_read_ready` reads only `available()` bytes.
2. **websockets' per-message deflate** on every ~44 KB frame (JPEG does not shrink): `compression=None`.
3. **Blocking `camera.read()`** holds the GIL while it waits for the next frame: `read_frame_nowait`
   (`block=False`) and `await asyncio.sleep(CAM_POLL_S)` in between.
4. A frame bigger than websockets' 32 KiB `write_limit` made every `send` wait for the link:
   `write_limit=256 KiB`.

**Lag guard** (`client_behind`): a client is skipped for this frame while its last frame is still in
asyncio's buffer or more than `WS_BEHIND_BYTES` (16 KB) of it is unacknowledged in the kernel (`SIOCOUTQ`),
and its socket send buffer is 32 KB. So a slow link or busy phone gets the newest frame instead of a queue,
and arm replies (`motion_done`, errors) never wait behind seconds of video. The `[FPS]` line now shows
jpeg / encode / send and `sent N/s, skipped M (link behind)`.

**Sequence pause, not abort** (`arm_bridge.py`, `SEQ_GRACE_S` 5 s): during MOVE_TO_BIN, DROP or HOME, no
app message for over 1 s pauses the sequence where it is (same pose streamed); if the app is back within
5 s it carries on from the same point (the leg's clock skips the pause; `motion_done` gets `paused_s`);
after 5 s the old watchdog (freeze, error `watchdog`). Below the app's 8 s stale-link reconnect. Manual
ARM_POSE keeps the 1 s rule; a disconnected app still freezes at once (the app is STOPPED on link loss).

**App bin run** (`BinRun`): after DROP the arm goes HOME (Right-Tank-New ends off home), so the run ends at
home; every command (MOVE_TO_BIN, DROP, HOME) has a 60 s `replyTimeout`; any failure that is not STOP or a
lost link sends HOLD (ends whatever the robot may still play) then HOME, and says why.

Tests: `test_clean_stream.py` `LagGuardTest` (2) and `UartPollTest`, `test_arm_bridge.py` (3 lag tests),
`bin_run_test.dart` (3); the skip, pause, timeout and home steps were break-checked. `SIOCOUTQ` is
Linux-only: tested on the board, stubbed on the Mac.

Restarting the app without the touchscreen: `python3 -c 'from maix import app; app.switch_app("elios_clean_m2c_v1")'`
(writes `/tmp/run_app.txt`), then stop the running app, or the launcher UI if it is in front; the
`launcher_daemon` starts the queued app. Do not `pkill -f` a pattern that is also in your own SSH command.
