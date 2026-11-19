# 0233 — Bin AprilTag check at the bin state point

Date: 19 November 2026. Branch `feat/bin-tag-check`, stacked on `feat/advanced-settings` (0232).

## Why

Each bin gets an AprilTag so the robot can confirm it reached the bin the app chose
(`robotBin`: detector, ELIOS AI, B3 veto) before it lets go of the item, the way the first
quiz confirms the object.

## Tags

| Bin | `Bin` | tag36h11 id |
|---|---|---|
| Anorganik | `anorganik` | 2 |
| Organik | `organik` | 3 |
| B3 | `b3` | 4 |

Printed 30 mm, black square 18.52 mm, like arm tag id 0:
`docs/print/apriltags-bins-id2-id3-id4-A4.pdf` (`tools/camera_test/make_bin_pdf.py`).
The ids live on `Bin.tagId` (`robot_controller.dart`). The firmware's `TAG_SIZES_MM` now
reports ids 2–4 with their size, so `arm_tags` carries them with a rough `dist_mm`.

## Flow

The arm steps in SORTING / WAIT_BOTH become:
0 `PICK` → 1 floor check → 2 `MOVE_TO_BIN` (to the bin's state point) → **3 bin tag look** → 4 `DROP`.

- The look starts at `MOVE_TO_BIN`'s `motion_done`. The arm holds still: no arm command is sent.
  Tag search is already on in SORTING / WAIT_BOTH (`wantsArmTags`, 0182).
- The right bin's tag seen for `binTagSeenFor` (0.5 s) → "Right bin!" and `DROP`.
- Another bin's tag for 0.5 s, or no right tag within `binLookTimeout` (3 s) → a failed look.
- First failed look: look again ("Looking again…"). Second: the session ends with reason
  `bin_check_failed`, **no `DROP`**, driving unlocked, and the control screen sends `HOME` through
  `MotionGate.home()` (owner, 19 Nov: retry once, then HOME with a message). The message asks for
  the item to be taken out of the gripper.
- A hand during the look pauses with `HOLD` as before; when it is gone the look starts over and the
  retry is not used up.
- Events: `r1_bin_check` {result `ok` / `wrong_bin_tag` / `bin_tag_not_seen`, bin, retried}.

## State points (owner, 19 Nov)

- `firmware/maixcam2/bin_sequences.json` holds the owner's sequences from robotic_hand_sim's
  Sequences tab (servo degrees, sim format) plus a `bins` map. **Only Left-Tank-Throw is used, and
  it is the B3 bin**: `MOVE_TO_BIN b3` = Poses 1–4, the tag check at Pose 4 (state point), `DROP` =
  Pose 5 (gripper opens) then Poses 6–7 (Pose 7 = home, gripper open). Right-Tank-Throw (one pose,
  unfinished) is stored but unused; Organik and Anorganik have no sequence yet.
- Checked in the sim: every pose is inside `hil/config.py` joint limits, every leg and the HOME
  from Pose 4 pass `kinematics.path_unsafe` (tank keep-out) as one straight joint-space move.
- The fake MaixCAM2 plays these steps through `kinematics.plan` (as the sim's playback does);
  bins without a sequence keep the placeholder `BIN_TARGETS`. Its joints now start and arrive
  together, the straight joint-space move the planner assumes. Hold times are not waited.
- The real MaixCAM2 still has no `PICK` / `MOVE_TO_BIN` / `DROP` (R1-fw, 0230 §4); it should read
  the same file.
- Safe zone after the state point, for now: hold still while looking, `HOLD` on a hand, never
  `DROP` on a failed check, `HOME` after the second failure. More behaviour comes with the owner's
  next sequences.

## Not handled

- `HOME` is skipped when a hand is in view at that moment (MotionGate holds instead); the arm then
  stays at the bin until the HOME button.
- Whether `HOME` keeps the gripper closed depends on the firmware's HOME (0027); not checked.
- Tag range at 18.52 mm from the arm's bin pose is not measured on the robot.
- Old firmware without `arm_tags`: every look fails, so the robot never drops; it goes HOME.

## Tests

`test/r1_orchestrator_test.dart` group "bin tag check": right tag → DROP; no tag → retry then
`bin_check_failed` without DROP; wrong tag twice; wrong then right on the retry → DROP; hand
during the look. Break-checked against the old orchestrator: 4 of 5 fail (the wrong-then-right
case also passes on the old code, which always dropped). Fake MaixCAM2: `bin_tags()` per `--bin-tag`; `bin_paths` data check; B3 sequence tank-safe in the
sim; PICK → MOVE_TO_BIN b3 ends at Pose 4 with tag 4 seen → DROP releases and ends home (break-checked:
fails without the sequences).
