# Changelog

All notable changes to ELIOS are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Milestones (M0 to M7) refer to the [Notion plan](https://app.notion.com/p/ELIOS-3f29675ed4f3800abef3fbb7daefe405).

Commit hashes below are from this repo's pushed history. The original local
history (which held committed API keys) was cleaned before the first push;
hashes updated after the history rewrite on 2026-10-08. The old-to-new map is
kept outside the repo.

## [Unreleased]

### Added
- Stage 2: single Gemma slot, streaming and cancellation (`5289c8b`).
  Tested with a mock only. Real proof is milestone M0.
- Stage 1: `FrameSource` interface with `PhoneFrameSource` and
  `MaixCamSource` (`46eb5cc`). Analyze is clean and the macOS build works.
  Not run on a phone or a real robot yet.
- Stage 0: snapshot baseline before the live-scan work (`9fc7239`). Removes
  old planning docs, the UDP discovery and Wi-Fi provisioning providers and
  the hotspot wrapper (confirmed intended).
- Repo setup (M7): `.gitignore` for keys, signing files and the model;
  Firebase config templates; README; this changelog; pull request template;
  pipeline map; decision records; secret check with a pre-push hook.

### Changed
- `android/app/google-services.json` is no longer tracked. Use the template
  and the README "Firebase setup" section.

### Removed
- Temporary debug double-decoding block in `websocket_service` (`eb08ab3`).

### Fixed
- A quiz left open on the robot screen no longer blocks detections the next
  time: `ControlScreen` dispose now dismisses the quiz popup (`008efae`).
- The macOS camera view swaps to a black box again when the quiz pauses it
  (`83c3bb8`).
