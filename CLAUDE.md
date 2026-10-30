# CLAUDE.md

Permanent rules for working in this repo (PhysicsEDU-Boris/ELIOS).

## Branching

- Base branch: `feature/live-scan`. One branch + one PR per task.
- Never push to `main`, never merge PRs.

## Never commit

- `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `Maixcam.txt`
- Any `DEVELOPMENT_TEAM` change
- `.env*` files
- Firebase config files
- The model file

## Git safety

- Never run `git reset --hard`, `git checkout -- .`, `git clean` or
  `git stash drop` without asking first.
- Before moving or rebasing a branch, run `git status`. If anything is
  uncommitted (including the files in "Never commit"), stop and ask, or
  copy those files to a temp folder first.

## Before opening/updating a PR

- `flutter analyze`
- `flutter test` (2 known-stale splash tests in `test/widget_test.dart` may fail)
- Secret scan (`scripts/check-secrets.sh`)

## Behaviour changes

- Update `CHANGELOG.md` and add/update a decision doc in `docs/decisions/`.
- Break-check new tests (confirm they fail against the old behaviour, then
  restore the fix).

## Robot build

- `flutter build macos --debug --dart-define=LIVE_SCAN=true --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, then launch
  with `open` — not `flutter run` from the IDE (breaks Local Network
  permission).

## Local debug app and model hygiene

- On the owner's Mac, the sole retained debug app is `~/Applications/ELIOS.app` (8f0e77c, verified 29 Oct 2026). Replace this same app; do not leave another registered worktree build. Move the final bundle rather than copying it, then verify one ELIOS registration. Keep the existing runtime model and original build asset.
- Before every Mac build, inventory existing ELIOS bundles/LaunchServices registrations and Gemma model stores; record which app path, bundle ID, APP_COMMIT and model copy are in use.
- Reuse the owner's existing debug app/output and verified model store where possible. An isolated source worktree does not justify another installed/registered app or a duplicate model download.
- If a separate test bundle is necessary, record its purpose and cleanup plan first. At task end, stop test processes, restore the normal app entry point, reconcile task-created registrations/bundles, and report exactly which app/model is kept and what older copies remain.
- Never silently leave old debug apps or model copies behind. Do not delete owner/pre-existing apps, models or data without confirming which copies to keep; remove only verified disposable artifacts created by the current task.
- Update the local build notes and HANDOFF after every build, including signing/Keychain or model-location changes. Do not commit model files, credentials or private configuration.

## Workflow

- Find code with CodeGraph (`codegraph_explore` / `codegraph explore`), not
  grep/find, when `.codegraph/` exists.
- Use Ponytail at the start and end of a task.
- Read only the files you're going to change.
- Keep reports short: files changed, what changed, tests run, how to test
  on the robot. No whole files or long logs.

## End of task

- Update `docs/HANDOFF.md` (under 60 lines) and commit it.
