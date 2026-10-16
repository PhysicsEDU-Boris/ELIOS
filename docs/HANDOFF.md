# Handoff

- Branch `feat/m2c-crop-identify`; app build c438e94. M2c INCOMPLETE; no push/merge.
- Latest task documentation only; preserve user Xcode scheme, Maixcam.txt,
  firmware app.yaml and dist/ changes; none staged with documentation.
- Corrected evidence: [M2c review](test-results/m2c-clean-image-review.md).

## Verified clean-image results (16 Oct 2026)

- Build LIVE_SCAN=true; launch 10:25:01 WIB, PID 8194. Ignored provenance:
  `m2c-diagnostics/clean-deploy-provenance.json`. Bundle hash still matches.
  Scan JSONLs lack app commit/PID; association relies on recorded launch.
- Four exact JPEG/JSONL pairs in gitignored `m2c-diagnostics/`:
  scan-1792124780829268-4 (11:26:20): dark phone -> baterai/anorganik -> B3;
  scan-1792124818914637-5 (11:26:58): lit phone -> ponsel/anorganik -> B3;
  scan-1792124904211888-6 (11:28:24): bottle -> botol plastik/anorganik;
  scan-1792124980890907-7 (11:29:40): paper item -> kertas/residu -> inorganic.
- All four exact inputs have NO synthetic masks/boxes/labels; object in crop
  (bottle cap partly clipped); byte counts match vision_submit. All clean_image,
  paired frame IDs 28/212/1174/2028, firmware hash matches local replacement:
  bbb3595e8070d4fab421ce38d5a9becbca26f6bcc8c34be4d7e29ed5c2ab79e6.
- Recording: Desktop/Screen Recording 2026-10-16 at 11.26.47.mov. S4 predates it.
  S5 demonstrates Looking -> B3 -> Continue -> quiz despite Gemma anorganik.
  S6 successful after cooldown/visible empty scene; no repeated identify per scan.
- S5 identify 5302 ms; confirmation wait 3352 ms; Q1 generation 5110 ms;
  total 13872 ms includes human wait. Full timing table in review.
- Earlier contaminated inputs and 10:28–10:29 missing-clean failures stay separate.
  No fallback to annotated pixels; cancellation/hazard/anti-spam rules unchanged.

## Owner clarifications / resolver inspection

- 01:24/01:32 red/noisy preview was intentional lens covering, NOT a firmware
  bug; recovered on uncovering. Owner will visibly re-record the action.
  Covering alone does not establish a qualifying empty-detector-scene interval.
- Three bins only: organik, anorganik, B3. Intended: Gemma category, hazardous
  veto from supported sources, then residu -> inorganic. This is destination
  routing, not a claim that residu is recyclable. S7 outcome is expected.
- Code discrepancy: ScannedWaste.fromLabel ignores residu hint and uses item
  keywords; kertas resolves inorganic, but organic/unknown items may not.
  Provider detector veto and hazardous item-keyword veto are present. Existing
  inorganic display text implies recyclability. Documented; runtime unchanged.
- Raw identify_result.category and resolved.category remain distinct in JSONL.
- Future quiz must strictly use taught course-module content; owner PDF pending.
  [Quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement):
  PLANNED, not implemented; external Notion plan not synchronized here.
- Duplicate/conflicting quiz questions and Paper Q4 fallback remain follow-ups.
  Q4 measured 8273 ms generation; timeout cause NOT established. Module context
  is not proven to fix latency/fallback reliability. Stdout gap stays separate.

## Remaining acceptance / checks

- Close during Looking: no late popup, then successful scan; explicit Rescan
  with no late popup; continuous visible 60-second hold with one identify/quiz;
  visibly moving preview during Looking/confirmation/quiz; owner TTS listening.
- Re-arm evidence excludes covered-lens intervals. Throughput comparison pending.
- Smallest next test: expose preview, cancel Looking, wait for late result,
  clear/re-arm, then complete phone scan through B3 Continue while moving object.
- Prior checks: analyzer clean; 226 pass / 2 known stale splash failures;
  focused rerun 16 Flutter tests + firmware test pass. This task: doc checks only.
