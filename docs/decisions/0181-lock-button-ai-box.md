# 0181: LOCK button — the AI boxes the item in the whole frame

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

- R3 phone Control gets a **LOCK** key in the action bar after RELEASE. It is enabled with a live
  link, a frame, and no open quiz. The automatic lock still runs as before (the .mud model is
  still on the camera until the firmware step).
- LOCK sends the **whole frame** through the existing identify call (one Gemini call, no backend
  change): the paired clean image when one arrived in the last second, else the live preview.
  With today's firmware the preview can carry the firmware's own drawn boxes and masks.
- The AI's `box_2d` crops the popup and History photo (as in 0180) and is kept as
  `WasteQuizUiState.lockBox`. The video shows it as a green box with the item name while that
  scan is open. It does not move with the object yet.
- No detector label: the bank pool and the hazard card come from the AI's answer only.
- No box from the AI: the popup and History photo are the whole frame.

## Not in this step

- R2 (tablet/Mac) Control has no LOCK key.
- The box does not follow a moving object (firmware step: MixFormerV2 + a track id).
- Arm picking still uses detector boxes.

## Tests

- `test/m2c_identification_test.dart`: the clean frame goes to the AI, its box crops the photo and
  is kept as `lockBox` (break-checked), cleared on dismiss; without a clean image the preview is
  sent and no box keeps the whole frame.
- `test/widgets/phone_control_test.dart`: LOCK taps through; the box is drawn over the video at the
  cover-scaled position (break-checked). `control_layout_test` (all sizes) passes with the key.
