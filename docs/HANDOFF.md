# Handoff

- Branch `feat/m2c-crop-identify`, local only (no push/merge). M2c INCOMPLETE.
- Latest code: 929fdf4 detector/Gemma mismatch gate (on da5621c cancel fix +
  build hash). Rebuild with `--dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`;
  JSONL `appCommit` must match. Firmware manifest tracked (b4458a0); zip ignored.
- Never commit the user Xcode scheme or Maixcam.txt.

## Mismatch gate (929fdf4, decision 0012)

- Detector class bin vs Gemma RAW category; residu ~ anorganik. Mismatch ->
  `confirmingMismatch` card (Pakai detektor / Pakai Gemma / Scan ulang), no quiz
  before a choice. Hazard card still wins. JSONL `category_mismatch` (hard
  example) + `mismatch_choice`. No robot sorting path exists in the app.
- Tests: 246 pass, 2 known splash failures; break-check done. Robot retest
  with the laptop (Cardboard + organik) pending.
- Corrected evidence: [M2c review](test-results/m2c-clean-image-review.md).

## 16 Oct 16:17 retest (build after e9a3b57) and da5621c fixes

- PASS: close during Looking (no late popup, next scan ok); B3 Rescan (no quiz);
  E_Waste veto over Gemma anorganik. TTS ok (owner). NOT TESTED: 60 s visible
  hold; residu routing (no residu returned). FAIL: preview hidden under
  Looking/B3/quiz sheets (design question for owner).
- Gaps: laptop Cardboard + Gemma organik went organik (now gated, 929fdf4);
  scan 3 item named bottle, possibly a cup.
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

## Owner clarifications (details: decision 0012, quiz plan)

- 01:24/01:32 red preview was deliberate lens covering, NOT a firmware bug.
- Three bins only (organik, anorganik, B3): Gemma category, hazard veto, then
  residu -> anorganik as hardware fallback (not a scientific claim). Raw Gemma
  category and resolved bin stay separate in JSONL.
- Module-grounded quiz with page/section citations: PLANNED; owner PDF pending.
- Follow-ups: duplicate/conflicting questions, Paper Q4 fallback (8273 ms
  generation; timeout cause NOT established), stdout logging gap.

## Remaining acceptance / checks

- Rebuild at da5621c, then retest: close during Looking (expect no
  vision_submit after dismiss), 60 s visible hold, residu item, hazard override.
- Owner decision: should the preview stay visible during Looking/B3/quiz?
- Retest the laptop: expect the mismatch card, a choice, then quiz.
