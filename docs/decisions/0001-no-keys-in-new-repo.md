# 0001: No API keys in the new repo, not even in history

- Status: Accepted
- Date: 2026-10-08
- Milestone: M7

## Context

The history scan before the first push to `PhysicsEDU-Boris/ELIOS` found
Firebase config files with real API keys in past commits
(`android/app/google-services.json`, `lib/firebase_options.dart`,
`ios/Runner/GoogleService-Info.plist`) and a committed `node_modules`
folder. The keys are already on the old remote.

## Decision

- The new repo must not contain any API key, including in history.
- The original local repo is never rewritten. History is cleaned with
  `git filter-repo --invert-paths` on a throwaway clone, and only that clean
  copy is pushed, with explicit refspecs.
- Real Firebase files stay gitignored. Templates with fake values are
  committed instead (`*.example`).
- `scripts/check-secrets.sh` runs from `.githooks/pre-push`.
- The owner restricts or rotates the Firebase keys in Google Cloud and
  regenerates the Roboflow key. The Roboflow key is outside this repo.

## Consequences

- Every commit hash changes in the pushed history. The old-to-new map is kept
  outside the repo and used to update `CHANGELOG.md` and the Notion plan.
- Each clone needs the real Firebase files from the Firebase console
  (README "Firebase setup") and `git config core.hooksPath .githooks`.
