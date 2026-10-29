# Lane D: Scan History and PDF crop images

Branch: `feat/d1-history-crops`. Base: `b842ce2` (includes #49 and #51).
Worktree: `/Users/macbookairm12020/GITHUB/ELIO/elios-d1-history-crops`.
The original temporary worktree disappeared; the committed branch was pushed
and recreated here on 2026-10-29.

## Photo provenance

1. `firmware/maixcam2/main.py` encodes `clean_image` before drawing masks,
   boxes or text. The camera's JPEG encoding quality is unspecified here.
2. `CapturedFrame.fromRobotMessage` accepts the clean JPEG only with protocol 1,
   matching frame/detection IDs and matching frame dimensions. Annotated preview
   bytes remain separate. Missing clean data never becomes a preview-image crop.
3. `prepareDetectionCrop` decodes `frame.cleanBytes`, maps the locked detection
   box from frame metadata coordinates into actual decoded pixel coordinates,
   and clips to the image edges. Previously this used the exact detection box;
   now it includes 5% padding on each side. There is no resize or upscaling.
   Output dimensions are the clamped right-minus-left and bottom-minus-top,
   with outward pixel rounding. JPEG quality was the image library default of
   100; it is now explicitly 100. No mask colour, pixel painting or halo removal
   is performed.
4. `WasteQuizNotifier._cropThenIdentify` assigns those bytes to `_cropBytes`
   and submits the same crop to identification. The `*-identify.jpg` diagnostic
   is the submitted image. `_finish` writes `_cropBytes` unchanged into
   the application Documents `scans/scan_<timestamp>.jpg` and puts that absolute
   path into `ScanRecord.cropPhotoPath`. The JSON store keeps the path, not the
   image. Device-camera input is retained as supplied, without recompression;
   a `ponytail:` marker records the lack of a paired clean frame for that path.
   Existing records and JPEG files are not migrated or rewritten.

## Display and PDF

- History previously used `BoxFit.cover` in both list and detail. It now uses
  `BoxFit.contain` on a neutral surface: 56 logical pixels in the list and 180
  in detail. Missing, corrupt, unreadable and absent paths show `PHOTO` through
  the same error-safe placeholder. The mobile detail title truncates to avoid
  overflow. The larger detail image scrolls with the rest of the detail.
- Previously the PDF did not read `cropPhotoPath`. It now reads and validates
  it, embeds the original JPEG bytes, and contains the image in a 120-point
  neutral square beside the session's item metadata. Missing or invalid files
  use a placeholder. Question/answer/explanation widgets still flow directly
  through `MultiPage`; pending grades still say `Menunggu penilaian`.
- No store, seed or bank implementation changed; #51's sample preservation is
  retained.

## Verification

90 tests pass across:

- `test/clean_robot_frame_test.dart`
- `test/m2c_identification_test.dart`
- `test/scan_diagnostics_test.dart`
- `test/screens/scan_history_screen_test.dart`
- `test/services/quiz_pdf_service_test.dart`
- `test/services/scan_record_store_test.dart`
- `test/quiz_export_acceptance_test.dart`

New checks cover portrait, landscape and tiny native crops; clean-pixel
provenance, padded bounds and exact quality-100 encoding; all three requested
viewports (1366x768, 770x553, 390x844); missing, overwritten/corrupt and legacy
photo paths; original JPEG embedding; and a photo with a long pending essay
that spans pages and retains its final text and both pending-grade labels.
All history stores and report output used by tests are temporary. The older
PDF sample test also now uses its test's temporary directory and cleans up.
The owner's real history file was never opened or modified.

Static analysis of all nine changed Dart files reports no issues.
Synthetic portrait, landscape, tiny and missing-photo PDFs were rendered and
visually inspected using PDFKit. The two-page essay also retained its final
text under independent PDFKit extraction. Review fixtures were generated under
`/private/tmp/d1-review`; they are temporary and are not repository assets.

## Limits and handoff

- Native macOS PDF picker acceptance is intentionally left to Claude Code.
- The supplied `scan-1792298280246520-7-identify.jpg` exists, but macOS denied
  reading its contents even after an approved attempt. Its stated approximate
  380x270 dimensions and halo were not independently inspected.
- A clean crop cannot restore detail lost in camera JPEG encoding or remove
  a halo already present in the source pixels. Existing photos remain intact;
  recapture from a clean frame is the upgrade path.
- The original test worktree used empty, ignored `.env.dev` and `.env.prod`
  asset placeholders; no owner credentials were copied. Those untracked files
  were not restored when recreating the worktree.

## Crop/photo ownership and Lane A overlap

Lane D changed exactly these production files for this task:

- `lib/Screens/scan_history_screen.dart`: contained thumbnails, larger detail
  photo, decode-error placeholder and narrow detail-title bounds.
- `lib/services/detection_crop.dart`: robot paired-clean-frame crop padding
  and explicit quality 100.
- `lib/services/quiz_pdf_service.dart`: original crop embedded beside metadata
  with aspect preserved and an invalid/missing-image placeholder.
- `lib/providers/waste_quiz_provider.dart`: one `ponytail:` comment in `_finish`
  documenting preservation of supplied photos; no executable change.

Lane A's photo capture/crop path, inspected at `39009a2` on
`feat/a1-android-test-apk`, changes these production files:

- `lib/Screens/device_scan_screen.dart`: crops the phone image to the
  viewfinder before identification and the no-model selection path.
- `lib/services/frame_source/viewfinder_crop.dart`: new phone viewfinder
  crop helper, JPEG quality 90; direct crop commit `e4183b5` touches this file
  and `device_scan_screen.dart`.
- `lib/services/frame_source/phone_frame_source.dart`: Android image-stream
  capture, upright orientation and preview dimensions.
- `lib/services/frame_source/yuv_jpeg.dart`: YUV-to-upright-JPEG conversion.
- `lib/providers/waste_quiz_provider.dart`: preserves a supplied `photo` in
  `startForLabel` for no-model History records, among other Lane A changes.

The only shared production file is `lib/providers/waste_quiz_provider.dart`.
D adds only a comment in `_finish`; A's photo change is in `startForLabel`.
These are separate hunks. D does not recrop phone photos: its crop helper is
used on the robot-lock path, while History/PDF render either path's saved
bytes. No Lane A files or commits were merged into D. This overlap is also
recorded in the Lane D PR description.
