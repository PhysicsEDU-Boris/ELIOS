# Decision records

One short file per decision, numbered in order (`NNNN-title.md`). Each one
has: status, date, context, decision, consequences. A decision is only
written here after the owner has made it. Superseded records stay, with
their status changed.

| No. | Decision | Status |
|---|---|---|
| [0001](0001-no-keys-in-new-repo.md) | No API keys in the new repo, not even in history | Accepted |
| [0002](0002-repo-layout-and-remotes.md) | Base branch, remotes and the stage 0 deletions | Accepted |
| [0003](0003-stop-generation.md) | `stopGeneration` really stops LiteRT-LM, so no fallback | Accepted |
| [0004](0004-stage-2-commit.md) | The stage 2 commit is documented, not split | Accepted |
| [0005](0005-m0-findings.md) | Findings from M0, recorded, not fixed in M0 | Accepted |
| [0006](0006-macos-release-entitlements.md) | macOS release builds may run a local server (for the 3D viewer) | Accepted |
| [0007](0007-stabilizer.md) | Detection stabilizer (stage 3a) | Accepted (parameters provisional) |
| [0008](0008-live-scan-state-machine.md) | Live-scan state machine for the robot path (behind a switch) | Accepted |
| [0009](0009-camera-stays-alive.md) | The camera stays alive during a quiz; Gemma preloads (M2b part 1) | Accepted |
| [0010](0010-tts-single-slot-and-overlay-staleness.md) | One TTS slot, no stale overlay numbers, a monotonic default clock (M2b part 2) | Accepted |
| [0011](0011-quiz-prefetch.md) | Prefetch questions through the single Gemma slot (M2b part 3) | Accepted |
| [0012](0012-crop-identification-and-hazards.md) | Identify the locked crop and confirm hazards (M2c) | Accepted (owner manual acceptance 16 Oct; hardware gaps listed in HANDOFF) |
| [0013](0013-quiz-answer-schema.md) | Multiple-choice schema: one correct answer plus wrong distractors (M3.1) | Accepted |
