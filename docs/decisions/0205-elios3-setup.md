# 0205 — ELIOS 3 ELIOS setup screen

Date: 10 November 2026. Stacked on `feat/elios3-motion-more` (0203). Figma `629:91327`
("L4 / Dark / ELIOS setup (after Select vehicle)"). 0204 is left for the Robot Wi-Fi QR sheet work.

## Decision

- `ConfigScreen` (body of `EliosSetupScreen`) is rebuilt to the frame: robot stage (two spotlight
  discs, floor shadow, the real 3D model clipped to the inner disc, tilted "Drag to rotate" chip,
  Status and Camera orbit bubbles, name tag), pill camera row, Connection cable stepper, flat Video
  stream section, Quiz section with the peeking bulb buddy.
- Cable stepper nodes come from `setupSteps(LinkView, found:)`:

  | Link | Found | Step 1 | Step 2 | Step 3 |
  |---|---|---|---|---|
  | not connected | no | current | to do | to do |
  | not connected | yes | done | done | current |
  | connecting / connected | – | done | done | current |
  | failed | no / yes | current / done | to do / done | problem |

  The app cannot see which Wi-Fi the phone is on, so step 1 counts as done once ELIOS has been
  found (Find) or a connection is underway. "Found at" uses the Find result, or the connected
  address.
- Find shows its result inline in step 2 (chip) instead of a snackbar; "Search again" repeats it.
- "Saved as default address" shows only when connected and the fields match the saved config;
  otherwise a "Save as default address" checkbox keeps the old switch's behaviour.
- Disconnect is left out while there is no link (it used to show disabled), so the Indonesian
  "Hubungkan sekarang" fits.
- On open the fields take the live link's address (`WebSocketService.ip/port`) over the saved
  default; before, a link to an unsaved address showed the saved one and a wrong "Found at".
- Auto-reconnect stays in step 3 (not in the frame, but it is real behaviour).
- The quiz source tiles become a `ConfigSegmented` (Question bank | ELIOS AI); the ELIOS AI status
  card stays below because it is the only place that says whether AI is reachable.
- Removed the now unused `ChoiceTile`, `StatusTile`, `ConfigSectionHeader`, `ConfigCardHeader`.

## Gaps (no real data)

- Battery bubble: hidden. The robot does not report battery.
- Bottom nav: Select vehicle and ELIOS setup are pushed over the shell (since 0196), so the nav
  is not shown. Unchanged here.
- Segment icons in the quiz switch and the subtitle indent under the back button: not done
  (shared widgets).
