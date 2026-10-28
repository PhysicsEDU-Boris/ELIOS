# Handoff

- Base: `feature/live-scan` at `254da97`; PRs #48 and #49 are merged.
- U4b branch: `feat/u4b-essay-rubric`; implementation commit `0bbca22`.
- Never commit the Xcode scheme, `Maixcam.txt`, `docs/module/`, `.env*`, Firebase configs, or the Gemma model.

## U4b — essay rubric

- Gemma is prompted for JSON with Accuracy /4, Key terms /3, Completeness /2, Clarity /1, total /10, short feedback, and one improvement suggestion.
- `EssayGrade` validates integer types, limits, total and sum. A valid total with an unusable rubric stays score-only; malformed or inconsistent results stay pending with zero trophies.
- The same validated score and rubric feed the overlay, trophy count, saved `QuizExplanation`, History and PDF. Synthetic rubric rows and essay source/AI claims are removed; old saved records remain compatible.
- Decision 0031 and CHANGELOG updated. Full owner-account/local-camera acceptance is still required before U4 is complete.

## Validation

- `flutter analyze`: clean. `scripts/check-secrets.sh`: clean.
- Focused rubric/lifecycle/overlay/store/PDF/HOME tests: 45 passed.
- Full Flutter suite: 515 passed; only the 2 documented stale splash tests failed.
- Tests cover complete/partial rubrics, malformed replies, criterion/total bounds, inconsistent sums, score-only fallback, unavailable model, and result persistence/PDF generation.
- #49 pending-grade and PDF pagination fixes remain unchanged.

## Mac build / acceptance

- Debug build from `0bbca22` succeeded at the temporary worktree output with `LIVE_SCAN=true`, `ESSAY_QUESTIONS=true`, `R1=true`, `G1_PICKUP_QUIZ_FLOW=true`; `APP_COMMIT=0bbca22`.
- Bundle ID and Team ID matched `~/Applications/ELIOS.app`, but `codesign --verify --deep --strict` returned `CSSMERR_TP_NOT_TRUSTED`; the keychain reported zero valid signing identities. The build app was removed without moving or launching it. Existing app remains at `~/Applications/ELIOS.app` (8f0e77c).
- Inventory found one ELIOS bundle on disk. CUA showed five historical same-ID entries; `NSWorkspace` resolved zero registration URLs before/after the uninstalled build. No old registrations or apps were removed.
- Existing 2.4 GB runtime model and original build asset were preserved; no model was bundled or downloaded. Temporary plist/scheme copies and empty env placeholders were removed.
- Real-model essay, localhost fake camera, isolated app-store persistence/relaunch, native PDF picker and PDF-content acceptance remain unrun pending valid signing and a verifiable single ELIOS registration.
- No sharing recipient selected; no physical robot or firmware contacted. PR #47 stays draft and `ARM_MOTION_ENABLED=false`.

## Preserve

- Canonical `/Users/macbookairm12020/GITHUB/ELIO/elios-clean` remains dirty only in the owner's scheme, `Maixcam.txt`, and `docs/module/`; do not overwrite or clean it.
- Decision 0031 defines the U4 overlay/history/PDF; decision 0027/0028/0030 cover HOME, trophies and saved records.
