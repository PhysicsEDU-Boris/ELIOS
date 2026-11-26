# Fake MaixCAM2 (sim-backed)

A WebSocket server the app connects to exactly like the robot's MaixCAM2, so you can test without
the robot. Frames are rendered by the owner's simulator,
[robotic_hand_sim](https://github.com/3dbore/robotic_hand_sim), through its offscreen
`SimCalibrationCamera`: 640x480, the same lens pose, and the camera turns with J1. Detections come
from ground truth, not a model. See decision
[0024](../../docs/decisions/0024-fake-maixcam-sim.md).

The protocol is copied from `firmware/maixcam2/main.py`:

- `{"status":"Connected"}` on connect.
- `ping` gets a `pong` with `firmware_version` `fake-sim-<n>`.
- `start_stream` / `stop_stream` turn the stream on and off; `disconnect` gets `disconnect_ack`.
- `motor` moves the simulated base; `servo` `reach` and `height` use 2 mm Cartesian IK steps
  without turning J1; debug `base` still turns J1. `lateral` is rejected because world-X motion
  needs J1 and would pan the attached camera. The `gripper` value is width (0 open, 100 closed).
- Frames carry `vision_protocol`, `firmware_sha256`, `frame_id`, `detection_frame_id`, `image`,
  `img_w`, `img_h` and `detections`. Detection frames (every 2nd frame) also carry
  `clean_detections` and `clean_image`.

P1 fields (`track_id`, `dist_cm`, `lateral_cm`, `arm_tags`; decision 0022) are on unless the
scenario says `p1: false` or you pass `--old-firmware`.

## Install

```sh
python3 -m venv ~/.venvs/fake-maixcam
~/.venvs/fake-maixcam/bin/pip install -r tools/fake_maixcam/requirements.txt
git clone https://github.com/3dbore/robotic_hand_sim.git ~/GITHUB/ELIO/robotic_hand_sim
```

Clone the simulator next to this repo; it is not copied in. It was tested against commit
`9b2737e` (2026-10-23), with Python 3.12, websockets 17.3, numpy 2.5, pyvista 0.49 and
opencv 5.0.

## Run

Once, for photo cards (see "Photo cards"): `make_crops.py --dataset ~/datasets/waste-dataset-v8`.

```sh
~/.venvs/fake-maixcam/bin/python tools/fake_maixcam/fake_maixcam.py \
    --sim-path ~/GITHUB/ELIO/robotic_hand_sim \
    --scenario tools/fake_maixcam/scenarios/single_item_60s.yaml
```

Options:

- `--port` (default 8765)
- `--fps` (default: the scenario's, else 10)
- `--old-firmware`
- `--bin-tag right|wrong|none` (default right): the AprilTag seen at a bin's state point after `MOVE_TO_BIN` (0233)

`ARM_POSE` (0234) plays the app's planned legs; a leg over the tank is logged as a warning.
`MOVE_TO_BIN` / `DROP` play the bin's saved sequence from `firmware/maixcam2/bin_sequences.json`
(b3 = Left-Tank-New, anorganik = Mid-Tank, organik = Right-Tank-New) through the sim's tank planner.

Motion follows the robot (decision 0240): every leg uses the MaixCAM2 bridge's own maths
(`firmware/maixcam2/arm_bridge.py`, pinned to robotic_hand_sim's `ProfiledMotion`). Each joint,
the gripper included, ramps up, cruises at its top speed and ramps down; all arrive together; each
saved step's `hold` is waited. Bin steps use their saved `motion` block; manual moves (`ARM_POSE`,
`HOME`) use the profile from `CONFIG` (Advanced settings › Speed & ramps), else the defaults.

Picking up is manual, as on the robot: closing the gripper (AMBIL, the Penjepit slider) with the
end effector within 60 mm of an item grips it; opening it at a bin's state point drops the item
in the bin, elsewhere on the floor. `PICK` still works for the R1 tests.

- `--show`: opens robotic_hand_sim's own 3D view (`hil/scene.py` `Scene`, the one
  `arm-hil-toolkit-2.py` shows) in its own window (`arm_view.py`) and follows the arm. It runs with
  the sim's Python (`<sim>/.venv/bin/python`, PyQt5 + pyvistaqt); `--show-python` picks another.
- `--seed` (sets the photo choice and the noise; the same seed repeats a run)
- `--check-labels`: compares `labels.yaml` with `main.py`'s `LABELS` and the app's
  `ScannedWaste.detectorLabels`, then exits. Exit code 1 means a mismatch.

The scenario clock starts at the first `start_stream`. Restart the server to replay a scenario.

## Point the app at it

Build the robot app as usual (`CLAUDE.md`, "Robot build"), open the robot config screen, set the
IP to `127.0.0.1` and the port to `8765`, and connect. From a phone on the same WiFi, use the
Mac's LAN IP instead.

## Photo cards

Each item is an upright card showing a photo. On 24 Oct, whole camera frames stretched onto tall
cards made Gemma guess wrong: a battery photo that was mostly pegboard wall came back as "Tiruan".
Placeholder cards printed their label, so Gemma read the word. Cards are now built like this:

- **Crops from the training set:**

  ```sh
  ~/.venvs/fake-maixcam/bin/python tools/fake_maixcam/make_crops.py --dataset ~/datasets/waste-dataset-v8
  ```

  - It writes up to `--per-class` (default 20) tight crops per class to `images/<label>/crops/`,
    with a 10 % margin.
  - It skips objects smaller than 80 px, objects touching the image edge, and Human_Hand.
  - It reads box and polygon (YOLO-seg) labels from every split.
  - The crops are the same for a given `--seed` (default 0). A rerun replaces the old set.
  - It stops if the dataset's `data.yaml` class names differ from `labels.yaml`.
  - With the default seed, each of the 9 classes got 20 crops (11 s).
- **Photo choice per item**, in this order:
  1. its own `photo:` (if the file exists);
  2. a crop from `images/<label>/crops/`;
  3. a whole photo from `images/<label>/`, centre-cropped to 4:3 (3:4 if portrait);
  4. a placeholder.

  The pick depends only on `--seed` and the item id, so a run repeats. Every item logs
  `[Photo] <id> (<label>): <kind> <path>`.
- **Placeholder:** a plain colour with diagonal stripes, **no text**. Each placeholder item logs a
  WARNING. Human_Hand always gets one unless you add photos to `images/Human_Hand/`.
- **Size:** `size_mm` is the card's **longer side**; the other side follows the photo's aspect
  ratio, so nothing is stretched. An old `[w, h]` pair counts as its larger value. The box is the
  projected card, so it matches the visible card exactly.
- **Occlusion** (`occlusion: true`, the default): a card hidden more than 60 % by nearer cards
  gets no box, and a partly hidden one gets the box of its visible part. The image is rendered
  with depth anyway, so `clean_image` and the app's identify crop show what the camera really
  sees. The arm does not occlude cards.

The images stay gitignored (licence and size).

## Timing rule

The first item locks about 1 s in, and its quiz blocks new locks until a tester closes it. So:

- **every event a scenario tests happens at t ≥ 25 s;**
- **a leave → appear swap on the same spot (within 5 cm) needs ≥ 8 s** (the cooldown's tail plus
  0020's 2 s absence).

Loading a scenario checks both, and prints `[Scenario] WARNING ...` (it is not an error).

## Scenarios (`scenarios/`)

| File | What it checks |
|---|---|
| `single_item_60s` | One item held 60 s: exactly one lock and one quiz. |
| `one_<label>` (9) | One crop of that class for 60 s: identify checks; bank questions of that class (0025). |
| `item_leaves_new_arrives` | The bottle leaves at 30 s; a can arrives on the same spot at 38 s: a second lock (0020). |
| `flicker_dropouts` | Score jitter, 15 % flicker, a 300 ms dropout every 2 s: still one lock. |
| `hand_enters` | A Human_Hand in front of the quizzed bottle from 25 to 40 s: the bottle is hidden, the hand never locks. |
| `two_items` | Two items with different labels: one locks; the other may lock after the 15 s cooldown even with the first in view (0020). |
| `two_same_class` | Two Plastic items: the second waits until the quizzed one has been gone 2 s (0020); with track ids (M6) it would not. |
| `all_classes` | Nine classes one after another (35 s each, 10 s gaps): identify checks in one run. |
| `b3_item` | E_Waste: the hazard confirmation path. |
| `label_change_same_box` | Paper becomes Cardboard on the same box at 30 s. |
| `link_drop_mid_quiz` | Keep the first quiz open; the link goes silent at 30 s for 12 s (longer than the 8 s watchdog): reconnect. |
| `old_firmware` | No P1 fields: behaviour identical to `single_item_60s`. |
| `j1_sweep_item_in_view` | From 25 s, J1 turns to 25, -25 and 0 at 40 deg/s; the box slides out and back. |
| `organic_items`, `organic_mango` | The owner's organic checks, now on dataset crops: a cut fruit (the closest to a mango), then a peel at 38 s. |
| `r1_full_sort` | Plastic PICK → organik bin → DROP. |
| `r1_b3_sort` | E_Waste phone for the B3 hazard-confirmation path. |
| `r1_hand_pauses_arm` | A hand appears during the sort window and leaves later. |
| `r1_unreachable` | PICK rejects an item outside arm reach. |
| `r1_position_nudge` | Item near the useful reach edge for manual base-position nudges. |

## Writing a scenario

```yaml
name: my_test
description: what the tester should see
duration_s: 60            # informational only
fps: 10                   # optional
p1: true                  # false = old firmware
occlusion: true           # nearer cards hide farther ones (default)
arm: {j1: 0}              # starting J1 angle, deg
noise: {score_jitter: 0.03, flicker: 0.0, dropout_ms: 0, dropout_every_s: 0, label_swap: 0.0, swap_to: null}
items:                    # upright photo cards standing on the floor
  - id: bottle
    label: Plastic        # one of labels.yaml
    pos_mm: [-54, -301]   # base frame x, y; the lens is at (-54, -51.1), looking along -Y,
                          # so this is 25 cm straight ahead
    size_mm: 120          # the card's longer side; the photo sets the other
    score: 0.88
    visible: true         # false = appears later through an event
    photo: images/Plastic/crops/x.jpg   # optional; default: see "Photo cards"
events:                   # t in seconds from start_stream; tested events at t >= 25 (timing rule)
  - {t: 25, do: appear, item: hand}
  - {t: 40, do: leave, item: hand}
  - {t: 30, do: set_label, item: bottle, label: Metal}
  - {t: 30, do: noise, flicker: 0.2}
  - {t: 30, do: link_drop, for_s: 12}    # silent, and new connections refused, for 12 s
  - {t: 25, do: arm, j1: 25}             # J1 moves there at 40 deg/s
```

A label must be one of the 10 detector classes. Unknown labels, items or events are refused when
the scenario loads.

## Heartbeat, watchdog and arm_moving (decision 0026)

Every command the fake receives gets a log line. For example, `[WS] STOP seq=12 -> wheels 0,
arm hold`, `[WS] heartbeat x4/s` (at most once a second) and `[WS] unknown cmd 'X'`. So after a
reconnect you can read STOP and `motor left=0 right=0` coming first.

- `{"cmd": "HEARTBEAT"}` (from the app, 4 Hz) is accepted, with no reply.
- With no app message for 1 s, the fake logs `[Watchdog] no app message for 1 s: wheels 0 / arm
  hold` and holds J1 where it is. It logs `[Watchdog] app messages again` when they return.
- With `p1` on, every frame carries `arm_moving` (true while J1 moves). The app's J1 guard uses
  it.

## Command link (decision 0023)

`{"cmd": NAME, "seq": n, ...}` gets `{"event": "ack" | "motion_done" | "error", "seq": n}` back.

- Answered:
  - `STATUS`: ack, with `drive_locked`, `ee_mm: [x,y,z]` and `at_home` (commanded target is all
    zero joints and gripper open; this is not physical position feedback);
  - `HOME`: ack, then motion_done after the simulated joints reach zero at the firmware speeds; opens the
    gripper to its D2 home value;
  - `LOCK_DRIVE` / `UNLOCK_DRIVE`: ack; `motor` is logged as dropped while locked;
  - `HOLD`: ack, then motion_done;
  - `STOP`: ack;
  - `J1_SWEEP {"to": deg}`: fake only, not part of 0023. Ack, then motion_done when J1 arrives at
    the firmware speeds.
- `PICK`, `MOVE_TO_BIN` and `DROP`: use the simulator's IK and per-joint firmware speeds (base 40, Arm A/B 30, pitch/yaw 45 deg/s, decision 0230); ACK is
  immediate and `motion_done` follows arrival. PICK matches supplied distance/lateral to a visible
  card; unreachable targets return `error: unreachable`. The carried card follows the gripper and
  is hidden after DROP.
- Any other command with a `seq` replies `error: unknown_cmd`.

Arm serial output and the app safety contract are specified in
[decision 0027](../../docs/decisions/0027-arm-serial-protocol.md): the fake's `HOME` and supported
hand axes follow that contract, but the app must gate HOME while STOPPED or sorting and pause it
on Human_Hand. A camera reboot does not home the arm; without servo feedback, only the last
commanded pose is known. The measured tag-check poses are `home` `[0,0,0,0,0]` (no arm tags
visible) and `inspect` `[0,50,-120,90,-45]` (tags 0 and 1 visible).

## Tests

```sh
cd tools/fake_maixcam && ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q
```

The tests need no hardware, but they do need the simulator: without it, the tests that use the
sim are skipped. Wheel motion uses estimated fixed PWM-to-speed and track-width values; calibrate
those before quantitative drive tests.

## Limits

- Cards don't occlude each other, and the arm doesn't occlude cards or tags, so a hidden item
  still gets a box.
- Tags count as "in view" when they face the lens and all their corners are inside the image.
- There is no segmentation mask.
