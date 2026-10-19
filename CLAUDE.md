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

## Workflow

- Find code with CodeGraph (`codegraph_explore` / `codegraph explore`), not
  grep/find, when `.codegraph/` exists.
- Use Ponytail at the start and end of a task.
- Read only the files you're going to change.
- Keep reports short: files changed, what changed, tests run, how to test
  on the robot. No whole files or long logs.

## End of task

- Update `docs/HANDOFF.md` (under 60 lines) and commit it.
