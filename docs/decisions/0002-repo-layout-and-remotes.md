# 0002: Base branch, remotes and the stage 0 deletions

- Status: Accepted
- Date: 2026-10-08
- Milestone: M7

## Context

The working repo was local only. Its old remote is
`Borisartz/ELIO-DEVELOPMENT`. The new remote is `PhysicsEDU-Boris/ELIOS`,
which started with one initial commit (LICENSE and README).

## Decision

- In the original local repo the old remote is renamed to `legacy`. Nothing
  is pushed to `legacy`.
- `feature/live-scan` was cut from the tip of `backup/phase7-broken-attempt`
  (`987d524`). It is pushed after cleaning. `backup/*` and
  `feature/ai-camera-configuration` are not pushed.
- `main` on the new remote keeps the initial commit and receives work only
  through pull requests.
- The 10 files deleted in the stage 0 snapshot (`710006d`) were intended:
  old planning docs, `ESP32CAM_HTTP_BRIDGE.txt`, `KAMERAESP32.txt`, the UDP
  discovery and Wi-Fi provisioning providers, and the hotspot trap wrapper.
  They remain in history before that commit.

## Consequences

- `lib/Screens` vs `lib/screens` is left alone for now. It gets its own
  commit later (plan 1.3).
