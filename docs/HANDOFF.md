# Handoff

- Branch `feat/m2c-crop-identify`; app build c438e94; no push/merge. M2c INCOMPLETE.
- Existing Xcode scheme change and untracked Maixcam.txt remain excluded.

## Latest hardware failure (16 Oct 2026)

- Rebuilt LIVE_SCAN app launched 10:25:01 WIB, PID 8194. Provenance:
  ignored `m2c-diagnostics/clean-deploy-provenance.json`; build/output logs
  `/private/tmp/m2c-clean-deploy-build.log`, `.stdout.log`, `.stderr.log`.
- Owner reports deploying/checking firmware, but active hash NOT independently
  verified. Backup `m2c-diagnostics/robot-backup/maiin.py` equals Maixcam.txt
  (SHA-256 da57d135a004e399a4a4bb7a8c132209ce340fc3565856640d70bc2f5734a0cc).
- Expected replacement hash: bbb3595e8070d4fab421ce38d5a9becbca26f6bcc8c34be4d7e29ed5c2ab79e6.
- New JSONLs copied to ignored `m2c-diagnostics/`: scan-1792121308094220-0,
  scan-1792121323937693-1, scan-1792121357069544-2, scan-1792121368294749-3.
  Locks at 10:28:28/43 and 10:29:17/28 WIB: E_Waste/Plastic/E_Waste/Plastic.
  All frameId/detectionFrameId/firmwareSha256 null, imageSource unavailable;
  crop invalid in 0–3 ms; no identify_request or question generation.
- First observed failure: transport-to-CapturedFrame lacks a usable clean pair.
  Code trace implies legacy schema (no vision_protocol); malformed protocol 1
  suppresses locks. Raw packets/active process hash needed to locate upstream cause.
- Metadata-only probe of ws://192.168.4.1:8765 timed out; result saved as
  `m2c-diagnostics/clean-failure-wire-probe.jsonl`. No payloads logged.
- Recording Desktop/Screen Recording 2026-10-16 at 10.29.08.mov: warning at
  00:09–15, preview visible 00:18, warning again 00:21. Overlay 10–12 fps;
  preview continuity behind opaque popup and throughput regression NOT verified.
- Uploaded red phone JPEG scan-1792119881048431-0 is 10:04:41 WIB, BEFORE
  launch: baterai/anorganik -> hazardous; identify 5.614 s, question 4.550 s.
  It cannot establish contamination in the new build's failed scans.

## Clean path / prior evidence

- firmware/maixcam2/main.py encodes originals before masks/boxes/text. Fresh
  clean_image/clean_detections share frame IDs; firmware hash accompanies frames.
- Annotated preview retained; one extra JPEG per nonempty fresh inference frame.
  Flutter rejects absent/mismatched clean data; never falls back to preview.
  Hazard veto, cancellation, model slot and anti-spam thresholds unchanged.
- Legacy firmware retains preview/controls, but LIVE_SCAN clean identify fails.
- Prior 01:29–01:30 WIB sessions ...8943399297-0, ...8975920656-1, ...9028005351-2
  prove red-mask/green-box contamination in old model inputs; all E_Waste -> B3.
  Third: identify 5.844 s, confirmation wait 10.369 s, question 5.562 s;
  total 21.820 s includes human wait. Accuracy effect remains unestablished.
- Actual diagnostics: /Users/macbookairm12020/Library/Containers/E798601C-A67E-46BF-AB3D-AE1A58572F44/Data/Library/Application Support/com.boris.elio/m2c-diagnostics/

## Next / validation

- Connect Mac to ELIOS Wi-Fi, keep preview running; capture active MaixVision
  startup hash and rerun metadata-only probe. Compare field names/types, lengths,
  protocol, IDs and hash before changing code; never print image base64.
- Then one phone scan: exact saved JPEG clean, object in crop, matching IDs/hash,
  E_Waste confirmation; Continue -> quiz. Bottle and moving segmented preview next.
- Still pending: Rescan, close during Looking/no late popup + recovery, 15 s plus
  >=2 s empty re-arm, 60 s hold, throughput, TTS separately with owner.
- c438e94 checks: analyzer clean, 226 tests pass / 2 known stale splash failures;
  firmware test and two break-checks passed. Latest rerun: 16 focused Flutter tests
  and firmware test pass; diff check clean. No runtime code change.
- Separate follow-ups: stdout scan-log gap, PET contradiction, Q5 fallback.
