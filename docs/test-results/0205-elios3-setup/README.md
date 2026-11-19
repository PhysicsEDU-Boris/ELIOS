# 0205 ELIOS 3 setup screen: phone check

- Date: 10 Nov 2026 · Motorola Edge 60 Fusion (1220×2712), USB · debug APK `APP_COMMIT=c36ca60`
  (`LIVE_SCAN`, `TESTER_BUILD`, `DARK_MODE_OPTION`), `adb install -r` (data kept)
- App state: Bahasa Indonesia, light (left as found). Fake MaixCAM2 (`tools/fake_maixcam`,
  `single_item_60s`) over `adb reverse tcp:8765`, IP `127.0.0.1`, "Simpan sebagai alamat bawaan"
  unticked so the owner's saved address (192.168.100.137) stayed unchanged.
- History: account file still 6 records (newest 17:18, before the test), 0 pending; it was
  rewritten at 18:04 by the cloud sync on Home. No scans were made.

| State | Light | Dark |
|---|---|---|
| Not connected (stage, steps current/todo/todo) | `light-off-1.jpg`, `light-off-2.jpg` | `dark-off-1.jpg` |
| Find ELIOS → "Ditemukan di 192.168.100.216" (real LAN search found the Mac's fake) | `light-find.jpg` | — |
| Connected: Online bubble, steps done/done/current, Online pill, Buka kontrol / Putuskan, video, quiz | `light-on-1..4.jpg` | `dark-on-1..4.jpg` |

Checked: connect opens Control as before; back shows Connected; reopening the page shows the live
address (fixed in `c36ca60`; before, it showed the saved one and a wrong "Found at"); Putuskan
disconnects and the steps go back to current/todo/todo.

Not checked: QR sheet contents (another session is redoing it), failed state on the phone (widget
tests cover it), 720p / FPS switches on the phone (widget test).
