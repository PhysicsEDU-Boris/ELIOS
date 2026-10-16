# M2c clean-image review — 16 October 2026

Review of `Screen Recording 2026-10-16 at 11.26.47.mov` (3:40.8), exact
identify JPEGs and matching JSONLs in gitignored `m2c-diagnostics/`.
Owner clarifications below supersede the initial conversational review.

## Provenance and verified results

App provenance records c438e94, LIVE_SCAN=true, launched 10:25:01 WIB,
PID 8194; bundle kernel SHA-256 still matches the recorded build. Scan logs
lack app commit/PID, so association depends on that launch record. Current
39793af adds documentation only. Earlier contaminated/failed scans are separate.
All four logs report clean_image, matching frame/detection IDs and firmware
SHA-256 `bbb3595e8070d4fab421ce38d5a9becbca26f6bcc8c34be4d7e29ed5c2ab79e6`,
matching the intended local replacement. Saved JPEG sizes match vision_submit.
No synthetic mask, box or detector label appears in any of these four inputs.
The objects are inside the crops; the bottle cap is partly clipped at the top.

| Scan ID | Lock WIB | Frame ID | Detector | Gemma raw item/category | Resolved identity/bin |
|---|---|---:|---|---|---|
| scan-1792124780829268-4 (S4) | 11:26:20.829 | 28 | E_Waste 75.9% | baterai/anorganik | Baterai/B3 |
| scan-1792124818914637-5 (S5) | 11:26:58.915 | 212 | E_Waste 95.2% | ponsel/anorganik | Ponsel/B3 |
| scan-1792124904211888-6 (S6) | 11:28:24.212 | 1174 | Plastic 83.3% | botol plastik/anorganik | Botol plastik/anorganik |
| scan-1792124980890907-7 (S7) | 11:29:40.891 | 2028 | Cardboard 79.9% | kertas/residu | Kertas/anorganik |

S4 predates the recording. Its dark-screen phone was misidentified as a
battery; S5's lit phone and S6's bottle were recognized. S7's notebook/paper-like
item does not conclusively establish whether Cardboard was a detector mistake.
S7's raw residu to inorganic destination is expected three-bin hardware routing,
not a category-override failure and not a claim that residu is recyclable.

| Scan | Crop ms | Identify first/completion ms | Confirmation wait ms | Q1 generation ms | Lock-to-question ms |
|---|---:|---:|---:|---:|---:|
| S4 | 136 | 5002 / 5580 | 6079 until dismissal | — | — |
| S5 | 103 | 4607 / 5302 | 3352 until Continue | 5110 | 13872 |
| S6 | 53 | 4313 / 4961 | Not applicable | 3453 | 8469 |
| S7 | 48 | 4417 / 4938 | Not applicable | 3668 | 8655 |

These are JSONL measurements; total time includes human confirmation waiting.
S5 shows Looking, B3 confirmation, Continue, then quiz (approximately 00:12–28).
E_Waste veto holds despite Gemma's anorganik category. S4 logs confirmation
dismissal without a question request, but neither the Rescan button nor the
following no-late-popup interval is shown for that scan.

## Corrected preview and re-arm assessment

At 01:24 and 01:32 the owner intentionally covered the lens. Red/noisy imagery
is an intentional test action, NOT a firmware-bug finding. Preview recovered
when uncovered. Owner will re-record with covering/uncovering clearly visible.
Lens covering alone does not establish a qualifying empty-detector-scene interval.

Separate exposed empty-scene samples at approximately 01:14–01:23, cooldown
ending by 01:20, and the subsequent successful bottle scan support re-arm.
The later bottle-to-paper transition also succeeds, but its physical empty
interval is not demonstrated. No cooldown threshold change is justified.
Exposed preview retains segmentation and changes with object motion. Counters
show about 8–13.3 preview FPS and 4–7 live-scan FPS; these do not establish
continuous motion behind opaque popups or a controlled throughput comparison.
One identify request is logged per scan. Visible post-quiz holds are only about
6 seconds for phone and 20 seconds for bottle; a continuous 60-second hold is
NOT TESTED. No missing-clean-image warning or unrecovered app freeze was observed.

## Quiz follow-ups, separate from clean-image acceptance

- Bottle Q3 and Q5 (about 02:03 and 02:16–17) repeat essentially the same
  emissions-stage question but mark different stages correct. Keep duplicate/
  conflicting questions, including the earlier PET contradiction, open.
- Paper Q4 displays a fallback badge at about 03:24. JSONL measures 8273 ms
  for its generation attempt; this is NOT proof of a timeout cause.
- Video next-wait overlays for Q2/Q3/Q4/Q5: phone 0/0/0/0 ms; bottle
  0/0/0/0 ms; paper 0/2261/3388/38 ms. Waits differ from generation duration.
- Phone/bottle Q5 prefetch retries are logged; their cause is not established.
- Module-grounded quizzes are planned, pending the owner's course PDF; see
  [quiz plan](../pipeline/README.md#module-grounded-quiz-plan-owner-requirement).
  Module context is not proven to fix latency, duplicates or fallback reliability.

## Remaining acceptance

M2c is incomplete. Explicitly demonstrate close during Looking with no late
popup and subsequent successful scan; Rescan with no late popup; continuous
visible 60-second hold with one identification/quiz; moving exposed preview
during Looking, B3 confirmation and quiz; and owner TTS listening separately.
Smallest next test: expose preview, cancel during Looking, wait for the late
result without a popup, re-arm, then finish a phone scan through B3 Continue.
No audio, memory or hidden-request behavior is inferred from video.
