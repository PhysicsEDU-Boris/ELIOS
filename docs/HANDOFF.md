# Handoff

Branch `feat/u4-quiz-explanation-pdf`, PR #49. Integrated base `c3c7351` (merged PR #48).

## Preserved

- G2c: only matching HOME completion confirms home/resets sliders; STATUS telemetry cannot bypass it.
- Serialized ScanRecordStore load/add/clear/save, startup preload, local sync text and real difficulty counts.
- U4: MCQ/essay explanations, schema-v2 saved review, native PDF export; legacy records supported.

## Acceptance fixes in progress

- Long essay PDF export must paginate instead of throwing; missing essay grading must remain pending.
- Update stale TTS fixture for the explaining phase; retest merged HOME/history and U4 features.
- Previous acceptance at 1b80900: 489 passed / 3 failures (2 splash, 1 stale TTS fixture); analyze/secrets clean.
- Native Mac LIVE_SCAN build/open passed; share/save and deliberate history quit/relaunch still need acceptance.

## Safety / next

- PR #49 stays unmerged; no physical robot actuation. Owner changes in elios-clean remain untouched.
- Decision 0031: explanations, local review and PDF; 0027/0028/0030: HOME, trophies and records.
- Firmware/watchdog, calibration and physical arm acceptance remain separate work.
