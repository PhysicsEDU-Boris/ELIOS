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
3. `prepareDetectionCrop` decodes `frame.cleanBytes` once and maps the locked
   detection box into actual decoded pixel coordinates. Identification keeps
   the original exact box, outward rounding, edge clipping and JPEG encoding
   call/settings (the library default is 100). Its diagnostics still describe
   that unpadded crop. A separate `historyBytes` crop adds 5% padding on each side,
   clips to the frame edges and explicitly encodes at quality 100. Neither crop
   is resized or upscaled. No mask colour or pixel painting is performed.
4. `WasteQuizNotifier._cropThenIdentify` keeps identification bytes in `_cropBytes`
   and submits only those bytes to identification and the `*-identify.jpg`
   diagnostic. `_historyPhotoBytes` keeps the separate padded photo. `_finish`
   prefers that photo, falling back to the supplied identification/device crop,
   and writes it unchanged into Documents `scans/scan_<timestamp>.jpg`.
   `ScanRecord.cropPhotoPath` references that file; the JSON store contains the
   path, not the image. Device-camera input remains as supplied, without further
   cropping or recompression. The `ponytail:` marker records the fallback limit.
   Both photo variables reset on new sessions and dismissal; stale asynchronous
   crop results are discarded before assigning either. Existing records and
   JPEG files are not migrated or rewritten. See decision `0070-history-crop.md`.

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

Revision validation (2026-10-29):

- `flutter analyze --no-pub`: no issues across the whole repository.
- `flutter test --no-pub --reporter expanded`: 545 passed, 2 failed. The failures
  are the two stale splash/login placeholder assertions in `test/widget_test.dart`
  (`ELIO`, `Login — coming soon`, `Home — coming soon`). Both independently
  reproduce on untouched base `b842ce2`; those unrelated tests were not edited.
- Identification expectations are restored to the original sizes (20x10, 10x5,
  and diagnostic width 30/left 50). Byte checks compare against the original
  unpadded JPEG encoding call. Separate History tests check padding, exact
  quality-100 encoding, clean pixels and no upscaling for portrait/landscape/tiny
  images. A temporary-store integration test confirms identification submits
  20x10 while the completed scan persists the separate 22x12 photo.
- History layout tests cover 1366x768, 770x553 and 390x844 with portrait,
  landscape, tiny, missing, corrupt and legacy images. PDF tests retain original
  JPEG bytes, pending labels and the end of a multipage essay. Seed-preservation
  regressions remain intact. All test stores, diagnostic outputs and photo files
  are temporary; the owner's real history was never opened or modified.
- Secret scan runs on the staged revision and the complete PR commit range.

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
- `lib/services/detection_crop.dart`: original unpadded identification bytes
  plus a separate padded quality-100 History photo from the same clean frame.
- `lib/services/quiz_pdf_service.dart`: original crop embedded beside metadata
  with aspect preserved and an invalid/missing-image placeholder.
- `lib/providers/waste_quiz_provider.dart`: separate `_historyPhotoBytes`,
  assignment after the stale-result guard, session resets, and `_finish` saving
  the History photo with a supplied-crop fallback.

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
D now changes `_cropThenIdentify`, `_finish`, device/session initialization,
`startForLabel` and dismissal to keep/reset the separate History photo. A changes
`startForLabel` to preserve a supplied phone photo. That function needs integration
review when merging the lanes: preserve A's `_cropBytes = photo` and clear D's
`_historyPhotoBytes` so `_finish` falls back to the supplied phone photo. D does
not recrop phone photos; its crop helper runs on robot locks. No Lane A code was
merged into D. The PR description records this overlap and the current validation
limits.
