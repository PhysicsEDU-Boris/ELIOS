# Handoff

- Branch: `feat/m2c-crop-identify`; diagnosing robot recording of `606be86`.
- Latest commit: `git log -1`. M2c acceptance is NOT complete; no push/merge.

## Verified by code inspection
- Current message's JPEG/detection reach the lock synchronously; compute
  retains that frame across later arrivals. Center XYWH scales to decoded
  pixels, floors/ceils edges and clips. Crop bytes reach Message.withImage.
- Receipt timestamp is not capture time; source detection time/ID unknown.
  Metadata dimensions can be cached. Local firmware reference reuses boxes
  between inference cycles and burns masks/boxes into JPEGs; deployed version
  unverified. JPEG decoder honors EXIF; boxes have no rotation transform.
- No demonstrated app crop/vision bug; no recognition/threshold guess-fix.
- Overlay 12.417 s measures lock-to-question, including identify and any B3
  human wait. Overlay first-token time belongs to the question, not identify.

## Recording evidence (owner supplied)
- Bottle → Looking → Botol minuman → relevant quiz; 12.417 s total.
- Phone: E_Waste detector, Barang plastik merah identification; B3 retained.
  Exact historical crop unavailable: model versus input-quality cause unknown.
- Rescan: no late quiz for ~18 s. Same bottle: no repeat for 30 s, not 60 s.
- Object changes during COOLDOWN did not show a qualifying empty interval.
- Separate follow-ups: contradictory PET/anorganik premise; Q5 waited 7.048 s
  then fallback. Causes unknown; no quiz-generation rewrite in this change.

## Diagnostics / checks

- Debug robot sessions: app-support `m2c-diagnostics/scan-<id>-identify.jpg`
  (exact supplied bytes) and matching `.jsonl`; `[M2c]` prints full path.
  Contains receipt age, dimensions/box/crop, raw JSON, resolved category/B3,
  request/session IDs, crop/identify first-token/completion/question/total
  timings and cancellation/stale markers. Writes do not await inference.
- Local only, gitignored; delete directory after inspection. No artifacts or
  keys committed. User Xcode scheme and Maixcam.txt remain excluded.
- `flutter analyze --no-pub`: clean. `flutter test --no-pub`: 221 passed;
  only the 2 documented stale splash tests in `test/widget_test.dart` failed.
- Exact-byte/timing and failure-isolation tests pass; deliberately corrupting
  saved bytes failed the new test, then restored. Secret scan: clean.
- Decision 0012 updated; decisions 0011 and 0012 now indexed.

## Owner-run robot acceptance (still pending)

Build `flutter build macos --debug --dart-define=LIVE_SCAN=true`, then
`open build/macos/Build/Products/Debug/*.app` (not IDE flutter run).

A. Isolate a stationary phone; compare saved JPEG with phone and returned JSON.
   If clearly the phone but named wrong, repeat with controlled light/angle;
   if masks obscure it, next compare clean versus overlay input.
B. B3: explicitly click Lanjut kuis and wait until the quiz appears.
C. Close during Looking; wait for completion/no late popup, then finish a scan.
D. After quiz close wait 15 s, keep detector scene empty >=2 s, introduce item.
E. Hold one item visibly for 60 s: one identification and no repeated quiz.
F. Expose preview and move an object during identify, B3 confirmation and quiz.

Record IDs/timestamps for A–F. TTS requires owner audio testing separately.
Full hardware class/edge-crop coverage and native vision behavior remain
unverified; mock tests cannot establish recognition, preview liveness or memory.
