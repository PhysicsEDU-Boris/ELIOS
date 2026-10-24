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
- `motor` and `servo` are only logged; `set_resolution` is ignored.
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

```sh
~/.venvs/fake-maixcam/bin/python tools/fake_maixcam/fake_maixcam.py \
    --sim-path ~/GITHUB/ELIO/robotic_hand_sim \
    --scenario tools/fake_maixcam/scenarios/single_item_60s.yaml
```

Options:

- `--port` (default 8765)
- `--fps` (default: the scenario's, else 10)
- `--old-firmware`
- `--seed` (sets the noise)
- `--check-labels`: compares `labels.yaml` with `main.py`'s `LABELS` and the app's
  `ScannedWaste.detectorLabels`, then exits. Exit code 1 means a mismatch.

The scenario clock starts at the first `start_stream`. Restart the server to replay a scenario.

## Point the app at it

Build the robot app as usual (`CLAUDE.md`, "Robot build"), open the robot config screen, set the
IP to `127.0.0.1` and the port to `8765`, and connect. From a phone on the same WiFi, use the
Mac's LAN IP instead.

## Scenarios (`scenarios/`)

| File | What it checks |
|---|---|
| `single_item_60s` | One item held 60 s: exactly one lock and one quiz. |
| `item_leaves_new_arrives` | The item leaves and a different one arrives: a second lock (0020). |
| `flicker_dropouts` | Score jitter, 15 % flicker, a 300 ms dropout every 2 s: still one lock. |
| `hand_enters` | A Human_Hand covers the item from 8 to 14 s: the hand never locks. |
| `two_items` | Two items: one locks, the other waits until the first leaves. |
| `b3_item` | E_Waste: the hazard confirmation path. |
| `label_change_same_box` | Paper becomes Cardboard on the same box at 10 s. |
| `link_drop_mid_quiz` | The link goes silent at 8 s for 12 s (longer than the 8 s watchdog): reconnect. |
| `old_firmware` | No P1 fields: behaviour identical to `single_item_60s`. |
| `j1_sweep_item_in_view` | J1 turns to 25, -25 and 0 at 60 deg/s; the box slides out and back. |

## Writing a scenario

```yaml
name: my_test
description: what the tester should see
duration_s: 30            # informational only
fps: 10                   # optional
p1: true                  # false = old firmware
arm: {j1: 0}              # starting J1 angle, deg
noise: {score_jitter: 0.03, flicker: 0.0, dropout_ms: 0, dropout_every_s: 0, label_swap: 0.0, swap_to: null}
items:                    # upright photo cards standing on the floor
  - id: bottle
    label: Plastic        # one of labels.yaml
    pos_mm: [-54, -301]   # base frame x, y; the lens is at (-54, -51.1), looking along -Y,
                          # so this is 25 cm straight ahead
    size_mm: [70, 120]    # width, height
    score: 0.88
    visible: true         # false = appears later through an event
    photo: images/Plastic/bottle.jpg   # optional; default: first photo in images/<label>/
events:                   # t in seconds from start_stream
  - {t: 8, do: appear, item: hand}
  - {t: 14, do: leave, item: hand}
  - {t: 10, do: set_label, item: bottle, label: Metal}
  - {t: 12, do: noise, flicker: 0.2}
  - {t: 20, do: link_drop, for_s: 12}    # silent, and new connections refused, for 12 s
  - {t: 5, do: arm, j1: 25}              # J1 moves there at 60 deg/s
```

A label must be one of the 10 detector classes. Unknown labels, items or events are refused when
the scenario loads.

## Command link (R1, decision 0023: not written yet)

`{"cmd": NAME, "id": n, ...}` gets `{"event": "ack" | "motion_done" | "error", "cmd": NAME, "id": n}`
back. The shape is provisional until 0023 defines it.

- Implemented: `HOLD` (ack, then motion_done), and `J1_SWEEP` with `{"to": deg}` (ack, then
  motion_done when J1 arrives at 60 deg/s).
- Not implemented yet: `PICK`, `MOVE_TO_BIN`, `DROP`, `STOP` and `DRIVE` reply
  `error: not_implemented`. The TODOs in `FakeMaixCam.__init__` say what each one should do.

## Tests

```sh
cd tools/fake_maixcam && ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q
```

The tests need no hardware, but they do need the simulator: without it, the tests that use the
sim are skipped.

## Limits

- Cards don't occlude each other, and the arm doesn't occlude cards or tags, so a hidden item
  still gets a box.
- Tags count as "in view" when they face the lens and all their corners are inside the image.
- There is no segmentation mask.
