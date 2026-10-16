# Handoff

- Branch `feat/m2c-crop-identify`, local only (no push/merge). M2c INCOMPLETE.
- Latest: da5621c cancel fix + build traceability. Rebuild with
  `--dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`; JSONL `appCommit` must match.
- Preserve the user Xcode scheme, Maixcam.txt, firmware/maixcam2/ (uncommitted).
- Corrected evidence: [M2c review](test-results/m2c-clean-image-review.md).

## 16 Oct 16:17 retest (build after e9a3b57) and da5621c fixes

- PASS: close during Looking (no late popup, next scan ok); B3 Rescan (no quiz);
  E_Waste veto over Gemma anorganik. TTS ok (owner). NOT TESTED: 60 s visible
  hold; residu routing (no residu returned). FAIL: preview hidden under
  Looking/B3/quiz sheets (design question for owner).
- Gaps: laptop detected Cardboard -> Gemma kardus/organik -> organic bin
  (veto needs detector E_Waste); scan 3 item named bottle, possibly a cup.
- Fixed in da5621c: scan 0 vision_submit came 0.87 s after close. Now no submit
  after a cancel (`submit_skipped`); running call's result discarded, slot busy
  until it ends (cap 8 s); close logged `failure: cancelled`, no ASK FAILED.
  Chat pre-empting a scan/prefetch now waits for that call to end.
- Tests: analyzer clean; full suite 235 pass, 2 known stale splash failures.
  Break-checked no-submit and slot-busy tests. Real-model
  `integration_test/gemma_cancel_test.dart` NOT re-run.

## Verified clean-image results (16 Oct 11:26, details in review)

- Exact JPEG/JSONL pairs in gitignored `m2c-diagnostics/` (11:26 scans -4..-7;
  16:17 scans scan-1792142261469202-0 to -4): no synthetic overlay, clean_image,
  firmware sha bbb3595e…. Annotated pixels are never a fallback.

## Owner clarifications / resolver inspection

- 01:24/01:32 red/noisy preview was intentional lens covering, NOT a firmware
  bug; recovered on uncovering. Owner will visibly re-record the action.
  Covering alone does not establish a qualifying empty-detector-scene interval.
- Three bins only: organik, anorganik, B3. Intended: Gemma category, hazardous
  veto from supported sources, then residu -> inorganic. This is destination
  routing, not a claim that residu is recyclable. S7 outcome is expected.
- Resolver now explicitly routes nonhazardous residu to inorganic independent
  of item keywords. rawCategory retains Gemma's value; category is destination.
  Detector hazard is a separate flag; detector/Gemma/item hazard still veto to B3.
  Other category routing unchanged. Residu context makes no recycling guarantee.
- Raw identify_result.category and resolved.category remain distinct in JSONL.
- Future quiz must strictly use taught course-module content; owner PDF pending.
  [Quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement):
  PLANNED, not implemented; external Notion plan not synchronized here.
- Duplicate/conflicting quiz questions and Paper Q4 fallback remain follow-ups.
  Q4 measured 8273 ms generation; timeout cause NOT established. Module context
  is not proven to fix latency/fallback reliability. Stdout gap stays separate.

## Remaining acceptance / checks

- Rebuild at da5621c, then retest: close during Looking (expect no
  vision_submit after dismiss), 60 s visible hold, residu item, hazard override.
- Owner decision: should the preview stay visible during Looking/B3/quiz?
- Detector-mislabel hazard gap (e-waste labelled Cardboard) needs a decision.
