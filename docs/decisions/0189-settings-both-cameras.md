# 0189: Config Settings work with MaixCAM2 and the phone camera

- Status: Accepted
- Date: 2026-11-07
- Base: `feature/live-scan`

## Problem

Config → Settings had switches that did nothing, or did nothing in one camera mode:

| Setting | MaixCAM2 | Phone camera |
|---|---|---|
| Auto-reconnect | worked | n/a (no link) |
| Resolution | worked | ignored (fixed per platform) |
| Show FPS overlay | worked | ignored |
| Sound effects | ignored | ignored |
| Master volume, Allow skip | worked | worked |
| Difficulty | broken in Bahasa Indonesia (saved "Sulit", read as Medium) | same |
| Timer | ignored (quiz had no countdown) | ignored |

## Decision

- **Difficulty**: the sheet saves `Easy`/`Medium`/`Hard` and only shows the
  translated label. Saved Indonesian values (`Mudah`/`Sedang`/`Sulit`) are mapped
  when preferences load.
- **Sound effects**: gates the Control click from 0188 (the haptic tick stays).
  `soundEffectsOn` mirrors the preference for code that has no `ref`; Control
  reads the preference on open so it is loaded before the first press.
- **Resolution (phone)**: `PhoneFrameSource(resolutionPreset:)` opens the camera at
  720p → `ResolutionPreset.high`, 480p → `medium`. Read when the scan screen opens.
  Android was always 720p before; with the default 480p it now opens at 480p.
  macOS camera is unchanged.
- **FPS overlay (phone)**: the scan screen shows `FPS n • WxH`. FPS counts
  Android image-stream frames; iOS has no stream, so it shows `-`.
- **Timer**: a countdown next to Skip on multiple-choice questions. At zero the
  question is recorded like a skip, answer "(time's up)", 0 trophies, even when
  Allow skip is off. Essays have no timer (typing needs the time).
  The count lives in the widget, so minimizing the popup restarts it.

## Validation

`test/settings_both_cameras_test.dart` (click silenced, countdown fires once) and
two tests in `test/quiz_behavior_test.dart` (time up, old Indonesian difficulty).
Each was break-checked against the old code. String audit 0.
