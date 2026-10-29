# Lane D: Scan History and PDF crop images

Branch: `feat/d1-history-crops`. Base: `b842ce2` (includes #49 and #51).
Worktree: `/private/tmp/elios-d1-history-crops`.

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
text under independent PDFKit extraction. Review fixtures live under
`/private/tmp/d1-review`; they are not repository assets.

## Limits and handoff

- Native macOS PDF picker acceptance is intentionally left to Claude Code.
- The supplied `scan-1792298280246520-7-identify.jpg` exists, but macOS denied
  reading its contents even after an approved attempt. Its stated approximate
  380x270 dimensions and halo were not independently inspected.
- A clean crop cannot restore detail lost in camera JPEG encoding or remove
  a halo already present in the source pixels. Existing photos remain intact;
  recapture from a clean frame is the upgrade path.
- Test-only `.env.dev` and `.env.prod` in this worktree are empty, ignored asset
  placeholders; no owner credentials were copied.
