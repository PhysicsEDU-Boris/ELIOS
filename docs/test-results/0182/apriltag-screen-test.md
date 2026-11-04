# 0182 AprilTag test on the real camera (4 Nov)

Camera firmware `m2c-track-v1`, sha256 `9cd825b3…` (same as the repo). Client: Python websockets
over USB `ws://10.73.69.1:8765`, `{"cmd":"arm_tags","on":true}`, then off. Target: the laptop
showing `apriltags-36h11-id0-id1.png` (both tags the same size on screen), held in front of the lens
by the owner. No firmware change.

| Run | Time | fps (frames to client) | Detection frames with a tag | ids |
|---|---|---|---|---|
| Tags on, both tags in view | 25 s | 22.2 | 154 / 279 (55 %) | id 0: 139, id 1: 76 |
| Tags off | 10 s | 44.9 | 0 / 225 | none |
| Tags on, laptop held still | 20 s | 20.5 | 205 / 206 (100 %) | id 0: 205, id 1: 0 |

- **Both ids decode** on the real camera. Wherever a tag was not washed out, it was found in
  almost every frame (`apriltag-screen-both.jpg`).
- **Misses were screen glare.** The room is dark, so auto-exposure saturates the laptop screen.
  In run 3 a bright patch covers id 1 (`apriltag-screen-glare.jpg`). Run 1 includes the laptop
  being moved into view. A matte print on the arm does not glow, so this is a test-setup effect,
  not a firmware bug.
- **fps cost.** The tag search halves the stream (45 → 21 fps). This is why tags stay off except
  around a grip.
- **Tag size seen.** Every tag found was 88–97 px across in the 640x480 frame, so 44–48 px in the
  320x240 search copy. The camera's lens-to-screen distance and the on-screen tag size were not
  measured, so `dist_mm` was not checked against a real distance. It reads 52–76 mm for id 0 and
  31–43 mm for id 1, because it assumes the print sizes 18.52 mm and 10 mm.

## Not tested (owner: later, once the tags are printed on the robot)

- **Small tags.** On the robot the tags will be much smaller in the frame. For example, the
  18.52 mm tag at 20 cm is about 35 px at 640 and 17 px in the search copy. The 10 mm tag at
  20 cm is about 19 px and 9 px, which may be too small for the half-size search. If id 1 is
  missed on the arm, search full-size inside a crop around the gripper. Do not search the whole
  640x480 frame, because that kills the process.
- `dist_mm` against a measured distance. It stays rough until the camera is calibrated.
- The app turning tags on for a manual PICK UP (5 s) and during R1 grips.
