# C1 Config screen: phone check (2 Nov 2026)

Device: motorola edge 60 fusion (ZP22233V8C), Android 16, USB. Build: arm64 **debug**,
`--dart-define=LIVE_SCAN=true`, debug-signed, installed with `adb install -r` over the tester build
(app data kept). The 2.59 GB model was moved out of `assets/models/` for the build and back after.
Screenshots: `adb exec-out screencap -p`, 540 px JPEG.

After this walk the owner chose to keep the old jump to Control after a successful connect; the build tested here stayed on Config, so the connected shots show the state before that change.

**Session:** the phone was signed in as the owner, not a guest. Signing out would have needed the
owner's password to undo, so it stayed signed in; no scan, quiz or record was made. Theme, camera
source and quiz source were changed for the walk and restored (light, MaixCAM2, bank); the saved
address stayed 192.168.4.1:8765 ("Save as default" was off for the test connects).

**Robot:** the phone had no Wi-Fi, so the fake MaixCAM (`tools/fake_maixcam`, Mac) was reached through
`adb reverse tcp:8765` at 127.0.0.1:8765, not over Wi-Fi. No real robot, no movement.

| Check | Result | Files |
|---|---|---|
| Not connected, light/dark | pass | `light_not_connected_1-3`, `dark_not_connected_1-2` |
| Connecting (fields locked, Cancel) | pass | `light_connecting`, `dark_connecting` |
| Failed: 192.168.4.1 unreachable | pass: "No answer from 192.168.4.1:8765 after 10 s", red fields, Try again, no snackbar (card visible) | `light_failed`, `dark_failed` |
| Connected to fake robot | pass: green hero, Online, Connected disabled, Disconnect enabled | `light_connected_1-2`, `dark_connected_1-2` |
| Robot lost, auto-reconnect on | pass: Connecting… + retry every 2 s | `light_robot_lost` |
| Cancel during reconnect | pass: no socket opened after Cancel | `light_cancel_stops_reconnect` |
| Background / foreground while connected | pass: still Connected, no new socket | `dark_connected_after_background` |
| Disconnect | pass: Not connected, no reconnect afterwards | `dark_after_disconnect` |
| Saved address after app restart | pass (192.168.4.1:8765) | `light_after_restart_restored` |
| ELIOS AI Activate → Loading → Active | pass: real model on GPU in 40 s | `light_ai_loading`, `light_ai_active`, `dark_ai_loading_phone_mode`, `dark_phone_camera_ai_active` |
| Quiz tiles: ELIOS AI needs a ready model | pass | `light_quiz_tiles_ai_ready`, `light_quiz_ai_selected` |
| Phone camera mode + Start scan | pass: scan screen opens, back returns to portrait | `dark_phone_camera_1-2`, `dark_start_scan_opens` |
| Settings sheet light/dark | pass, no Tampilan section | `light_settings_1-2`, `dark_settings_1-2` |
| logcat | no Flutter errors or exceptions from the app | |

Not checked on the phone: AI Error and Paused states (need a failing load or a hot phone; widget-tested),
light phone-camera mode, wrong-port refusal, auto-reconnect off (both covered by
`test/services/config_connection_test.dart`). The dark in-card divider fix came after these shots, so
`dark_settings_*` and `dark_*_connected_*` show the old invisible divider.
Seen, not in scope: the shell banner says "ELIO disconnected… connection was lost" also after a
deliberate Disconnect.
