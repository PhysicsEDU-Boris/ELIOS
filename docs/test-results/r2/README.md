# R2 gamified Control: test results (2 Nov 2026)

Decision [0173](../../decisions/0173-r2-control-gamified.md). Branch `feat/r2-control-gamified` on `feature/live-scan` (c38809d).

## A/B command log (fake_maixcam)

Same scripted session on both builds: connect from Config (127.0.0.1:8765 via `adb reverse`, Save as
default off), then forward, left, right, back, speed 100 (base: slider end; new: gear chip 100),
forward, height max/min, reach max/min, gripper 100/0, PICK UP, RELEASE, HOME (hold), STOP, forward
and height while STOPPED, Lanjutkan, forward, kill the fake, restart it, forward while STOPPED,
Lanjutkan, forward, Exit. Scenario: no items (`items: []`), so no quiz covers the controls.

- `fakelog_base_raw.txt` / `fakelog_new_raw.txt`: the fake's output.
- `fakelog_base.txt` / `fakelog_new.txt`: the same, without heartbeat, ping, watchdog and connect lines
  (timing only) and with `seq=N`.
- `fakelog.diff`: the only difference is at Exit. The new build sends `motor 0,0` and `disconnect`.
  The base build stays connected (the fake keeps getting pings): reproduced twice, its logcat shows
  "Stopping MaixCAM2 stream" but never "Leaving robot control, disconnecting WebSocket", with no error
  logged. `dispose` is byte-identical in both builds, and the new build logs both lines (also with a
  quiz open, check f), so this is a base-build problem whose cause was not found, not a change in
  commands. All motion, STOP and reconnect lines match line for line.

## Widget tests

`flutter test --dart-define=R2_PNG=true test/widgets/control_layout_test.dart` renders `widget/<size>-<state>-<mode>[-stopped].png`
(8 sizes × 3 link states × light/dark × STOPPED or not = 96 PNGs). The checks behind them are in
`test/widgets/control_layout_test.dart`.

## Phone (Motorola Edge 60 Fusion, USB)

Before: `com.boris.elio` versionName 1.0.0, updated 2 Nov 14:43 (the C1/theme debug build per HANDOFF).
Builds: debug APKs with `LIVE_SCAN=true TESTER_BUILD=true APP_COMMIT=<sha>` (base c38809d, new d6bbd37,
7551142, dd429ed). The Gemma model was moved out of `assets/models/` for the builds and moved back.
The owner session was used read-only. Records stayed at 27 scans / 222 trophies, and no quiz was
answered. The theme was switched to light for the light checks and set back to dark. The fake was
reached over `adb reverse tcp:8765`; no real robot, no movement. Screenshots are 1356 px JPEGs in `phone/`.

| Check | Result | Files |
|---|---|---|
| a. Joystick drives; let go = 0,0; gears, speed, arm faders, gripper, PICK UP / RELEASE / HOME = base lines | pass (see `fakelog.diff`) | `dark_connected` |
| b. STOP button and strip; motion blocked (only the let-go 0,0); Lanjutkan | pass, dark and light | `dark_stopped`, `light_stopped` |
| c. Kill the fake: disconnected design, STOPPED pill, real countdown ("Retrying in 2 s · attempt 4 of 30"); controls send nothing | pass | `dark_disconnected_retry` |
| d. Restart the fake: connected, STOP + motor 0,0 first, still STOPPED until Lanjutkan | pass. The waiting view only flashes (over `adb reverse` a connect attempt resolves at once) | `dark_reconnected_still_stopped` |
| e. Scan quiz opens; minimise; reopen with the yellow button | pass | `dark_quiz_open`, `dark_quiz_minimised_yellow_button`, `dark_quiz_reopened` |
| e. Scan lagi | not run: it needs a finished quiz, which would save a record in the owner's history | |
| f. Leaving Control with a quiz open disconnects (#78) | pass (logcat + fake `disconnect`) | |
| g. Avatar opens the drawer; History opens | pass | `dark_avatar_opens_drawer_cropped` (account row cropped out), `light_history_opens` |
| HUD with `dist_cm`: "Plastic · 25 cm", bands, ELIO tip "in the pick zone"; Scan quiz toggle off | pass. The first build blinked the tag (fixed in 7551142); band labels got a dark backing (dd429ed) | `dark_hud_dist_cm_tag_scanquiz_off`, `light_hud_bands_final` |
| h. Light and dark | pass | `light_connected_hud` |
| h. Rotate to portrait | not run: Control locks landscape on phones (unchanged code); portrait is covered by the 412x915 / 390x844 widget tests | |

Left on the phone: the R2 debug build dd429ed (tester flags), dark mode, at Home, `adb reverse` removed.
