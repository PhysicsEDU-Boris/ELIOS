# M2c clean-image firmware

Deployed on the robot 16 Oct 2026: scan JSONL `firmwareSha256`
`bbb3595e8070d4fab421ce38d5a9becbca26f6bcc8c34be4d7e29ed5c2ab79e6` matches
`shasum -a 256 main.py`.

## MaixVision package

`app.yaml` is the MaixVision app manifest (`elios_clean_m2c_v1` v1.0.0, files:
`main.py`). The package `dist/maix-elios_clean_m2c_v1-v1.0.0.zip` is a build
output (exactly `app.yaml` + `main.py`), so it is gitignored; rebuild it from
these two files in MaixVision. Bump `version` when `main.py` changes.

Deployable entry point: **main.py** in this directory. It is a complete copy
of the owner's local Maixcam.txt reference with the clean-image stream change.
Reference SHA-256: `da57d135a004e399a4a4bb7a8c132209ce340fc3565856640d70bc2f5734a0cc`.
Maixcam.txt itself remains untracked and unchanged. The reference has not been
verified byte-for-byte against the robot's currently installed script.

## Owner deployment

1. Export/back up the **currently running** robot main.py through your existing
   MaixVision/SSH workflow. Record its active project/boot path and SHA-256.
   Compare it to the reference above before replacing it; if it differs, review
   those changes first so device-specific behavior is not lost. This reference's
   motor/servo handlers only print commands; it does not add hardware actuation.
2. Deploy this directory's `main.py` to that confirmed active entry-point path,
   retaining the robot's existing model `/root/models/elios_waste_seg.mud`,
   MaixPy, numpy, websockets and AP configuration. Do not deploy the test file.
   Do not run a second server beside the existing port-8765 process.
3. Restart the existing robot application using your normal deployment workflow.
   Its console must print `[Firmware] m2c-clean-v1 <sha256>`.
   Compare that hash with the local result of:
   `shasum -a 256 firmware/maixcam2/main.py`.
   The hash is also returned by `{"cmd":"ping"}` and included in scan JSONL
   as `firmwareSha256`. A version string alone is not a deployment check.
4. Build the matching app from this branch:
   `flutter build macos --debug --dart-define=LIVE_SCAN=true --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`.
   Quit the previous app, then `open build/macos/Build/Products/Debug/ELIOS.app`.
5. To roll back, restore the backed-up robot script at the same active path and
   restart. The new app will retain preview/controls but cannot identify from
   that old annotated-only stream; use the previous app only if needed for
   historical behavior, knowing it sends annotated pixels to Gemma.

## Wire contract

- `image`, `img_w`, `img_h`, `detections`: existing annotated preview contract.
- `vision_protocol: 1`, increasing `frame_id`, `firmware_sha256`: every message.
- `detection_frame_id == frame_id` plus `clean_detections`: only a successful
  inference on this original capture. Fresh matched objects only; boxes held
  through missed detections remain in the preview list, never the clean list.
- `clean_image`: base64 JPEG encoded from that original capture BEFORE mask,
  box and label drawing, only when `clean_detections` is nonempty. Identical
  dimensions/orientation to preview; center XYWH geometry uses those pixels.
- Between inference frames, detection_frame_id is null and clean fields are
  omitted. No cached clean images are retransmitted. A fresh empty list counts
  as an empty-scene observation; a preview-only frame does not.

One extra JPEG is necessary on nonempty inference frames to retain the proven
burned-in mask preview without inventing another mask-rendering protocol.
There is no extra JPEG on intervening, empty or held-only frames. Encoding is
once per capture, shared across clients; legacy clients ignore the added fields
but still receive the larger inference messages. Bandwidth/FPS require hardware
measurement; identification now samples fresh inference frames, not every preview.
No cooldown, lock or score thresholds changed. No recoloring/inpainting is used.

## Retest gate

- Isolated phone and bottle: inspect exact saved `*-identify.jpg` files, not
  preview screenshots. No synthetic red mask, green box or detector text may
  appear. JSONL must show `imageSource: clean_image`, matching frame/detection
  IDs and the deployed firmware hash. Record returned item/material/category.
- Preview must retain segmentation and visibly move during Looking, B3
  confirmation and quiz. Check FPS with the extra inference-frame encoding.
- E_Waste must still force B3 confirmation when Gemma returns anorganik/residu;
  Continue must open the quiz, Rescan must not open a late quiz.
- Close during Looking, wait for the late result, then finish a later scan.
  After quiz close wait 15 s plus >=2 s empty; hold an item 60 s without repeats.
- Report crop, identify first-token/completion and question generation separately
  from human confirmation wait. `hazard_continue` minus `resolved` elapsed time
  gives confirmation wait. Total lock-to-question includes that wait.

Local check: `python3 firmware/maixcam2/test_clean_stream.py`. This executes the
actual stream function with fake camera/inference; it does not verify MaixPy's
native encoder, deployment, performance, or recognition. M2c remains incomplete.
