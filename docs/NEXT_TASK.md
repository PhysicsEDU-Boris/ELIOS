Continue ELIOS with one focused task: **U4b — real essay rubric and Mac acceptance**.

Context:
- PR #48 (G2c) and PR #49 (explanations/history/PDF) are merged into `feature/live-scan`. Last verified base: `254da97`; tested U4 fix: `8f0e77c`.
- Read `CLAUDE.md`, the latest local `docs/HANDOFF.md`, decision 0031 and the Notion UI plan first: https://app.notion.com/p/4049675ed4f381649071ec29838b4f98.
- Check git status before changing branches. Preserve the owner's dirty canonical checkout `/Users/macbookairm12020/GITHUB/ELIO/elios-clean` (scheme, Maixcam.txt, docs/module/). Reuse a suitable clean isolated worktree; fetch the current base. Work on `feat/u4b-essay-rubric`, one agent/task at a time. Use CodeGraph first only if that worktree already has `.codegraph/`; do not index it without the owner's instruction.

Goal: complete the existing U4 requirement. The current essay overlay exists, but `reviewEssay` returns prose and the explanation service uses generic rubric rows; that is not the planned 4/3/2/1 rubric.

Implement the smallest complete change:
1. Trace all essay grading callers and persisted explanation consumers. Ask Gemma for structured grading: Accuracy /4, Key terms /3, Completeness /2, Clarity /1, total /10, short feedback and one improvement suggestion. Reuse existing explanation/record models where possible.
2. Strictly validate types, criterion limits, total range and consistency with the sum. Add good, partial, malformed, out-of-range, mismatched-total and unavailable-model tests. If only a trustworthy total can be recovered, show score-only feedback without invented rubric rows; otherwise retain null score, pending label and zero trophies. Preserve #49's pending-grade and PDF pagination fixes and old history compatibility.
3. Carry the same validated result through overlay, trophies, saved review and PDF. Do not show fabricated criterion scores, sources or AI grading claims.
4. Break-check the meaningful regressions. Run analyze, full Flutter tests, secrets and focused HOME/store/PDF regressions. Previous baseline: 508 passed, only two documented stale splash failures.

Then test on the owner's Mac:
- First inventory all existing ELIOS apps/registrations and Gemma 4 E2B copies. Reuse the existing debug app/output and verified model store; do not install/download duplicates. Record each build path/commit/model store and reconcile temporary/older artifacts before finishing. Do not delete pre-existing copies without owner confirmation.
- Build the normal signed debug app with LIVE_SCAN=true and APP_COMMIT; launch with `open`, never `flutter run`. Preserve shared Keychain signing/auth and remove any temporary Firebase config copy.
- Use the real local Gemma model with a localhost fake camera, isolated test records, and no physical robot. Verify a graded essay, unavailable/malformed grading, explanation before next question, trophy math, camera continuity, saved review after quit/relaunch, native PDF export and complete PDF contents. Distinguish mocks/harness tests from real-model acceptance. Never select a sharing recipient or send a report unless asked.
- Computer-use screenshots previously failed with ScreenCaptureKit errors. Prefer CUA; the owner authorized local macOS automation fallback for this local acceptance workflow. Keep actions confined to ELIOS and verify each result.

Commit in small steps, keep HANDOFF under 60 lines, update decision/changelog, push one PR against feature/live-scan and leave it unmerged. Report exact branch/commit, test results, native evidence and remaining limitations.

Out of scope: Firebase sync, Figma edits, firmware deployment or physical movement. Existing firmware PR #47 is draft/unmerged at c116007 with ARM_MOTION_ENABLED=false; it still needs authenticated app integration, protected transport and owner slave/watchdog validation. Do not duplicate or enable it during this task.
