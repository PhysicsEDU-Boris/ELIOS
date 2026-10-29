# Handoff

- Branch `feat/u4b-essay-rubric`; draft PR #51 targets `feature/live-scan`, unmerged. Base `254da97` includes #48/#49.
- Canonical `~/GITHUB/ELIO/elios-clean` retains the owner's dirty scheme, `Maixcam.txt`, and `docs/module/`.
- Persistent worktree: `~/Documents/ChatGPT/ELIOS 2/u4b-essay-rubric`; evidence in sibling `u4b-native-evidence/`.

## U4b implementation

- Strict JSON grading: Accuracy /4, Key terms /3, Completeness /2, Clarity /1; integer total /10 must equal the sum.
- Valid total with unusable rubric is score-only; malformed/inconsistent total stays pending, null score, zero trophies. No fabricated rows or essay source attribution.
- Real model initially returned a word array for `keyTerms`; prompt now explicitly requires an integer. Completion summary now includes essay questions in its denominator.
- Overlay, trophies, saved explanation and PDF reuse the same validated result; legacy history and #49 pagination/pending fixes retained.
- Debug sample insertion now preserves existing unloaded history and skips duplicate IDs, with serialized writes and a regression test.

## Native evidence / incident

- Real Gemma native harness returned 4/4 + 2/3 + 2/2 + 1/1 = 9/10, +9 trophies; four isolated records totalled 17 trophies and survived quit/relaunch.
- Earlier real 8/10 response correctly stayed score-only. Malformed/unavailable responses were injected harness cases, both pending/zero trophies.
- Actual saved rubric PDF includes all four criteria, score, answer, feedback and suggestion. Native sharing picker opened and was cancelled without selecting a recipient. Long PDF includes both boundary markers across two pages.
- Normal app connected only to localhost simulator; camera advanced F95 to F3917 at ~9.9 FPS across History opening/closing. No robot movement controls used.
- **Acceptance incident:** an unlabeled History control was mistakenly clicked and seeded debug samples into the normal owner store, replacing its one pre-existing record (Hard, five questions, 10 trophies). Exact original JSON was not recovered from heap, local files or snapshots. Four debug samples remain; original crop remains. Do not claim owner history was preserved or acceptance fully complete.
- Recovery evidence and the data-preservation regression are in the evidence folder. Do not replace missing original answers with guesses. Owner backup/review is needed for restoration.

## Build / verification

- Earlier invalid-signature/launch results were sandbox artifacts: elevated verification finds one valid Apple Development identity and signatures pass. `open` and CUA work.
- Documents File Provider added forbidden Finder metadata to generated apps; build output moved to `~/Library/Caches/elios-u4b-build-20261029`. Generated module caches were regenerated after ASTReader crashes; missing generated Flutter engine restored from intact local SDK cache.
- Existing runtime model remains `~/Library/Containers/E798601C-A67E-46BF-AB3D-AE1A58572F44/Data/Documents/gemma-4-E2B-it.litertlm`; model install logs explicitly skip download. Pre-existing model copies and Trash bundles untouched.
- Completed native builds were moved to the retained `~/Applications/ELIOS.app`; generated/Trash registrations unregistered, one installed registration verified. Trash bundles were not deleted.
- Validation before seed fix: analyze clean; full 516 passed with only two stale splash failures; focused 74 passed; summary break-check fails old behavior. Seed regression also fails old destructive behavior.
- Final seed-fix validation: analyze clean, full 517 passed / two stale splash failures; secret scan clean. Seed-preservation break-check fails the old behavior.
- Final normal signed app built from `6d67f30` with LIVE_SCAN=true, APP_COMMIT=6d67f30, R1/G1_PICKUP_QUIZ_FLOW/ESSAY_QUESTIONS=true; moved to `~/Applications/ELIOS.app`, verified after moving and launched with `open`. One ELIOS registration verified.
- Temporary Firebase config, env placeholders, harness entry and build symlink removed; worktree scheme restored. Local cache retains compiled dependencies, no duplicate app bundle. Never commit config/model assets.
- No Firebase sync, Figma or firmware changes. PR #47 remains draft/unmerged; `ARM_MOTION_ENABLED=false`; physical/authenticated firmware validation remains owner work.
