# 0181: LOCK labels and boxes the item; SCAN opens its quiz

- Status: Accepted (owner, 3 Nov 2026: step 1 of "drop the .mud model, Gemini box on LOCK,
  tracking after the lock, AprilTags for the arm")
- Date: 2026-11-03
- Builds on: [0180](0180-segmentation-and-fps-options.md) (`box_2d` in the identify call),
  [0174](0174-r3-control-phone.md) (R3 phone Control), [0012](0012-crop-identification-and-hazards.md).

## Why

The owner's segmentation model misses items and mislabels them (a cardboard box as E_Waste), and
its masks are untidy. A Gemini box on every frame would use the free quota in minutes, so the user
starts one AI box per object with a button. Tracking the box while the object moves comes next
(firmware: MixFormerV2 started from this box; ByteTrack needs a per-frame detector, which goes
away with the .mud model).

## Decision

- **LOCK** labels and boxes; it opens no quiz (owner, 3 Nov: "locking doesn't need to open the
  quiz"). It sends the **whole frame** through the identify call (one Gemini call, no backend
  change): the paired clean image when one arrived in the last second, else the live preview. With
  today's firmware the preview can carry the firmware's own boxes and masks.
- The whole-frame prompt asks for one waste item, not hands, walls, boards, tables, floors or
  cables, and allows "tidak jelas" (none). A first robot test named a cable "kardus" with the
  plain prompt. The detector-lock prompt is unchanged.
- The answer stays on the video as a green box with the item name until **UNLOCK** (the same
  key) or the next LOCK. No item: a snackbar, nothing locked.
- **SCAN** opens the quiz popup for the locked item from the LOCK answer (no second call). With
  nothing locked, SCAN locks first. The popup and History photo are the AI's box cut from the
  frame (the whole frame without a box). No detector label: bank pool and hazard come from the AI.
- LOCK and SCAN sit at the bottom right of the video (R3 phone). The action bar had no room: with
  five keys the gripper fader got 27 px on an 800 px phone.
- The detector's automatic lock and its popup still run (the "Scan quiz" toggle turns them off)
  until the .mud model is dropped in the firmware step.

## Not in this step

- R2 (tablet/Mac) Control has no LOCK key.
- The box does not follow a moving object (firmware step: MixFormerV2 + a track id).
- Arm picking still uses detector boxes.

## Tests

- `test/m2c_identification_test.dart`: LOCK sends the clean frame with the waste-only prompt, opens
  no quiz (break-checked), and keeps the box and its crop; SCAN starts the quiz from that answer
  with no second call; "tidak jelas" locks nothing; no box keeps the whole preview.
- `test/widgets/phone_control_test.dart`: LOCK and SCAN tap through; a locked item reads UNLOCK and
  its box is drawn over the video at the cover-scaled position. `control_layout_test` (all sizes)
  passes.

## Robot test (3 Nov, APK `a7e8158`, real MaixCAM2)

- LOCK sent the paired clean frame; `gemini-3.1-flash-lite` answered in 2.2 s with "kardus" and a
  box; the green "Kardus" box sat on the video at the right place
  (`docs/test-results/0181/lock-green-box-on-video.png`). Closed with ✕, nothing saved.
- Problem found: no waste item was in view, and the AI still named something: it boxed a strip of
  cable along the table edge as "kardus". The identify prompt asks for "the main object", which a
  whole frame always has. Next: a LOCK prompt that may answer "nothing" (wall, board, table and
  cables are not waste).
- The live preview still shows the .mud model's large red mask over the pegboard, the owner's
  "untidy mask" complaint.
